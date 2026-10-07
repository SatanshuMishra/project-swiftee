import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/kit/cover_picture.dart';
import 'package:swiftie_quiz/ui/kit/vinyl.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

class RecordPlayer extends StatefulWidget {
  const RecordPlayer({
    super.key,
    required this.revealed,
    required this.answered,
    required this.spinning,
    this.coverUrl,
    this.placeholder,
    this.previousCoverUrl,
    this.previousPlaceholder,
  });

  static const double boxFactor = 1.47;
  static const double discFactor = 0.94;
  static const double discTopFactor = 0.03;
  static const double discRestFactor = 0.4;
  static const double discOutFactor = 0.52;
  static const double labelFactor = 0.33;
  static const discSlideCurve = Cubic(0.2, 0.8, 0.2, 1);
  static final Duration discTurn = Duration(
    microseconds:
        (Duration.microsecondsPerMillisecond * 360 / AppMotion.discDegreesPerMs)
            .round(),
  );

  final bool revealed;
  final bool answered;
  final bool spinning;
  final String? coverUrl;
  final Color? placeholder;
  final String? previousCoverUrl;
  final Color? previousPlaceholder;

  @override
  State<RecordPlayer> createState() => _RecordPlayerState();
}

class _RecordPlayerState extends State<RecordPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: RecordPlayer.discTurn,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSpin();
  }

  @override
  void didUpdateWidget(RecordPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _syncSpin() {
    final run = widget.spinning && !AppMotion.reduced(context);
    if (run && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!run && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sleeve = AppLayout.of(context).sleeve;
    final disc = sleeve * RecordPlayer.discFactor;
    final motion = AppMotion.duration(context, AppMotion.recordFlip);
    final (backUrl, backPlaceholder) = widget.revealed
        ? (widget.coverUrl, widget.placeholder)
        : (widget.previousCoverUrl, widget.previousPlaceholder);
    const front = SleeveFront();
    final back = SleeveBack(coverUrl: backUrl, placeholder: backPlaceholder);
    return ExcludeSemantics(
      child: SizedBox(
        width: sleeve * RecordPlayer.boxFactor,
        height: sleeve,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(
                end: widget.answered
                    ? RecordPlayer.discOutFactor
                    : RecordPlayer.discRestFactor,
              ),
              duration: motion,
              curve: RecordPlayer.discSlideCurve,
              builder: (context, slide, child) => Positioned(
                left: sleeve * slide,
                top: sleeve * RecordPlayer.discTopFactor,
                width: disc,
                height: disc,
                child: child!,
              ),
              child: RotationTransition(
                turns: _spin,
                child: VinylDisc(
                  size: disc,
                  labelUrl: widget.coverUrl,
                  labelFraction:
                      RecordPlayer.labelFactor / RecordPlayer.discFactor,
                  showLabelImage: widget.revealed,
                  style: VinylStyle.record,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: sleeve,
              height: sleeve,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: widget.revealed ? 1 : 0),
                duration: motion,
                curve: AppMotion.recordFlipCurve,
                builder: (context, turn, _) =>
                    RecordSleeve(turn: turn, front: front, back: back),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecordSleeve extends StatelessWidget {
  const RecordSleeve({
    super.key,
    required this.turn,
    required this.front,
    required this.back,
  });

  static const double perspective = 1400;

  final double turn;
  final Widget front;
  final Widget back;

  double get degrees => turn * 180;

  bool get showsBack => turn > 0.5;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, -1 / perspective)
        ..rotateY(turn * math.pi),
      child: showsBack
          ? Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(math.pi),
              child: back,
            )
          : front,
    );
  }
}

class SleeveFront extends StatelessWidget {
  const SleeveFront({super.key});

  static const String side = 'Side A';
  static const String speed = '33⅓';
  static const double padding = 16;
  static const double ringFraction = 0.38;
  static const ringColor = Color.from(
    alpha: 0.18,
    red: 59 / 255,
    green: 47 / 255,
    blue: 47 / 255,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.sleeve,
        borderRadius: _sleeveRadius,
        boxShadow: _sleeveShadow(tokens),
      ),
      child: Padding(
        padding: const EdgeInsets.all(padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              side,
              style: AppType.display(
                22,
                italic: true,
                height: 24 / 22,
                color: tokens.sleeveFg,
              ),
            ),
            Align(
              child: FractionallySizedBox(
                widthFactor: ringFraction,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ringColor,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Text(
              speed,
              style: AppType.sized(11, 14).copyWith(color: tokens.sleeveFg),
            ),
          ],
        ),
      ),
    );
  }
}

class SleeveBack extends StatelessWidget {
  const SleeveBack({super.key, this.coverUrl, this.placeholder});

  final String? coverUrl;
  final Color? placeholder;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final url = coverUrl;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _sleeveRadius,
        boxShadow: _sleeveShadow(tokens),
      ),
      child: ClipRRect(
        borderRadius: _sleeveRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: placeholder ?? (url == null ? tokens.sleeve : tokens.card),
            ),
            if (url != null) CoverPicture(url),
          ],
        ),
      ),
    );
  }
}

const _sleeveRadius = BorderRadius.all(Radius.circular(4));

List<BoxShadow> _sleeveShadow(AppTokens tokens) => [
  CssBoxShadow(color: tokens.shadow, offset: const Offset(0, 18), blur: 40),
];
