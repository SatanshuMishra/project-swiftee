import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

class ScreenBackground extends StatelessWidget {
  const ScreenBackground({super.key, required this.child, this.controller});

  final Widget child;
  final ScrollController? controller;

  static CssLinearGradient gradientFor(AppTokens tokens) => GradientPair(
    tokens.background,
    tokens.muted.slashOpacity(20),
  ).tailwind(const CssGradientDirection.toBottomRight());

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return ColoredBox(
      color: tokens.background,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          controller: controller,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              minHeight: constraints.maxHeight,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: gradientFor(tokens)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
