import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const scriptPath = 'tool/release/package_macos.sh';
const builtAppPath = 'build/macos/Build/Products/Release/Project Swiftie.app';
const packaging = Timeout(Duration(minutes: 4));

const builtPlist = {
  'CFBundleExecutable': 'Project Swiftie',
  'CFBundleIdentifier': 'com.swiftiequiz.desktop',
  'CFBundleName': 'Project Swiftie',
  'CFBundlePackageType': 'APPL',
  'CFBundleShortVersionString': '0.5.4',
};

const anaPlist = {
  'CFBundleDisplayName': 'Project Swiftie Ana',
  'CFBundleExecutable': 'Project Swiftie',
  'CFBundleIdentifier': 'com.swiftiequiz.desktop.ana',
  'CFBundleName': 'Project Swiftie Ana',
  'CFBundlePackageType': 'APPL',
  'CFBundleShortVersionString': '0.5.4',
};

const frameworkPlist = {
  'CFBundleExecutable': 'Fake',
  'CFBundleIdentifier': 'com.example.fake',
  'CFBundlePackageType': 'FMWK',
};

void writePlist(String path, Map<String, String> entries) {
  File(path).parent.createSync(recursive: true);
  File(path).writeAsStringSync(
    [
      '<?xml version="1.0" encoding="UTF-8"?>',
      '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
          '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
      '<plist version="1.0">',
      '<dict>',
      for (final MapEntry(:key, :value) in entries.entries) ...[
        '\t<key>$key</key>',
        '\t<string>$value</string>',
      ],
      '</dict>',
      '</plist>',
      '',
    ].join('\n'),
  );
}

void copyTrue(String path) {
  File(path).parent.createSync(recursive: true);
  File('/usr/bin/true').copySync(path);
}

void writeFakeBuiltApp(Directory root) {
  final contents = '${root.path}/$builtAppPath/Contents';
  writePlist('$contents/Info.plist', builtPlist);
  copyTrue('$contents/MacOS/Project Swiftie');
  final framework = '$contents/Frameworks/Fake.framework';
  copyTrue('$framework/Versions/A/Fake');
  writePlist('$framework/Versions/A/Resources/Info.plist', frameworkPlist);
  Link('$framework/Versions/Current').createSync('A');
  Link('$framework/Fake').createSync('Versions/Current/Fake');
  Link('$framework/Resources').createSync('Versions/Current/Resources');
}

String output(ProcessResult result) => '${result.stdout}\n${result.stderr}';

Future<ProcessResult> runScript(
  Directory root,
  List<String> arguments, {
  Map<String, String>? environment,
}) => Process.run(
  'bash',
  ['${root.path}/$scriptPath', ...arguments],
  workingDirectory: root.path,
  environment: environment,
);

List<String> lastLines(ProcessResult result, int count) {
  final lines = const LineSplitter()
      .convert(result.stdout as String)
      .where((line) => line.isNotEmpty)
      .toList();
  return lines.sublist(lines.length < count ? 0 : lines.length - count);
}

Future<Map<String, Object?>> readPlist(String path) async {
  final result = await Process.run('plutil', [
    '-convert',
    'json',
    '-o',
    '-',
    path,
  ]);
  expect(result.exitCode, 0, reason: output(result));
  return jsonDecode(result.stdout as String) as Map<String, Object?>;
}

Future<void> expectVerifies(String app) async {
  final result = await Process.run('codesign', [
    '--verify',
    '--deep',
    '--strict',
    app,
  ]);
  expect(result.exitCode, 0, reason: output(result));
}

Future<List<String>> listArchive(String archive) async {
  final result = await Process.run('tar', ['-tzf', archive]);
  expect(result.exitCode, 0, reason: output(result));
  return const LineSplitter()
      .convert(result.stdout as String)
      .where((line) => line.isNotEmpty)
      .toList();
}

Future<String> extractArchive(Directory root, String archive) async {
  final folder = Directory('${root.path}/extracted')..createSync();
  final result = await Process.run('tar', ['-xzf', archive, '-C', folder.path]);
  expect(result.exitCode, 0, reason: output(result));
  return folder.path;
}

Future<ProcessResult> hdiutil(
  List<String> Function(int attempt) arguments,
) async {
  for (var attempt = 1; ; attempt++) {
    final result = await Process.run('hdiutil', arguments(attempt));
    if (result.exitCode == 0 || attempt == 3) {
      return result;
    }
    await Future<void>.delayed(const Duration(seconds: 5));
  }
}

