import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader_geometry.dart';

enum CatLoaderSize { lg, sm }

class CatLoader extends StatefulWidget {
  const CatLoader({
    super.key,
    this.size = CatLoaderSize.lg,
    this.label,
    this.labelStyle = defaultLabelStyle,
    this.px,
    this.phase,
  }) : assert(px == null || px > 0);

  static const TextStyle defaultLabelStyle = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: Color(0xFFA1A1A1),
  );

  static const double labelGap = 16;

  final CatLoaderSize size;
  final String? label;
  final TextStyle labelStyle;
  final double? px;
  final double? phase;

  @override
  State<CatLoader> createState() => _CatLoaderState();
}

class _CatLoaderState extends State<CatLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: CatLoaderGeometry.cycle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration =
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
        ? CatLoaderGeometry.reducedMotionCycle
        : CatLoaderGeometry.cycle;
    _run();
  }

  @override
  void didUpdateWidget(CatLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.phase == null) != (widget.phase == null)) {
      _run();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _run() {
    if (widget.phase == null) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final small = widget.size == CatLoaderSize.sm;
    final px = widget.px;
    final fixedPhase = widget.phase;
    final label = widget.label;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: px ?? (small ? 80 : 480),
          height: px ?? (small ? 80 : 360),
          child: Center(
            child: SizedBox.square(
              dimension: px ?? (small ? 80 : 300),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: CatLoaderPainter(
                    variant: small
                        ? CatLoaderGeometry.small
                        : CatLoaderGeometry.large,
                    phase: fixedPhase == null
                        ? _controller
                        : AlwaysStoppedAnimation<double>(fixedPhase % 1),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (label != null && label.isNotEmpty) ...<Widget>[
          const SizedBox(height: CatLoader.labelGap),
          Text(label, style: widget.labelStyle),
        ],
      ],
    );
  }
}

class CatLoaderPainter extends CustomPainter {
  CatLoaderPainter({required this.variant, required this.phase})
    : super(repaint: phase);

  final CatLoaderVariant variant;
  final Animation<double> phase;

  @override
  void paint(Canvas canvas, Size size) {
    final pose = CatLoaderGeometry.poseAt(phase.value);
    const viewBox = CatLoaderGeometry.viewBox;
    final scale = math.min(
      size.width / viewBox.width,
      size.height / viewBox.height,
    );
    canvas
      ..save()
      ..translate(
        (size.width - viewBox.width * scale) / 2,
        (size.height - viewBox.height * scale) / 2,
      )
      ..scale(scale)
      ..translate(-viewBox.left, -viewBox.top)
      ..transform(pose.frame)
      ..drawPath(
        pose.silhouette,
        _stroke(CatLoaderPalette.dark, variant.outline)
          ..strokeJoin = StrokeJoin.miter
          ..strokeMiterLimit = 4,
      )
      ..drawPath(pose.silhouette, _fill(CatLoaderPalette.cream));
    switch (pose.tummy) {
      case CatLoaderTummyArc(:final path):
        canvas.drawPath(
          path,
          _stroke(
            CatLoaderPalette.belly,
            CatLoaderGeometry.tummyWidth,
            cap: StrokeCap.round,
          ),
        );
      case CatLoaderTummyDot(:final centre):
        canvas.drawCircle(
          centre,
          CatLoaderGeometry.tummyWidth / 2,
          _fill(CatLoaderPalette.belly),
        );
    }
    canvas
      ..drawCircle(
        CatLoaderGeometry.bellyCentre,
        CatLoaderGeometry.bellyRadius,
        _fill(CatLoaderPalette.pink),
      )
      ..save()
      ..transform(CatLoaderGeometry.frontPawsPlacement)
      ..drawPath(CatLoaderGeometry.frontPaws, _fill(CatLoaderPalette.dark))
      ..restore()
      ..save()
      ..transform(CatLoaderGeometry.facePlacement);
    _paintFace(canvas);
    canvas
      ..restore()
      ..save()
      ..transform(pose.back)
      ..drawPath(CatLoaderGeometry.backPaws, _fill(CatLoaderPalette.dark));
    _paintStrokes(
      canvas,
      variant.toes,
      _stroke(
        CatLoaderPalette.line,
        CatLoaderGeometry.toeWidth,
        cap: StrokeCap.round,
      ),
    );
    canvas
      ..restore()
      ..drawPath(
        pose.tail,
        _stroke(CatLoaderPalette.dark, CatLoaderGeometry.tailWidth),
      )
      ..drawCircle(
        pose.tailTip,
        CatLoaderGeometry.tailTipRadius,
        _fill(CatLoaderPalette.dark),
      );
    if (variant.hasTailLine) {
      canvas.drawPath(
        pose.tailLine,
        _stroke(
          CatLoaderPalette.line,
          CatLoaderGeometry.tailLineWidth,
          cap: StrokeCap.round,
        ),
      );
    }
    canvas.restore();
  }

  void _paintFace(Canvas canvas) {
    _paintStrokes(
      canvas,
      variant.whiskers,
      _stroke(
        CatLoaderPalette.dark,
        variant.whiskerWidth,
        cap: StrokeCap.round,
      ),
    );
    final eyePaint = _fill(CatLoaderPalette.eye);
    for (final eye in variant.eyes) {
      canvas.drawCircle(eye, variant.eyeRadius, eyePaint);
    }
    canvas.drawOval(variant.mask, _fill(CatLoaderPalette.dark));
    final mouthPaint = _stroke(CatLoaderPalette.dark, variant.mouthWidth);
    for (final mouth in variant.mouths) {
      canvas.drawCircle(mouth, variant.mouthRadius, mouthPaint);
    }
  }

  static void _paintStrokes(
    Canvas canvas,
    List<CatLoaderStroke> strokes,
    Paint paint,
  ) {
    for (final stroke in strokes) {
      canvas.drawLine(stroke.from, stroke.to, paint);
    }
  }

  static Paint _fill(Color color) => Paint()..color = color;

  static Paint _stroke(
    Color color,
    double width, {
    StrokeCap cap = StrokeCap.butt,
  }) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = cap;

  @override
  bool shouldRepaint(CatLoaderPainter oldDelegate) =>
      oldDelegate.variant != variant || oldDelegate.phase.value != phase.value;
}
