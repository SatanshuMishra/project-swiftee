import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/misu_lines.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';

final DateTime _morning = DateTime(2026, 10, 6, 8);
final DateTime _afternoon = DateTime(2026, 10, 6, 14);
final DateTime _evening = DateTime(2026, 10, 6, 19);
final DateTime _night = DateTime(2026, 10, 6, 2);

void main() {
  group('misu lines', () {
    test(
      'misu speaks in the first person for ana and the third person for open',
      () {
        String ana(MisuLine kind, {DateTime? now, int count = 0}) => misuLine(
          kind,
          edition: Edition.ana,
          name: displayName(Edition.ana, null),
          now: now ?? _evening,
          count: count,
        );
        String open(MisuLine kind, {DateTime? now, int count = 0}) => misuLine(
          kind,
          edition: Edition.open,
          name: displayName(Edition.open, 'Sam'),
          now: now ?? _evening,
          count: count,
        );

        final cases = <(String, String, String)>[
          (
            ana(MisuLine.greet, now: _morning),
            "Morning, Ana. I've been up since five.",
            'ana greet morning',
          ),
          (
            ana(MisuLine.greet, now: _afternoon),
            "Nap's over. Let's play, Ana.",
            'ana greet afternoon',
          ),
          (
            ana(MisuLine.greet, now: _evening),
            'Saved you a spot on the couch, Ana.',
            'ana greet evening',
          ),
          (
            ana(MisuLine.greet, now: _night),
            "It's late, Ana. One more round?",
            'ana greet night',
          ),
          (
            ana(MisuLine.intro),
            "I'm Misu. I'll drop by now and then.",
            'ana intro',
          ),
          (
            ana(MisuLine.streak5, count: 5),
            'Five in a row, Ana. My tail is doing the thing.',
            'ana streak5 five',
          ),
          (
            ana(MisuLine.streak5, count: 15),
            'Fifteen in a row, Ana. My tail is doing the thing.',
            'ana streak5 fifteen',
          ),
          (
            ana(MisuLine.streak10),
            "Ten in a row. I'm telling everyone.",
            'ana streak10',
          ),
          (
            ana(MisuLine.miss3),
            "I'm not judging. I'm a little judging.",
            'ana miss3',
          ),
          (
            ana(MisuLine.sumHigh),
            "Even I'm impressed. And I'm a cat.",
            'ana sumHigh',
          ),
          (
            ana(MisuLine.sumMid),
            "Solid round. I'd like a treat for this.",
            'ana sumMid',
          ),
          (ana(MisuLine.sumLow), 'Shake it off. Again?', 'ana sumLow'),
          (
            open(MisuLine.greet, now: _morning),
            "Morning, Sam. Misu's been up since five.",
            'open greet morning',
          ),
          (
            open(MisuLine.greet, now: _afternoon),
            "Nap's over, Sam. Misu's ready.",
            'open greet afternoon',
          ),
          (
            open(MisuLine.greet, now: _evening),
            'Misu saved you a spot on the couch, Sam.',
            'open greet evening',
          ),
          (
            open(MisuLine.greet, now: _night),
            "It's late, Sam. Misu says one more round.",
            'open greet night',
          ),
          (
            open(MisuLine.intro),
            "I'm Misu. I'll drop by now and then.",
            'open intro',
          ),
          (
            open(MisuLine.streak5, count: 5),
            "Five in a row, Sam. Misu's tail is doing the thing.",
            'open streak5 five',
          ),
          (
            open(MisuLine.streak5, count: 20),
            "Twenty in a row, Sam. Misu's tail is doing the thing.",
            'open streak5 twenty',
          ),
          (
            open(MisuLine.streak10),
            "Ten in a row. Misu's telling everyone.",
            'open streak10',
          ),
          (
            open(MisuLine.miss3),
            "Misu isn't judging. Misu is a little judging.",
            'open miss3',
          ),
          (
            open(MisuLine.sumHigh),
            "Even Misu's impressed, Sam.",
            'open sumHigh',
          ),
          (open(MisuLine.sumMid), 'Solid round. Misu approves.', 'open sumMid'),
          (open(MisuLine.sumLow), 'Shake it off, Sam. Again?', 'open sumLow'),
        ];

        for (final (actual, expected, label) in cases) {
          expect(actual, expected, reason: label);
        }

        const words = {
          5: 'Five',
          10: 'Ten',
          15: 'Fifteen',
          20: 'Twenty',
          25: 'Twenty-five',
          30: 'Thirty',
          35: '35',
          40: '40',
        };
        for (final MapEntry(key: count, value: word) in words.entries) {
          expect(
            ana(MisuLine.streak5, count: count),
            '$word in a row, Ana. My tail is doing the thing.',
            reason: 'ana $count',
          );
          expect(
            open(MisuLine.streak5, count: count),
            "$word in a row, Sam. Misu's tail is doing the thing.",
            reason: 'open $count',
          );
        }
      },
    );

    test('a nameless open player is called you', () {
      expect(displayName(Edition.open, null), 'you');
      expect(displayName(Edition.open, 'Sam'), 'Sam');
      expect(displayName(Edition.ana, 'Sam'), 'Ana');
      expect(displayName(Edition.ana, null), 'Ana');
      expect(
        misuLine(
          MisuLine.sumLow,
          edition: Edition.open,
          name: displayName(Edition.open, null),
          now: _evening,
        ),
        'Shake it off, you. Again?',
      );
    });

    test('the day part follows the hour of the given time', () {
      final expected = {
        0: DayPart.night,
        4: DayPart.night,
        5: DayPart.morning,
        11: DayPart.morning,
        12: DayPart.afternoon,
        16: DayPart.afternoon,
        17: DayPart.evening,
        22: DayPart.evening,
        23: DayPart.night,
      };
      for (final MapEntry(key: hour, value: part) in expected.entries) {
        expect(
          DayPart.of(DateTime(2026, 10, 6, hour, 59)),
          part,
          reason: 'hour $hour',
        );
      }
    });
  });
}
