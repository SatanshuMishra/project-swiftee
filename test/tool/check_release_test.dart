import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release/check_release.dart';

const productionKey =
    'dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk6IEU0NEZFQkM5NDVEQTlCRUYK'
    'UldUdm05cEZ5ZXRQNUs3a2RLYkpuUzU4cTVEN20yR1NpZE9iQXdiZWxOZDlQZC9Vczd1QUtMdDgK';

const pubspec = '''
name: swiftie_quiz
description: "A Taylor Swift trivia game"
publish_to: none
version: 0.3.0+1
''';

const changelog = '''
# Changelog

All notable changes to Swiftie Quiz are documented here.

## [0.3.0] - 2026-10-05

### Changed
- **Rewritten in Flutter.** Same game, same save.

- Updates arrive as before.


## [0.2.3] - 2026-10-05

### Fixed
- Update checks no longer repeat every few seconds.
''';

String updateConfigWith(String key) =>
    "import 'dart:core';\n\nconst updaterPublicKey = '$key';\n";

String developmentKey() => base64.encode(
  utf8.encode(
    'untrusted comment: minisign public key: 2A43CC33F3FB57BB\n'
    'RWS7V/MzzENDKpfjIc9P8Jw9yzOuKNTYOMaTE1wuFPyBnvDIrj29k6dX\n',
  ),
);

Matcher refusesWith(String text) => throwsA(
  isA<ReleaseCheckFailure>().having(
    (failure) => failure.message,
    'message',
    contains(text),
  ),
);

