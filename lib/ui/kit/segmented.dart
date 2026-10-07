import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  static const trackPadding = EdgeInsets.all(3);
  static const segmentPadding = EdgeInsets.symmetric(
    vertical: 6,
    horizontal: 14,
  );
  static const double gap = 2;
  static const radius = BorderRadius.all(Radius.circular(999));
  static final TextStyle style = AppType.sized(13, 18, weight: FontWeight.w500);

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final shift = AppMotion.duration(context, AppMotion.selectionShift);
    return Container(
      padding: trackPadding,
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: radius,
        border: Border.all(color: tokens.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, (option, label)) in options.indexed) ...[
            if (index > 0) const SizedBox(width: gap),
            Pressable(
              onPressed: switch (onChanged) {
                final onChanged? => () => onChanged(option),
                null => null,
              },
              selected: option == value,
              focusRadius: radius,
              builder: (context, state) {
                final selected = option == value;
                return AnimatedContainer(
                  duration: shift,
                  curve: Curves.ease,
                  padding: segmentPadding,
                  decoration: BoxDecoration(
                    color: selected
                        ? tokens.btn
                        : tokens.btn.withValues(alpha: 0),
                    borderRadius: radius,
                  ),
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(
                      end: selected
                          ? tokens.onBtn
                          : state.hovered
                          ? tokens.fg
                          : tokens.mut,
                    ),
                    duration: shift,
                    curve: Curves.ease,
                    builder: (context, color, _) => Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: style.copyWith(color: color),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
