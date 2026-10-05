import 'dart:async';
import 'dart:math';

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/util/shuffle.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
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
final class MotionPose {
  const MotionPose({
    this.opacity = 1,
    this.offset = Offset.zero,
    this.scale = 1,
  });

  static const MotionPose rest = MotionPose();

  final double opacity;
  final Offset offset;
  final double scale;

  @override
  bool operator ==(Object other) =>
      other is MotionPose &&
      other.opacity == opacity &&
      other.offset == offset &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(opacity, offset, scale);
}

class Motion extends StatefulWidget {
  const Motion({
    required super.key,
    required this.child,
    this.initial = MotionPose.rest,
    this.exit = MotionPose.rest,
    this.delay = Duration.zero,
    this.exiting = false,
    this.onExited,
  });

  static const double restSpeed = 10;

  final Widget child;
  final MotionPose initial;
  final MotionPose exit;
  final Duration delay;
  final bool exiting;
  final VoidCallback? onExited;

  @override
  State<Motion> createState() => _MotionState();
}

class _MotionState extends State<Motion> with TickerProviderStateMixin {
  late final AnimationController _opacity = AnimationController.unbounded(
    vsync: this,
    value: widget.initial.opacity,
  );
  late final AnimationController _x = AnimationController.unbounded(
    vsync: this,
    value: widget.initial.offset.dx,
  );
  late final AnimationController _y = AnimationController.unbounded(
    vsync: this,
    value: widget.initial.offset.dy,
  );
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: widget.initial.scale,
  );
  late final Listenable _frame = Listenable.merge([_opacity, _x, _y, _scale]);

  @override
  void initState() {
    super.initState();
    if (widget.exiting) {
      _exit();
    } else {
      _animateTo(MotionPose.rest, widget.delay);
    }
  }

  @override
  void didUpdateWidget(Motion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exiting == widget.exiting) {
      return;
    }
    if (widget.exiting) {
      _exit();
    } else {
      _animateTo(MotionPose.rest, Duration.zero);
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _x.dispose();
    _y.dispose();
    _scale.dispose();
    super.dispose();
  }

  Future<void> _exit() async {
    await _animateTo(widget.exit, Duration.zero);
    if (mounted && widget.exiting) {
      widget.onExited?.call();
    }
  }

  Future<void> _animateTo(MotionPose target, Duration delay) {
    final delaySeconds = delay.inMicroseconds / Duration.microsecondsPerSecond;
    return Future.wait<void>([
      _opacity.animateWith(
        _DelayedSimulation(
          delaySeconds,
          _EasedTween(
            from: _opacity.value,
            to: target.opacity,
            seconds:
                AppMotion.defaultOpacityDuration.inMicroseconds /
                Duration.microsecondsPerSecond,
            curve: AppMotion.defaultOpacityCurve,
          ),
        ),
      ),
      _spring(_x, target.offset.dx, AppMotion.defaultTranslateSpring, delay),
      _spring(_y, target.offset.dy, AppMotion.defaultTranslateSpring, delay),
      _spring(
        _scale,
        target.scale,
        target.scale == 0
            ? AppMotion.defaultScaleToZeroSpring
            : AppMotion.defaultScaleSpring,
        delay,
      ),
    ]);
  }

  static TickerFuture _spring(
    AnimationController controller,
    double target,
    SpringDescription spring,
    Duration delay,
  ) {
    final start = controller.value;
    final delta = target - start;
    return controller.animateWith(
      _DelayedSimulation(
        delay.inMicroseconds / Duration.microsecondsPerSecond,
        SpringSimulation(
          spring,
          start,
          target,
          controller.velocity,
          tolerance: Tolerance(
            distance: delta.abs() < 5
                ? AppMotion.granularRestDelta
                : AppMotion.restDelta,
            velocity: Motion.restSpeed,
          ),
          snapToEnd: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _frame,
      builder: (context, child) {
        final scale = _scale.value;
        return Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(scale, scale, 1)
              ..setTranslationRaw(_x.value, _y.value, 0),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class MotionPresence extends StatefulWidget {
  const MotionPresence({super.key, this.child, this.spacing = 0});

  final Motion? child;
  final double spacing;

  @override
  State<MotionPresence> createState() => _MotionPresenceState();
}

class _MotionPresenceState extends State<MotionPresence> {
  late Motion? _shown = widget.child;
  bool _exiting = false;

  @override
  void didUpdateWidget(MotionPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.child;
    final shown = _shown;
    if (shown == null) {
      _shown = incoming;
      _exiting = false;
    } else if (incoming != null && incoming.key == shown.key) {
      _shown = incoming;
      _exiting = false;
    } else {
      _exiting = true;
    }
  }

  void _handleExited() {
    if (!mounted) {
      return;
    }
    setState(() {
      _shown = widget.child;
      _exiting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown == null) {
      return const SizedBox.shrink();
    }
    final motion = _exiting
        ? Motion(
            key: shown.key,
            initial: shown.initial,
            exit: shown.exit,
            delay: shown.delay,
            exiting: true,
            onExited: _handleExited,
            child: shown.child,
          )
        : shown;
    if (widget.spacing == 0) {
      return motion;
    }
    return Padding(
      padding: EdgeInsets.only(top: widget.spacing),
      child: motion,
    );
  }
}

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

final class _DelayedSimulation extends Simulation {
  _DelayedSimulation(this.delay, this.simulation)
    : super(tolerance: simulation.tolerance);

  final double delay;
  final Simulation simulation;

  @override
  double x(double time) =>
      time < delay ? simulation.x(0) : simulation.x(time - delay);

  @override
  double dx(double time) => time < delay ? 0 : simulation.dx(time - delay);

  @override
  bool isDone(double time) => time >= delay && simulation.isDone(time - delay);
}

final class _EasedTween extends Simulation {
  _EasedTween({
    required this.from,
    required this.to,
    required this.seconds,
    required this.curve,
  });

  final double from;
  final double to;
  final double seconds;
  final Curve curve;

  @override
  double x(double time) => time >= seconds
      ? to
      : from + (to - from) * curve.transform(max(0, time) / seconds);

  @override
  double dx(double time) => 0;

  @override
  bool isDone(double time) => time >= seconds;
}
