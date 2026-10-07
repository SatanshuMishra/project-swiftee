import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/whole_word_text.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  static const padding = EdgeInsets.symmetric(vertical: 14, horizontal: 16);
  static const radius = BorderRadius.all(Radius.circular(14));
  static const double textGap = 2;
  static const double titleSize = 24;
  static const double minWidth = 120;

  static double minWidthFor(TextScaler scaler) =>
      minWidth * scaler.scale(titleSize) / titleSize;

  final String title;
  final String description;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Pressable(
      onPressed: onTap,
      selected: selected,
      focusRadius: radius,
      builder: (context, state) => AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.selectionShift),
        curve: Curves.ease,
        padding: padding,
        decoration: BoxDecoration(
          color: selected ? tokens.card : tokens.card.withValues(alpha: 0),
          borderRadius: radius,
          border: Border.all(
            color: selected || state.hovered ? tokens.coral : tokens.line2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            WholeWordText(
              title,
              style: AppType.display(
                titleSize,
                height: 28 / titleSize,
                color: tokens.fg,
              ),
            ),
            const SizedBox(height: textGap),
            Text(description, style: AppType.small.copyWith(color: tokens.mut)),
          ],
        ),
      ),
    );
  }
}
