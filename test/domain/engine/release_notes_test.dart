import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/release_notes.dart';

import '../../../tool/release/check_release.dart';

List<String> releasedVersions(String changelog) => [
  for (final match in RegExp(
    r'^## \[(\d+\.\d+\.\d+)\]',
    multiLine: true,
  ).allMatches(changelog))
    match[1]!,
];

void main() {
  final changelog = File('CHANGELOG.md').readAsStringSync();

  group('release notes read as headings, bullets and paragraphs', () {
    test('changelog headings and bullets keep their structure', () {
      expect(
        parseReleaseNotes(
          '### Updating from v0.4.0\n'
          '- On Windows, try it again.\n'
          '\n'
          '### Fixed\n'
          '- The window fits.\n'
          '- Updates install.\n',
        ),
        const [
          NotesBlock.heading('Updating from v0.4.0'),
          NotesBlock.bullet('On Windows, try it again.'),
          NotesBlock.heading('Fixed'),
          NotesBlock.bullet('The window fits.'),
          NotesBlock.bullet('Updates install.'),
        ],
      );
    });

    test('bold, code and links lose their markup', () {
      expect(
        parseReleaseNotes(
          '- **A new look.** See [the guide](docs/INSTALL.md) and `latest.json`.',
        ),
        const [NotesBlock.bullet('A new look. See the guide and latest.json.')],
      );
    });

    test('a bullet wrapped onto indented lines stays one bullet', () {
      expect(
        parseReleaseNotes(
          '### Fixed\n'
          '- **Lyrics mode loading.** The timeout is cleared as\n'
          '  soon as lyrics finish loading.\n'
          '- Timers update.\n',
        ),
        const [
          NotesBlock.heading('Fixed'),
          NotesBlock.bullet(
            'Lyrics mode loading. The timeout is cleared as soon as lyrics '
            'finish loading.',
          ),
          NotesBlock.bullet('Timers update.'),
        ],
      );
    });

    test('a paragraph stays a paragraph', () {
      expect(
        parseReleaseNotes(
          'Initial manual distribution.\n(No public changelog was kept.)',
        ),
        const [
          NotesBlock.paragraph(
            'Initial manual distribution. (No public changelog was kept.)',
          ),
        ],
      );
    });

    test('plain notes put each heading on its own line and mark bullets '
        'with a dot', () {
      expect(
        plainReleaseNotes(
          '### Updating from v0.4.0\n'
          '- **On Windows**, try it again.\n'
          '\n'
          '### Fixed\n'
          '- The window fits.\n',
        ),
        'Updating from v0.4.0\n'
        '• On Windows, try it again.\n'
        '\n'
        'Fixed\n'
        '• The window fits.',
      );
    });

    test('every changelog section reads the same from its plain notes as '
        'from its Markdown', () {
      final versions = releasedVersions(changelog);
      expect(versions, contains('0.4.1'));
      for (final version in versions) {
        final markdown = changelogSection(changelog, version);
        final plain = plainReleaseNotes(markdown);

        expect(
          parseReleaseNotes(plain),
          parseReleaseNotes(markdown),
          reason: version,
        );
        expect(plain, isNot(contains('###')), reason: version);
        expect(plain, isNot(contains('**')), reason: version);
      }
    });
  });
}
