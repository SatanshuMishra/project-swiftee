import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../tool/release/release_gate.dart';

const repository = 'SatanshuMishra/project-swiftee';
const sha = '92b7e625358b662570f2f9227e41c9d1d4aef87a';
const prefix = '/repos/$repository';

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Map<String, Object?> runs(List<Map<String, Object?>> workflowRuns) => {
  'total_count': workflowRuns.length,
  'workflow_runs': workflowRuns,
};

Map<String, Object?> jobs(List<Map<String, Object?>> entries) => {
  'total_count': entries.length,
  'jobs': entries,
};

Map<String, Object?> ciOk(String status, [String? conclusion]) => {
  'name': 'CI OK',
  'status': status,
  'conclusion': conclusion,
};

const analyze = {
  'name': 'Analyze and test',
  'status': 'completed',
  'conclusion': 'success',
};

void main() {
  group('release gate decisions', () {
    test('only commits on main may ship', () {
      expect(isOnMain('identical'), isTrue);
      expect(isOnMain('behind'), isTrue);
      expect(isOnMain('ahead'), isFalse);
      expect(isOnMain('diverged'), isFalse);
      expect(isOnMain('null'), isFalse);
    });

    test('the newest push run of CI is the one that counts', () {
      expect(latestPushRunId(runs(const [])), isNull);
      expect(latestPushRunId(const {}), isNull);
      expect(
        latestPushRunId(
          runs(const [
            {'id': 11, 'run_number': 4},
            {'id': 12, 'run_number': 7},
            {'id': 13, 'run_number': 5},
          ]),
        ),
        12,
      );
    });

    test('CI OK passes only when it completed with success', () {
      expect(ciOkState(jobs([analyze])), isA<CiPending>());
      expect(ciOkState(jobs([analyze, ciOk('queued')])), isA<CiPending>());
      expect(ciOkState(jobs([analyze, ciOk('in_progress')])), isA<CiPending>());
      expect(
        ciOkState(jobs([analyze, ciOk('completed', 'success')])),
        isA<CiPassed>(),
      );
      for (final conclusion in ['failure', 'cancelled', 'skipped', 'null']) {
        final state = ciOkState(jobs([ciOk('completed', conclusion)]));
        expect(state, isA<CiFailed>(), reason: conclusion);
        expect((state as CiFailed).conclusion, conclusion);
      }
    });

    test('a release becomes latest only above the current latest', () {
      expect(shouldBecomeLatest('0.3.0', null), isTrue);
      expect(shouldBecomeLatest('0.3.0', 'v0.2.4'), isTrue);
      expect(shouldBecomeLatest('0.10.0', 'v0.9.9'), isTrue);
      expect(shouldBecomeLatest('0.3.0', 'v0.3.0'), isFalse);
      expect(shouldBecomeLatest('0.3.0', 'v0.3.1'), isFalse);
      expect(shouldBecomeLatest('0.2.5', 'v0.3.0'), isFalse);
    });

    test('only MAJOR.MINOR.PATCH versions are releases', () {
      expect(isReleaseVersion('0.3.0'), isTrue);
      expect(isReleaseVersion('10.20.30'), isTrue);
      expect(isReleaseVersion('0.4.0-rc.1'), isFalse);
      expect(isReleaseVersion('0.3'), isFalse);
      expect(isReleaseVersion('v0.3.0'), isFalse);
    });
  });

  group('waiting for CI on main', () {
    late DateTime clock;
    late int sleeps;
    late List<Uri> requests;
    late StringBuffer log;

    Future<void> sleep(Duration duration) async {
      clock = clock.add(duration);
      sleeps += 1;
    }

    GitHubApi api(Future<http.Response> Function(http.Request) handler) =>
        GitHubApi(
          client: MockClient((request) {
            requests = [...requests, request.url];
            return handler(request);
          }),
          repository: repository,
          token: 'test-token',
        );

    Future<void> wait(Future<http.Response> Function(http.Request) handler) =>
        waitForCiOnMain(
          api: api(handler),
          sha: sha,
          log: log,
          sleep: sleep,
          now: () => clock,
        );

    setUp(() {
      clock = DateTime.utc(2026, 10, 5, 12);
      sleeps = 0;
      requests = const [];
      log = StringBuffer();
    });

    test('passes when the push run of CI on main passed CI OK', () async {
      await wait((request) async {
        return switch (request.url.path) {
          '$prefix/compare/main...$sha' => json({'status': 'identical'}),
          '$prefix/actions/workflows/ci.yml/runs' => json(
            runs(const [
              {'id': 501, 'run_number': 9},
            ]),
          ),
          '$prefix/actions/runs/501/jobs' => json(
            jobs([analyze, ciOk('completed', 'success')]),
          ),
          _ => json({}, 404),
        };
      });

      expect(sleeps, 0);
      final runsQuery = requests.singleWhere(
        (uri) => uri.path.endsWith('/actions/workflows/ci.yml/runs'),
      );
      expect(runsQuery.queryParameters, {
        'head_sha': sha,
        'event': 'push',
        'branch': 'main',
      });
      expect(log.toString(), contains('CI OK passed on main'));
    });

    test('refuses a commit that is not on main', () async {
      for (final status in ['ahead', 'diverged']) {
        await expectLater(
          wait((request) async => json({'status': status})),
          throwsA(
            isA<GateFailure>().having(
              (failure) => failure.message,
              'message',
              contains('is not on main'),
            ),
          ),
        );
      }
    });

    test('waits while CI OK is pending, then passes', () async {
      var polls = 0;
      await wait((request) async {
        if (request.url.path.endsWith('/compare/main...$sha')) {
          return json({'status': 'behind'});
        }
        if (request.url.path.endsWith('/ci.yml/runs')) {
          return json(
            runs(const [
              {'id': 7, 'run_number': 3},
            ]),
          );
        }
        polls += 1;
        return json(
          jobs([
            if (polls < 3) ciOk('queued') else ciOk('completed', 'success'),
          ]),
        );
      });

      expect(sleeps, 2);
    });

    test('fails when CI OK failed or was cancelled', () async {
      for (final conclusion in ['failure', 'cancelled']) {
        await expectLater(
          wait((request) async {
            if (request.url.path.endsWith('/compare/main...$sha')) {
              return json({'status': 'identical'});
            }
            if (request.url.path.endsWith('/ci.yml/runs')) {
              return json(
                runs(const [
                  {'id': 7, 'run_number': 3},
                ]),
              );
            }
            return json(jobs([ciOk('completed', conclusion)]));
          }),
          throwsA(
            isA<GateFailure>().having(
              (failure) => failure.message,
              'message',
              contains('finished as $conclusion'),
            ),
          ),
        );
      }
    });

    test('fails clearly when main never ran CI for the commit', () async {
      await expectLater(
        wait((request) async {
          if (request.url.path.endsWith('/compare/main...$sha')) {
            return json({'status': 'behind'});
          }
          return json(runs(const []));
        }),
        throwsA(
          isA<GateFailure>().having(
            (failure) => failure.message,
            'message',
            contains('No CI run on main exists'),
          ),
        ),
      );
      expect(
        clock.difference(DateTime.utc(2026, 10, 5, 12)),
        greaterThan(defaultMissingRunGrace),
      );
      expect(
        clock.difference(DateTime.utc(2026, 10, 5, 12)),
        lessThan(defaultMissingRunGrace + const Duration(minutes: 1)),
      );
    });

    test('keeps waiting through GitHub API errors', () async {
      var failures = 0;
      await wait((request) async {
        if (request.url.path.endsWith('/compare/main...$sha')) {
          return json({'status': 'identical'});
        }
        if (failures < 2) {
          failures += 1;
          return json({'message': 'Server Error'}, 502);
        }
        if (request.url.path.endsWith('/ci.yml/runs')) {
          return json(
            runs(const [
              {'id': 7, 'run_number': 3},
            ]),
          );
        }
        return json(jobs([ciOk('completed', 'success')]));
      });

      expect(sleeps, 2);
      expect(log.toString(), contains('GitHub API error, retrying'));
    });

    test('gives up with a message when CI does not finish in time', () async {
      await expectLater(
        wait((request) async {
          if (request.url.path.endsWith('/compare/main...$sha')) {
            return json({'status': 'identical'});
          }
          if (request.url.path.endsWith('/ci.yml/runs')) {
            return json(
              runs(const [
                {'id': 7, 'run_number': 3},
              ]),
            );
          }
          return json(jobs([ciOk('in_progress')]));
        }),
        throwsA(
          isA<GateFailure>().having(
            (failure) => failure.message,
            'message',
            contains('did not finish within 90 minutes'),
          ),
        ),
      );
    });
  });

  group('publishing the release', () {
    late List<http.Request> requests;
    late StringBuffer log;

    GitHubApi api({
      required Map<String, Object?> release,
      required String? latestTag,
    }) => GitHubApi(
      client: MockClient((request) async {
        requests = [...requests, request];
        return switch ((request.method, request.url.path)) {
          ('GET', '$prefix/releases/42') => json(release),
          ('GET', '$prefix/releases/latest') =>
            latestTag == null
                ? json({'message': 'Not Found'}, 404)
                : json({'tag_name': latestTag}),
          ('PATCH', '$prefix/releases/42') => json({
            ...release,
            ...(jsonDecode(request.body) as Map).cast<String, Object?>(),
            'html_url': 'https://github.com/$repository/releases/tag/v0.3.0',
          }),
          _ => json({}, 404),
        };
      }),
      repository: repository,
      token: 'test-token',
    );

    Map<String, Object?> patchBody() => (jsonDecode(
      requests.singleWhere((request) => request.method == 'PATCH').body,
    ) as Map).cast<String, Object?>();

    setUp(() {
      requests = const [];
      log = StringBuffer();
    });

    test('publishes a newer version as the latest release', () async {
      await publishRelease(
        api: api(
          release: const {'draft': true, 'tag_name': 'v0.3.0'},
          latestTag: 'v0.2.4',
        ),
        releaseId: 42,
        version: '0.3.0',
        log: log,
      );

      expect(patchBody(), {
        'draft': false,
        'prerelease': false,
        'make_latest': 'true',
      });
      expect(log.toString(), contains('as the latest release'));
    });

    test('publishes the first release as the latest', () async {
      await publishRelease(
        api: api(
          release: const {'draft': true, 'tag_name': 'v0.3.0'},
          latestTag: null,
        ),
        releaseId: 42,
        version: '0.3.0',
        log: log,
      );

      expect(patchBody()['make_latest'], 'true');
    });

    test('never lets an older version replace the latest release', () async {
      await publishRelease(
        api: api(
          release: const {'draft': true, 'tag_name': 'v0.3.0'},
          latestTag: 'v0.3.1',
        ),
        releaseId: 42,
        version: '0.3.0',
        log: log,
      );

      expect(patchBody()['make_latest'], 'false');
      expect(patchBody()['draft'], false);
      expect(
        log.toString(),
        contains('without replacing the latest release v0.3.1'),
      );
    });

    test('leaves an already published release alone', () async {
      await publishRelease(
        api: api(
          release: const {'draft': false, 'tag_name': 'v0.3.0'},
          latestTag: 'v0.3.1',
        ),
        releaseId: 42,
        version: '0.3.0',
        log: log,
      );

      expect(requests.where((request) => request.method == 'PATCH'), isEmpty);
      expect(log.toString(), contains('already published'));
    });

    test('refuses a version that is not MAJOR.MINOR.PATCH', () async {
      await expectLater(
        publishRelease(
          api: api(
            release: const {'draft': true, 'tag_name': 'v0.4.0-rc.1'},
            latestTag: 'v0.3.0',
          ),
          releaseId: 42,
          version: '0.4.0-rc.1',
          log: log,
        ),
        throwsA(isA<GateFailure>()),
      );
      expect(requests, isEmpty);
    });
  });

  group('command line', () {
    test('rejects an unknown command', () async {
      final errors = StringBuffer();

      final code = await runReleaseGate(
        const ['ship'],
        environment: const {},
        client: MockClient((request) async => json({}, 404)),
        output: StringBuffer(),
        errors: errors,
      );

      expect(code, 64);
      expect(errors.toString(), contains('ci-passed|publish'));
    });

    test('reports a missing environment variable as an error', () async {
      final errors = StringBuffer();

      final code = await runReleaseGate(
        const ['publish'],
        environment: const {'GITHUB_REPOSITORY': repository, 'GH_TOKEN': 't'},
        client: MockClient((request) async => json({}, 404)),
        output: StringBuffer(),
        errors: errors,
      );

      expect(code, 1);
      expect(errors.toString(), contains('::error::RELEASE_ID is not set'));
    });

    test('publish runs end to end from the environment', () async {
      final output = StringBuffer();
      var patched = false;

      final code = await runReleaseGate(
        const ['publish'],
        environment: const {
          'GITHUB_REPOSITORY': repository,
          'GH_TOKEN': 'test-token',
          'RELEASE_ID': '42',
          'VERSION': '0.3.0',
        },
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test-token');
          if (request.method == 'PATCH') {
            patched = true;
            return json({'html_url': 'https://example.invalid/v0.3.0'});
          }
          return request.url.path.endsWith('/releases/42')
              ? json({'draft': true, 'tag_name': 'v0.3.0'})
              : json({'tag_name': 'v0.2.4'});
        }),
        output: output,
        errors: StringBuffer(),
      );

      expect(code, 0);
      expect(patched, isTrue);
    });
  });
}
