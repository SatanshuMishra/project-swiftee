import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/misu_lines.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';

final DateTime _morning = DateTime(2026, 10, 6, 8);
final DateTime _afternoon = DateTime(2026, 10, 6, 14);
final DateTime _evening = DateTime(2026, 10, 6, 19);
final DateTime _night = DateTime(2026, 10, 6, 2);
final List<DateTime> _dayParts = [_morning, _afternoon, _evening, _night];

final RegExp _firstPerson = RegExp(r"\b(I|I'm|I've|I'd|I'll|me|my|mine)\b");

List<String> _lines(
  MisuLine kind,
  Edition edition, {
  DateTime? now,
  int count = 5,
  double seconds = 0.3,
}) => misuLines(
  kind,
  edition: edition,
  name: displayName(edition, 'Sam'),
  now: now ?? _evening,
  count: count,
  seconds: seconds,
);

Iterable<String> _everyLine(Edition edition) => [
  for (final kind in MisuLine.values)
    if (kind == MisuLine.greet)
      for (final now in _dayParts) ..._lines(kind, edition, now: now)
    else if (kind != MisuLine.intro)
      ..._lines(kind, edition),
];

void main() {
  group('misu lines', () {
    test('every line has its versions in both editions, none repeated', () {
      for (final edition in Edition.values) {
        for (final kind in MisuLine.values) {
          final expected = switch (kind) {
            MisuLine.intro => 1,
            MisuLine.away => 6,
            _ => 4,
          };
          for (final now in _dayParts) {
            final lines = _lines(kind, edition, now: now);
            expect(lines, hasLength(expected), reason: '$edition $kind');
            expect(
              lines.toSet(),
              hasLength(expected),
              reason: '$edition $kind',
            );
          }
        }
        final all = _everyLine(edition).toList();
        expect(all.toSet(), hasLength(all.length), reason: '$edition');
      }
    });

    test('ana misu talks as himself and open misu talks about himself', () {
      for (final line in _everyLine(Edition.ana)) {
        expect(line, isNot(contains('Misu')), reason: line);
        expect(line, isNot(contains('Sam')), reason: line);
      }
      for (final line in _everyLine(Edition.open)) {
        expect(line, isNot(matches(_firstPerson)), reason: line);
        expect(line, isNot(contains('Ana')), reason: line);
      }
    });

    test('ana is named in about one line in five', () {
      final lines = _everyLine(Edition.ana).toList();
      final named = lines.where((line) => line.contains('Ana')).length;

      expect(named, 11);
      expect(lines, hasLength(54));
    });

    test('the lines approved for each moment are the ones misu says', () {
      expect(_lines(MisuLine.greet, Edition.ana, now: _night), [
        "It's late. One more round?",
        'Midnight snack? For me, I mean.',
        'Zoomies start at three. Get your rounds in now.',
        'Still up, Ana? Good. Someone has to open the treats.',
      ]);
      expect(_lines(MisuLine.greet, Edition.ana, now: _afternoon), [
        "Nap's over. Let's play, Ana.",
        'Lunch was hours ago. Just saying.',
        "I rolled all over your hoodie. It's fluffier now.",
        "Quiz now, treats after. That's the deal.",
      ]);
      expect(
        _lines(MisuLine.streak5, Edition.ana),
        contains("Five in a row. Keep going, I've got treats riding on this."),
      );
      expect(
        _lines(MisuLine.away, Edition.ana),
        contains("You've been gone so long I rolled on everything you own."),
      );
      expect(
        _lines(MisuLine.sumLow, Edition.open).first,
        'Shake it off. Again?',
      );
      expect(
        _lines(MisuLine.greet, Edition.open, now: _night).first,
        "It's late. Misu says one more round.",
      );
      for (final edition in Edition.values) {
        expect(_lines(MisuLine.intro, edition), [
          "I'm Misu. I'll drop by now and then.",
        ]);
      }
    });

    test('streaks, gaps and the nickname fill every line that uses them', () {
      const words = {
        5: 'Five',
        15: 'Fifteen',
        20: 'Twenty',
        25: 'Twenty-five',
        30: 'Thirty',
        35: '35',
      };
      for (final edition in Edition.values) {
        for (final MapEntry(key: count, value: word) in words.entries) {
          for (final line in _lines(MisuLine.streak5, edition, count: count)) {
            expect(line, startsWith('$word in a row'), reason: line);
          }
        }
        for (final line in _lines(
          MisuLine.closeFinish,
          edition,
          seconds: 4.3 - 4.0,
        )) {
          expect(line, startsWith('0.3 seconds'), reason: line);
          expect(line, isNot(contains('Sam')), reason: line);
          expect(line, isNot(contains('Ana')), reason: line);
        }
      }
      expect(
        _lines(MisuLine.greet, Edition.open, now: _morning).first,
        "Morning, Sam. Misu's been up since five.",
      );
      expect(
        _lines(MisuLine.away, Edition.open),
        contains('Misu kept your spot warm, Sam. Come back.'),
      );
    });

    test('a nameless open player is called you', () {
      expect(displayName(Edition.open, null), 'you');
      expect(displayName(Edition.open, 'Sam'), 'Sam');
      expect(displayName(Edition.ana, 'Sam'), 'Ana');
      expect(displayName(Edition.ana, null), 'Ana');
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

    test('the greeting version moves on each calendar day, not each hour', () {
      final days = [
        for (var day = 0; day < 8; day++)
          dayVariant(DateTime(2026, 12, 29 + day, 9), 4),
      ];

      for (var day = 1; day < days.length; day++) {
        expect(days[day], isNot(days[day - 1]), reason: 'day $day');
      }
      expect(days.take(4).toSet(), {0, 1, 2, 3});
      expect(
        dayVariant(DateTime(2026, 10, 6, 5), 4),
        dayVariant(DateTime(2026, 10, 6, 23, 59), 4),
      );
    });

    test('every version is drawn once before any repeats, and never twice '
        'in a row', () {
      final random = Random(7);
      var bag = const <int>[];
      int? last;
      final drawn = <int>[];
      for (var draw = 0; draw < 60; draw++) {
        final (:pick, :rest) = drawVariant(
          bag,
          variants: 4,
          random: random,
          last: last,
        );
        expect(pick, isNot(last), reason: 'draw $draw');
        drawn.add(pick);
        bag = rest;
        last = pick;
      }

      for (var start = 0; start < drawn.length; start += 4) {
        expect(drawn.sublist(start, start + 4).toSet(), {0, 1, 2, 3});
      }
      expect(
        drawVariant(const [], variants: 1, random: random, last: 0).pick,
        0,
      );
    });
  });
}
