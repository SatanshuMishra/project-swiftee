import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swiftie_quiz/services/updater/update_installer.dart';

const _directoryMode = 0x1ed;
const _executableMode = 0x1ed;
const _fileMode = 0x1a4;

ArchiveFile _directory(String name) =>
    ArchiveFile.directory(name)..mode = _directoryMode;

ArchiveFile _file(String name, String content, {int mode = _fileMode}) =>
    ArchiveFile.bytes(name, utf8.encode(content))..mode = mode;

ArchiveFile _link(String name, String target) =>
    ArchiveFile.symlink(name, target);

Uint8List _tarGz(List<ArchiveFile> entries) {
  final archive = Archive();
  for (final entry in entries) {
    archive.addFile(entry);
  }
  return const GZipEncoder().encodeBytes(TarEncoder().encodeBytes(archive));
}

Uint8List _appArchive({String topFolder = 'Swiftie Quiz.app'}) => _tarGz([
  _directory('$topFolder/'),
  _directory('$topFolder/Contents/'),
  _file('$topFolder/Contents/Info.plist', 'new info'),
  _directory('$topFolder/Contents/MacOS/'),
  _file(
    '$topFolder/Contents/MacOS/swiftie-quiz',
    'new binary',
    mode: _executableMode,
  ),
  _directory('$topFolder/Contents/Frameworks/App.framework/Versions/A/'),
  _file(
    '$topFolder/Contents/Frameworks/App.framework/Versions/A/App',
    'framework binary',
    mode: _executableMode,
  ),
  _link('$topFolder/Contents/Frameworks/App.framework/Versions/Current', 'A'),
  _link(
    '$topFolder/Contents/Frameworks/App.framework/App',
    'Versions/Current/App',
  ),
]);

String? _posixPermissionsSkipReason() {
  if (Platform.isWindows) {
    return 'needs POSIX permissions';
  }
  final uid = Process.runSync('id', ['-u']).stdout.toString().trim();
  return uid == '0' ? 'root ignores directory permissions' : null;
}

final class _Sandbox {
  _Sandbox(this.root);

  final Directory root;
  final List<List<String>> processCalls = [];
  final List<String> createdTempDirectories = [];
  final List<int> exitCodes = [];

  String get applications => p.join(root.path, 'Applications');

  String get bundlePath => p.join(applications, 'Swiftie Quiz.app');

  String bundleFile(String relative) => p.join(bundlePath, relative);

  void createOldBundle() {
    for (final MapEntry(key: relative, value: content) in const {
      'Contents/Info.plist': 'old info',
      'Contents/MacOS/swiftie-quiz': 'old binary',
      'Contents/Resources/old-only.txt': 'only in the old version',
    }.entries) {
      File(bundleFile(relative))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }
  }

  void expectOldBundle() {
    expect(
      File(bundleFile('Contents/Info.plist')).readAsStringSync(),
      'old info',
    );
    expect(
      File(bundleFile('Contents/MacOS/swiftie-quiz')).readAsStringSync(),
      'old binary',
    );
    expect(
      File(bundleFile('Contents/Resources/old-only.txt')).existsSync(),
      isTrue,
    );
  }

  Future<Directory> createTempDirectory(String prefix) async {
    final directory = await root.createTemp(prefix);
    createdTempDirectories.add(directory.path);
    return directory;
  }

  Future<ProcessResult> runProcess(
    String executable,
    List<String> arguments, {
    int fakeExitCode = 0,
  }) async {
    processCalls.add([executable, ...arguments]);
    if (executable == '/bin/chmod' || executable == '/usr/bin/touch') {
      return Process.run(executable, arguments);
    }
    return ProcessResult(
      0,
      fakeExitCode,
      '',
      fakeExitCode == 0 ? '' : 'failed',
    );
  }

  MacUpdateInstaller macInstaller({
    TempDirectoryProvider? createTempDirectory,
    int stubbedExitCode = 0,
  }) => MacUpdateInstaller(
    bundlePath: bundlePath,
    createTempDirectory: createTempDirectory ?? this.createTempDirectory,
    runProcess: (executable, arguments) =>
        runProcess(executable, arguments, fakeExitCode: stubbedExitCode),
    exitProcess: exitCodes.add,
  );

  List<String> leftovers() =>
      [for (final entity in root.listSync()) p.basename(entity.path)]..sort();
}

