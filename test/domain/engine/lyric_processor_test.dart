import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/lyric_processor.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';

TrackLyrics makeLyrics({
  required int lrclibId,
  required List<String> lines,
  required String sourceTrack,
  required String sourceAlbum,
}) => TrackLyrics(
  lrclibId: lrclibId,
  lines: lines,
  lineCount: lines.length,
  sourceTrack: sourceTrack,
  sourceAlbum: sourceAlbum,
);

List<String> numberedLines() => [
  for (var i = 0; i < 20; i++) 'This is line number ${i + 1} with enough words',
];

void main() {
  group('lyric processor parity', () {
    group('detectChorusRegions', () {
      test('detects repeated lines as chorus', () {
        final lines = [
          'Verse line one',
          'Verse line two',
          'Chorus line A',
          'Chorus line B',
          'Verse line three',
          'Chorus line A',
          'Chorus line B',
          'Outro line',
        ];
        final regions = detectChorusRegions(lines);
        expect(regions.length, greaterThan(0));
      });

      test('returns empty for all unique lines', () {
        final lines = ['Line one', 'Line two', 'Line three', 'Line four'];
        final regions = detectChorusRegions(lines);
        expect(regions.length, 0);
      });

      test('ignores single repeated lines (needs contiguous block of 2+)', () {
        final lines = [
          'Unique one',
          'Repeated',
          'Unique two',
          'Repeated',
          'Unique three',
        ];
        final regions = detectChorusRegions(lines);
        expect(regions.length, 0);
      });
    });

    group('extractSnippet', () {
      final lines = [
        'First line of song',
        'Second line',
        'Third line',
        'Fourth line',
        'Fifth line',
        'Sixth line',
        'Last line of song',
      ];

      test('extracts the requested number of lines', () {
        final snippet = extractSnippet(
          lines,
          3,
          false,
          false,
          random: Random(1),
        );
        expect(snippet.lines.length, 3);
        expect(snippet.sourceLineIndices.length, 3);
      });

      test('returns all lines when song has fewer than requested', () {
        final short = ['Only line one', 'Only line two'];
        final snippet = extractSnippet(
          short,
          4,
          false,
          false,
          random: Random(2),
        );
        expect(snippet.lines.length, 2);
      });

      test('extracts contiguous lines', () {
        final snippet = extractSnippet(
          lines,
          3,
          false,
          false,
          random: Random(3),
        );
        final indices = snippet.sourceLineIndices;
        for (var i = 1; i < indices.length; i++) {
          expect(indices[i] - indices[i - 1], 1);
        }
      });

      test('never extracts first line when possible', () {
        final longLines = [for (var i = 0; i < 20; i++) 'Line ${i + 1}'];
        final random = Random(4);
        var firstIncluded = false;
        for (var i = 0; i < 50; i++) {
          final snippet = extractSnippet(
            longLines,
            3,
            false,
            false,
            random: random,
          );
          if (snippet.sourceLineIndices.contains(0)) {
            firstIncluded = true;
            break;
          }
        }
        expect(firstIncluded, isFalse);
      });
    });

    group('sanitiseSnippet', () {
      test('replaces song title with blanks', () {
        final lines = ['I knew you were Enchanted to meet me'];
        final result = sanitiseSnippet(lines, 'Enchanted');
        expect(result[0], contains('______'));
        expect(result[0], isNot(contains('Enchanted')));
      });

      test('handles case insensitive replacement', () {
        final lines = ['she said cardigan on the floor'];
        final result = sanitiseSnippet(lines, 'Cardigan');
        expect(result[0], contains('______'));
      });

      test('does not modify lines without the title', () {
        final lines = ['This line has nothing to do with it'];
        final result = sanitiseSnippet(lines, 'Enchanted');
        expect(result[0], 'This line has nothing to do with it');
      });

      test('strips parentheticals from title before matching', () {
        final lines = ['enchanted by the moonlight'];
        final result = sanitiseSnippet(lines, "Enchanted (Taylor's Version)");
        expect(result[0], contains('______'));
      });

      test('handles empty title gracefully', () {
        final lines = ['Some lyric line'];
        final result = sanitiseSnippet(lines, '');
        expect(result[0], 'Some lyric line');
      });
    });

    group('selectDecoyOrReal', () {
      final currentLines = [
        'Line one of current song with enough words here',
        'Line two of current song and some more content',
        'Line three with sufficient word count for testing',
        'Line four also has plenty of words for the filter',
      ];

      TrackLyrics decoyLyrics() => makeLyrics(
        lrclibId: 999,
        lines: [
          'A different song line one with many words',
          'A different song line two with enough content',
          'Short',
          'Another long line from the different song here',
        ],
        sourceTrack: 'Different Song',
        sourceAlbum: 'Some Album',
      );

      TrackLyrics numberedDecoy() => makeLyrics(
        lrclibId: 999,
        lines: numberedLines(),
        sourceTrack: 'Decoy Song',
        sourceAlbum: 'Decoy Album',
      );

      test('returns a result with lines array and isReal flag', () {
        final pool = {999: decoyLyrics()};
        final result = selectDecoyOrReal(
          currentLines,
          pool,
          Difficulty.medium,
          random: Random(5),
        );
        expect(result.lines, isA<List<String>>());
        expect(result.lines.length, greaterThan(0));
        expect(result.lines[0], isNotEmpty);
        expect(result.isReal, isA<bool>());
      });

      test('includes sourceSong when fake', () {
        final pool = {999: decoyLyrics()};
        final random = Random(6);
        var foundFake = false;
        for (var i = 0; i < 50; i++) {
          final result = selectDecoyOrReal(
            currentLines,
            pool,
            Difficulty.medium,
            random: random,
          );
          if (!result.isReal) {
            expect(result.sourceSong, 'Different Song');
            foundFake = true;
            break;
          }
        }
        expect(foundFake, isTrue);
      });

      test('falls back to real when decoy pool is empty', () {
        final result = selectDecoyOrReal(
          currentLines,
          {},
          Difficulty.medium,
          random: Random(7),
        );
        expect(result.isReal, isTrue);
        expect(result.lines.length, 1);
      });

      test('returns multiple contiguous lines when lineCount > 1', () {
        final manyLines = numberedLines();
        final pool = {999: numberedDecoy()};
        final random = Random(8);
        for (var i = 0; i < 20; i++) {
          final result = selectDecoyOrReal(
            manyLines,
            pool,
            Difficulty.easy,
            lineCount: 3,
            random: random,
          );
          expect(result.lines.length, 3);
        }
      });

      test('returns exactly 1 line when lineCount defaults', () {
        final pool = {999: decoyLyrics()};
        final result = selectDecoyOrReal(
          currentLines,
          pool,
          Difficulty.hard,
          random: Random(9),
        );
        expect(result.lines.length, 1);
      });

      test('returns 2 lines for medium lineCount', () {
        final manyLines = numberedLines();
        final pool = {999: numberedDecoy()};
        final random = Random(10);
        for (var i = 0; i < 20; i++) {
          final result = selectDecoyOrReal(
            manyLines,
            pool,
            Difficulty.medium,
            lineCount: 2,
            random: random,
          );
          expect(result.lines.length, 2);
        }
      });

      test('excludes lines containing the song title from real results', () {
        final linesWithTitle = [
          'Enchanted by the moonlight glow tonight',
          'Dancing in the dark with you my love',
          'Enchanted is all I ever felt for you',
          'Sparkling lights across the endless sky tonight',
          'I was so Enchanted to meet you there',
        ];
        final random = Random(11);

        for (var i = 0; i < 30; i++) {
          final result = selectDecoyOrReal(
            linesWithTitle,
            {},
            Difficulty.easy,
            lineCount: 1,
            currentTrackTitle: 'Enchanted',
            random: random,
          );
          expect(result.isReal, isTrue);
          for (final line in result.lines) {
            expect(line.toLowerCase(), isNot(contains('enchanted')));
          }
        }
      });

      test('falls back to unfiltered lines when all contain the title', () {
        final allTitleLines = [
          'Enchanted by the glow of the evening stars',
          'I was so Enchanted to meet you at the ball',
          'Enchanted nights and enchanted days forever more',
        ];

        final result = selectDecoyOrReal(
          allTitleLines,
          {},
          Difficulty.easy,
          lineCount: 1,
          currentTrackTitle: 'Enchanted',
          random: Random(12),
        );
        expect(result.isReal, isTrue);
        expect(result.lines.length, 1);
        expect(result.lines[0], isNotEmpty);
      });
    });

    group('era groups', () {
      final currentLines = [
        'Line one of current song with enough words here',
        'Line two of current song and some more content',
        'Line three with sufficient word count for testing',
      ];

      Map<int, TrackLyrics> mixedPool() => {
        1: makeLyrics(
          lrclibId: 1,
          lines: ['Same era decoy line with plenty of words here'],
          sourceTrack: 'willow',
          sourceAlbum: 'evermore',
        ),
        2: makeLyrics(
          lrclibId: 2,
          lines: ['Other era decoy line with plenty of words here'],
          sourceTrack: 'Cruel Summer',
          sourceAlbum: 'Lover',
        ),
        3: makeLyrics(
          lrclibId: 3,
          lines: ['Same album decoy line with plenty of words here'],
          sourceTrack: 'august',
          sourceAlbum: 'folklore',
        ),
      };

      test('easy decoys come from a different era', () {
        final random = Random(13);
        final fakeSources = {
          for (var i = 0; i < 40; i++)
            if (selectDecoyOrReal(
                  currentLines,
                  mixedPool(),
                  Difficulty.easy,
                  currentTrackAlbum: 'folklore',
                  random: random,
                )
                case DecoyResult(isReal: false, :final sourceSong))
              sourceSong,
        };
        expect(fakeSources, {'Cruel Summer'});
      });

      test('hard decoys come from the same album', () {
        final random = Random(14);
        final fakeSources = {
          for (var i = 0; i < 40; i++)
            if (selectDecoyOrReal(
                  currentLines,
                  mixedPool(),
                  Difficulty.hard,
                  currentTrackAlbum: 'folklore',
                  random: random,
                )
                case DecoyResult(isReal: false, :final sourceSong))
              sourceSong,
        };
        expect(fakeSources, {'august'});
      });

      test('keeps the era table of the TypeScript engine', () {
        expect(eraGroups.keys, [
          'country',
          'countryPop',
          'pop',
          'romanticPop',
          'indieFolk',
          'midnightsPop',
          'ttpd',
          'showgirl',
        ]);
        expect(eraGroups['country'], [
          'Taylor Swift',
          "Fearless (Taylor's Version)",
          "Speak Now (Taylor's Version)",
        ]);
        expect(eraGroups['countryPop'], ["Red (Taylor's Version)"]);
        expect(eraGroups['pop'], ["1989 (Taylor's Version)", 'reputation']);
        expect(eraGroups['romanticPop'], ['Lover']);
        expect(eraGroups['indieFolk'], ['folklore', 'evermore']);
        expect(eraGroups['midnightsPop'], ['Midnights']);
        expect(eraGroups['ttpd'], ['THE TORTURED POETS DEPARTMENT']);
        expect(eraGroups['showgirl'], ['The Life of a Showgirl']);
      });
    });
  });

  group('sanitiseSnippet across lines', () {
    test('blanks the title on every line that contains it', () {
      final result = sanitiseSnippet([
        'Enchanted to meet you',
        'I was enchanted',
      ], 'Enchanted');
      expect(result, ['______ to meet you', 'I was ______']);
    });
  });
}
