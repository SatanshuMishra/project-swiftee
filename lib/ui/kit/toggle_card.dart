import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/selected_check.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

class ToggleCard extends StatelessWidget {
  const ToggleCard({
    super.key,
    required this.title,
    required this.checked,
    required this.onTap,
  });

  static const padding = EdgeInsets.symmetric(vertical: 11, horizontal: 14);
  static const radius = BorderRadius.all(Radius.circular(12));
  static const double checkSize = 18;
  static const double gap = 10;
  static const double titleSize = 20;
  static const double titleLineHeight = 24;

  final String title;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Pressable(
      onPressed: onTap,
      checked: checked,
      focusRadius: radius,
      builder: (context, state) => AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.selectionShift),
        curve: Curves.ease,
        padding: padding,
        decoration: BoxDecoration(
          color: checked ? tokens.card : tokens.card.withValues(alpha: 0),
          borderRadius: radius,
          border: Border.all(
            color: checked || state.hovered ? tokens.coral : tokens.line2,
          ),
        ),
        child: Row(
          spacing: gap,
          children: [
            SelectedCheck(size: checkSize, checked: checked),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.display(
                  titleSize,
                  height: titleLineHeight / titleSize,
                  color: tokens.fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
