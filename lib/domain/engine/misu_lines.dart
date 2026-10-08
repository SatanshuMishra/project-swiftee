import 'dart:math';

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
  closeFinish,
  wonTogether,
  away,
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

List<String> misuLines(
  MisuLine kind, {
  required Edition edition,
  required String name,
  required DateTime now,
  int count = 0,
  double seconds = 0,
}) => List.unmodifiable(switch (edition) {
  Edition.ana => _anaLines(kind, now, _countWord(count), _gap(seconds)),
  Edition.open => _openLines(kind, name, now, _countWord(count), _gap(seconds)),
});

int dayVariant(DateTime now, int variants) =>
    DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay %
    variants;

({int pick, List<int> rest}) drawVariant(
  List<int> bag, {
  required int variants,
  required Random random,
  int? last,
}) {
  final order = bag.isEmpty ? _shuffled(variants, random, last) : bag;
  return (pick: order.first, rest: List.unmodifiable(order.skip(1)));
}

List<int> _shuffled(int variants, Random random, int? last) {
  final order = List.generate(variants, (index) => index)..shuffle(random);
  return order.length > 1 && order.first == last
      ? [...order.skip(1), order.first]
      : order;
}

String _countWord(int count) => _numberWords[count] ?? '$count';

String _gap(double seconds) => seconds.toStringAsFixed(1);

List<String> _anaLines(MisuLine kind, DateTime now, String count, String gap) =>
    switch (kind) {
      MisuLine.greet => switch (DayPart.of(now)) {
        DayPart.morning => const [
          "Morning, Ana. I've been up since five.",
          "You're up! I already had breakfast. Twice.",
          "Coffee first, Ana? I'll wait. Barely.",
          "Morning. I slept on your chair, so it's mostly fur now.",
        ],
        DayPart.afternoon => const [
          "Nap's over. Let's play, Ana.",
          'Lunch was hours ago. Just saying.',
          "I rolled all over your hoodie. It's fluffier now.",
          "Quiz now, treats after. That's the deal.",
        ],
        DayPart.evening => const [
          'Saved you a spot on the couch, Ana.',
          "Dinner was late. I've decided to forgive you.",
          'I knocked your mug off the table. It was empty. Probably.',
          "Your side of the couch is all fur now. Mine's fine.",
        ],
        DayPart.night => const [
          "It's late. One more round?",
          'Midnight snack? For me, I mean.',
          'Zoomies start at three. Get your rounds in now.',
          'Still up, Ana? Good. Someone has to open the treats.',
        ],
      },
      MisuLine.intro => const [_intro],
      MisuLine.streak5 => [
        '$count in a row, Ana. My tail is doing the thing.',
        "$count in a row. That's worth a treat. For me.",
        '$count in a row. Almost as smart as me.',
        "$count in a row. Keep going, I've got treats riding on this.",
      ],
      MisuLine.streak10 => const [
        "Ten in a row. I'm telling everyone.",
        "Ten in a row. Something's getting knocked off a shelf.",
        'Ten in a row. I want a treat for each one.',
        "Ten in a row. Clear the hallway, I've got the zoomies.",
      ],
      MisuLine.miss3 => const [
        "I'm not judging. I'm a little judging.",
        "That's three. I'll look away for the next one.",
        "Three wrong. I could do better, and I don't have thumbs.",
        'Three wrong, Ana? I thought you knew every Taylor song.',
      ],
      MisuLine.sumHigh => const [
        "Even I'm impressed. And I'm a cat.",
        "I'd bring you a mouse for that. You're welcome.",
        "That deserves a treat. I'll hold onto it for you.",
        'Nailed it, Ana. Now, about my dinner.',
      ],
      MisuLine.sumMid => const [
        "Solid round. I'd like a treat for this.",
        "Good round. I'll allow one belly rub.",
        "Decent. I've had better rounds chasing my tail.",
        'That was fine. I expected more from you, Ana.',
      ],
      MisuLine.sumLow => const [
        'Shake it off. Again?',
        "I knock things off tables for fun. What's your excuse?",
        "I've coughed up better hairballs.",
        "Again, Ana. This time I'm watching.",
      ],
      MisuLine.closeFinish => [
        "$gap seconds apart. I'm calling it a tie.",
        '$gap seconds. Too close. Somebody owes me a treat.',
        "$gap seconds apart. I'd have been faster, but I was eating.",
        "$gap seconds apart. Do it again, I wasn't watching.",
      ],
      MisuLine.wonTogether => const [
        'You won! I knew you would.',
        "Winner. I'm taking some of the credit.",
        'First place! Victory zoomies, right now.',
        'Winners buy the treats. Those are the rules.',
      ],
      MisuLine.away => const [
        "If you're not back soon, I'm sitting on the keyboard.",
        "Still there? I'll wait. Loudly.",
        'I kept your spot warm, Ana. Come back.',
        "If you're getting snacks, I want half.",
        "You've been gone so long I rolled on everything you own.",
        "You'd never leave me this long without a treat. Would you?",
      ],
    };

