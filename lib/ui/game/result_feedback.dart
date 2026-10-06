import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/util/shuffle.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';
import 'package:swiftie_quiz/ui/widgets/primary_button.dart';

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

@immutable
class ResultFeedback extends StatefulWidget {
  const ResultFeedback({
    super.key,
    required this.correct,
    required this.correctTrack,
    required this.onNext,
    this.quizType,
    this.lyricsMode,
    this.decoySourceSong,
  });

  static const Duration nextDelay = Duration(seconds: 2);
  static const double panelEntranceScale = 0.9;
  static const double gap = 16;
  static const double panelPadding = 24;
  static const double panelRadius = AppRadii.xl;
  static const double badgeSize = 40;
  static const double iconSize = 20;
  static const double correctGap = 12;
  static const double incorrectGap = 8;
  static const int borderPercent = 20;
  static const int fillPercent = 10;
  static const int badgePercent = 20;
  static const int artistPercent = 70;

  final bool correct;
  final Track correctTrack;
  final VoidCallback onNext;
  final QuizType? quizType;
  final LyricsMode? lyricsMode;
  final String? decoySourceSong;

  @override
  State<ResultFeedback> createState() => _ResultFeedbackState();
}

class _ResultFeedbackState extends State<ResultFeedback> {
  late final String _message;
  bool _ready = false;
  Timer? _readyTimer;

  @override
  void initState() {
    super.initState();
    _message = drawNextMessage(widget.quizType);
    _readyTimer = Timer(ResultFeedback.nextDelay, () {
      _readyTimer = null;
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Entrance(
          fromScale: ResultFeedback.panelEntranceScale,
          child: widget.correct ? _correctPanel() : _incorrectPanel(),
        ),
        const SizedBox(height: ResultFeedback.gap),
        PrimaryButton(
          label: _ready ? 'Next' : 'Next...',
          onPressed: _ready ? widget.onNext : null,
          cursor: SystemMouseCursors.click,
        ),
      ],
    );
  }

  Widget _correctPanel() {
    const accent = AppPalette.green400;
    return _panel(
      tone: AppPalette.green500,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _badge(AppPalette.green500, LucideGlyph.check, accent),
          const SizedBox(width: ResultFeedback.correctGap),
          Flexible(child: Text(_message, style: _headline(accent))),
        ],
      ),
    );
  }

  Widget _incorrectPanel() {
    const accent = AppPalette.red400;
    return _panel(
      tone: AppPalette.red500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _badge(AppPalette.red500, LucideGlyph.x, accent),
          for (final line in _incorrectLines(accent)) ...[
            const SizedBox(height: ResultFeedback.incorrectGap),
            line,
          ],
        ],
      ),
    );
  }

  List<Widget> _incorrectLines(Color accent) {
    if (widget.quizType == QuizType.lyrics &&
        widget.lyricsMode == LyricsMode.lyricsOrLie) {
      final source = widget.decoySourceSong;
      return [
        Text(
          source != null && source.isNotEmpty
              ? "That's actually from “$source”."
              : "Nope — that one's real!",
          style: _headline(accent),
        ),
      ];
    }
    final track = widget.correctTrack;
    final title = track.titleShort.isNotEmpty ? track.titleShort : track.title;
    return [
      Text('It was “$title”', style: _headline(accent)),
      Text(
        'by ${track.artist.name}',
        style: AppText.sm.copyWith(
          color: accent.slashOpacity(ResultFeedback.artistPercent),
        ),
      ),
    ];
  }

  static TextStyle _headline(Color color) =>
      AppText.lg.copyWith(fontWeight: FontWeight.w700, color: color);

  static Widget _panel({required Color tone, required Widget child}) =>
      Container(
        padding: const EdgeInsets.all(ResultFeedback.panelPadding),
        decoration: BoxDecoration(
          color: tone.slashOpacity(ResultFeedback.fillPercent),
          border: Border.all(
            color: tone.slashOpacity(ResultFeedback.borderPercent),
          ),
          borderRadius: BorderRadius.circular(ResultFeedback.panelRadius),
        ),
        child: child,
      );

  static Widget _badge(Color tone, LucideGlyph glyph, Color accent) =>
      Container(
        width: ResultFeedback.badgeSize,
        height: ResultFeedback.badgeSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tone.slashOpacity(ResultFeedback.badgePercent),
          shape: BoxShape.circle,
        ),
        child: AppIcon(glyph, size: ResultFeedback.iconSize, color: accent),
      );
}
