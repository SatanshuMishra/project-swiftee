import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

class NextPrompt extends StatelessWidget {
  const NextPrompt({
    super.key,
    required this.onNext,
    this.enabled = false,
    this.label = nextSong,
  });

  static const String nextSong = 'Next song →';
  static const String seeRound = 'See your round →';
  static const String hint = 'or press Enter';
  static const double gap = 14;
  static const double waitingOpacity = 0.45;
  static const padding = EdgeInsets.symmetric(vertical: 12, horizontal: 24);
  static const radius = BorderRadius.all(Radius.circular(999));
  static const opacityMotion = Duration(milliseconds: 300);
  static const riseMotion = Duration(milliseconds: 300);

  final VoidCallback onNext;
  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return RiseIn(
      duration: riseMotion,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: gap,
        runSpacing: gap,
        children: [
          AnimatedOpacity(
            opacity: enabled ? 1 : waitingOpacity,
            duration: AppMotion.duration(context, opacityMotion),
            curve: Curves.ease,
            child: Pressable(
              onPressed: onNext,
              enabled: enabled,
              focusRadius: radius,
              builder: (context, _) => DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.btn,
                  borderRadius: radius,
                ),
                child: Padding(
                  padding: padding,
                  child: Text(
                    label,
                    style: AppType.sized(
                      15,
                      20,
                      weight: FontWeight.w600,
                    ).copyWith(color: tokens.onBtn),
                  ),
                ),
              ),
            ),
          ),
          Text(hint, style: AppType.small.copyWith(color: tokens.faint)),
        ],
      ),
    );
  }
}

class RiseIn extends StatelessWidget {
  const RiseIn({super.key, required this.duration, required this.child});

  static const double offset = 8;

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.duration(context, duration),
      curve: Curves.ease,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, offset * (1 - progress)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
