import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/option_generator.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

Track makeTrack(int id, String title) => Track(
  id: id,
  title: title,
  titleShort: title,
  duration: 30,
  preview: 'https://example.com/preview.mp3',
  artist: const Artist(id: 12246, name: 'Taylor Swift'),
  album: const Album(id: 1, title: 'Test Album', coverMedium: null),
);

void main() {
  group('option generator parity', () {
    group('generateOptions', () {
      test('includes the correct track', () {
        final correct = makeTrack(1, 'Enchanted');
        final pool = [
          correct,
          makeTrack(2, 'Sparks Fly'),
          makeTrack(3, 'Back to December'),
          makeTrack(4, 'Haunted'),
          makeTrack(5, 'Last Kiss'),
        ];

        final options = generateOptions(correct, pool, random: Random(1));
        expect(options.any((track) => track.id == correct.id), isTrue);
      });

      test('returns 4 options when pool is large enough', () {
        final correct = makeTrack(1, 'Enchanted');
        final pool = [
          correct,
          makeTrack(2, 'Sparks Fly'),
          makeTrack(3, 'Back to December'),
          makeTrack(4, 'Haunted'),
          makeTrack(5, 'Last Kiss'),
        ];

        final options = generateOptions(correct, pool, random: Random(2));
        expect(options.length, 4);
      });

      test('de-duplicates by normalized title', () {
        final correct = makeTrack(1, 'Enchanted');
        final pool = [
          correct,
          makeTrack(2, "Enchanted (Taylor's Version)"),
          makeTrack(3, 'Sparks Fly'),
          makeTrack(4, 'Back to December'),
          makeTrack(5, 'Haunted'),
        ];

        final options = generateOptions(correct, pool, random: Random(3));
        final enchantedCount = options
            .where(
              (track) =>
                  track.titleShort == 'Enchanted' ||
                  track.title.startsWith('Enchanted'),
            )
            .length;
        expect(enchantedCount, 1);
      });

      test('handles small pool gracefully', () {
        final correct = makeTrack(1, 'Enchanted');
        final pool = [correct, makeTrack(2, 'Sparks Fly')];

        final options = generateOptions(correct, pool, random: Random(4));
        expect(options.length, 2);
        expect(options.any((track) => track.id == 1), isTrue);
        expect(options.any((track) => track.id == 2), isTrue);
      });
    });
  });
}
