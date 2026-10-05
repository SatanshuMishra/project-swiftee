import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release/make_manifest.dart';

const baseUrl =
    'https://github.com/SatanshuMishra/project-swiftee/releases/download/v0.3.0';
const macSignature =
    'dW50cnVzdGVkIGNvbW1lbnQ6IHNpZ25hdHVyZSBmcm9tIHRhdXJpIHNlY3JldCBrZXkKbWFj';
const windowsSignature =
    'dW50cnVzdGVkIGNvbW1lbnQ6IHNpZ25hdHVyZSBmcm9tIHRhdXJpIHNlY3JldCBrZXkKd2lu';
const notes = '### Changed\n- **Rewritten in Flutter.** Same game, same save.';

const macArchive = SignedArtifact(
  fileName: 'Swiftie.Quiz.app.tar.gz',
  signature: macSignature,
);
const windowsInstaller = SignedArtifact(
  fileName: 'Swiftie.Quiz_0.3.0_x64-setup.exe',
  signature: windowsSignature,
);

const expectedMac = {
  'signature': macSignature,
  'url': '$baseUrl/Swiftie.Quiz.app.tar.gz',
};
const expectedWindows = {
  'signature': windowsSignature,
  'url': '$baseUrl/Swiftie.Quiz_0.3.0_x64-setup.exe',
};
const expectedManifest = {
  'version': '0.3.0',
  'notes': notes,
  'pub_date': '2026-10-05T12:00:00Z',
  'platforms': {
    'darwin-aarch64': expectedMac,
    'darwin-aarch64-app': expectedMac,
    'windows-x86_64': expectedWindows,
    'windows-x86_64-nsis': expectedWindows,
  },
};

Map<String, Object> fixtureManifest({
  String pubDate = '2026-10-05T12:00:00Z',
  String base = baseUrl,
  SignedArtifact mac = macArchive,
  SignedArtifact windows = windowsInstaller,
}) => buildManifest(
  version: '0.3.0',
  notes: notes,
  pubDate: pubDate,
  baseUrl: base,
  macArchive: mac,
  windowsInstaller: windows,
);

void main() {
  group('latest.json carries every platform', () {
    test('writes version, notes, pub_date and the four Tauri platform '
        'keys', () {
      expect(jsonDecode(encodeManifest(fixtureManifest())), expectedManifest);
    });

    test('macOS keys share the .app.tar.gz and Windows keys share the setup '
        'exe', () {
      final platforms = fixtureManifest()['platforms']! as Map<String, Object>;

      expect(platforms.keys, [
        'darwin-aarch64',
        'darwin-aarch64-app',
        'windows-x86_64',
        'windows-x86_64-nsis',
      ]);
      expect(platforms['darwin-aarch64'], platforms['darwin-aarch64-app']);
      expect(platforms['windows-x86_64'], platforms['windows-x86_64-nsis']);
    });

    test('percent-encodes file names in the release download URL', () {
      final platforms =
          fixtureManifest(
                mac: const SignedArtifact(
                  fileName: 'Swiftie Quiz.app.tar.gz',
                  signature: macSignature,
                ),
                windows: const SignedArtifact(
                  fileName: 'Swiftie Quiz_0.3.0_x64-setup.exe',
                  signature: windowsSignature,
                ),
              )['platforms']!
              as Map<String, Map<String, String>>;

      expect(
        platforms['darwin-aarch64']!['url'],
        '$baseUrl/Swiftie%20Quiz.app.tar.gz',
      );
      expect(
        platforms['windows-x86_64-nsis']!['url'],
        '$baseUrl/Swiftie%20Quiz_0.3.0_x64-setup.exe',
      );
    });

    test('accepts a base URL with a trailing slash', () {
      final platforms =
          fixtureManifest(base: '$baseUrl/')['platforms']!
              as Map<String, Map<String, String>>;

      expect(platforms['darwin-aarch64']!['url'], expectedMac['url']);
    });

    test('uses the signature file text without its line break', () {
      final platforms =
          fixtureManifest(
                mac: const SignedArtifact(
                  fileName: 'Swiftie.Quiz.app.tar.gz',
                  signature: '$macSignature\n',
                ),
              )['platforms']!
              as Map<String, Map<String, String>>;

      expect(platforms['darwin-aarch64']!['signature'], macSignature);
    });

    test('refuses an empty signature or a non RFC 3339 date', () {
      expect(
        () => fixtureManifest(
          windows: const SignedArtifact(
            fileName: 'Swiftie.Quiz_0.3.0_x64-setup.exe',
            signature: '\n',
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => fixtureManifest(pubDate: '2026-10-05 12:00'),
        throwsFormatException,
      );
      expect(
        () => fixtureManifest(pubDate: '2026-10-05T12:00:00.123+02:00'),
        returnsNormally,
      );
    });

    test('the manifest cannot be changed after it is built', () {
      final manifest = fixtureManifest();

      expect(() => manifest['version'] = '9.9.9', throwsUnsupportedError);
    });

    group('command line', () {
      late Directory temp;
      late StringBuffer output;
      late StringBuffer errors;

      String write(String name, String contents) {
        final file = File('${temp.path}/$name')..writeAsStringSync(contents);
        return file.path;
      }

      List<String> arguments(String out) => [
        '--version',
        '0.3.0',
        '--notes-file',
        write('notes.md', '$notes\n'),
        '--pub-date',
        '2026-10-05T12:00:00Z',
        '--base-url',
        baseUrl,
        '--mac-tar',
        'artifacts/macos/Swiftie.Quiz.app.tar.gz',
        '--mac-sig',
        write('Swiftie.Quiz.app.tar.gz.sig', macSignature),
        '--win-exe',
        'artifacts/windows/Swiftie.Quiz_0.3.0_x64-setup.exe',
        '--win-sig',
        write('Swiftie.Quiz_0.3.0_x64-setup.exe.sig', '$windowsSignature\n'),
        '--out',
        out,
      ];

      setUp(() {
        temp = Directory.systemTemp.createTempSync('swiftie_manifest_');
        output = StringBuffer();
        errors = StringBuffer();
      });

      tearDown(() => temp.deleteSync(recursive: true));

      test('writes latest.json from the signature files', () {
        final out = '${temp.path}/latest.json';

        final code = runMakeManifest(
          arguments(out),
          output: output,
          errors: errors,
        );

        expect(code, 0, reason: errors.toString());
        expect(jsonDecode(File(out).readAsStringSync()), expectedManifest);
        expect(File(out).readAsStringSync(), endsWith('}\n'));
      });

      test('refuses missing, unknown and repeated options', () {
        final out = '${temp.path}/latest.json';
        final complete = arguments(out);

        for (final broken in [
          complete.sublist(0, complete.length - 2),
          [...complete, '--arch', 'x64'],
          [...complete, '--version', '0.3.1'],
          [...complete, '--out'],
        ]) {
          expect(
            runMakeManifest(broken, output: output, errors: errors),
            64,
            reason: broken.join(' '),
          );
        }
        expect(File(out).existsSync(), isFalse);
        expect(errors.toString(), contains('::error::Missing --out'));
        expect(errors.toString(), contains('::error::Unknown option --arch'));
      });

      test('fails when a signature file is missing', () {
        final out = '${temp.path}/latest.json';
        final broken = [
          for (final value in arguments(out))
            value.endsWith('.app.tar.gz.sig')
                ? '${temp.path}/missing.sig'
                : value,
        ];

        expect(runMakeManifest(broken, output: output, errors: errors), 1);
        expect(errors.toString(), contains('missing.sig'));
        expect(File(out).existsSync(), isFalse);
      });
    });
  });
}
