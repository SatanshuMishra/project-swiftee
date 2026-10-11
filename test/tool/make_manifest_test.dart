import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/services/updater/update_config.dart';

import '../../tool/release/make_manifest.dart';

const baseUrl =
    'https://github.com/SatanshuMishra/project-swiftee/releases/download/v0.3.0';
const macSignature =
    'dW50cnVzdGVkIGNvbW1lbnQ6IHNpZ25hdHVyZSBmcm9tIHRhdXJpIHNlY3JldCBrZXkKbWFj';
const macAnaSignature =
    'dW50cnVzdGVkIGNvbW1lbnQ6IHNpZ25hdHVyZSBmcm9tIHRhdXJpIHNlY3JldCBrZXkKYW5h';
const windowsSignature =
    'dW50cnVzdGVkIGNvbW1lbnQ6IHNpZ25hdHVyZSBmcm9tIHRhdXJpIHNlY3JldCBrZXkKd2lu';
const windowsOpenSignature =
    'dW50cnVzdGVkIGNvbW1lbnQ6IHNpZ25hdHVyZSBmcm9tIHRhdXJpIHNlY3JldCBrZXkKb3Blbg==';
const notes = '### Changed\n- **Rewritten in Flutter.** Same game, same save.';

const macArchive = SignedArtifact(
  fileName: 'Project.Swiftie.app.tar.gz',
  signature: macSignature,
);
const macAnaArchive = SignedArtifact(
  fileName: 'Project.Swiftie.Ana.app.tar.gz',
  signature: macAnaSignature,
);
const windowsInstaller = SignedArtifact(
  fileName: 'Project.Swiftie_0.3.0_x64-setup.exe',
  signature: windowsSignature,
);
const windowsOpenInstaller = SignedArtifact(
  fileName: 'Project.Swiftie.Open_0.3.0_x64-setup.exe',
  signature: windowsOpenSignature,
);

const expectedMac = {
  'signature': macSignature,
  'url': '$baseUrl/Project.Swiftie.app.tar.gz',
};
const expectedMacAna = {
  'signature': macAnaSignature,
  'url': '$baseUrl/Project.Swiftie.Ana.app.tar.gz',
};
const expectedWindows = {
  'signature': windowsSignature,
  'url': '$baseUrl/Project.Swiftie_0.3.0_x64-setup.exe',
};
const expectedWindowsOpen = {
  'signature': windowsOpenSignature,
  'url': '$baseUrl/Project.Swiftie.Open_0.3.0_x64-setup.exe',
};
const expectedManifest = {
  'version': '0.3.0',
  'notes': notes,
  'pub_date': '2026-10-05T12:00:00Z',
  'platforms': {
    'darwin-aarch64': expectedMac,
    'darwin-aarch64-app': expectedMac,
    'darwin-aarch64-ana': expectedMacAna,
    'windows-x86_64': expectedWindows,
    'windows-x86_64-nsis': expectedWindows,
    'windows-x86_64-open': expectedWindowsOpen,
  },
};

Map<String, Object> fixtureManifest({
  String pubDate = '2026-10-05T12:00:00Z',
  String base = baseUrl,
  SignedArtifact mac = macArchive,
  SignedArtifact macAna = macAnaArchive,
  SignedArtifact windows = windowsInstaller,
  SignedArtifact windowsOpen = windowsOpenInstaller,
}) => buildManifest(
  version: '0.3.0',
  notes: notes,
  pubDate: pubDate,
  baseUrl: base,
  macArchive: mac,
  macAnaArchive: macAna,
  windowsInstaller: windows,
  windowsOpenInstaller: windowsOpen,
);

Matcher throwsFormatMessage(String message) => throwsA(
  isA<FormatException>().having((error) => error.message, 'message', message),
);

