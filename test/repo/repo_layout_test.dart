import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const List<String> retiredPaths = [
  'src',
  'src-tauri',
  'package.json',
  'package-lock.json',
  'index.html',
  'public',
  'vite.config.ts',
  'vitest.config.ts',
  'eslint.config.js',
  'tsconfig.json',
  'rust-toolchain.toml',
];

const List<String> scannedDirectories = ['.claude', '.github'];

const List<String> scannedFiles = [
  'CLAUDE.md',
  'AGENTS.md',
  'README.md',
  'docs/INSTALL.md',
  'receipts.config.json',
];

const List<String> retiredCommands = [
  'npm run',
  'cargo ',
  'tauri dev',
  'tauri build',
];

const List<String> flutterCommandDocs = ['CLAUDE.md', 'README.md'];

Map<String, String> gitEnvironment({bool isolated = false}) => {
  for (final MapEntry(:key, :value) in Platform.environment.entries)
    if (!key.startsWith('GIT_')) key: value,
  if (isolated) ...{
    'GIT_CONFIG_NOSYSTEM': '1',
    'GIT_CONFIG_GLOBAL': p.join(
      Directory.systemTemp.path,
      'swiftie-layout-no-git-config',
    ),
  },
};

List<String> automationFiles(String root, {Map<String, String>? environment}) {
  final result = Process.runSync(
    'git',
    [
      'ls-files',
      '-z',
      '--cached',
      '--others',
      '--exclude-standard',
      '--',
      ...scannedDirectories,
    ],
    workingDirectory: root,
    environment: environment ?? gitEnvironment(),
    includeParentEnvironment: false,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      'git',
      const ['ls-files'],
      '${result.stderr}',
      result.exitCode,
    );
  }
  return [
    for (final path in (result.stdout as String).split('\u0000'))
      if (path.isNotEmpty) p.joinAll(path.split('/')),
    ...scannedFiles,
  ];
}

String? textOf(File file) {
  if (!file.existsSync()) {
    return null;
  }
  final bytes = file.readAsBytesSync();
  return bytes.contains(0) ? null : utf8.decode(bytes, allowMalformed: true);
}

List<String> retiredCommandOffences(String root, List<String> files) => [
  for (final path in files)
    if (textOf(File(p.join(root, path))) case final text?)
      for (final command in retiredCommands)
        if (text.contains(command)) '$path: "$command"',
];

void main() {
  group('tauri stack is gone and docs describe flutter', () {
    late String root;

    setUp(() {
      root = Directory.current.path;
    });

    test('the Tauri, React and Rust paths are deleted', () {
      final present = [
        for (final path in retiredPaths)
          if (FileSystemEntity.typeSync(
                p.join(root, path),
                followLinks: false,
              ) !=
              FileSystemEntityType.notFound)
            path,
      ];

      expect(present, isEmpty);
    });

    test('no doc or automation file names an npm, cargo or Tauri CLI '
        'build or test command', () {
      final files = automationFiles(root);

      expect(files, containsAll(scannedFiles));
      expect(files, contains(p.join('.claude', 'settings.json')));
      expect(retiredCommandOffences(root, files), isEmpty);
    });

    test('the scan reads the files git tracks or would add, and skips '
        'ignored, deleted and binary ones', () {
      final fixture = Directory.systemTemp.createTempSync('swiftie_layout_');
      addTearDown(() => fixture.deleteSync(recursive: true));
      final environment = gitEnvironment(isolated: true);
      void write(String path, List<int> bytes) => (File(
        p.join(fixture.path, path),
      )..createSync(recursive: true)).writeAsBytesSync(bytes);
      void git(List<String> arguments) {
        final result = Process.runSync(
          'git',
          arguments,
          workingDirectory: fixture.path,
          environment: environment,
          includeParentEnvironment: false,
        );
        expect(result.exitCode, 0, reason: '${result.stderr}');
      }

      write('.gitignore', utf8.encode('.DS_Store\n.claude/ignored.md\n'));
      write('.claude/design/.DS_Store', [0x00, 0x00, 0x00, 0x01, 0xff, 0xfe]);
      write('.claude/ignored.md', utf8.encode('npm run build\n'));
      write('.claude/icon.png', [0x00, ...utf8.encode('npm run build')]);
      write('.claude/notes.md', utf8.encode('Run cargo test first.\n'));
      write('.claude/gone.md', utf8.encode('flutter test\n'));
      write('.github/workflows/ci.yml', utf8.encode('run: flutter test\n'));
      for (final path in scannedFiles) {
        write(path, utf8.encode('flutter test\n'));
      }
      git(['init', '--quiet']);
      git([
        'add',
        '.gitignore',
        '.claude/icon.png',
        '.claude/notes.md',
        '.claude/gone.md',
        '.github',
        ...scannedFiles,
      ]);
      File(p.join(fixture.path, '.claude', 'gone.md')).deleteSync();
      write('.claude/new.md', utf8.encode('tauri dev\n'));

      final files = automationFiles(fixture.path, environment: environment);

      expect(files, isNot(contains(p.join('.claude', 'design', '.DS_Store'))));
      expect(files, isNot(contains(p.join('.claude', 'ignored.md'))));
      expect(
        files,
        containsAll([
          p.join('.claude', 'icon.png'),
          p.join('.claude', 'gone.md'),
          p.join('.claude', 'new.md'),
        ]),
      );
      expect(
        retiredCommandOffences(fixture.path, files),
        unorderedEquals([
          '${p.join('.claude', 'notes.md')}: "cargo "',
          '${p.join('.claude', 'new.md')}: "tauri dev"',
        ]),
      );
    });

    test('CLAUDE.md and README.md give the flutter test command', () {
      for (final path in flutterCommandDocs) {
        expect(
          File(p.join(root, path)).readAsStringSync(),
          contains('flutter test'),
          reason: path,
        );
      }
    });
  });
}
