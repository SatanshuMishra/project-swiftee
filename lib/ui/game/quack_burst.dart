import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

@immutable
final class QuackWord {
  const QuackWord({
    required this.offset,
    required this.degrees,
    required this.delay,
    required this.size,
  });

  final Offset offset;
  final double degrees;
  final Duration delay;
  final double size;

  QuackWord copyWith({
    Offset? offset,
    double? degrees,
    Duration? delay,
    double? size,
  }) => QuackWord(
    offset: offset ?? this.offset,
    degrees: degrees ?? this.degrees,
    delay: delay ?? this.delay,
    size: size ?? this.size,
  );

  @override
  bool operator ==(Object other) =>
      other is QuackWord &&
      other.offset == offset &&
      other.degrees == degrees &&
      other.delay == delay &&
      other.size == size;

  @override
  int get hashCode => Object.hash(offset, degrees, delay, size);
}

class QuackBurst extends StatefulWidget {
  const QuackBurst({super.key, required this.level});

  static const String word = 'quack';
  static const int ringLevel = 5;
  static const int ringWords = 14;
  static const anchor = FractionalOffset(0.4, 0);
  static const double anchorTop = 30;
  static const curve = Cubic(0.2, 0.8, 0.2, 1);
  static const double fadeInShare = 0.15;
  static const double startScale = 0.4;
  static const double endScale = 1.1;

  final int level;

  static List<QuackWord> wordsFor(int level) {
    if (level <= 0) {
      return const [];
    }
    if (level >= ringLevel) {
      return List.unmodifiable([
        for (var i = 0; i < ringWords; i++)
          QuackWord(
            offset: Offset(
              math.cos(i / ringWords * 2 * math.pi) * (140 + (i % 3) * 30),
              math.sin(i / ringWords * 2 * math.pi) * (90 + (i % 2) * 30),
            ),
            degrees: ((i % 5) - 2) * 12,
            delay: Duration(milliseconds: 30 * i),
            size: 18 + (i % 3) * 6,
          ),
      ]);
    }
    return List.unmodifiable([
      for (var i = 0; i < level; i++)
        QuackWord(
          offset: Offset(30 + 34.0 * i, -34 - 10.0 * i),
          degrees: (i - 1) * 8,
          delay: Duration(milliseconds: 120 * i),
          size: 16 + 2.0 * i,
        ),
    ]);
  }

  static Duration lengthFor(int level) {
    final words = wordsFor(level);
    if (words.isEmpty) {
      return Duration.zero;
    }
    return words.last.delay + AppMotion.quackBurst;
  }

  static double opacityAt(double t) {
    if (t <= 0 || t >= 1) {
      return 0;
    }
    if (t < fadeInShare) {
      return curve.transform(t / fadeInShare);
    }
    return 1 - curve.transform((t - fadeInShare) / (1 - fadeInShare));
  }

  @override
  State<QuackBurst> createState() => _QuackBurstState();
}

class _QuackBurstState extends State<QuackBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _restart();
    } else if (_clock.isAnimating && AppMotion.reduced(context)) {
      _clock.value = 1;
    }
  }

  @override
  void didUpdateWidget(QuackBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      _restart();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _restart() {
    final length = QuackBurst.lengthFor(widget.level);
    if (length == Duration.zero || AppMotion.reduced(context)) {
      _clock
        ..duration = Duration.zero
        ..value = 1;
      return;
    }
    _clock
      ..duration = length
      ..forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTokens.of(context).coralT;
    final words = QuackBurst.wordsFor(widget.level);
    final length = QuackBurst.lengthFor(widget.level);
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.only(top: QuackBurst.anchorTop),
        child: Align(
          alignment: QuackBurst.anchor,
          child: SizedBox.shrink(
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) {
                if (_clock.value >= 1) {
                  return const SizedBox.shrink();
                }
                final now = length * _clock.value;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final word in words)
                      _wordAt(word, now - word.delay, ink),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _wordAt(QuackWord word, Duration since, Color ink) {
    final t =
        since.inMicroseconds / AppMotion.quackBurst.inMicroseconds.toDouble();
    final travel = QuackBurst.curve.transform(t.clamp(0.0, 1.0));
    return Positioned(
      left: 0,
      top: 0,
      child: Opacity(
        opacity: QuackBurst.opacityAt(t),
        child: Transform.translate(
          offset: word.offset * travel,
          child: Transform.scale(
            scale:
                QuackBurst.startScale +
                (QuackBurst.endScale - QuackBurst.startScale) * travel,
            child: Transform.rotate(
              angle: word.degrees * travel * math.pi / 180,
              child: Text(
                QuackBurst.word,
                maxLines: 1,
                softWrap: false,
                style: AppType.display(
                  word.size,
                  italic: true,
                  height: 1,
                  color: ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
