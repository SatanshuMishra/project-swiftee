import 'dart:math';

import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/util/shuffle.dart';

const List<String> positiveMessages = [
  'Purrfection',
  "Meow, that's impressive.",
  "You've earned a head boop.",
  'A meow-ster guess! Incredible.',
  'Nine lives, zero wrong answers.',
  'You belong with this song.',
  'Fearless guess.',
  "You're in your music era.",
  'Enchanting performance.',
  "This is why we can't have nice quizzes — you keep winning.",
  'You knew it all too well.',
  'No blank space in your knowledge.',
  "You need to calm down — you're too good.",
  'Cruel summer? More like cool guesser.',
  "It's me, hi, you're the winner, it's you.",
  "Are you sure you aren't Taylor?",
  "Elizabeth Taylor couldn't have done it better.",
  'Uncancellable.',
  'Take a bow, showgirl.',
  "Who's afraid of little old you? The quiz is.",
  'The prophecy was right about you.',
  'Pure alchemy.',
];

const List<String> lyricsPositiveMessages = [
  'You read that like poetry.',
  'The pen is mightier — and you know every word.',
  'Straight from the page to your brain.',
  "You don't need a melody. The words are enough.",
  'That lyric never stood a chance.',
  "Reading between the lines? You're reading the actual lines.",
  'Ink in your veins.',
  'The manuscript reveals its secrets to you.',
  'No audiobook needed.',
  'Your lyric radar is flawless.',
  'Words are your instrument.',
  'Every syllable, accounted for.',
  'You could recite this catalogue in your sleep.',
  'Chapter and verse. You know it all.',
  'The songwriter would be impressed.',
  'The cat read the lyrics. The cat approves.',
  'Purrfectly quoted.',
  "Even nine lives aren't enough to learn all these lyrics. But you did it.",
  'A well-read cat is a powerful cat.',
  'Curiosity read the songbook.',
  'Cat-alogued every lyric.',
  'Feline poetry appreciation at its finest.',
  'The cat librarian nods in approval.',
  'Whiskers twitching with pride.',
  'A meow-sterpiece of lyric knowledge.',
  'Written in the stars — and you read them.',
  'The manuscript is safe with you.',
  'Guilty of being lyrically brilliant.',
  'Down bad for the right words.',
  'Take a bow, you lyric showgirl.',
];

final class MessageBag {
  MessageBag(Iterable<String> messages, {Random? random})
    : messages = List.unmodifiable(messages),
      _random = random ?? Random();

  final List<String> messages;
  final Random _random;
  List<String> _queue = const [];
  String _last = '';

  String draw() {
    if (_queue.isEmpty) {
      _queue = _refill();
    }
    final message = _queue.last;
    _queue = List.unmodifiable(_queue.take(_queue.length - 1));
    _last = message;
    return message;
  }

  List<String> _refill() {
    final shuffled = shuffle(messages, random: _random);
    final end = shuffled.length - 1;
    if (shuffled.length <= 1 || shuffled[end] != _last) {
      return shuffled;
    }
    final swap = _random.nextInt(end);
    return List.unmodifiable([
      for (var index = 0; index < shuffled.length; index++)
        index == end
            ? shuffled[swap]
            : (index == swap ? shuffled[end] : shuffled[index]),
    ]);
  }
}

final MessageBag _soundMessages = MessageBag(positiveMessages);
final MessageBag _lyricsMessages = MessageBag(lyricsPositiveMessages);

String drawNextMessage([QuizType? quizType]) => quizType == QuizType.lyrics
    ? _lyricsMessages.draw()
    : _soundMessages.draw();
