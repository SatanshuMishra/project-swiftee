import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

class SelectedCheck extends StatelessWidget {
  const SelectedCheck({super.key, required this.size, this.checked = true});

  static const String glyph = '✓';
  static const double ringWidth = 1.5;

  final double size;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? tokens.coral : null,
          border: checked
              ? null
              : Border.all(color: tokens.line2, width: ringWidth),
        ),
        child: checked
            ? Center(
                child: Text(
                  glyph,
                  style: AppType.sized(
                    size * 13 / 24,
                    size * 13 / 24,
                    weight: FontWeight.w700,
                  ).copyWith(color: tokens.onCoral),
                ),
              )
            : null,
      ),
    );
  }
}
