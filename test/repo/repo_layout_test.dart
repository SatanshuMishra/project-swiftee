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

List<String> trackedAutomationFiles(String root) {
  final result = Process.runSync('git', [
    'ls-files',
    '-z',
    '--',
    ...scannedDirectories,
  ], workingDirectory: root);
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
      final files = trackedAutomationFiles(root);

      expect(files, containsAll(scannedFiles));
      expect(files, contains(p.join('.claude', 'settings.json')));
      expect(retiredCommandOffences(root, files), isEmpty);
    });

    test('the scan reads only files git tracks and skips binary ones', () {
      final fixture = Directory.systemTemp.createTempSync('swiftie_layout_');
      addTearDown(() => fixture.deleteSync(recursive: true));
      void write(String path, List<int> bytes) => (File(
        p.join(fixture.path, path),
      )..createSync(recursive: true)).writeAsBytesSync(bytes);
      void git(List<String> arguments) {
        final result = Process.runSync(
          'git',
          arguments,
          workingDirectory: fixture.path,
        );
        expect(result.exitCode, 0, reason: '${result.stderr}');
      }

      write('.gitignore', utf8.encode('.DS_Store\n'));
      write('.claude/design/.DS_Store', [0x00, 0x00, 0x00, 0x01, 0xff, 0xfe]);
      write('.claude/icon.png', [0x89, 0x50, 0x4e, 0x47, 0x00, 0xff]);
      write('.claude/notes.md', utf8.encode('Run cargo test first.\n'));
      write('.github/workflows/ci.yml', utf8.encode('run: flutter test\n'));
      write('.claude/untracked.md', utf8.encode('npm run build\n'));
      for (final path in scannedFiles) {
        write(path, utf8.encode('flutter test\n'));
      }
      git(['init', '--quiet']);
      git([
        'add',
        '.gitignore',
        '.claude/icon.png',
        '.claude/notes.md',
        '.github',
        ...scannedFiles,
      ]);

      final files = trackedAutomationFiles(fixture.path);

      expect(files, isNot(contains(p.join('.claude', 'design', '.DS_Store'))));
      expect(files, isNot(contains(p.join('.claude', 'untracked.md'))));
      expect(files, contains(p.join('.claude', 'icon.png')));
      expect(retiredCommandOffences(fixture.path, files), [
        '${p.join('.claude', 'notes.md')}: "cargo "',
      ]);
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