Future<void> withMountedImage(
  String image,
  Future<void> Function(String volume) inspect,
) async {
  final attach = await hdiutil(
    (_) => ['attach', '-readonly', '-nobrowse', '-noautoopen', image],
  );
  expect(attach.exitCode, 0, reason: output(attach));
  final mount = RegExp(
    r'/Volumes/.*$',
    multiLine: true,
  ).firstMatch(attach.stdout as String);
  expect(mount, isNotNull, reason: output(attach));
  final volume = mount!.group(0)!.trimRight();
  try {
    await inspect(volume);
  } finally {
    final detach = await hdiutil(
      (attempt) => ['detach', volume, if (attempt == 3) '-force'],
    );
    expect(detach.exitCode, 0, reason: output(detach));
  }
}

void expectApplicationsLink(String volume) {
  final link = '$volume/Applications';
  expect(FileSystemEntity.isLinkSync(link), isTrue, reason: link);
  expect(Link(link).targetSync(), '/Applications');
}

void main() {
  group('package_macos.sh', () {
    late Directory root;

    setUp(() {
      root = Directory(
        Directory.systemTemp
            .createTempSync('swiftie_package_macos_')
            .resolveSymbolicLinksSync(),
      );
      File('${root.path}/$scriptPath').parent.createSync(recursive: true);
      File(scriptPath).copySync('${root.path}/$scriptPath');
      writeFakeBuiltApp(root);
    });

    tearDown(() => root.deleteSync(recursive: true));

    test('packages the Ana edition as Project Swiftie Ana', () async {
      final result = await runScript(root, const ['0.5.4', 'ana']);

      expect(result.exitCode, 0, reason: output(result));
      final release = '${root.path}/build/release';
      final dmg = '$release/Project Swiftie Ana_0.5.4_aarch64.dmg';
      final archive = '$release/Project Swiftie Ana.app.tar.gz';
      expect(lastLines(result, 2), [dmg, archive]);
      expect(File(dmg).existsSync(), isTrue, reason: dmg);
      expect(File(archive).existsSync(), isTrue, reason: archive);

      final entries = await listArchive(archive);
      expect(entries, isNotEmpty);
      expect(entries, everyElement(startsWith('Project Swiftie Ana.app/')));

      final extracted = await extractArchive(root, archive);
      final extractedApp = '$extracted/Project Swiftie Ana.app';
      expect(await readPlist('$extractedApp/Contents/Info.plist'), anaPlist);
      await expectVerifies(extractedApp);

      await withMountedImage(dmg, (volume) async {
        expect(
          volume.split('/').last,
          matches(RegExp(r'^Project Swiftie Ana( \d+)?$')),
        );
        final mountedApp = '$volume/Project Swiftie Ana.app';
        expect(await readPlist('$mountedApp/Contents/Info.plist'), anaPlist);
        await expectVerifies(mountedApp);
        expectApplicationsLink(volume);
      });

      final built = await readPlist(
        '${root.path}/$builtAppPath/Contents/Info.plist',
      );
      expect(built, builtPlist);
      expect(built.containsKey('CFBundleDisplayName'), isFalse);
      expect(
        Directory('${root.path}/$builtAppPath/Contents/_CodeSignature')
            .existsSync(),
        isFalse,
      );
    }, timeout: packaging);

    test('packages the Open edition under its existing names', () async {
      final result = await runScript(root, const ['0.5.4', 'open']);

      expect(result.exitCode, 0, reason: output(result));
      final release = '${root.path}/build/release';
      final dmg = '$release/Project Swiftie_0.5.4_aarch64.dmg';
      final archive = '$release/Project Swiftie.app.tar.gz';
      expect(
        Directory(release)
            .listSync()
            .map((entry) => entry.path.split('/').last)
            .toList(),
        unorderedEquals([
          'Project Swiftie_0.5.4_aarch64.dmg',
          'Project Swiftie.app.tar.gz',
        ]),
      );
      expect(lastLines(result, 2), [dmg, archive]);

      final entries = await listArchive(archive);
      expect(entries, isNotEmpty);
      expect(entries, everyElement(startsWith('Project Swiftie.app/')));

      final extracted = await extractArchive(root, archive);
      final extractedApp = '$extracted/Project Swiftie.app';
      final plist = await readPlist('$extractedApp/Contents/Info.plist');
      expect(
        plist,
        containsPair('CFBundleIdentifier', 'com.swiftiequiz.desktop'),
      );
      expect(plist, containsPair('CFBundleName', 'Project Swiftie'));
      expect(plist, builtPlist);
      await expectVerifies(extractedApp);

      await withMountedImage(dmg, (volume) async {
        expect(
          volume.split('/').last,
          matches(RegExp(r'^Project Swiftie( \d+)?$')),
        );
        final mountedApp = '$volume/Project Swiftie.app';
        expect(Directory(mountedApp).existsSync(), isTrue, reason: mountedApp);
        expect(await readPlist('$mountedApp/Contents/Info.plist'), builtPlist);
        await expectVerifies(mountedApp);
        expectApplicationsLink(volume);
      });
    }, timeout: packaging);

    test('refuses a missing or unknown edition', () async {
      const refused = [
        ['0.5.4'],
        ['0.5.4', 'Ana'],
        ['0.5.4', 'OPEN'],
        ['0.5.4', 'windows'],
        ['0.5.4', 'open', 'extra'],
        ['v0.5.4', 'open'],
      ];

      for (final arguments in refused) {
        final result = await runScript(root, arguments);

        expect(result.exitCode, 64, reason: '$arguments\n${output(result)}');
        expect(
          result.stderr,
          allOf(contains('<version>'), contains('<ana|open>')),
          reason: '$arguments',
        );
        expect(
          Directory('${root.path}/build/release').existsSync(),
          isFalse,
          reason: '$arguments',
        );
      }
    }, timeout: packaging);

    test('packages an Ana build that already has a display name', () async {
      writePlist('${root.path}/$builtAppPath/Contents/Info.plist', {
        ...builtPlist,
        'CFBundleDisplayName': 'Project Swiftie',
      });

      final result = await runScript(root, const ['0.5.4', 'ana']);

      expect(result.exitCode, 0, reason: output(result));
      final archive =
          '${root.path}/build/release/Project Swiftie Ana.app.tar.gz';
      final extracted = await extractArchive(root, archive);
      final extractedApp = '$extracted/Project Swiftie Ana.app';
      final plist = await readPlist('$extractedApp/Contents/Info.plist');
      expect(plist, containsPair('CFBundleDisplayName', 'Project Swiftie Ana'));
      expect(plist, containsPair('CFBundleName', 'Project Swiftie Ana'));
      expect(
        plist,
        containsPair('CFBundleIdentifier', 'com.swiftiequiz.desktop.ana'),
      );
      expect(plist, containsPair('CFBundleExecutable', 'Project Swiftie'));
      await expectVerifies(extractedApp);
    }, timeout: packaging);

    test(
      'stops before packaging when the signed bundle does not verify',
      () async {
        final stubs = Directory('${root.path}/stubs')..createSync();
        final codesign = '${stubs.path}/codesign';
        final log = File('${stubs.path}/codesign.log');
        File(codesign).writeAsStringSync(
          [
            '#!/bin/sh',
            "log='${log.path}'",
            r'printf "%s\n" "$@" >> "$log"',
            r'echo "=== end of call" >> "$log"',
            r'for a in "$@"; do [ "$a" = "--verify" ] && exit 1; done',
            r'exec /usr/bin/codesign "$@"',
            '',
          ].join('\n'),
        );
        final chmod = await Process.run('chmod', ['755', codesign]);
        expect(chmod.exitCode, 0, reason: output(chmod));
        final environment = {
          'PATH': '${stubs.path}:${Platform.environment['PATH']}',
        };
        final builtApp = '${root.path}/$builtAppPath';
        final signedApp = {
          'ana': allOf(endsWith('/Project Swiftie Ana.app'), isNot(builtApp)),
          'open': equals(builtApp),
        };

        for (final edition in const ['ana', 'open']) {
          log.writeAsStringSync('');

          final result = await runScript(root, [
            '0.5.4',
            edition,
          ], environment: environment);

          expect(
            result.exitCode,
            isNot(anyOf(0, 64)),
            reason: '$edition\n${output(result)}',
          );
          expect(
            Directory('${root.path}/build/release').existsSync(),
            isFalse,
            reason: edition,
          );

          final calls = log
              .readAsStringSync()
              .split('=== end of call\n')
              .where((call) => call.isNotEmpty)
              .map(const LineSplitter().convert)
              .toList();
          final signs = calls.where((call) => call.contains('--sign'));
          final verifies = calls.where((call) => call.contains('--verify'));
          expect(signs, hasLength(1), reason: '$edition\n$calls');
          expect(verifies, hasLength(1), reason: '$edition\n$calls');
          expect(verifies.single.last, signs.single.last, reason: edition);
          expect(signs.single.last, signedApp[edition], reason: edition);
        }
      },
      timeout: packaging,
    );
  }, skip: Platform.isMacOS ? false : 'needs codesign, hdiutil and PlistBuddy');
}
