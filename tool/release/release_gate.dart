import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

const ciWorkflowFile = 'ci.yml';
const ciOkJobName = 'CI OK';
const defaultPollInterval = Duration(seconds: 30);
const defaultMissingRunGrace = Duration(minutes: 10);
const defaultCiDeadline = Duration(minutes: 90);

final class GateFailure implements Exception {
  const GateFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

sealed class CiState {
  const CiState();
}

final class CiPassed extends CiState {
  const CiPassed();
}

final class CiPending extends CiState {
  const CiPending(this.detail);

  final String detail;
}

final class CiFailed extends CiState {
  const CiFailed(this.conclusion);

  final String conclusion;
}

bool isOnMain(String compareStatus) =>
    compareStatus == 'identical' || compareStatus == 'behind';

final class CiRun {
  const CiRun({
    required this.id,
    required this.status,
    required this.conclusion,
  });

  final int id;
  final String status;
  final String conclusion;
}

CiRun? latestPushRun(Map<String, Object?> runsResponse) {
  final runs = [
    for (final run in (runsResponse['workflow_runs'] as List?) ?? const [])
      if (run is Map && run['id'] is int && run['run_number'] is int) run,
  ];
  if (runs.isEmpty) {
    return null;
  }
  final newest = runs.reduce(
    (best, run) =>
        (run['run_number'] as int) > (best['run_number'] as int) ? run : best,
  );
  return CiRun(
    id: newest['id'] as int,
    status: '${newest['status']}',
    conclusion: '${newest['conclusion']}',
  );
}

CiState ciOkState(Map<String, Object?> jobsResponse) {
  final ciOk = [
    for (final job in (jobsResponse['jobs'] as List?) ?? const [])
      if (job is Map && job['name'] == ciOkJobName) job,
  ];
  if (ciOk.isEmpty) {
    return const CiPending('no $ciOkJobName job yet');
  }
  final job = ciOk.last;
  if (job['status'] != 'completed') {
    return CiPending('$ciOkJobName is ${job['status']}');
  }
  final conclusion = '${job['conclusion']}';
  return conclusion == 'success' ? const CiPassed() : CiFailed(conclusion);
}

bool isReleaseVersion(String version) =>
    RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version);

bool shouldBecomeLatest(String version, String? latestTag) {
  if (latestTag == null) {
    return true;
  }
  final latest = latestTag.startsWith('v') ? latestTag.substring(1) : latestTag;
  try {
    return Version.parse(version) > Version.parse(latest);
  } on FormatException {
    return true;
  }
}

final class GitHubApi {
  GitHubApi({
    required this.client,
    required this.repository,
    required this.token,
    this.baseUrl = 'https://api.github.com',
  });

  final http.Client client;
  final String repository;
  final String token;
  final String baseUrl;

  Map<String, String> get _headers => {
    'Accept': 'application/vnd.github+json',
    'Authorization': 'Bearer $token',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'swiftie-quiz-release',
  };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/repos/$repository/$path')
          .replace(queryParameters: query);

  Future<Map<String, Object?>?> getJson(
    String path, [
    Map<String, String>? query,
  ]) async {
    final response = await client.get(_uri(path, query), headers: _headers);
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      throw http.ClientException(
        'GET $path returned ${response.statusCode}',
        _uri(path, query),
      );
    }
    return (jsonDecode(response.body) as Map).cast<String, Object?>();
  }

  Future<Map<String, Object?>> patchJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await client.patch(
      _uri(path),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'PATCH $path returned ${response.statusCode}: ${response.body}',
        _uri(path),
      );
    }
    return (jsonDecode(response.body) as Map).cast<String, Object?>();
  }
}

