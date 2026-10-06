import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/game/bracelet.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/ui/widgets/back_link.dart';

class GameTopBar extends StatelessWidget {
  const GameTopBar({
    super.key,
    required this.modeLabel,
    required this.difficultyLabel,
    required this.streak,
    required this.onExit,
    this.round,
    this.totalRounds,
    this.timeFraction,
    this.timerRunning = false,
  });

  static const String exitLabel = 'Exit';
  static const padding = EdgeInsets.fromLTRB(32, 14, 32, 12);
  static const double gap = 16;
  static const double labelGap = 8;
  static const double timerHeight = 2;
  static const double timerInset = 32;
  static const double urgentFraction = 0.3;
  static const runningMotion = Duration(milliseconds: 100);
  static const settleMotion = Duration(milliseconds: 300);
  static const colorMotion = Duration(milliseconds: 300);

  final String modeLabel;
  final String difficultyLabel;
  final int streak;
  final VoidCallback onExit;
  final int? round;
  final int? totalRounds;
  final double? timeFraction;
  final bool timerRunning;

  String get label => '$modeLabel · $difficultyLabel';

  String? get roundLabel => switch ((round, totalRounds)) {
    (final round?, final total?) when total > 0 => '· Round $round of $total',
    _ => null,
  };

  static bool urgentAt(double fraction) => fraction <= urgentFraction;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final style = AppType.sized(14, 20);
    final rounds = roundLabel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: padding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BackLink(
                label: exitLabel,
                onPressed: onExit,
                animateEntrance: false,
              ),
              const SizedBox(width: gap),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(color: tokens.mut),
                      ),
                    ),
                    if (rounds != null) ...[
                      const SizedBox(width: labelGap),
                      Text(
                        rounds,
                        maxLines: 1,
                        softWrap: false,
                        style: style.copyWith(color: tokens.fg),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: gap),
              Bracelet(streak: streak),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: timerInset),
          child: SizedBox(
            height: timerHeight,
            child: ColoredBox(
              color: tokens.line,
              child: switch (timeFraction) {
                final fraction? => TimerFill(
                  fraction: fraction.clamp(0.0, 1.0),
                  running: timerRunning,
                ),
                null => const SizedBox.shrink(),
              },
            ),
          ),
        ),
      ],
    );
  }
}

class TimerFill extends StatelessWidget {
  const TimerFill({super.key, required this.fraction, required this.running});

  final double fraction;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final color = GameTopBar.urgentAt(fraction) ? tokens.rose : tokens.coral;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: fraction),
      duration: AppMotion.duration(
        context,
        running ? GameTopBar.runningMotion : GameTopBar.settleMotion,
      ),
      curve: running ? Curves.linear : Curves.ease,
      builder: (context, width, child) => FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: width,
        child: child,
      ),
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: AppMotion.duration(context, GameTopBar.colorMotion),
        curve: Curves.ease,
        builder: (context, fill, _) =>
            ColoredBox(color: fill ?? color, child: const SizedBox.expand()),
      ),
    );
  }
}
