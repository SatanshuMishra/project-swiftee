import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/services/updater/update_config.dart';

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
      const fixtures = 'test/fixtures/updater';
      late Directory temp;
      late StringBuffer output;
      late StringBuffer errors;
      late String signature;
      late String testKey;

      String write(String name, String contents) {
        final file = File('${temp.path}/$name')..writeAsStringSync(contents);
        return file.path;
      }

      String copyArtifact(String name) =>
          File('$fixtures/artifact.bin').copySync('${temp.path}/$name').path;

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
        copyArtifact('Swiftie.Quiz.app.tar.gz'),
        '--mac-sig',
        write('Swiftie.Quiz.app.tar.gz.sig', signature),
        '--win-exe',
        copyArtifact('Swiftie.Quiz_0.3.0_x64-setup.exe'),
        '--win-sig',
        write('Swiftie.Quiz_0.3.0_x64-setup.exe.sig', '$signature\n'),
        '--out',
        out,
      ];

      Future<int> run(List<String> arguments, {String? publicKey}) =>
          runMakeManifest(
            arguments,
            output: output,
            errors: errors,
            publicKey: publicKey ?? testKey,
          );

      setUp(() {
        temp = Directory.systemTemp.createTempSync('swiftie_manifest_');
        output = StringBuffer();
        errors = StringBuffer();
        signature = File('$fixtures/artifact.bin.sig')
            .readAsStringSync()
            .trim();
        testKey = File('$fixtures/test_key.pub').readAsStringSync().trim();
      });

      tearDown(() => temp.deleteSync(recursive: true));

      test('writes latest.json from signatures that verify', () async {
        final out = '${temp.path}/latest.json';

        final code = await run(arguments(out));

        Map<String, String> expectedEntry(String fileName) => {
          'signature': signature,
          'url': '$baseUrl/$fileName',
        };
        expect(code, 0, reason: errors.toString());
        expect(jsonDecode(File(out).readAsStringSync()), {
          ...expectedManifest,
          'platforms': {
            'darwin-aarch64': expectedEntry('Swiftie.Quiz.app.tar.gz'),
            'darwin-aarch64-app': expectedEntry('Swiftie.Quiz.app.tar.gz'),
            'windows-x86_64': expectedEntry('Swiftie.Quiz_0.3.0_x64-setup.exe'),
            'windows-x86_64-nsis': expectedEntry(
              'Swiftie.Quiz_0.3.0_x64-setup.exe',
            ),
          },
        });
        expect(File(out).readAsStringSync(), endsWith('}\n'));
      });

      test('refuses missing, unknown and repeated options', () async {
        final out = '${temp.path}/latest.json';
        final complete = arguments(out);

        for (final broken in [
          complete.sublist(0, complete.length - 2),
          [...complete, '--arch', 'x64'],
          [...complete, '--version', '0.3.1'],
          [...complete, '--out'],
        ]) {
          expect(await run(broken), 64, reason: broken.join(' '));
        }
        expect(File(out).existsSync(), isFalse);
        expect(errors.toString(), contains('::error::Missing --out'));
        expect(errors.toString(), contains('::error::Unknown option --arch'));
      });

      test('fails when a signature file is missing', () async {
        final out = '${temp.path}/latest.json';
        final broken = [
          for (final value in arguments(out))
            value.endsWith('.app.tar.gz.sig')
                ? '${temp.path}/missing.sig'
                : value,
        ];

        expect(await run(broken), 1);
        expect(errors.toString(), contains('missing.sig'));
        expect(File(out).existsSync(), isFalse);
      });

      test(
        'refuses a signature made with a key other than the update key',
        () async {
          final out = '${temp.path}/latest.json';

          final code = await run(arguments(out), publicKey: updaterPublicKey);

          expect(code, 1);
          expect(
            errors.toString(),
            contains(
              '::error::The signature of Swiftie.Quiz.app.tar.gz does not '
              "verify with the app's update key",
            ),
          );
          expect(File(out).existsSync(), isFalse);
        },
      );

      test('refuses an artifact changed after it was signed', () async {
        final out = '${temp.path}/latest.json';
        final complete = arguments(out);
        File('${temp.path}/Swiftie.Quiz_0.3.0_x64-setup.exe')
            .writeAsBytesSync([1, 2, 3], mode: FileMode.append);

        expect(await run(complete), 1);
        expect(
          errors.toString(),
          contains('The signature of Swiftie.Quiz_0.3.0_x64-setup.exe'),
        );
        expect(File(out).existsSync(), isFalse);
      });

      test('uses the update key of the app by default', () async {
        List<String> decodedLines(String tauriText) =>
            utf8.decode(base64.decode(tauriText.trim())).split('\n');
        final keyLine = base64.decode(decodedLines(updaterPublicKey)[1]);
        final signatureLines = decodedLines(signature);
        final signatureLine = base64.decode(signatureLines[1]);
        final claimingAppKey = base64.encode(
          utf8.encode(
            [
              signatureLines.first,
              base64.encode([
                ...signatureLine.sublist(0, 2),
                ...keyLine.sublist(2, 10),
                ...signatureLine.sublist(10),
              ]),
              ...signatureLines.sublist(2),
            ].join('\n'),
          ),
        );
        signature = claimingAppKey;
        final out = '${temp.path}/latest.json';

        final code = await runMakeManifest(
          arguments(out),
          output: output,
          errors: errors,
        );

        expect(code, 1);
        expect(
          errors.toString(),
          contains('The signature verification failed'),
        );
        expect(errors.toString(), isNot(contains('different key')));
        expect(File(out).existsSync(), isFalse);
      });
    });
  });
}
