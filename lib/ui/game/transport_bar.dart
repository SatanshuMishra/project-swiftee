import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/domain/engine/relisten_schedule.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

enum TransportStatus { idle, loading, playing, paused, ended }

class TransportBar extends StatelessWidget {
  const TransportBar({
    super.key,
    required this.status,
    required this.stage,
    required this.elapsed,
    required this.duration,
    required this.onToggle,
    this.spaceToggles = true,
  });

  static const int fullClipSeconds = 30;
  static const String playingCaption = 'Space to pause';
  static const String clickCaption = 'Click to pause';
  static const String pausedCaption = 'Paused';
  static const String loadingCaption = 'Loading the clip…';
  static const String extendedNote = 'Clip extended to help with your guess';
  static const String playAction = 'Play';
  static const String pauseAction = 'Pause';
  static const double buttonSize = 44;
  static const double barHeight = 3;
  static const double rowGap = 14;
  static const double lineGap = 8;
  static const double captionGap = 12;
  static const progressMotion = Duration(milliseconds: 100);

  final TransportStatus status;
  final int stage;
  final double elapsed;
  final double duration;
  final VoidCallback? onToggle;
  final bool spaceToggles;

  static String captionFor(
    TransportStatus status,
    int stage, {
    bool spaceToggles = true,
  }) => switch (status) {
    TransportStatus.ended =>
      stage + 1 >= fullClipThreshold
          ? 'Play full clip (${fullClipSeconds}s)'
          : 'Listen again (${relistenSchedule[math.max(0, stage)].round()}s)',
    TransportStatus.paused => pausedCaption,
    TransportStatus.loading => loadingCaption,
    TransportStatus.idle ||
    TransportStatus.playing => spaceToggles ? playingCaption : clickCaption,
  };

  static String timeFor(double elapsed, double duration) =>
      '${elapsed.floor()}s / ${duration.round()}s';

  static bool extendedAt(int stage) => stage >= firstEscalationRelisten;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final caption = captionFor(status, stage, spaceToggles: spaceToggles);
    final fraction = duration > 0 ? (elapsed / duration).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: AppLayout.of(context).sleeve,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (status == TransportStatus.loading)
                const SizedBox.square(
                  dimension: buttonSize,
                  child: ClipRect(
                    child: Center(
                      child: CatLoader(size: CatLoaderSize.sm, px: buttonSize),
                    ),
                  ),
                )
              else
                TransportButton(
                  status: status,
                  semanticLabel: switch (status) {
                    TransportStatus.playing => pauseAction,
                    TransportStatus.ended => caption,
                    TransportStatus.idle ||
                    TransportStatus.loading ||
                    TransportStatus.paused => playAction,
                  },
                  onPressed: onToggle,
                ),
              const SizedBox(width: rowGap),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                  child: SizedBox(
                    height: barHeight,
                    child: ColoredBox(
                      color: tokens.line,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: fraction),
                        duration: AppMotion.duration(context, progressMotion),
                        builder: (context, value, _) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: value,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: tokens.fg,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: rowGap),
              Text(
                timeFor(elapsed, duration),
                style: AppType.caption.copyWith(
                  color: tokens.mut,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: lineGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  caption,
                  style: AppType.caption.copyWith(color: tokens.faint),
                ),
              ),
              if (extendedAt(stage)) ...[
                const SizedBox(width: captionGap),
                Flexible(
                  child: Text(
                    extendedNote,
                    textAlign: TextAlign.end,
                    style: AppType.caption.copyWith(color: tokens.mut),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

enum TransportGlyph { play, pause, again }

class TransportButton extends StatelessWidget {
  const TransportButton({
    super.key,
    required this.status,
    required this.onPressed,
    this.semanticLabel,
  });

  static const double hoverScale = 1.08;
  static const double pressScale = 0.94;
  static const focusRadius = BorderRadius.all(
    Radius.circular(TransportBar.buttonSize / 2),
  );

  final TransportStatus status;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  TransportGlyph get glyph => switch (status) {
    TransportStatus.playing => TransportGlyph.pause,
    TransportStatus.ended => TransportGlyph.again,
    TransportStatus.idle ||
    TransportStatus.loading ||
    TransportStatus.paused => TransportGlyph.play,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final motion = AppMotion.duration(context, AppMotion.hoverLift);
    return Pressable(
      onPressed: onPressed,
      focusRadius: focusRadius,
      semanticLabel: semanticLabel,
      builder: (context, state) => AnimatedScale(
        scale: state.pressed
            ? pressScale
            : state.hovered
            ? hoverScale
            : 1,
        duration: motion,
        curve: AppMotion.hoverLiftCurve,
        child: SizedBox.square(
          dimension: TransportBar.buttonSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.btn,
            ),
            child: Center(
              child: ExcludeSemantics(
                child: _Glyph(glyph: glyph, color: tokens.onBtn),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.glyph, required this.color});

  static const double barWidth = 4;
  static const double barHeight = 14;
  static const double barGap = 4;
  static const Size triangle = Size(13, 16);
  static const double triangleNudge = 3;
  static const String again = '↻';

  final TransportGlyph glyph;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return switch (glyph) {
      TransportGlyph.pause => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _bar(),
          const SizedBox(width: barGap),
          _bar(),
        ],
      ),
      TransportGlyph.play => Padding(
        padding: const EdgeInsets.only(left: triangleNudge),
        child: CustomPaint(size: triangle, painter: _TrianglePainter(color)),
      ),
      TransportGlyph.again => Text(
        again,
        style: AppType.sized(
          20,
          20,
          weight: FontWeight.w600,
        ).copyWith(color: color),
      ),
    };
  }

  Widget _bar() => SizedBox(
    width: barWidth,
    height: barHeight,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(1)),
      ),
    ),
  );
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}
