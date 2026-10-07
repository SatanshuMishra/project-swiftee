import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class WholeWordText extends StatelessWidget {
  const WholeWordText(String this.data, {super.key, this.style, this.textAlign})
    : textSpan = null;

  const WholeWordText.rich(
    TextSpan this.textSpan, {
    super.key,
    this.style,
    this.textAlign,
  }) : data = null;

  final String? data;
  final TextSpan? textSpan;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => _WholeWords(
    child: switch ((data, textSpan)) {
      (final String data, _) => Text(data, style: style, textAlign: textAlign),
      (_, final TextSpan span) => Text.rich(
        span,
        style: style,
        textAlign: textAlign,
      ),
      _ => const SizedBox.shrink(),
    },
  );
}

class _WholeWords extends SingleChildRenderObjectWidget {
  const _WholeWords({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderWholeWords();
}

class _RenderWholeWords extends RenderProxyBox {
  static const double smallestScale = 0.01;

  final LayerHandle<TransformLayer> _layer = LayerHandle<TransformLayer>();
  double _scale = 1;

  double _longestWord(RenderBox child) =>
      child.getMinIntrinsicWidth(double.infinity);

  double _scaleFor(RenderBox child, double maxWidth) {
    final longest = _longestWord(child);
    return !maxWidth.isFinite || longest <= maxWidth
        ? 1
        : math.max(maxWidth / longest, smallestScale);
  }

  double _widthAt(RenderBox child, double width, double scale) =>
      scale == 1 ? width : math.max(width / scale, _longestWord(child));

  BoxConstraints _childConstraints(
    RenderBox child,
    BoxConstraints constraints,
    double scale,
  ) => scale == 1
      ? constraints
      : BoxConstraints(
          minWidth: constraints.minWidth / scale,
          maxWidth: _widthAt(child, constraints.maxWidth, scale),
          minHeight: constraints.minHeight / scale,
          maxHeight: constraints.maxHeight / scale,
        );

  Matrix4 get _transform => Matrix4.diagonal3Values(_scale, _scale, 1);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      _scale = 1;
      size = constraints.smallest;
      return;
    }
    _scale = _scaleFor(child, constraints.maxWidth);
    child.layout(
      _childConstraints(child, constraints, _scale),
      parentUsesSize: true,
    );
    size = constraints.constrain(child.size * _scale);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) {
      return constraints.smallest;
    }
    final scale = _scaleFor(child, constraints.maxWidth);
    return constraints.constrain(
      child.getDryLayout(_childConstraints(child, constraints, scale)) * scale,
    );
  }

  double _heightAt(double width, double Function(RenderBox, double) measure) {
    final child = this.child;
    if (child == null) {
      return 0;
    }
    final scale = _scaleFor(child, width);
    return measure(child, _widthAt(child, width, scale)) * scale;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _heightAt(width, (child, width) => child.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _heightAt(width, (child, width) => child.getMaxIntrinsicHeight(width));

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    if (child == null) {
      return null;
    }
    final scale = _scaleFor(child, constraints.maxWidth);
    return switch (child.getDryBaseline(
      _childConstraints(child, constraints, scale),
      baseline,
    )) {
      final distance? => distance * scale,
      null => null,
    };
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      switch (child?.getDistanceToActualBaseline(baseline)) {
        final distance? => distance * _scale,
        null => null,
      };

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) {
      _layer.layer = null;
      return;
    }
    if (_scale == 1) {
      _layer.layer = null;
      context.paintChild(child, offset);
      return;
    }
    _layer.layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: _layer.layer,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    return child != null &&
        result.addWithPaintTransform(
          transform: _transform,
          position: position,
          hitTest: (result, position) =>
              child.hitTest(result, position: position),
        );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.multiply(_transform);

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }
}
