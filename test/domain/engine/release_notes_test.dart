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

const Map<String, String> noteShapes = {
  'headings and bullets':
      '### Updating from v0.4.0\n- On Windows, try it again.\n\n'
      '### Fixed\n- The window fits.\n- Updates install.\n',
  'a heading with only a sentence': '### Fixed\nThe window no longer flickers.',
  'a sentence before a list':
      '- A\n\nBefore you update:\n- Close the app.\n- Open it again.',
  'a sentence at the start': 'Before you update:\n- Close the app.',
  'a sentence between bullets': '- A\n\nThen:\n\n- B',
  'an empty subsection': '### Added\n\n### Fixed\n- The window fits.',
  'a heading with a sentence and a list':
      '### Updating\nTwo steps:\n\n1. Open Settings.\n2. Click Check now.',
  'numbered steps': '1. Open Settings.\n2. Click Check now.',
  'nested bullets': '- A\n  - B\n    - C\n- D',
  'numbered steps with a nested bullet':
      '### Updating\n1. Open Settings.\n   - On Windows, as admin.\n'
      '2. Click Check now.',
  'a bullet continued without an indent': '- A bug.\nwhich also fixes B',
  'code that looks like markup':
      '- Match `**/*.dart` and `__init__` and `_x_`.\n- Run `xattr -cr`.',
  'a paragraph after a list': '### Fixed\n- A\n\nThanks for the reports.',
  'two paragraphs': 'One.\n\nTwo.',
  'a heading after a paragraph': 'Intro.\n\n### Fixed\n- A',
};