void main() {
  group('installers mirror the Tauri updater', () {
    late _Sandbox sandbox;

    setUp(() {
      sandbox = _Sandbox(
        Directory.systemTemp.createTempSync('swiftie_updater'),
      );
      sandbox.createOldBundle();
    });

    tearDown(() async {
      for (final path in [
        sandbox.applications,
        p.join(sandbox.root.path, 'locked'),
      ]) {
        if (Directory(path).existsSync()) {
          await Process.run('chmod', ['755', path]);
        }
      }
      sandbox.root.deleteSync(recursive: true);
    });

    test('a tar.gz of "Swiftie Quiz.app/Contents/..." replaces the running '
        'bundle', () async {
      await sandbox.macInstaller().install(_appArchive(), version: '0.3.0');

      expect(
        File(sandbox.bundleFile('Contents/Info.plist')).readAsStringSync(),
        'new info',
      );
      expect(
        File(sandbox.bundleFile('Contents/MacOS/swiftie-quiz'))
            .readAsStringSync(),
        'new binary',
      );
      expect(
        File(sandbox.bundleFile('Contents/Resources/old-only.txt'))
            .existsSync(),
        isFalse,
      );
      expect(sandbox.leftovers(), ['Applications']);
    });

    test('each entry loses its first path component, whatever the top folder '
        'is called', () async {
      await sandbox.macInstaller().install(
        _appArchive(topFolder: 'Renamed.app'),
        version: '0.3.0',
      );

      expect(
        File(sandbox.bundleFile('Contents/Info.plist')).readAsStringSync(),
        'new info',
      );
      expect(
        Directory(p.join(sandbox.bundlePath, 'Renamed.app')).existsSync(),
        isFalse,
      );
      expect(
        Directory(p.join(sandbox.applications, 'Renamed.app')).existsSync(),
        isFalse,
      );
    });

    test('executable bits and framework symlinks survive the unpack', () async {
      await sandbox.macInstaller().install(_appArchive(), version: '0.3.0');

      final executable = File(
        sandbox.bundleFile('Contents/MacOS/swiftie-quiz'),
      );
      expect(executable.statSync().mode & 0x1ff, _executableMode);
      expect(
        File(sandbox.bundleFile('Contents/Info.plist')).statSync().mode & 0x1ff,
        _fileMode,
      );
      final frameworkLink = Link(
        sandbox.bundleFile('Contents/Frameworks/App.framework/App'),
      );
      expect(frameworkLink.targetSync(), 'Versions/Current/App');
      expect(File(frameworkLink.path).readAsStringSync(), 'framework binary');
      expect(
        sandbox.processCalls,
        contains(equals(['/usr/bin/touch', sandbox.bundlePath])),
      );
    }, skip: Platform.isWindows ? 'needs POSIX permissions' : null);

    test('a failed move restores the old bundle', () async {
      final locked = Directory(p.join(sandbox.root.path, 'locked'))
        ..createSync();
      final installer = sandbox.macInstaller(
        createTempDirectory: (prefix) async {
          if (!prefix.contains('updated')) {
            return sandbox.createTempDirectory(prefix);
          }
          final directory = await locked.createTemp(prefix);
          await Process.run('chmod', ['555', locked.path]);
          return directory;
        },
      );

      await expectLater(
        installer.install(_appArchive(), version: '0.3.0'),
        throwsA(
          isA<UpdateInstallException>().having(
            (error) => error.message,
            'message',
            contains('previous version was restored'),
          ),
        ),
      );

      sandbox.expectOldBundle();
      expect(sandbox.leftovers(), ['Applications', 'locked']);
    }, skip: _posixPermissionsSkipReason());

    test('a permission-denied move falls back to osascript with administrator '
        'privileges', () async {
      await Process.run('chmod', ['555', sandbox.applications]);

      await sandbox.macInstaller().install(_appArchive(), version: '0.3.0');

      final extractDirectory = sandbox.createdTempDirectories.firstWhere(
        (path) => p.basename(path).startsWith('swiftie_quiz_updated_app'),
      );
      expect(
        sandbox.processCalls,
        contains(
          equals([
            '/usr/bin/osascript',
            '-e',
            macAdministratorSwapScript(
              bundlePath: sandbox.bundlePath,
              newBundlePath: extractDirectory,
            ),
          ]),
        ),
      );
    }, skip: _posixPermissionsSkipReason());

    test('a refused administrator prompt leaves the old bundle', () async {
      await Process.run('chmod', ['555', sandbox.applications]);

      await expectLater(
        sandbox
            .macInstaller(stubbedExitCode: 1)
            .install(_appArchive(), version: '0.3.0'),
        throwsA(
          isA<UpdateInstallException>().having(
            (error) => error.message,
            'message',
            'Failed to move the new app into place',
          ),
        ),
      );

      sandbox.expectOldBundle();
      expect(sandbox.leftovers(), ['Applications']);
    }, skip: _posixPermissionsSkipReason());

    test('the administrator script quotes paths as Tauri does', () {
      expect(
        macAdministratorSwapScript(
          bundlePath: '/Applications/Swiftie Quiz.app',
          newBundlePath: '/var/folders/x/T/swiftie_quiz_updated_app1',
        ),
        'do shell script "rm -rf \'/Applications/Swiftie Quiz.app\' && '
        "mv -f '/var/folders/x/T/swiftie_quiz_updated_app1' "
        '\'/Applications/Swiftie Quiz.app\'" with administrator privileges',
      );
      expect(
        macAdministratorSwapScript(
          bundlePath: '/Users/o\'neil "x"/Swiftie Quiz.app',
          newBundlePath: '/tmp/new',
        ),
        r'''do shell script "rm -rf '/Users/o'\\''neil \"x\"/Swiftie Quiz.app' && mv -f '/tmp/new' '/Users/o'\\''neil \"x\"/Swiftie Quiz.app'" with administrator privileges''',
      );
    });

    test('an archive entry or link that leaves the bundle is refused before '
        'the bundle is touched', () async {
      final escapingArchives = [
        _tarGz([
          _directory('Swiftie Quiz.app/'),
          _file('Swiftie Quiz.app/../../escaped.txt', 'escaped'),
        ]),
        _tarGz([
          _directory('Swiftie Quiz.app/'),
          _link('Swiftie Quiz.app/Contents/escape', '../../../..'),
        ]),
        _tarGz([
          _directory('Swiftie Quiz.app/'),
          _link('Swiftie Quiz.app/Contents/absolute', '/etc'),
        ]),
        _tarGz([
          _directory('Swiftie Quiz.app/'),
          _link('Swiftie Quiz.app/Contents/up', '..'),
          _link('Swiftie Quiz.app/Contents/up/out', '..'),
          _file('Swiftie Quiz.app/Contents/up/out/escaped.txt', 'escaped'),
        ]),
      ];

      for (final archive in escapingArchives) {
        await expectLater(
          sandbox.macInstaller().install(archive, version: '0.3.0'),
          throwsA(isA<UpdateInstallException>()),
        );
        sandbox.expectOldBundle();
        expect(sandbox.leftovers(), ['Applications']);
      }
    });

    test('bytes that are not a tar.gz leave the bundle untouched', () async {
      await expectLater(
        sandbox.macInstaller().install(
          Uint8List.fromList(utf8.encode('not an archive')),
          version: '0.3.0',
        ),
        throwsA(isA<UpdateInstallException>()),
      );

      sandbox.expectOldBundle();
      expect(sandbox.leftovers(), ['Applications']);
    });

    test('the bundle path is the .app above Contents/MacOS', () {
      expect(
        macBundlePathFromExecutable(
          '/Applications/Swiftie Quiz.app/Contents/MacOS/swiftie-quiz',
        ),
        '/Applications/Swiftie Quiz.app',
      );
      expect(
        macBundlePathFromExecutable('/opt/swiftie/swiftie-quiz'),
        '/opt/swiftie',
      );
    });

    test('relaunch opens a new instance of the bundle and exits', () async {
      await sandbox.macInstaller().relaunch();

      expect(sandbox.processCalls, [
        ['/usr/bin/open', '-n', sandbox.bundlePath],
      ]);
      expect(sandbox.exitCodes, [0]);
    });

    test('a failed relaunch throws instead of exiting', () async {
      await expectLater(
        sandbox.macInstaller(stubbedExitCode: 1).relaunch(),
        throwsA(isA<UpdateInstallException>()),
      );
      expect(sandbox.exitCodes, isEmpty);
    });

    test('the Windows argument list is /P /UPDATE /R /ARGS', () {
      expect(windowsInstallerArguments(), ['/P', '/UPDATE', '/R', '/ARGS']);
    });

    test('the Windows installer writes the setup exe to a temporary file, '
        'starts it detached and exits', () async {
      final setup = Uint8List.fromList([0x4d, 0x5a, ...utf8.encode('setup')]);
      final started = <(String, List<String>, ProcessStartMode)>[];
      final installer = WindowsUpdateInstaller(
        createTempDirectory: sandbox.createTempDirectory,
        startProcess:
            (executable, arguments, {mode = ProcessStartMode.normal}) async {
              started.add((executable, arguments, mode));
            },
        exitProcess: sandbox.exitCodes.add,
      );

      await installer.install(setup, version: '0.3.0');
      await installer.relaunch();

      final directory = sandbox.createdTempDirectories.single;
      expect(p.basename(directory), startsWith('Swiftie Quiz-0.3.0-updater-'));
      final setupPath = p.join(directory, 'Swiftie Quiz-0.3.0-installer.exe');
      expect(File(setupPath).readAsBytesSync(), setup);
      final (executable, arguments, mode) = started.single;
      expect(executable, setupPath);
      expect(arguments, ['/P', '/UPDATE', '/R', '/ARGS']);
      expect(mode, ProcessStartMode.detached);
      expect(sandbox.exitCodes, [0]);
    });

    test('the Windows installer refuses a file that is not an exe', () async {
      final installer = WindowsUpdateInstaller(
        createTempDirectory: sandbox.createTempDirectory,
        startProcess: (
          executable,
          arguments, {
          mode = ProcessStartMode.normal,
        }) async => fail('started $executable'),
        exitProcess: sandbox.exitCodes.add,
      );

      await expectLater(
        installer.install(
          Uint8List.fromList(utf8.encode('not an exe')),
          version: '0.3.0',
        ),
        throwsA(isA<UpdateInstallException>()),
      );
      expect(sandbox.exitCodes, isEmpty);
    });
  });
}
