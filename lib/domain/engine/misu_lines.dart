import 'package:swiftie_quiz/domain/models/edition.dart';

enum MisuLine {
  greet,
  intro,
  streak5,
  streak10,
  miss3,
  sumHigh,
  sumMid,
  sumLow,
}

enum DayPart {
  morning,
  afternoon,
  evening,
  night;

  static DayPart of(DateTime now) => switch (now.hour) {
    >= 5 && < 12 => DayPart.morning,
    >= 12 && < 17 => DayPart.afternoon,
    >= 17 && < 23 => DayPart.evening,
    _ => DayPart.night,
  };
}

const Map<int, String> _numberWords = {
  5: 'Five',
  10: 'Ten',
  15: 'Fifteen',
  20: 'Twenty',
  25: 'Twenty-five',
  30: 'Thirty',
};

String displayName(Edition edition, String? nickname) => switch (edition) {
  Edition.ana => 'Ana',
  Edition.open => nickname ?? 'you',
};

String misuLine(
  MisuLine kind, {
  required Edition edition,
  required String name,
  required DateTime now,
  int count = 0,
}) => switch (edition) {
  Edition.ana => _anaLine(kind, now, count),
  Edition.open => _openLine(kind, name, now, count),
};

String _countWord(int count) => _numberWords[count] ?? '$count';

String _anaLine(MisuLine kind, DateTime now, int count) => switch (kind) {
  MisuLine.greet => switch (DayPart.of(now)) {
    DayPart.morning => "Morning, Ana. I've been up since five.",
    DayPart.afternoon => "Nap's over. Let's play, Ana.",
    DayPart.evening => 'Saved you a spot on the couch, Ana.',
    DayPart.night => "It's late, Ana. One more round?",
  },
  MisuLine.intro => _intro,
  MisuLine.streak5 =>
    '${_countWord(count)} in a row, Ana. My tail is doing the thing.',
  MisuLine.streak10 => "Ten in a row. I'm telling everyone.",
  MisuLine.miss3 => "I'm not judging. I'm a little judging.",
  MisuLine.sumHigh => "Even I'm impressed. And I'm a cat.",
  MisuLine.sumMid => "Solid round. I'd like a treat for this.",
  MisuLine.sumLow => 'Shake it off. Again?',
};

String _openLine(MisuLine kind, String name, DateTime now, int count) =>
    switch (kind) {
      MisuLine.greet => switch (DayPart.of(now)) {
        DayPart.morning => "Morning, $name. Misu's been up since five.",
        DayPart.afternoon => "Nap's over, $name. Misu's ready.",
        DayPart.evening => 'Misu saved you a spot on the couch, $name.',
        DayPart.night => "It's late, $name. Misu says one more round.",
      },
      MisuLine.intro => _intro,
      MisuLine.streak5 =>
        "${_countWord(count)} in a row, $name. Misu's tail is doing the thing.",
      MisuLine.streak10 => "Ten in a row. Misu's telling everyone.",
      MisuLine.miss3 => "Misu isn't judging. Misu is a little judging.",
      MisuLine.sumHigh => "Even Misu's impressed, $name.",
      MisuLine.sumMid => 'Solid round. Misu approves.',
      MisuLine.sumLow => 'Shake it off, $name. Again?',
    };

const String _intro = "I'm Misu. I'll drop by now and then.";
