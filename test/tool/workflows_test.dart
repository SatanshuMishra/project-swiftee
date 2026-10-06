import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const ciPath = '.github/workflows/ci.yml';
const releasePath = '.github/workflows/release.yml';
const flutterAction = 'subosito/flutter-action@';
const entryPointCondition = "steps.app.outputs.present == 'true'";
const signCommand = 'npx --yes @tauri-apps/cli@2.12.1 signer sign';

YamlMap loadWorkflow(String path) =>
    loadYaml(File(path).readAsStringSync()) as YamlMap;

YamlMap triggers(YamlMap workflow) =>
    (workflow['on'] ?? workflow[true]) as YamlMap;

YamlMap jobsOf(YamlMap workflow) => workflow['jobs'] as YamlMap;

YamlMap job(YamlMap workflow, String id) {
  final found = jobsOf(workflow)[id];
  expect(found, isA<YamlMap>(), reason: 'job $id');
  return found as YamlMap;
}

List<YamlMap> stepsOf(YamlMap job) => [
  for (final step in (job['steps'] as YamlList?) ?? YamlList()) step as YamlMap,
];

List<String> needsOf(YamlMap job) => switch (job['needs']) {
  null => const [],
  final String single => [single],
  final YamlList many => [for (final need in many) need as String],
  final Object other => throw StateError('unexpected needs: $other'),
};

List<String> runsOf(YamlMap job) => [
  for (final step in stepsOf(job))
    if (step['run'] case final String command) command,
];

int indexOfStep(YamlMap job, bool Function(YamlMap step) test) =>
    stepsOf(job).indexWhere(test);

bool usesAction(YamlMap step, String prefix) =>
    step['uses'] is String && (step['uses'] as String).startsWith(prefix);

bool runsCommand(YamlMap step, String command) =>
    step['run'] is String && (step['run'] as String).contains(command);

List<YamlMap> matrixLegs(YamlMap job) => [
  for (final leg
      in (((job['strategy'] as YamlMap?)?['matrix'] as YamlMap?)?['include']
              as YamlList?) ??
          YamlList())
    leg as YamlMap,
];

String resolveMatrix(String text, YamlMap leg) => text.replaceAllMapped(
  RegExp(r'\$\{\{\s*matrix\.(\w+)\s*\}\}'),
  (match) => '${leg[match.group(1)!]}',
);

Map<String, String> legEnv(YamlMap job, YamlMap leg) => {
  for (final MapEntry(:key, :value) in (job['env'] as YamlMap).entries)
    if ('$value'.contains('matrix.')) '$key': resolveMatrix('$value', leg),
};

String resolveLeg(String text, YamlMap leg, Map<String, String> env) =>
    env.entries.fold(
      resolveMatrix(text, leg),
      (resolved, variable) => resolved.replaceAll(
        RegExp('\\\$\\{${variable.key}\\}|\\\$(env:)?${variable.key}(?!\\w)'),
        variable.value,
      ),
    );

List<String> allUses(YamlMap workflow) => [
  for (final entry in jobsOf(workflow).values)
    if ((entry as YamlMap)['uses'] case final String reusable) reusable,
  for (final entry in jobsOf(workflow).values)
    for (final step in stepsOf(entry as YamlMap))
      if (step['uses'] case final String action) action,
];