void main() {
  group('release checks', () {
    test('accepts a coherent release and returns its CHANGELOG section', () {
      final notes = checkRelease(
        tag: 'v0.3.0',
        pubspec: pubspec,
        changelog: changelog,
        updateConfig: updateConfigWith(productionKey),
      );

      expect(
        notes,
        '### Changed\n'
        '- **Rewritten in Flutter.** Same game, same save.\n'
        '\n'
        '- Updates arrive as before.',
      );
    });

    test('ignores the build number after + in pubspec.yaml', () {
      expect(pubspecVersion('version: 0.3.0+17\n'), '0.3.0');
      expect(pubspecVersion('version: 0.3.0\n'), '0.3.0');
      expect(pubspecVersion('name: a\nversion: "1.2.3+4"\n'), '1.2.3');
    });

    test('compares the tag without its leading v', () {
      expect(versionFromTag('v0.3.0'), '0.3.0');
      expect(versionFromTag('0.3.0'), '0.3.0');
    });

    test('refuses a tag that differs from pubspec.yaml', () {
      expect(
        () => checkRelease(
          tag: 'v0.3.1',
          pubspec: pubspec,
          changelog: changelog,
          updateConfig: updateConfigWith(productionKey),
        ),
        refusesWith('tag v0.3.1 is 0.3.1 but pubspec.yaml is 0.3.0'),
      );
    });

    test('refuses a pubspec.yaml without a version', () {
      expect(
        () => pubspecVersion('name: swiftie_quiz\n'),
        refusesWith('pubspec.yaml has no version'),
      );
    });

    test('refuses a release without a CHANGELOG heading for the version', () {
      expect(
        () => checkRelease(
          tag: 'v0.3.0',
          pubspec: pubspec,
          changelog: changelog.replaceFirst('## [0.3.0]', '## [Unreleased]'),
          updateConfig: updateConfigWith(productionKey),
        ),
        refusesWith('No CHANGELOG.md entry found for ## [0.3.0]'),
      );
    });

    test('does not mistake a longer version heading for the version', () {
      expect(
        () => changelogSection('## [0.3.0-beta.1]\n\n- Beta.\n', '0.3.0'),
        refusesWith('No CHANGELOG.md entry found for ## [0.3.0]'),
      );
    });

    test('refuses an empty CHANGELOG section', () {
      expect(
        () => changelogSection(
          '## [0.3.0] - 2026-10-05\n\n   \n\n## [0.2.3]\n\n- Fix.\n',
          '0.3.0',
        ),
        refusesWith('The CHANGELOG section for 0.3.0 is empty'),
      );
      expect(
        () => changelogSection('## [0.3.0]\n\n', '0.3.0'),
        refusesWith('The CHANGELOG section for 0.3.0 is empty'),
      );
    });

    test('reads the last section up to the end of the file', () {
      expect(
        changelogSection('## [0.3.0]\n\n### Added\n- Cats.\n\n', '0.3.0'),
        '### Added\n- Cats.',
      );
    });

    test('refuses when update_config.dart has no updaterPublicKey line', () {
      for (final source in [
        '',
        'const updaterPublicKey = "$productionKey";\n',
        "  const updaterPublicKey = '$productionKey';\n",
        "final updaterPublicKey = '$productionKey';\n",
      ]) {
        expect(
          () => checkUpdaterPublicKey(source),
          refusesWith('does not declare'),
          reason: source,
        );
      }
    });

    test('refuses an empty or implausibly short updater key', () {
      for (final key in ['', productionKey.substring(0, 63)]) {
        expect(
          () => checkUpdaterPublicKey(updateConfigWith(key)),
          refusesWith('empty or implausibly short'),
          reason: key,
        );
      }
    });

    test('refuses an updater key that is not base64', () {
      for (final key in [
        '${productionKey.substring(4)}!!!!',
        productionKey.substring(1),
        base64Url.encode(List<int>.filled(48, 0xFF)),
      ]) {
        expect(
          () => checkUpdaterPublicKey(updateConfigWith(key)),
          refusesWith('not valid base64'),
          reason: key,
        );
      }
    });

    test('refuses the development updater key', () {
      expect(
        () => checkRelease(
          tag: 'v0.3.0',
          pubspec: pubspec,
          changelog: changelog,
          updateConfig: updateConfigWith(developmentKey()),
        ),
        refusesWith('key ID 2A43CC33F3FB57BB'),
      );
    });

    test('accepts a production key of exactly the minimum length', () {
      final key = base64.encode(List<int>.filled(48, 65));

      expect(key.length, minimumPublicKeyLength);
      expect(
        () => checkUpdaterPublicKey(updateConfigWith(key)),
        returnsNormally,
      );
    });

    group('command line', () {
      late Directory root;
      late StringBuffer output;
      late StringBuffer errors;

      void writeRepoFile(String relativePath, String contents) {
        File('${root.path}/$relativePath')
          ..createSync(recursive: true)
          ..writeAsStringSync(contents);
      }

      setUp(() {
        root = Directory.systemTemp.createTempSync('swiftie_release_');
        output = StringBuffer();
        errors = StringBuffer();
        writeRepoFile('pubspec.yaml', pubspec);
        writeRepoFile('CHANGELOG.md', changelog);
        writeRepoFile(
          'lib/services/updater/update_config.dart',
          updateConfigWith(productionKey),
        );
      });

      tearDown(() => root.deleteSync(recursive: true));

      test('prints the release notes and succeeds', () {
        final code = runCheckRelease(
          ['v0.3.0'],
          root: root.path,
          output: output,
          errors: errors,
        );

        expect(code, 0);
        expect(errors.toString(), isEmpty);
        expect(
          output.toString(),
          '### Changed\n'
          '- **Rewritten in Flutter.** Same game, same save.\n'
          '\n'
          '- Updates arrive as before.\n',
        );
      });

      test('reports a refusal as a GitHub error annotation and fails', () {
        final code = runCheckRelease(
          ['v9.9.9'],
          root: root.path,
          output: output,
          errors: errors,
        );

        expect(code, 1);
        expect(output.toString(), isEmpty);
        expect(errors.toString(), startsWith('::error::Version drift'));
      });

      test('fails when the updater config file is missing', () {
        File('${root.path}/lib/services/updater/update_config.dart')
            .deleteSync();

        final code = runCheckRelease(
          ['v0.3.0'],
          root: root.path,
          output: output,
          errors: errors,
        );

        expect(code, 1);
        expect(errors.toString(), startsWith('::error::Cannot read'));
        expect(errors.toString(), contains('update_config.dart'));
      });

      test('requires exactly one tag argument', () {
        expect(
          runCheckRelease([], root: root.path, output: output, errors: errors),
          64,
        );
        expect(errors.toString(), contains('usage:'));
      });
    });
  });
}
