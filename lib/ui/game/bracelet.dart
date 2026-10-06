import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/kit/bead.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

class Bracelet extends StatelessWidget {
  const Bracelet({super.key, required this.streak, this.maxBeads = 10});

  static const String label = 'Your streak';
  static const double beadSize = 12;
  static const double gap = 5;
  static const double minWidth = 56;
  static const double sidePadding = 2;
  static const double tagHeight = 16;
  static const double tagPadding = 5;
  static const tagRadius = BorderRadius.all(Radius.circular(3));

  final int streak;
  final int maxBeads;

  static Color colorAt(int position) =>
      BrandColors.beads[position % BrandColors.beads.length];

  Iterable<int> get positions sync* {
    final first = streak > maxBeads ? streak - maxBeads : 0;
    for (var position = first; position < streak; position++) {
      yield position;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Semantics(
      label: label,
      value: '$streak',
      container: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: minWidth),
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            Positioned.fill(
              child: Center(
                child: SizedBox(
                  height: 1,
                  width: double.infinity,
                  child: ColoredBox(color: tokens.line2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: sidePadding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final position in positions) ...[
                    Bead(
                      key: ValueKey(position),
                      color: colorAt(position),
                      size: beadSize,
                      pop: position == streak - 1,
                    ),
                    const SizedBox(width: gap),
                  ],
                  ExcludeSemantics(
                    child: _Tag(streak: streak, tokens: tokens),
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

class _Tag extends StatelessWidget {
  const _Tag({required this.streak, required this.tokens});

  final int streak;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.paper,
        borderRadius: Bracelet.tagRadius,
        border: Border.all(
          color: tokens.line2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: SizedBox(
        height: Bracelet.tagHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Bracelet.tagPadding),
          child: Center(
            widthFactor: 1,
            child: Text(
              '$streak',
              style: AppType.sized(11, 16, weight: FontWeight.w700).copyWith(
                color: tokens.paperFg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
