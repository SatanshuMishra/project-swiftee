import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

class TextLink extends StatelessWidget {
  const TextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.leading,
  });

  static const double minHeight = 44;
  static const double leadingGap = 8;
  static const focusRadius = BorderRadius.all(Radius.circular(4));
  static final TextStyle style = AppType.sized(14, 20);

  final String label;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Pressable(
      onPressed: onTap,
      focusRadius: focusRadius,
      builder: (context, state) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading case final leading?) ...[
              leading,
              const SizedBox(width: leadingGap),
            ],
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: state.hovered ? tokens.fg : tokens.mut),
              duration: AppMotion.duration(context, AppMotion.colorShift),
              curve: AppMotion.colorShiftCurve,
              builder: (context, color, _) =>
                  Text(label, style: style.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