void main() {
  group('ci and release workflows', () {
    late YamlMap ci;
    late YamlMap release;
    late Map<String, String> sources;

    setUp(() {
      ci = loadWorkflow(ciPath);
      release = loadWorkflow(releasePath);
      sources = {
        ciPath: File(ciPath).readAsStringSync(),
        releasePath: File(releasePath).readAsStringSync(),
      };
    });

    test('CI runs on main pushes and pull requests', () {
      final on = triggers(ci);

      expect((on['push'] as YamlMap)['branches'], ['main']);
      expect(on.containsKey('pull_request'), isTrue);
      expect(on.containsKey('workflow_call'), isFalse);
      expect(sources[ciPath], isNot(contains('skip-bundle')));
      expect(ci['permissions'], {'contents': 'read'});
      expect(
        (ci['concurrency'] as YamlMap)['group'],
        "ci-\${{ github.ref }}-\${{ github.event_name == 'pull_request' "
        "&& 'pr' || github.sha }}",
      );
      expect(
        (ci['concurrency'] as YamlMap)['cancel-in-progress'],
        "\${{ github.event_name == 'pull_request' }}",
      );
    });

    test('CI OK needs every other CI job and fails on failure or '
        'cancellation', () {
      final jobs = jobsOf(ci);
      final aggregators = [
        for (final entry in jobs.entries)
          if ((entry.value as YamlMap)['name'] == 'CI OK') entry.key as String,
      ];

      expect(aggregators, ['ci-ok']);
      final ciOk = job(ci, 'ci-ok');
      expect(ciOk['if'], 'always()');
      expect(
        needsOf(ciOk).toSet(),
        {for (final id in jobs.keys) id as String}..remove('ci-ok'),
      );
      final check = runsOf(ciOk).single;
      expect(check, contains('.value.result == "failure"'));
      expect(check, contains('.value.result == "cancelled"'));
      expect(check, contains('exit 1'));
      expect(stepsOf(ciOk).single['env'], {'NEEDS': r'${{ toJSON(needs) }}'});
    });

    test('every third-party action is pinned to a full commit SHA with its '
        'version', () {
      final pinned = RegExp(r'^[\w.-]+/[\w.-]+(/[\w./-]+)?@[0-9a-f]{40}$');

      for (final workflow in [ci, release]) {
        final thirdParty = [
          for (final uses in allUses(workflow))
            if (!uses.startsWith('./')) uses,
        ];
        expect(thirdParty, isNotEmpty);
        for (final uses in thirdParty) {
          expect(uses, matches(pinned));
        }
      }
      for (final source in sources.entries) {
        final usesLines = [
          for (final line in source.value.split('\n'))
            if (RegExp(r'^\s*(- )?uses: [^.]').hasMatch(line)) line.trim(),
        ];
        expect(usesLines, isNotEmpty, reason: source.key);
        for (final line in usesLines) {
          expect(
            line,
            matches(RegExp(r'@[0-9a-f]{40} # v\d+(\.\d+)*$')),
            reason: source.key,
          );
        }
      }
    });

    test('every Flutter setup pins Flutter 3.47.5 stable', () {
      for (final workflow in [ci, release]) {
        final setups = [
          for (final entry in jobsOf(workflow).values)
            for (final step in stepsOf(entry as YamlMap))
              if (usesAction(step, flutterAction)) step,
        ];
        expect(setups, isNotEmpty);
        for (final setup in setups) {
          final settings = setup['with'] as YamlMap;
          expect(settings['flutter-version'], '3.47.5');
          expect(settings['channel'], 'stable');
        }
      }
    });

    test('every checkout leaves no credentials behind', () {
      for (final workflow in [ci, release]) {
        for (final entry in jobsOf(workflow).values) {
          for (final step in stepsOf(entry as YamlMap)) {
            if (usesAction(step, 'actions/checkout@')) {
              expect((step['with'] as YamlMap)['persist-credentials'], false);
            }
          }
        }
      }
    });

    test('Analyze and test runs format, analyze and tests on '
        'ubuntu-24.04', () {
      final analyze = job(ci, 'analyze');
      final steps = stepsOf(analyze);
      final setup = indexOfStep(analyze, (s) => usesAction(s, flutterAction));
      final pubGet = indexOfStep(analyze, (s) => s['run'] == 'flutter pub get');

      expect(analyze['name'], 'Analyze and test');
      expect(analyze['runs-on'], 'ubuntu-24.04');
      expect(usesAction(steps.first, 'actions/checkout@'), isTrue);
      expect((steps[setup]['with'] as YamlMap)['cache'], true);
      expect(pubGet, greaterThan(setup));
      expect(
        runsOf(analyze),
        containsAllInOrder([
          'flutter pub get',
          'dart format --output=none --set-exit-if-changed lib test tool',
          'flutter analyze --fatal-infos',
          'flutter test',
        ]),
      );
    });

    test('build jobs build and package on macos-26 and windows-2025', () {
      final macos = job(ci, 'build-macos');
      final windows = job(ci, 'build-windows');

      expect(macos['name'], 'Build (macos-26)');
      expect(macos['runs-on'], 'macos-26');
      expect(windows['name'], 'Build (windows-2025)');
      expect(windows['runs-on'], 'windows-2025');
      for (final build in [macos, windows]) {
        expect(needsOf(build), ['analyze']);
        expect(build['if'], isNull);
      }
      expect(runsOf(macos), contains('flutter build macos --release'));
      expect(
        runsOf(macos).where((run) => run.contains('package_macos.sh')),
        hasLength(1),
      );
      expect(
        runsOf(windows),
        contains('flutter build windows --release --dart-define=EDITION=ana'),
      );
      expect(
        runsOf(windows).where((run) => run.contains('choco install nsis -y')),
        hasLength(1),
      );
      expect(
        runsOf(windows).where((run) => run.contains('package_windows.ps1')),
        [contains('-Edition ana')],
      );
    });

    test('build artifacts upload for 14 days on non-fork events', () {
      final expectedPaths = {
        'build-macos': ['.dmg', '.app.tar.gz'],
        'build-windows': ['-setup.exe'],
      };
      for (final entry in expectedPaths.entries) {
        final upload = stepsOf(job(ci, entry.key))
            .singleWhere((s) => usesAction(s, 'actions/upload-artifact@'));
        final settings = upload['with'] as YamlMap;

        expect(settings['retention-days'], 14, reason: entry.key);
        expect(settings['if-no-files-found'], 'error', reason: entry.key);
        for (final suffix in entry.value) {
          expect(settings['path'], contains(suffix), reason: entry.key);
        }
        expect(
          upload['if'],
          contains(
            "github.event_name != 'pull_request' || "
            'github.event.pull_request.head.repo.full_name == '
            'github.repository',
          ),
        );
      }
    });

    test('build steps run only once the app entry point exists', () {
      for (final id in ['build-macos', 'build-windows']) {
        final steps = stepsOf(job(ci, id));
        final check = steps.indexWhere((s) => s['id'] == 'app');

        expect(check, 1, reason: id);
        expect(usesAction(steps.first, 'actions/checkout@'), isTrue);
        expect(steps[check]['if'], isNull);
        expect(steps[check]['run'], contains('lib/main.dart'));
        expect(
          steps[check]['run'],
          contains(r'present=true" >> "$GITHUB_OUTPUT'),
        );
        expect(
          steps[check]['run'],
          contains(r'present=false" >> "$GITHUB_OUTPUT'),
        );
        for (final step in steps.skip(check + 1)) {
          expect(
            step['if'],
            contains(entryPointCondition),
            reason: '$id $step',
          );
        }
      }
    });

    test('release runs on v tags and keeps every release job', () {
      final on = triggers(release);

      expect((on['push'] as YamlMap)['tags'], ['v*']);
      expect(release['permissions'], {'contents': 'read'});
      expect(jobsOf(release).keys.toSet(), {
        'validate-versions',
        'ci-passed',
        'create-release',
        'build-macos',
        'build-windows',
        'publish-manifest',
        'attest',
        'publish-release',
      });
      expect(needsOf(job(release, 'ci-passed')), ['validate-versions']);
      expect(
        needsOf(job(release, 'create-release')),
        containsAll(['validate-versions', 'ci-passed']),
      );
      expect(
        needsOf(job(release, 'build-macos')),
        containsAll(['validate-versions', 'create-release']),
      );
      expect(
        needsOf(job(release, 'build-windows')),
        containsAll(['validate-versions', 'create-release']),
      );
      expect(
        needsOf(job(release, 'publish-manifest')),
        containsAll(['create-release', 'build-macos', 'build-windows']),
      );
      expect(
        needsOf(job(release, 'attest')),
        containsAll(['build-macos', 'build-windows']),
      );
      expect(
        needsOf(job(release, 'publish-release')),
        containsAll(['validate-versions', 'publish-manifest', 'attest']),
      );
    });

    test('the macOS and Windows builds run side by side', () {
      expect(
        needsOf(job(release, 'build-windows')),
        isNot(contains('build-macos')),
      );
      expect(
        needsOf(job(release, 'build-macos')),
        isNot(contains('build-windows')),
      );
    });

    test('a release ships only a main commit whose CI OK passed, without '
        'running CI again', () {
      final gate = job(release, 'ci-passed');
      final step = stepsOf(gate)
          .singleWhere((s) => runsCommand(s, 'release_gate.dart'));

      expect(
        jobsOf(release).values.where((j) => (j as YamlMap)['uses'] != null),
        isEmpty,
      );
      expect(gate['permissions'], {'contents': 'read', 'actions': 'read'});
      expect(gate['timeout-minutes'], greaterThan(90));
      expect(step['run'], 'dart run tool/release/release_gate.dart ci-passed');
      expect(step['env'], {
        'GH_TOKEN': r'${{ github.token }}',
        'SHA': r'${{ github.sha }}',
      });
    });

    test('the release is created as a draft that is never overwritten once '
        'published', () {
      final create = runsOf(job(release, 'create-release')).single;

      expect(create, contains('-F draft=true'));
      expect(create, contains('already published; refusing'));
      expect(
        (job(release, 'create-release')['permissions'] as YamlMap)['contents'],
        'write',
      );
    });

    test('release tools run after Flutter is set up and packages are '
        'resolved', () {
      final tools = {
        'validate-versions': 'dart run tool/release/check_release.dart',
        'ci-passed': 'dart run tool/release/release_gate.dart ci-passed',
        'publish-manifest': 'dart run tool/release/make_manifest.dart',
        'publish-release': 'dart run tool/release/release_gate.dart publish',
      };
      for (final entry in tools.entries) {
        final current = job(release, entry.key);
        final setup = indexOfStep(current, (s) => usesAction(s, flutterAction));
        final pubGet = indexOfStep(
          current,
          (s) => s['run'] == 'flutter pub get',
        );
        final tool = indexOfStep(current, (s) => runsCommand(s, entry.value));

        expect(setup, isNonNegative, reason: entry.key);
        expect(pubGet, greaterThan(setup), reason: entry.key);
        expect(tool, greaterThan(pubGet), reason: entry.key);
      }
      final validate = job(release, 'validate-versions');
      expect(
        (validate['outputs'] as YamlMap)['release_notes'],
        r'${{ steps.check.outputs.notes }}',
      );
      expect(
        stepsOf(validate).singleWhere((s) => s['id'] == 'check')['run'],
        contains(r'NOTES_$(openssl rand -hex 16)'),
      );
    });

    test('release builds package, sign with the Tauri signer and upload to the '
        'draft release', () {
      final builds = {
        'build-macos': (
          runner: 'macos-26',
          build: 'flutter build macos --release --dart-define=EDITION=open',
          package: 'tool/release/package_macos.sh',
          signed: 'Project Swiftie.app.tar.gz',
        ),
        'build-windows': (
          runner: 'windows-2025',
          build: r'flutter build windows --release --dart-define=EDITION="$EDITION"',
          package: 'tool/release/package_windows.ps1',
          signed: r'${PRODUCT}_${VERSION}_x64-setup.exe',
        ),
      };
      for (final entry in builds.entries) {
        final build = job(release, entry.key);
        final steps = stepsOf(build);
        final sign = steps.indexWhere((s) => runsCommand(s, signCommand));
        final upload = steps.indexWhere(
          (s) => runsCommand(s, 'gh release upload'),
        );

        expect(build['runs-on'], entry.value.runner);
        expect(build['environment'], 'release');
        expect((build['permissions'] as YamlMap)['contents'], 'write');
        expect(runsOf(build), contains(entry.value.build));
        expect(
          steps.indexWhere((s) => runsCommand(s, entry.value.package)),
          lessThan(sign),
        );
        expect(steps[sign]['run'], contains(entry.value.signed));
        expect(steps[sign]['env'], {
          'TAURI_SIGNING_PRIVATE_KEY':
              r'${{ secrets.TAURI_SIGNING_PRIVATE_KEY }}',
          'TAURI_SIGNING_PRIVATE_KEY_PASSWORD':
              r'${{ secrets.TAURI_SIGNING_PRIVATE_KEY_PASSWORD }}',
        });
        expect(
          steps.where((s) => '${s['env']}'.contains('secrets.')),
          hasLength(1),
          reason: 'only the signing step sees the signing key',
        );
        expect('${build['env']}', isNot(contains('secrets.')));
        expect(
          steps.where((s) => usesAction(s, 'actions/setup-node@')),
          hasLength(1),
        );
        expect(upload, greaterThan(sign));
        expect(steps[upload]['run'], contains('--clobber'));
        for (final setup in steps.where((s) => usesAction(s, flutterAction))) {
          expect((setup['with'] as YamlMap)['cache'], false);
        }
      }
      expect(
        runsOf(job(release, 'build-windows'))
            .where((run) => run.contains('choco install nsis -y')),
        hasLength(1),
      );
    });

    test('latest.json is published from verified signatures and checked '
        'against the release assets', () {
      final manifestJob = job(release, 'publish-manifest');
      final publish = runsOf(manifestJob).join('\n');
      final steps = stepsOf(manifestJob);
      final upload = steps.indexWhere(
        (s) => runsCommand(s, 'gh release upload "\$TAG" latest.json'),
      );
      final verifyIndex = steps.indexWhere(
        (s) => runsCommand(s, 'latest.json is not publishable'),
      );
      final verify = steps[verifyIndex]['run'] as String;

      expect(publish, contains('--base-url "\$BASE_URL"'));
      expect(
        (steps.singleWhere((s) => runsCommand(s, 'make_manifest.dart'))['env']
            as YamlMap)['BASE_URL'],
        r'https://github.com/${{ github.repository }}/releases/download/'
        r'${{ github.ref_name }}',
      );
      expect(upload, isNonNegative);
      expect(verifyIndex, greaterThan(upload));
      for (final platform in [
        'darwin-aarch64',
        'darwin-aarch64-app',
        'windows-x86_64',
        'windows-x86_64-nsis',
        'windows-x86_64-open',
      ]) {
        expect(verify, contains(platform));
      }
      expect(verify, contains("--jq '.[].name'"));
      expect(verify, contains(r'expected="${TAG#v}"'));
      expect(verify, contains(r'grep -qxF -- "$name"'));
    });

    test('a verified release publishes itself with no manual step', () {
      final publish = job(release, 'publish-release');
      final step = stepsOf(publish)
          .singleWhere((s) => runsCommand(s, 'release_gate.dart'));

      expect(publish['environment'], isNull);
      expect(publish['permissions'], {'contents': 'write'});
      expect(step['run'], 'dart run tool/release/release_gate.dart publish');
      expect(step['env'], {
        'GH_TOKEN': r'${{ github.token }}',
        'RELEASE_ID': r'${{ needs.create-release.outputs.release_id }}',
        'VERSION': r'${{ needs.validate-versions.outputs.version }}',
      });
    });

    test('no release job or step can pass while a check it runs fails', () {
      for (final entry in jobsOf(release).entries) {
        final current = entry.value as YamlMap;
        expect(current['if'], isNull, reason: '${entry.key}');
        expect(current['continue-on-error'], isNull, reason: '${entry.key}');
        for (final step in stepsOf(current)) {
          expect(step['if'], isNull, reason: '${entry.key}: ${step['name']}');
          expect(
            step['continue-on-error'],
            isNull,
            reason: '${entry.key}: ${step['name']}',
          );
        }
      }
    });

    test('attestations cover the archive, the DMG and the setup '
        'executable', () {
      final attest = job(release, 'attest');
      final provenance = stepsOf(
        attest,
      ).singleWhere((s) => usesAction(s, 'actions/attest-build-provenance@'));
      final subjects =
          (provenance['with'] as YamlMap)['subject-path'] as String;

      expect(attest['permissions'], {
        'contents': 'read',
        'id-token': 'write',
        'attestations': 'write',
      });
      expect(subjects, contains('*.app.tar.gz'));
      expect(subjects, contains('*.dmg'));
      for (final edition in ['ana', 'open']) {
        expect(subjects, contains('artifacts/windows-$edition/**/*-setup.exe'));
        expect(
          stepsOf(attest).where(
            (s) =>
                usesAction(s, 'actions/download-artifact@') &&
                (s['with'] as YamlMap)['name'] == 'windows-$edition-bundles' &&
                (s['with'] as YamlMap)['path'] == 'artifacts/windows-$edition',
          ),
          hasLength(1),
          reason: edition,
        );
      }
    });

    test('the release builds macos open and both windows editions', () {
      final windows = job(release, 'build-windows');
      final legs = matrixLegs(windows);
      const products = {
        'ana': 'Project Swiftie',
        'open': 'Project Swiftie Open',
      };

      expect(
        runsOf(job(release, 'build-macos')),
        contains('flutter build macos --release --dart-define=EDITION=open'),
      );
      expect([for (final leg in legs) leg['edition']], ['ana', 'open']);
      for (final leg in legs) {
        final edition = leg['edition'] as String;
        final env = legEnv(windows, leg);
        final runs = [
          for (final run in runsOf(windows)) resolveLeg(run, leg, env),
        ];
        final upload = stepsOf(windows)
            .singleWhere((s) => usesAction(s, 'actions/upload-artifact@'));
        final uploadSettings = upload['with'] as YamlMap;

        expect(
          runs,
          contains(
            'flutter build windows --release --dart-define=EDITION="$edition"',
          ),
          reason: edition,
        );
        expect(runs.where((run) => run.contains('package_windows.ps1')), [
          contains('-Edition $edition'),
        ], reason: edition);
        expect(runs.where((run) => run.contains(signCommand)), [
          '$signCommand '
              '"build/release/${products[edition]}_\${VERSION}_x64-setup.exe"',
        ], reason: edition);
        expect(runs.where((run) => run.contains('gh release upload')), [
          contains('build/upload/*'),
        ], reason: edition);
        expect(
          resolveLeg('${uploadSettings['name']}', leg, env),
          'windows-$edition-bundles',
        );
        expect(uploadSettings['path'], contains('*-setup.exe'));
        expect(uploadSettings['path'], contains('*-setup.exe.sig'));
      }

      final manifestJob = job(release, 'publish-manifest');
      final manifestRun =
          stepsOf(
                manifestJob,
              ).singleWhere((s) => runsCommand(s, 'make_manifest.dart'))['run']
              as String;
      for (final edition in ['ana', 'open']) {
        expect(
          stepsOf(manifestJob).where(
            (s) =>
                usesAction(s, 'actions/download-artifact@') &&
                (s['with'] as YamlMap)['name'] == 'windows-$edition-bundles',
          ),
          hasLength(1),
          reason: edition,
        );
      }
      expect(
        manifestRun,
        contains('Project.Swiftie.Open_\${VERSION}_x64-setup.exe.sig'),
      );
      expect(manifestRun, contains('--win-open-exe "\${win_open_sig%.sig}"'));
      expect(manifestRun, contains('--win-open-sig "\$win_open_sig"'));
      expect(
        stepsOf(manifestJob).singleWhere(
          (s) => runsCommand(s, 'latest.json is not publishable'),
        )['run'],
        contains(
          'for platform in darwin-aarch64 darwin-aarch64-app windows-x86_64 '
          'windows-x86_64-nsis windows-x86_64-open; do',
        ),
      );
    });

    test('every job has a timeout', () {
      for (final workflow in [ci, release]) {
        for (final entry in jobsOf(workflow).entries) {
          final current = entry.value as YamlMap;
          if (current['uses'] == null) {
            expect(
              current['timeout-minutes'],
              isA<int>(),
              reason: '${entry.key}',
            );
          }
        }
      }
    });

    test('workflows carry no comments besides action version notes', () {
      final versionNote = RegExp(r'@[0-9a-f]{40} # v\d+(\.\d+)*$');
      for (final source in sources.entries) {
        final comments = [
          for (final line in source.value.split('\n'))
            if (line.trimLeft().startsWith('#') ||
                (line.contains(' # ') && !versionNote.hasMatch(line)))
              line,
        ];
        expect(comments, isEmpty, reason: source.key);
      }
    });
  });
}
