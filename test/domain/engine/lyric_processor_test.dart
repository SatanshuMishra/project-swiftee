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

      test('never draws a fake line from the song being asked about', () {
        TrackLyrics version(int id, String title) => makeLyrics(
          lrclibId: id,
          lines: [
            'You were dancing through the lightning strikes',
            'Sleepless in the onyx night',
            'But now the sky is opalite',
          ],
          sourceTrack: title,
          sourceAlbum: 'The Life of a Showgirl',
        );
        final pool = {
          1: version(1, 'Opalite'),
          2: version(2, 'Opalite (Acoustic Version)'),
        };
        final random = Random(11);
        for (var i = 0; i < 40; i++) {
          final result = selectDecoyOrReal(
            currentLines,
            pool,
            Difficulty.medium,
            currentTrackTitle: 'Opalite',
            random: random,
          );
          expect(result.isReal, isTrue);
        }
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

  group('lines already shown', () {
    final lines = numberedLines();
    Set<String> keys(Iterable<String> shown) => {
      for (final line in shown) lyricLineKey(line),
    };

    test('a snippet skips lines shown earlier in the session', () {
      final seen = keys(lines.sublist(1, 15));
      for (var seed = 0; seed < 50; seed++) {
        final snippet = extractSnippet(
          lines,
          2,
          false,
          false,
          random: Random(seed),
          avoid: seen,
        );

        expect(
          snippet.lines.where((line) => seen.contains(lyricLineKey(line))),
          isEmpty,
        );
      }
    });

    test('a chorus snippet picks a chorus block not shown yet', () {
      final song = [
        'Opening line here',
        'We are never ever',
        'Getting back together',
        'First verse goes here',
        'Like ever',
        'Ooh we are never',
        'Second verse goes here',
        'We are never ever',
        'Getting back together',
        'Like ever',
        'Ooh we are never',
        'Closing line here',
      ];
      final seen = keys(['We are never ever', 'Getting back together']);

      for (var seed = 0; seed < 30; seed++) {
        final snippet = extractSnippet(
          song,
          2,
          true,
          false,
          random: Random(seed),
          avoid: seen,
        );

        expect(snippet.lines, hasLength(2));
        expect(
          snippet.lines.where((line) => seen.contains(lyricLineKey(line))),
          isEmpty,
        );
      }
    });

    test('a song whose every line was shown still gives a snippet', () {
      final snippet = extractSnippet(
        lines,
        3,
        false,
        false,
        random: Random(1),
        avoid: keys(lines),
      );

      expect(snippet.lines, hasLength(3));
    });

    test('a real lyric skips lines shown as an earlier fake', () {
      final seen = keys(lines.sublist(0, 18));
      for (var seed = 0; seed < 50; seed++) {
        final result = selectDecoyOrReal(
          lines,
          const {},
          Difficulty.medium,
          random: Random(seed),
          avoid: seen,
        );

        expect(result.isReal, isTrue);
        expect(seen.contains(lyricLineKey(result.lines.single)), isFalse);
      }
    });

    test('a fake never reuses a line already shown', () {
      final decoy = makeLyrics(
        lrclibId: 9,
        lines: [
          'Shown before as a fake line',
          'A fresh line that was never shown',
        ],
        sourceTrack: 'Other Song',
        sourceAlbum: 'Lover',
      );
      final seen = keys(['Shown before as a fake line']);
      for (var seed = 0; seed < 50; seed++) {
        final result = selectDecoyOrReal(
          ['Real words of this song here'],
          {9: decoy},
          Difficulty.medium,
          currentTrackTitle: 'This Song',
          random: Random(seed),
          avoid: seen,
        );

        if (!result.isReal) {
          expect(result.lines, ['A fresh line that was never shown']);
        }
      }
    });

    test(
      'an easy snippet moves to unseen verses once the chorus was shown',
      () {
        final song = [
          'Opening line here',
          'First verse line one',
          'First verse line two',
          'First verse line three',
          'First verse line four',
          'Shake it off shake it off',
          'Baby I am just gonna shake',
          'Players gonna play play play',
          'Haters gonna hate hate hate',
          'Second verse line one',
          'Shake it off shake it off',
          'Baby I am just gonna shake',
          'Players gonna play play play',
          'Haters gonna hate hate hate',
          'Closing line here',
        ];
        final seen = keys(song.sublist(5, 9));
        for (var seed = 0; seed < 50; seed++) {
          final snippet = extractSnippet(
            song,
            4,
            true,
            false,
            random: Random(seed),
            avoid: seen,
          );

          expect(
            snippet.lines.where((line) => seen.contains(lyricLineKey(line))),
            isEmpty,
          );
        }
      },
    );

    test('a real lyric reuses a playable line before an unplayable one', () {
      final song = [
        'Oh',
        'This playable line was shown before',
        'Ah',
        'Another playable line shown before too',
        'Ooh',
      ];
      final seen = keys([song[1], song[3]]);
      for (var seed = 0; seed < 50; seed++) {
        final result = selectDecoyOrReal(
          song,
          const {},
          Difficulty.medium,
          random: Random(seed),
          avoid: seen,
        );

        expect(result.lines.single, isIn([song[1], song[3]]));
      }
    });

    test('a fake reuses a playable line before an unplayable one', () {
      final decoy = makeLyrics(
        lrclibId: 9,
        lines: ['Oh', 'A fake line that was shown before'],
        sourceTrack: 'Other Song',
        sourceAlbum: 'Lover',
      );
      final seen = keys(['A fake line that was shown before']);
      for (var seed = 0; seed < 50; seed++) {
        final result = selectDecoyOrReal(
          ['Real words of this song here'],
          {9: decoy},
          Difficulty.medium,
          currentTrackTitle: 'This Song',
          random: Random(seed),
          avoid: seen,
        );

        if (!result.isReal) {
          expect(result.lines, ['A fake line that was shown before']);
        }
      }
    });

    test('lines from other songs change nothing', () {
      final other = keys(['A line from a different song entirely']);
      final decoys = {
        9: makeLyrics(
          lrclibId: 9,
          lines: numberedLines().reversed.toList(),
          sourceTrack: 'Other Song',
          sourceAlbum: 'Lover',
        ),
      };
      for (var seed = 0; seed < 200; seed++) {
        for (final (count, chorus) in [(4, true), (2, false), (1, false)]) {
          expect(
            extractSnippet(
              lines,
              count,
              chorus,
              !chorus,
              random: Random(seed),
              avoid: other,
            ).lines,
            extractSnippet(
              lines,
              count,
              chorus,
              !chorus,
              random: Random(seed),
            ).lines,
          );
          final pick = selectDecoyOrReal(
            lines,
            decoys,
            Difficulty.hard,
            lineCount: count,
            currentTrackTitle: 'This Song',
            random: Random(seed),
            avoid: other,
          );
          final plain = selectDecoyOrReal(
            lines,
            decoys,
            Difficulty.hard,
            lineCount: count,
            currentTrackTitle: 'This Song',
            random: Random(seed),
          );
          expect(pick.lines, plain.lines);
          expect(pick.isReal, plain.isReal);
        }
      }
    });
  });
}
