import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';

class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.streak});

  static const double gap = 6;
  static const double iconSize = 16;
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 6,
  );
  static const int borderPercent = 20;
  static const int fillPercent = 10;

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: AppPalette.orange500.slashOpacity(fillPercent),
        shape: StadiumBorder(
          side: BorderSide(
            color: AppPalette.orange500.slashOpacity(borderPercent),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon(
            LucideGlyph.sparkles,
            size: iconSize,
            color: AppPalette.orange400,
          ),
          const SizedBox(width: gap),
          Text(
            '$streak',
            style: AppText.sm.copyWith(
              fontWeight: FontWeight.w500,
              color: AppPalette.orange400,
            ),
          ),
        ],
      ),
    );
  }
}
