import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

class ArrowRow extends StatelessWidget {
  const ArrowRow({
    super.key,
    required this.title,
    required this.description,
    required this.onTap,
    this.primary = false,
  });

  static const double verticalPadding = 26;
  static const double gap = 20;
  static const double titleGap = 4;
  static const double titleLineHeight = 1.1;
  static const double arrowSize = 44;
  static const double arrowGlyphSize = 20;
  static const String arrow = '→';

  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    return Opacity(
      opacity: onTap == null ? PillButton.disabledOpacity : 1,
      child: Pressable(
        onPressed: onTap,
        builder: (context, state) => Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.line)),
          ),
          child: AnimatedPadding(
            duration: AppMotion.duration(context, AppMotion.rowHoverPad),
            curve: AppMotion.rowHoverPadCurve,
            padding: EdgeInsets.only(
              left: state.hovered ? AppMotion.rowHoverPadOffset : 0,
              top: verticalPadding,
              bottom: verticalPadding,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppType.display(
                          layout.rowTitle,
                          height: titleLineHeight,
                          color: tokens.fg,
                        ),
                      ),
                      const SizedBox(height: titleGap),
                      Text(
                        description,
                        style: AppType.body.copyWith(color: tokens.mut),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: gap),
                SizedBox.square(
                  dimension: arrowSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary
                          ? tokens.coral
                          : tokens.coral.withValues(alpha: 0),
                      border: Border.all(
                        color: primary ? tokens.coral : tokens.line2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        arrow,
                        style: AppType.sized(
                          arrowGlyphSize,
                          24,
                        ).copyWith(color: primary ? tokens.onCoral : tokens.fg),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
