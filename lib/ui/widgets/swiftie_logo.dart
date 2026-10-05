import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

class SwiftieLogo extends StatelessWidget {
  const SwiftieLogo({super.key, this.size = 80, this.shadows = const []});

  final double size;
  final List<Shadow> shadows;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: SwiftieLogoPainter(shadows: shadows),
      ),
    );
  }
}

class SwiftieLogoPainter extends CustomPainter {
  const SwiftieLogoPainter({this.shadows = const []});

  static const double viewBox = 64;
  static const circleColor = AppPalette.brand;
  static const noteColor = AppPalette.white;
  static const noteOrigin = Offset(18, 12);
  static const stem = Rect.fromLTWH(20, 0, 4, 28);
  static const flag = Rect.fromLTWH(20, 0, 10, 4);
  static const headCenter = Offset(8, 34);
  static const double headRadius = 8;
  static const cornerRadius = Radius.circular(2);

  final List<Shadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    const center = Offset(viewBox / 2, viewBox / 2);
    const radius = viewBox / 2;
    final scale = size.width / viewBox;
    canvas
      ..save()
      ..scale(scale, scale);
    for (final shadow in shadows) {
      canvas.drawCircle(
        center + shadow.offset / scale,
        radius,
        Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            shadow.blurSigma / scale,
          ),
      );
    }
    final note = Paint()..color = noteColor;
    canvas
      ..drawCircle(center, radius, Paint()..color = circleColor)
      ..translate(noteOrigin.dx, noteOrigin.dy)
      ..drawRRect(RRect.fromRectAndRadius(stem, cornerRadius), note)
      ..drawCircle(headCenter, headRadius, note)
      ..drawRRect(RRect.fromRectAndRadius(flag, cornerRadius), note)
      ..restore();
  }

  @override
  bool shouldRepaint(SwiftieLogoPainter oldDelegate) =>
      !listEquals(oldDelegate.shadows, shadows);
}
