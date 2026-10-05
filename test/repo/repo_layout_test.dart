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

bool isPersonalClaudeFile(String relativePath) {
  final parts = p.split(relativePath);
  if (parts.first != '.claude') {
    return false;
  }
  return relativePath == p.join('.claude', 'settings.local.json') ||
      (parts.length > 2 &&
          const {'sessions', 'state', 'cache'}.contains(parts[1])) ||
      relativePath.endsWith('.log');
}

List<String> committedAutomationFiles(String root) => [
  for (final directory in scannedDirectories)
    for (final entity in Directory(
      p.join(root, directory),
    ).listSync(recursive: true, followLinks: false))
      if (entity is File &&
          !isPersonalClaudeFile(p.relative(entity.path, from: root)))
        p.relative(entity.path, from: root),
  ...scannedFiles,
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
      final files = committedAutomationFiles(root);
      final offences = [
        for (final path in files)
          for (final command in retiredCommands)
            if (File(p.join(root, path)).readAsStringSync().contains(command))
              '$path: "$command"',
      ];

      expect(files, containsAll(scannedFiles));
      expect(offences, isEmpty);
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