List<String> _openLines(
  MisuLine kind,
  String name,
  DateTime now,
  String count,
  String gap,
) => switch (kind) {
  MisuLine.greet => switch (DayPart.of(now)) {
    DayPart.morning => [
      "Morning, $name. Misu's been up since five.",
      "You're up! Misu already had breakfast. Twice.",
      "Breakfast first. Misu's, then yours.",
      "Misu slept on your chair. It's mostly fur now.",
    ],
    DayPart.afternoon => [
      "Nap's over, $name. Misu's ready.",
      "Lunch was hours ago. Misu's just saying.",
      "Misu rolled all over your hoodie. It's fluffier now.",
      "Quiz now, treats after. That's Misu's deal.",
    ],
    DayPart.evening => [
      'Misu saved you a spot on the couch, $name.',
      'Dinner was late. Misu has decided to forgive you.',
      'Misu knocked your mug off the table. It was empty. Probably.',
      "Your side of the couch is all fur now. Misu's side is fine.",
    ],
    DayPart.night => [
      "It's late. Misu says one more round.",
      'Midnight snack? For Misu, obviously.',
      "Misu's zoomies start at three. Get your rounds in now.",
      'Still up, $name? Good. Someone has to open the treats.',
    ],
  },
  MisuLine.intro => const [_intro],
  MisuLine.streak5 => [
    "$count in a row, $name. Misu's tail is doing the thing.",
    "$count in a row. That's worth a treat. For Misu.",
    '$count in a row. Almost as smart as Misu.',
    "$count in a row. Keep going, Misu's got treats riding on this.",
  ],
  MisuLine.streak10 => const [
    "Ten in a row. Misu's telling everyone.",
    "Ten in a row. Something's getting knocked off a shelf.",
    'Ten in a row. Misu wants a treat for each one.',
    "Ten in a row. Clear the hallway, Misu's got the zoomies.",
  ],
  MisuLine.miss3 => [
    "Misu isn't judging. Misu is a little judging.",
    "That's three. Misu will look away for the next one.",
    'Three wrong. Misu could do better, and Misu has no thumbs.',
    'Three wrong, $name? Misu thought you knew every Taylor song.',
  ],
  MisuLine.sumHigh => [
    "Even Misu's impressed, $name.",
    "Misu would bring you a mouse for that. You're welcome.",
    'That deserves a treat. Misu will hold onto it for you.',
    "Nailed it. Now, about Misu's dinner.",
  ],
  MisuLine.sumMid => [
    'Solid round. Misu approves.',
    'Good round. Misu will allow one belly rub.',
    "Decent. Misu's had better rounds chasing his tail.",
    'That was fine. Misu expected more from you, $name.',
  ],
  MisuLine.sumLow => [
    'Shake it off. Again?',
    "Misu knocks things off tables for fun. What's your excuse?",
    'Misu has coughed up better hairballs.',
    "Again, $name. This time Misu's watching.",
  ],
  MisuLine.closeFinish => [
    '$gap seconds apart. Misu calls it a tie.',
    '$gap seconds. Too close. Somebody owes Misu a treat.',
    "$gap seconds apart. Misu would've been faster, but he was eating.",
    "$gap seconds apart. Do it again, Misu wasn't watching.",
  ],
  MisuLine.wonTogether => [
    'You won, $name! Misu knew it.',
    "Winner. Misu's taking some of the credit.",
    'First place! Victory zoomies, right now.',
    "Winners buy the treats. Those are Misu's rules.",
  ],
  MisuLine.away => [
    "If you're not back soon, Misu's sitting on the keyboard.",
    'Still there? Misu will wait. Loudly.',
    'Misu kept your spot warm, $name. Come back.',
    "If you're getting snacks, Misu wants half.",
    "You've been gone so long Misu rolled on everything you own.",
    "You'd never leave Misu this long without a treat. Would you?",
  ],
};

const String _intro = "I'm Misu. I'll drop by now and then.";