Future<void> waitForCiOnMain({
  required GitHubApi api,
  required String sha,
  required StringSink log,
  required Future<void> Function(Duration) sleep,
  required DateTime Function() now,
  Duration pollInterval = defaultPollInterval,
  Duration missingRunGrace = defaultMissingRunGrace,
  Duration deadline = defaultCiDeadline,
}) async {
  final started = now();
  var confirmedOnMain = false;
  while (true) {
    final elapsed = now().difference(started);
    if (elapsed > deadline) {
      throw GateFailure(
        '$ciOkJobName on $sha did not finish within ${deadline.inMinutes} '
        'minutes; re-run CI on main, then re-run this release',
      );
    }
    try {
      if (!confirmedOnMain) {
        final compare = await api.getJson('compare/main...$sha');
        final position = '${compare?['status']}';
        if (!isOnMain(position)) {
          throw GateFailure(
            '$sha is not on main (compare status: $position); releases ship '
            'only from main',
          );
        }
        confirmedOnMain = true;
      }
      final runs = await api.getJson('actions/workflows/$ciWorkflowFile/runs', {
        'head_sha': sha,
        'event': 'push',
        'branch': 'main',
      });
      final run = runs == null ? null : latestPushRun(runs);
      if (run == null) {
        if (elapsed > missingRunGrace) {
          throw GateFailure(
            'No CI run on main exists for $sha. Tag the commit main pointed '
            'at after the merge, not a commit from the pull request branch',
          );
        }
        log.writeln('Waiting for CI on main to start for $sha');
      } else {
        final jobs = await api.getJson('actions/runs/${run.id}/jobs');
        switch (ciOkState(jobs ?? const {})) {
          case CiPassed():
            log.writeln('$ciOkJobName passed on main for $sha (run ${run.id})');
            return;
          case CiFailed(:final conclusion):
            throw GateFailure(
              '$ciOkJobName on $sha finished as $conclusion (run ${run.id}); '
              're-run CI on main, then re-run this release',
            );
          case CiPending() when run.status == 'completed':
            throw GateFailure(
              'CI run ${run.id} on main ended as ${run.conclusion} without a '
              '$ciOkJobName result; fix or re-run CI on main, then re-run '
              'this release',
            );
          case CiPending(:final detail):
            log.writeln('Waiting: $detail (run ${run.id})');
        }
      }
    } on http.ClientException catch (error) {
      log.writeln('GitHub API error, retrying: ${error.message}');
    } on SocketException catch (error) {
      log.writeln('Network error, retrying: ${error.message}');
    }
    await sleep(pollInterval);
  }
}

Future<String> publishRelease({
  required GitHubApi api,
  required int releaseId,
  required String version,
  required StringSink log,
}) async {
  if (!isReleaseVersion(version)) {
    throw GateFailure('$version is not a MAJOR.MINOR.PATCH release version');
  }
  final release = await api.getJson('releases/$releaseId');
  if (release == null) {
    throw GateFailure('Release $releaseId does not exist');
  }
  if (release['draft'] != true) {
    log.writeln('Release ${release['tag_name']} is already published');
    return 'already published';
  }
  final latest = await api.getJson('releases/latest');
  final makeLatest = shouldBecomeLatest(
    version,
    latest?['tag_name'] as String?,
  );
  final published = await api.patchJson('releases/$releaseId', {
    'draft': false,
    'prerelease': false,
    'make_latest': makeLatest ? 'true' : 'false',
  });
  final summary =
      'Published ${published['html_url']}'
      '${makeLatest ? ' as the latest release' : ' without replacing the latest release ${latest?['tag_name']}'}';
  log.writeln(summary);
  return summary;
}

String _requireEnvironment(Map<String, String> environment, String name) {
  final value = environment[name];
  if (value == null || value.isEmpty) {
    throw GateFailure('$name is not set');
  }
  return value;
}

Future<int> runReleaseGate(
  List<String> arguments, {
  required Map<String, String> environment,
  required http.Client client,
  required StringSink output,
  required StringSink errors,
  Future<void> Function(Duration) sleep = Future<void>.delayed,
  DateTime Function() now = DateTime.now,
}) async {
  if (arguments.length != 1 ||
      !const {'ci-passed', 'publish'}.contains(arguments.single)) {
    errors.writeln(
      'usage: dart run tool/release/release_gate.dart ci-passed|publish',
    );
    return 64;
  }
  try {
    final api = GitHubApi(
      client: client,
      repository: _requireEnvironment(environment, 'GITHUB_REPOSITORY'),
      token: _requireEnvironment(environment, 'GH_TOKEN'),
      baseUrl: environment['GITHUB_API_URL'] ?? 'https://api.github.com',
    );
    if (arguments.single == 'ci-passed') {
      await waitForCiOnMain(
        api: api,
        sha: _requireEnvironment(environment, 'SHA'),
        log: output,
        sleep: sleep,
        now: now,
      );
    } else {
      final releaseId = int.tryParse(
        _requireEnvironment(environment, 'RELEASE_ID'),
      );
      if (releaseId == null) {
        throw const GateFailure('RELEASE_ID is not a number');
      }
      await publishRelease(
        api: api,
        releaseId: releaseId,
        version: _requireEnvironment(environment, 'VERSION'),
        log: output,
      );
    }
    return 0;
  } on GateFailure catch (failure) {
    errors.writeln('::error::${failure.message}');
    return 1;
  } on http.ClientException catch (failure) {
    errors.writeln('::error::${failure.message}');
    return 1;
  }
}

Future<void> main(List<String> arguments) async {
  final client = http.Client();
  try {
    exitCode = await runReleaseGate(
      arguments,
      environment: Platform.environment,
      client: client,
      output: stdout,
      errors: stderr,
    );
  } finally {
    client.close();
  }
}
