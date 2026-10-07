import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  static const padding = EdgeInsets.symmetric(vertical: 16, horizontal: 18);
  static const radius = BorderRadius.all(Radius.circular(14));
  static const double gap = 14;
  static const double textGap = 2;
  static const double radioSize = 18;
  static const double radioTop = 3;
  static const double radioBorder = 1.5;
  static const double dotSize = 8;
  static const double titleSize = 26;
  static const double minTextWidth = 110;

  static double minWidthFor(TextScaler scaler) =>
      padding.horizontal +
      radioSize +
      gap +
      minTextWidth * scaler.scale(titleSize) / titleSize;

  final String title;
  final String description;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final shift = AppMotion.duration(context, AppMotion.selectionShift);
    final ring = selected ? tokens.coral : tokens.line2;
    return Pressable(
      onPressed: onTap,
      selected: selected,
      focusRadius: radius,
      builder: (context, state) => AnimatedContainer(
        duration: shift,
        curve: Curves.ease,
        padding: padding,
        decoration: BoxDecoration(
          color: selected ? tokens.card : tokens.card.withValues(alpha: 0),
          borderRadius: radius,
          border: Border.all(color: state.hovered ? tokens.coral : ring),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: radioTop),
              child: AnimatedContainer(
                duration: shift,
                curve: Curves.ease,
                width: radioSize,
                height: radioSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: radioBorder),
                ),
                alignment: Alignment.center,
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: shift,
                  curve: Curves.ease,
                  child: AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: shift,
                    curve: Curves.ease,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tokens.coral,
                      ),
                      child: const SizedBox.square(dimension: dotSize),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppType.display(
                      titleSize,
                      height: 30 / titleSize,
                      color: tokens.fg,
                    ),
                  ),
                  const SizedBox(height: textGap),
                  Text(
                    description,
                    style: AppType.sized(14, 20).copyWith(color: tokens.mut),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
