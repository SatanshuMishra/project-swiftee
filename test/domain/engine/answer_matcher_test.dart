import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/answer_matcher.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

Track makeTrack({int id = 1, String title = "Enchanted (Taylor's Version)"}) =>
    Track(
      id: id,
      title: title,
      titleShort: 'Enchanted',
      duration: 319,
      preview: 'https://example.com/preview.mp3',
      artist: const Artist(id: 12246, name: 'Taylor Swift'),
      album: const Album(id: 1, title: 'Speak Now', coverMedium: null),
    );

void main() {
  group('answer matcher parity', () {
    group('normalizeTitle', () {
      test('lowercases', () {
        expect(normalizeTitle('Enchanted'), 'enchanted');
      });

      test('removes a dash suffix after the title', () {
        expect(
          normalizeTitle(
            'All Too Well (Sad Girl Autumn Version) - Recorded at Long Pond Studios',
          ),
          'all too well',
        );
        expect(normalizeTitle('Anti-Hero'), 'anti hero');
      });

      test('removes parenthetical suffixes', () {
        expect(normalizeTitle("Enchanted (Taylor's Version)"), 'enchanted');
        expect(
          normalizeTitle("All Too Well (Taylor's Version) (From The Vault)"),
          'all too well',
        );
      });

      test('strips punctuation', () {
        expect(normalizeTitle("Don't Blame Me"), 'dont blame me');
        expect(normalizeTitle('...Ready For It?'), 'ready for it');
        expect(normalizeTitle('Anti-Hero'), 'anti hero');
      });

      test('collapses whitespace', () {
        expect(normalizeTitle('  hello   world  '), 'hello world');
      });
    });

    group('checkAnswer', () {
      group('Easy/Medium (multiple choice by ID)', () {
        test('matches correct track ID', () {
          final track = makeTrack(id: 42);
          expect(checkAnswer(42, track, Difficulty.easy), isTrue);
          expect(checkAnswer(42, track, Difficulty.medium), isTrue);
        });

        test('rejects wrong track ID', () {
          final track = makeTrack(id: 42);
          expect(checkAnswer(99, track, Difficulty.easy), isFalse);
        });
      });

      group('Hard (text input)', () {
        test('matches exact title after normalization', () {
          final track = makeTrack(title: "Enchanted (Taylor's Version)");
          expect(checkAnswer('enchanted', track, Difficulty.hard), isTrue);
          expect(checkAnswer('Enchanted', track, Difficulty.hard), isTrue);
        });

        test('matches with parentheticals removed', () {
          final track = makeTrack(
            title: "All Too Well (Taylor's Version) (From The Vault)",
          );
          expect(checkAnswer('all too well', track, Difficulty.hard), isTrue);
        });

        test('matches with punctuation removed', () {
          final track = makeTrack(title: "Don't Blame Me");
          expect(checkAnswer('dont blame me', track, Difficulty.hard), isTrue);
          expect(checkAnswer("don't blame me", track, Difficulty.hard), isTrue);
        });

        test('allows typos via Levenshtein for long titles', () {
          final track = makeTrack(title: 'Anti-Hero');
          expect(checkAnswer('anit hero', track, Difficulty.hard), isTrue);
        });

        test('requires exact match for short titles', () {
          final track = makeTrack(title: '22');
          expect(checkAnswer('22', track, Difficulty.hard), isTrue);
          expect(checkAnswer('23', track, Difficulty.hard), isFalse);
        });

        test('handles ...Ready For It?', () {
          final track = makeTrack(title: '...Ready For It?');
          expect(checkAnswer('ready for it', track, Difficulty.hard), isTrue);
        });
      });
    });
  });
}