void main() {
  group('latest.json carries every platform', () {
    test('writes version, notes, pub_date and the six platform keys', () {
      final encoded = encodeManifest(fixtureManifest());

      expect(jsonDecode(encoded), expectedManifest);
      expect(encoded, encodeManifest(expectedManifest));
    });

    test('the Open macOS keys share the Open archive, Ana has its own, and '
        'Windows keys share the setup exe', () {
      final platforms = fixtureManifest()['platforms']! as Map<String, Object>;

      expect(platforms.keys, [
        'darwin-aarch64',
        'darwin-aarch64-app',
        'darwin-aarch64-ana',
        'windows-x86_64',
        'windows-x86_64-nsis',
        'windows-x86_64-open',
      ]);
      expect(platforms['darwin-aarch64'], platforms['darwin-aarch64-app']);
      expect(platforms['darwin-aarch64-ana'], expectedMacAna);
      expect(
        platforms['darwin-aarch64-ana'],
        isNot(platforms['darwin-aarch64']),
      );
      expect(platforms['windows-x86_64'], platforms['windows-x86_64-nsis']);
    });

    test("the manifest maps each platform key to its edition's artefact", () {
      final platforms =
          buildManifest(
                version: '0.3.0',
                notes: notes,
                pubDate: '2026-10-05T12:00:00Z',
                baseUrl: baseUrl,
                macArchive: macArchive,
                macAnaArchive: macAnaArchive,
                windowsInstaller: windowsInstaller,
                windowsOpenInstaller: windowsOpenInstaller,
              )['platforms']!
              as Map<String, Map<String, String>>;

      expect(platforms.keys, [
        'darwin-aarch64',
        'darwin-aarch64-app',
        UpdatePlatform.macosAna.manifestKey,
        'windows-x86_64',
        'windows-x86_64-nsis',
        UpdatePlatform.windowsOpen.manifestKey,
      ]);
      expect(platforms, {
        'darwin-aarch64': expectedMac,
        'darwin-aarch64-app': expectedMac,
        UpdatePlatform.macosAna.manifestKey: expectedMacAna,
        'windows-x86_64': expectedWindows,
        'windows-x86_64-nsis': expectedWindows,
        UpdatePlatform.windowsOpen.manifestKey: expectedWindowsOpen,
      });
      for (final missing in [
        const SignedArtifact(fileName: '', signature: windowsOpenSignature),
        const SignedArtifact(
          fileName: 'Project.Swiftie.Open_0.3.0_x64-setup.exe',
          signature: '\n',
        ),
        windowsInstaller,
      ]) {
        expect(
          () => fixtureManifest(windowsOpen: missing),
          throwsFormatException,
          reason: missing.fileName,
        );
      }
      expect(
        () => parseOptions([
          for (final MapEntry(:key, :value) in {
            'version': '0.3.0',
            'notes-file': 'notes.md',
            'pub-date': '2026-10-05T12:00:00Z',
            'base-url': baseUrl,
            'mac-tar': macArchive.fileName,
            'mac-sig': '${macArchive.fileName}.sig',
            'win-exe': windowsInstaller.fileName,
            'win-sig': '${windowsInstaller.fileName}.sig',
            'out': 'latest.json',
          }.entries) ...['--$key', value],
        ]),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('--win-open-exe'), contains('--win-open-sig')),
          ),
        ),
      );
    });

    test('refuses a macOS Ana archive that is the Open archive', () {
      expect(
        () => fixtureManifest(
          macAna: const SignedArtifact(
            fileName: 'Project.Swiftie.app.tar.gz',
            signature: macAnaSignature,
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('Project.Swiftie.app.tar.gz'),
              contains('Open archive'),
            ),
          ),
        ),
      );
      for (final missing in [
        const SignedArtifact(fileName: '', signature: macAnaSignature),
        const SignedArtifact(
          fileName: 'Project.Swiftie.Ana.app.tar.gz',
          signature: '\n',
        ),
      ]) {
        expect(
          () => fixtureManifest(macAna: missing),
          throwsFormatException,
          reason: missing.fileName,
        );
      }
    });

    test('refuses a manifest whose macOS archives are swapped', () async {
      const fixtures = 'test/fixtures/updater';
      SignedArtifact named(String fileName, String signature) =>
          SignedArtifact(fileName: fileName, signature: signature);

      expect(
        () => buildManifest(
          version: '0.3.0',
          notes: 'notes',
          pubDate: '2026-10-05T12:00:00Z',
          baseUrl: baseUrl,
          macArchive: named('Project.Swiftie.Ana.app.tar.gz', 'c2lnLWFuYQ=='),
          macAnaArchive: named('Project.Swiftie.app.tar.gz', 'c2lnLW9wZW4='),
          windowsInstaller: named(
            'Project.Swiftie_0.3.0_x64-setup.exe',
            'c2lnLXdpbg==',
          ),
          windowsOpenInstaller: named(
            'Project.Swiftie.Open_0.3.0_x64-setup.exe',
            'c2lnLXdpbi1vcGVu',
          ),
        ),
        throwsFormatMessage(
          'darwin-aarch64 must point at Project.Swiftie.app.tar.gz, '
          'not Project.Swiftie.Ana.app.tar.gz',
        ),
      );

      final temp = Directory.systemTemp.createTempSync('swiftie_swap_');
      addTearDown(() => temp.deleteSync(recursive: true));
      final signature = File('$fixtures/artifact.bin.sig').readAsStringSync();
      final testKey = File('$fixtures/test_key.pub').readAsStringSync().trim();
      String artefact(String name) {
        File('$fixtures/artifact.bin').copySync('${temp.path}/$name');
        File('${temp.path}/$name.sig').writeAsStringSync(signature);
        return '${temp.path}/$name';
      }

      final open = artefact('Project.Swiftie.app.tar.gz');
      final ana = artefact('Project.Swiftie.Ana.app.tar.gz');
      final windows = artefact('Project.Swiftie_0.3.0_x64-setup.exe');
      final windowsOpen = artefact('Project.Swiftie.Open_0.3.0_x64-setup.exe');
      final notesFile = File('${temp.path}/notes.md')..writeAsStringSync('n\n');
      final out = '${temp.path}/latest.json';
      final errors = StringBuffer();

      final code = await runMakeManifest(
        [
          '--version',
          '0.3.0',
          '--notes-file',
          notesFile.path,
          '--pub-date',
          '2026-10-05T12:00:00Z',
          '--base-url',
          baseUrl,
          '--mac-tar',
          ana,
          '--mac-sig',
          '$ana.sig',
          '--mac-ana-tar',
          open,
          '--mac-ana-sig',
          '$open.sig',
          '--win-exe',
          windows,
          '--win-sig',
          '$windows.sig',
          '--win-open-exe',
          windowsOpen,
          '--win-open-sig',
          '$windowsOpen.sig',
          '--out',
          out,
        ],
        output: StringBuffer(),
        errors: errors,
        publicKey: testKey,
      );

      expect(code, 64, reason: errors.toString());
      expect(errors.toString(), contains('must point at'));
      expect(File(out).existsSync(), isFalse);
    });

    test('refuses an artefact under another key', () {
      for (final (build, message) in [
        (
          () => fixtureManifest(
            windowsOpen: const SignedArtifact(
              fileName: 'Project.Swiftie.Ana.app.tar.gz',
              signature: windowsOpenSignature,
            ),
          ),
          'windows-x86_64-open must point at '
              'Project.Swiftie.Open_0.3.0_x64-setup.exe, not '
              'Project.Swiftie.Ana.app.tar.gz',
        ),
        (
          () => fixtureManifest(
            macAna: const SignedArtifact(
              fileName: 'Project.Swiftie.Open_0.3.0_x64-setup.exe',
              signature: macAnaSignature,
            ),
          ),
          'darwin-aarch64-ana must point at Project.Swiftie.Ana.app.tar.gz, '
              'not Project.Swiftie.Open_0.3.0_x64-setup.exe',
        ),
        (
          () => fixtureManifest(
            windows: const SignedArtifact(
              fileName: 'Project.Swiftie.Open_0.3.0_x64-setup.exe',
              signature: windowsSignature,
            ),
            windowsOpen: const SignedArtifact(
              fileName: 'Project.Swiftie_0.3.0_x64-setup.exe',
              signature: windowsOpenSignature,
            ),
          ),
          'windows-x86_64 must point at Project.Swiftie_0.3.0_x64-setup.exe, '
              'not Project.Swiftie.Open_0.3.0_x64-setup.exe',
        ),
        (
          () => fixtureManifest(
            windows: const SignedArtifact(
              fileName: 'Project.Swiftie_0.2.9_x64-setup.exe',
              signature: windowsSignature,
            ),
          ),
          'windows-x86_64 must point at Project.Swiftie_0.3.0_x64-setup.exe, '
              'not Project.Swiftie_0.2.9_x64-setup.exe',
        ),
        (
          () => fixtureManifest(
            mac: const SignedArtifact(
              fileName: 'Project.Swiftie_0.3.0_x64-setup.exe',
              signature: macSignature,
            ),
          ),
          'darwin-aarch64 must point at Project.Swiftie.app.tar.gz, '
              'not Project.Swiftie_0.3.0_x64-setup.exe',
        ),
      ]) {
        expect(build, throwsFormatMessage(message), reason: message);
      }
    });

    test('keeps the identical-name refusals', () {
      expect(
        () => fixtureManifest(
          macAna: const SignedArtifact(
            fileName: 'Project.Swiftie.app.tar.gz',
            signature: macAnaSignature,
          ),
        ),
        throwsFormatMessage(
          'The Ana archive Project.Swiftie.app.tar.gz is the Open archive',
        ),
      );
      expect(
        () => fixtureManifest(
          windowsOpen: const SignedArtifact(
            fileName: 'Project.Swiftie_0.3.0_x64-setup.exe',
            signature: windowsOpenSignature,
          ),
        ),
        throwsFormatMessage(
          'The Open installer Project.Swiftie_0.3.0_x64-setup.exe is the Ana '
          'installer',
        ),
      );
    });

    test('refuses a command line without the macOS Ana archive', () {
      expect(
        () => parseOptions([
          for (final MapEntry(:key, :value) in {
            'version': '0.3.0',
            'notes-file': 'notes.md',
            'pub-date': '2026-10-05T12:00:00Z',
            'base-url': baseUrl,
            'mac-tar': macArchive.fileName,
            'mac-sig': '${macArchive.fileName}.sig',
            'win-exe': windowsInstaller.fileName,
            'win-sig': '${windowsInstaller.fileName}.sig',
            'win-open-exe': windowsOpenInstaller.fileName,
            'win-open-sig': '${windowsOpenInstaller.fileName}.sig',
            'out': 'latest.json',
          }.entries) ...['--$key', value],
        ]),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('--mac-ana-tar'), contains('--mac-ana-sig')),
          ),
        ),
      );
    });

    test('percent-encodes file names in the release download URL', () {
      String urlOf(String fileName, String signature) => platformEntry(
        baseUrl,
        SignedArtifact(fileName: fileName, signature: signature),
      )['url']!;

      expect(
        urlOf('Project Swiftie.app.tar.gz', macSignature),
        '$baseUrl/Project%20Swiftie.app.tar.gz',
      );
      expect(
        urlOf('Project Swiftie Ana.app.tar.gz', macAnaSignature),
        '$baseUrl/Project%20Swiftie%20Ana.app.tar.gz',
      );
      expect(
        urlOf('Project Swiftie Open_0.3.0_x64-setup.exe', windowsOpenSignature),
        '$baseUrl/Project%20Swiftie%20Open_0.3.0_x64-setup.exe',
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
                  fileName: 'Project.Swiftie.app.tar.gz',
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
            fileName: 'Project.Swiftie_0.3.0_x64-setup.exe',
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
        copyArtifact('Project.Swiftie.app.tar.gz'),
        '--mac-sig',
        write('Project.Swiftie.app.tar.gz.sig', signature),
        '--mac-ana-tar',
        copyArtifact('Project.Swiftie.Ana.app.tar.gz'),
        '--mac-ana-sig',
        write('Project.Swiftie.Ana.app.tar.gz.sig', '$signature\n'),
        '--win-exe',
        copyArtifact('Project.Swiftie_0.3.0_x64-setup.exe'),
        '--win-sig',
        write('Project.Swiftie_0.3.0_x64-setup.exe.sig', '$signature\n'),
        '--win-open-exe',
        copyArtifact('Project.Swiftie.Open_0.3.0_x64-setup.exe'),
        '--win-open-sig',
        write('Project.Swiftie.Open_0.3.0_x64-setup.exe.sig', '$signature\n'),
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
        final written =
            jsonDecode(File(out).readAsStringSync()) as Map<String, Object?>;
        expect(written, {
          ...expectedManifest,
          'notes': "Changed\n• Rewritten in Flutter. Same game, same save.",
          'platforms': {
            'darwin-aarch64': expectedEntry('Project.Swiftie.app.tar.gz'),
            'darwin-aarch64-app': expectedEntry('Project.Swiftie.app.tar.gz'),
            'darwin-aarch64-ana': expectedEntry(
              'Project.Swiftie.Ana.app.tar.gz',
            ),
            'windows-x86_64': expectedEntry(
              'Project.Swiftie_0.3.0_x64-setup.exe',
            ),
            'windows-x86_64-nsis': expectedEntry(
              'Project.Swiftie_0.3.0_x64-setup.exe',
            ),
            'windows-x86_64-open': expectedEntry(
              'Project.Swiftie.Open_0.3.0_x64-setup.exe',
            ),
          },
        });
        expect((written['platforms']! as Map<String, Object?>).keys, [
          'darwin-aarch64',
          'darwin-aarch64-app',
          'darwin-aarch64-ana',
          'windows-x86_64',
          'windows-x86_64-nsis',
          'windows-x86_64-open',
        ]);
        expect(File(out).readAsStringSync(), endsWith('}\n'));
      });

      test('writes each signature under its own key', () async {
        final out = '${temp.path}/latest.json';
        final complete = arguments(out);
        final lines = utf8.decode(base64.decode(signature)).split('\n');
        String commented(String comment) => base64.encode(
          utf8.encode(
            ['untrusted comment: $comment', ...lines.skip(1)].join('\n'),
          ),
        );
        final mac = commented('mac');
        final macAna = commented('mac-ana');
        final win = commented('win');
        final winOpen = commented('win-open');
        for (final (name, text) in [
          ('Project.Swiftie.app.tar.gz', mac),
          ('Project.Swiftie.Ana.app.tar.gz', macAna),
          ('Project.Swiftie_0.3.0_x64-setup.exe', win),
          ('Project.Swiftie.Open_0.3.0_x64-setup.exe', winOpen),
        ]) {
          write('$name.sig', '$text\n');
        }

        final code = await run(complete);

        expect(code, 0, reason: errors.toString());
        expect({mac, macAna, win, winOpen}, hasLength(4));
        final written =
            jsonDecode(File(out).readAsStringSync()) as Map<String, Object?>;
        final platforms = written['platforms']! as Map<String, Object?>;
        expect(
          {
            for (final MapEntry(:key, :value) in platforms.entries)
              key: (value! as Map<String, Object?>)['signature'],
          },
          {
            'darwin-aarch64': mac,
            'darwin-aarch64-app': mac,
            'darwin-aarch64-ana': macAna,
            'windows-x86_64': win,
            'windows-x86_64-nsis': win,
            'windows-x86_64-open': winOpen,
          },
        );
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
              '::error::The signature of Project.Swiftie.app.tar.gz does not '
              "verify with the app's update key",
            ),
          );
          expect(File(out).existsSync(), isFalse);
        },
      );

      for (final installer in [
        'Project.Swiftie_0.3.0_x64-setup.exe',
        'Project.Swiftie.Open_0.3.0_x64-setup.exe',
      ]) {
        test('refuses $installer changed after it was signed', () async {
          final out = '${temp.path}/latest.json';
          final complete = arguments(out);
          File('${temp.path}/$installer')
              .writeAsBytesSync([1, 2, 3], mode: FileMode.append);

          expect(await run(complete), 1);
          expect(errors.toString(), contains('The signature of $installer'));
          expect(File(out).existsSync(), isFalse);
        });
      }

      test(
        'refuses Project.Swiftie.Ana.app.tar.gz changed after it was signed',
        () async {
          final out = '${temp.path}/latest.json';
          final complete = arguments(out);
          File('${temp.path}/Project.Swiftie.Ana.app.tar.gz')
              .writeAsBytesSync([1, 2, 3], mode: FileMode.append);

          expect(await run(complete), 1);
          expect(
            errors.toString(),
            contains('The signature of Project.Swiftie.Ana.app.tar.gz'),
          );
          expect(File(out).existsSync(), isFalse);
        },
      );

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
