import 'package:flutter/material.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';

class BackLink extends StatelessWidget {
  const BackLink({
    super.key,
    required this.onPressed,
    this.label = 'Back',
    this.animateEntrance = true,
  });

  static const entranceOffset = Offset(-10, 0);
  static const double minHeight = 32;
  static const String arrow = '← ';
  static const focusRadius = BorderRadius.all(Radius.circular(4));
  static final TextStyle style = AppType.sized(14, 20);

  final VoidCallback onPressed;
  final String label;
  final bool animateEntrance;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final link = Pressable(
      onPressed: onPressed,
      focusRadius: focusRadius,
      builder: (context, state) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: state.hovered ? tokens.fg : tokens.mut),
          duration: AppMotion.duration(context, AppMotion.colorShift),
          curve: AppMotion.colorShiftCurve,
          builder: (context, color, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(arrow, style: style.copyWith(color: color)),
              Text(label, style: style.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
    if (!animateEntrance || AppMotion.reduced(context)) {
      return link;
    }
    return Entrance(fromOffset: entranceOffset, child: link);
  }
}
