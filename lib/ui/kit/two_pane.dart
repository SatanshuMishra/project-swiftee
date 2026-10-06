import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

class TwoPane extends StatelessWidget {
  const TwoPane({super.key, required this.left, required this.right});

  static const double dividerWidth = 1;

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final tokens = AppTokens.of(context);
    return LayoutBuilder(
      builder: (context, viewport) {
        final minHeight = viewport.hasBoundedHeight ? viewport.maxHeight : 0.0;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: layout.isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [left, right],
                  )
                : _PaneRow(
                    leftWidth: layout.leftColumn,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: tokens.line,
                              width: dividerWidth,
                            ),
                          ),
                        ),
                        child: left,
                      ),
                      right,
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _PaneRow extends MultiChildRenderObjectWidget {
  const _PaneRow({required this.leftWidth, required super.children});

  final double leftWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaneRow(leftWidth);

  @override
  void updateRenderObject(BuildContext context, _RenderPaneRow renderObject) {
    renderObject.leftWidth = leftWidth;
  }
}

class _PaneParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderPaneRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PaneParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PaneParentData> {
  _RenderPaneRow(this._leftWidth);

  double _leftWidth;

  set leftWidth(double value) {
    if (value != _leftWidth) {
      _leftWidth = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PaneParentData) {
      child.parentData = _PaneParentData();
    }
  }

  RenderBox get _left => firstChild!;

  RenderBox get _right => childAfter(_left)!;

  (double, double) _widths(double width) {
    final left = math.min(_leftWidth, width);
    return (left, width - left);
  }

  BoxConstraints _paneConstraints(BoxConstraints constraints, double width) =>
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        minHeight: constraints.minHeight,
        maxHeight: constraints.maxHeight,
      );

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final (leftWidth, rightWidth) = _widths(constraints.maxWidth);
    final height = math.max(
      _left.getDryLayout(_paneConstraints(constraints, leftWidth)).height,
      _right.getDryLayout(_paneConstraints(constraints, rightWidth)).height,
    );
    return constraints.constrain(Size(constraints.maxWidth, height));
  }

  @override
  void performLayout() {
    final (leftWidth, rightWidth) = _widths(constraints.maxWidth);
    final left = _left;
    final right = _right;
    left.layout(_paneConstraints(constraints, leftWidth), parentUsesSize: true);
    right.layout(
      _paneConstraints(constraints, rightWidth),
      parentUsesSize: true,
    );
    final height = math.max(left.size.height, right.size.height);
    if (left.size.height != height) {
      left.layout(
        BoxConstraints.tightFor(width: leftWidth, height: height),
        parentUsesSize: true,
      );
    }
    if (right.size.height != height) {
      right.layout(
        BoxConstraints.tightFor(width: rightWidth, height: height),
        parentUsesSize: true,
      );
    }
    (left.parentData! as _PaneParentData).offset = Offset.zero;
    (right.parentData! as _PaneParentData).offset = Offset(leftWidth, 0);
    size = constraints.constrain(Size(constraints.maxWidth, height));
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _leftWidth + _right.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _leftWidth + _right.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) {
    final (leftWidth, rightWidth) = _widths(width);
    return math.max(
      _left.getMinIntrinsicHeight(leftWidth),
      _right.getMinIntrinsicHeight(rightWidth),
    );
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final (leftWidth, rightWidth) = _widths(width);
    return math.max(
      _left.getMaxIntrinsicHeight(leftWidth),
      _right.getMaxIntrinsicHeight(rightWidth),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
