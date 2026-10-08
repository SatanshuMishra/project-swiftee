import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

class ChoiceGrid extends StatelessWidget {
  const ChoiceGrid({
    super.key,
    required this.columns,
    required this.minTileWidth,
    required this.children,
  });

  static const double gap = 10;

  final int columns;
  final double minTileWidth;
  final List<Widget> children;

  int _columnsIn(double width) => width.isFinite
      ? ((width + gap) / (minTileWidth + gap)).floor().clamp(1, columns)
      : columns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        for (final row in children.slices(_columnsIn(constraints.maxWidth)))
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: gap,
              children: [for (final child in row) Expanded(child: child)],
            ),
          ),
      ],
    ),
  );
}