void main() {
  final changelog = File('CHANGELOG.md').readAsStringSync();

  group('Markdown notes read as headings, items and paragraphs', () {
    test('changelog headings and bullets keep their structure', () {
      expect(parseMarkdownNotes(noteShapes['headings and bullets']!), const [
        NotesBlock.heading('Updating from v0.4.0'),
        NotesBlock.item('On Windows, try it again.'),
        NotesBlock.heading('Fixed'),
        NotesBlock.item('The window fits.'),
        NotesBlock.item('Updates install.'),
      ]);
    });

    test('bold, code and links lose their markup', () {
      expect(
        parseMarkdownNotes(
          '- **A new look.** See [the guide](docs/INSTALL.md) and `latest.json`.',
        ),
        const [NotesBlock.item('A new look. See the guide and latest.json.')],
      );
    });

    test('a bullet wrapped over several lines stays one bullet', () {
      expect(
        parseMarkdownNotes(
          '### Fixed\n'
          '- **Lyrics mode\n'
          '  loading.** The timeout is cleared as\n'
          'soon as lyrics finish loading.\n'
          '- Timers update.\n',
        ),
        const [
          NotesBlock.heading('Fixed'),
          NotesBlock.item(
            'Lyrics mode loading. The timeout is cleared as soon as lyrics '
            'finish loading.',
          ),
          NotesBlock.item('Timers update.'),
        ],
      );
    });

    test('a line right under a bullet continues it, indented or not', () {
      expect(
        parseMarkdownNotes(noteShapes['a bullet continued without an indent']!),
        const [NotesBlock.item('A bug. which also fixes B')],
      );
    });

    test('a paragraph stays a paragraph', () {
      expect(
        parseMarkdownNotes(
          'Initial manual distribution.\n(No public changelog was kept.)',
        ),
        const [
          NotesBlock.paragraph(
            'Initial manual distribution. (No public changelog was kept.)',
          ),
        ],
      );
    });

    test('numbered steps keep their numbers', () {
      expect(parseMarkdownNotes(noteShapes['numbered steps']!), const [
        NotesBlock.item('Open Settings.', marker: '1.'),
        NotesBlock.item('Click Check now.', marker: '2.'),
      ]);
    });

    test('numbered steps count up the way Markdown shows them', () {
      expect(
        parseMarkdownNotes('1. A\n1. B\n   - Under B\n1. C\n\nAfter.\n\n1) D'),
        const [
          NotesBlock.item('A', marker: '1.'),
          NotesBlock.item('B', marker: '2.'),
          NotesBlock.item('Under B', depth: 1),
          NotesBlock.item('C', marker: '3.'),
          NotesBlock.paragraph('After.'),
          NotesBlock.item('D', marker: '1)'),
        ],
      );
    });

    test('nested bullets keep their depth', () {
      expect(parseMarkdownNotes(noteShapes['nested bullets']!), const [
        NotesBlock.item('A'),
        NotesBlock.item('B', depth: 1),
        NotesBlock.item('C', depth: 2),
        NotesBlock.item('D'),
      ]);
    });

    test('code keeps its text and only real emphasis is removed', () {
      expect(
        parseMarkdownNotes(
          r'- Match `**/*.dart` and `__init__`, not __bold__, *it*, _it_ or '
          r'\*star\*; 2*3*4 and snake_case_name stay.',
        ),
        const [
          NotesBlock.item(
            'Match **/*.dart and __init__, not bold, it, it or *star*; '
            '2*3*4 and snake_case_name stay.',
          ),
        ],
      );
    });

    test('links with brackets in their address and images keep their text', () {
      expect(
        parseMarkdownNotes(
          'See [the docs](https://x.test/a_(b)) and ![the icon](icon.png) at '
          '<https://x.test>.',
        ),
        const [
          NotesBlock.paragraph('See the docs and the icon at https://x.test.'),
        ],
      );
    });

    test('Windows line endings read the same', () {
      for (final MapEntry(key: shape, value: markdown) in noteShapes.entries) {
        expect(
          parseMarkdownNotes(markdown.replaceAll('\n', '\r\n')),
          parseMarkdownNotes(markdown),
          reason: shape,
        );
      }
    });

    test('a heading with nothing under it at the end is left out', () {
      expect(parseMarkdownNotes('### Added\n- A\n\n### Fixed\n'), const [
        NotesBlock.heading('Added'),
        NotesBlock.item('A'),
      ]);
    });

    test('underlined headings and rules read as Markdown shows them', () {
      expect(parseMarkdownNotes('Fixed\n-----\n- A\n\n***\n\nAfter.'), const [
        NotesBlock.heading('Fixed'),
        NotesBlock.item('A'),
        NotesBlock.paragraph('After.'),
      ]);
    });
  });

  group('plain notes read the same as the Markdown they came from', () {
    test('each heading sits on its own line and bullets are marked with '
        'a dot', () {
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

    test('a heading keeps a sentence directly under it', () {
      expect(
        plainReleaseNotes(noteShapes['a heading with only a sentence']!),
        'Fixed\nThe window no longer flickers.',
      );
    });

    test('a sentence before a list is set apart from it', () {
      expect(
        plainReleaseNotes(noteShapes['a sentence before a list']!),
        '• A\n\nBefore you update:\n\n• Close the app.\n• Open it again.',
      );
    });

    test('numbered steps and nested bullets each take their own line', () {
      expect(
        plainReleaseNotes(noteShapes['numbered steps with a nested bullet']!),
        'Updating\n'
        '1. Open Settings.\n'
        '  • On Windows, as admin.\n'
        '2. Click Check now.',
      );
    });

    test('an empty subsection keeps its heading above the next one', () {
      expect(
        plainReleaseNotes(noteShapes['an empty subsection']!),
        'Added\nFixed\n• The window fits.',
      );
    });

    test('code that looks like markup is shown as written', () {
      final plain = plainReleaseNotes(
        noteShapes['code that looks like markup']!,
      );
      expect(
        plain,
        '• Match **/*.dart and __init__ and _x_.\n• Run xattr -cr.',
      );
      expect(parseReleaseNotes(plain), const [
        NotesBlock.item('Match **/*.dart and __init__ and _x_.'),
        NotesBlock.item('Run xattr -cr.'),
      ]);
    });

    test('every shape reads back as the blocks it came from', () {
      for (final MapEntry(key: shape, value: markdown) in noteShapes.entries) {
        final plain = plainReleaseNotes(markdown);
        expect(
          parseReleaseNotes(plain),
          parseMarkdownNotes(markdown),
          reason: '$shape:\n$plain',
        );
        expect(
          parseReleaseNotes(plain.replaceAll('\n', '\r\n')),
          parseMarkdownNotes(markdown),
          reason: '$shape with Windows line endings',
        );
      }
    });

    test('every changelog section reads back as its Markdown', () {
      final versions = releasedVersions(changelog);
      expect(versions, contains('0.4.1'));
      for (final version in versions) {
        final markdown = changelogSection(changelog, version);
        final plain = plainReleaseNotes(markdown);

        expect(
          parseReleaseNotes(plain),
          parseMarkdownNotes(markdown),
          reason: version,
        );
        expect(plain, isNot(contains('###')), reason: version);
        expect(plain, isNot(contains('**')), reason: version);
      }
    });

    test('Markdown that reaches the window still reads as Markdown', () {
      expect(parseReleaseNotes('### Fixed\n- **The window** fits.'), const [
        NotesBlock.heading('Fixed'),
        NotesBlock.item('The window fits.'),
      ]);
    });
  });
}
