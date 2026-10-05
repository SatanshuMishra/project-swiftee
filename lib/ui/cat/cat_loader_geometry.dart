import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

typedef CatLoaderKeyframes = ({
  List<double> times,
  List<double> values,
  double shift,
});

typedef CatLoaderStroke = ({Offset from, Offset to});

typedef CatLoaderVariant = ({
  double outline,
  List<CatLoaderStroke> whiskers,
  double whiskerWidth,
  List<Offset> eyes,
  double eyeRadius,
  Rect mask,
  List<Offset> mouths,
  double mouthRadius,
  double mouthWidth,
  List<CatLoaderStroke> toes,
  bool hasTailLine,
});

typedef CatLoaderPose = ({
  double spin,
  double bodyEnd,
  Float64List frame,
  Path silhouette,
  CatLoaderTummy tummy,
  Float64List back,
  Path tail,
  Offset tailTip,
  Path tailLine,
});

sealed class CatLoaderTummy {
  const CatLoaderTummy();
}

final class CatLoaderTummyArc extends CatLoaderTummy {
  const CatLoaderTummyArc(this.path);

  final Path path;
}

final class CatLoaderTummyDot extends CatLoaderTummy {
  const CatLoaderTummyDot(this.centre);

  final Offset centre;
}

abstract final class CatLoaderPalette {
  static const Color dark = Color(0xFF3B2F2F);
  static const Color cream = Color(0xFFF5E5D4);
  static const Color belly = Color(0xFFFBF0E6);
  static const Color eye = Color(0xFF6FA8DC);
  static const Color pink = Color(0xFFD4A0A0);
  static const Color line = Color(0xFFEBE9E9);
}

abstract final class CatLoaderGeometry {
  static const Duration cycle = Duration(milliseconds: 2740);
  static const Duration reducedMotionCycle = Duration(milliseconds: 6850);

  static const Rect viewBox = Rect.fromLTWH(-30, -30, 300, 300);
  static const Offset centre = Offset(120, 120);

  static const double ringRadius = 90;
  static const double halfWidth = 24;
  static const double iconScale = 0.8;
  static const double earAngle = -72;
  static const double earDip = 4.6;
  static const double dipAngle = earAngle + earDip;

  static const double iconCentreX = 43.5;
  static const double earDipIconY = 14;
  static const double faceIconY = 36;
  static const double bellyIconY = 67;
  static const double frontPawsIconY = 87.5;
  static const double rumpIconY = 141.5;
  static const double backPawsIconY = 142.5;
  static const double tailTipIconY = 174;

  static const double tummyWidth = 33 * iconScale;
  static const double bellyRadius = 15 * iconScale;
  static const double tailWidth = 13 * iconScale;
  static const double tailTipIconRadius = 6.5;
  static const double tailTipRadius = tailTipIconRadius * iconScale;
  static const double tailLineWidth = 1.5 * iconScale;
  static const double toeWidth = 1.5;

  static const CatLoaderKeyframes spinKeyframes = (
    times: <double>[0, .1, .2, .4, .5, .68, .9, 1],
    values: <double>[0, -80, -180, -245, -250, -300, -560, -720],
    shift: -720,
  );

  static const CatLoaderKeyframes bodyKeyframes = (
    times: <double>[0, .1, .2, .4, .5, .65, .8, .9, 1],
    values: <double>[180, 105.9, 38.7, -5.7, -5.7, 16.7, 72.6, 139.4, 180],
    shift: 0,
  );

  static const CatLoaderVariant large = (
    outline: 10,
    whiskers: <CatLoaderStroke>[
      (from: Offset(68.5, 31.5), to: Offset(92, 23.5)),
      (from: Offset(68.5, 35.5), to: Offset(93, 35.5)),
      (from: Offset(68.5, 39.5), to: Offset(92, 47)),
      (from: Offset(18.5, 31.5), to: Offset(-5, 23.5)),
      (from: Offset(18.5, 35.5), to: Offset(-6, 35.5)),
      (from: Offset(18.5, 39.5), to: Offset(-5, 47)),
    ],
    whiskerWidth: 2,
    eyes: <Offset>[Offset(31, 32), Offset(56, 32)],
    eyeRadius: 3.5,
    mask: Rect.fromLTRB(35.5, 30, 51.5, 42),
    mouths: <Offset>[Offset(39.5, 41.5), Offset(47.5, 41.5)],
    mouthRadius: 3.5,
    mouthWidth: 2,
    toes: <CatLoaderStroke>[
      (from: Offset(26.5, 134), to: Offset(26.5, 150)),
      (from: Offset(60.5, 134), to: Offset(60.5, 150)),
    ],
    hasTailLine: true,
  );

  static const CatLoaderVariant small = (
    outline: 16,
    whiskers: <CatLoaderStroke>[
      (from: Offset(70, 31), to: Offset(84, 26)),
      (from: Offset(70, 39), to: Offset(84, 43)),
      (from: Offset(17, 31), to: Offset(3, 26)),
      (from: Offset(17, 39), to: Offset(3, 43)),
    ],
    whiskerWidth: 5,
    eyes: <Offset>[Offset(30, 31), Offset(57, 31)],
    eyeRadius: 6,
    mask: Rect.fromLTRB(34, 30.5, 53, 45.5),
    mouths: <Offset>[],
    mouthRadius: 0,
    mouthWidth: 0,
    toes: <CatLoaderStroke>[],
    hasTailLine: false,
  );

  static const double _degreesPerRadian = 180 / math.pi;

  static final double Function(double) _spin = monotoneSpline(spinKeyframes);
  static final double Function(double) _bodyEnd = monotoneSpline(bodyKeyframes);

  static final List<Offset> frontEdge = List<Offset>.unmodifiable(<Offset>[
    for (var i = 0; i <= 24; i++) _frontEdgePoint(i),
  ]);

  static final Path frontPaws = _paws(top: 75);
  static final Path backPaws = _paws(top: 130);

  static final Offset bellyCentre = pol(ringRadius, angY(bellyIconY));
  static final Float64List frontPawsPlacement = place(
    angY(frontPawsIconY),
    frontPawsIconY,
  );
  static final Float64List facePlacement = place(angY(faceIconY), faceIconY);

  static double spin(double p) => _spin(p);

  static double bodyEnd(double p) => _bodyEnd(p);

  static double Function(double) monotoneSpline(CatLoaderKeyframes keyframes) {
    final t = keyframes.times;
    final v = keyframes.values;
    final n = t.length;
    final times = List<double>.unmodifiable(<double>[
      t[n - 2] - 1,
      ...t,
      t[1] + 1,
    ]);
    final values = List<double>.unmodifiable(<double>[
      v[n - 2] - keyframes.shift,
      ...v,
      v[1] + keyframes.shift,
    ]);
    final slopes = List<double>.unmodifiable(<double>[
      for (var k = 0; k < times.length - 1; k++)
        (values[k + 1] - values[k]) / (times[k + 1] - times[k]),
    ]);
    final tangents = List<double>.generate(times.length, (k) {
      if (k == 0) return slopes[0];
      if (k == times.length - 1) return slopes[k - 1];
      if (slopes[k - 1] * slopes[k] <= 0) return 0;
      return (slopes[k - 1] + slopes[k]) / 2;
    });
    for (var k = 0; k < slopes.length; k++) {
      if (slopes[k] == 0) {
        tangents[k] = 0;
        tangents[k + 1] = 0;
        continue;
      }
      final a = tangents[k] / slopes[k];
      final b = tangents[k + 1] / slopes[k];
      final s = a * a + b * b;
      if (s > 9) {
        final tau = 3 / math.sqrt(s);
        tangents[k] = tau * a * slopes[k];
        tangents[k + 1] = tau * b * slopes[k];
      }
    }
    final m = List<double>.unmodifiable(tangents);
    return (p) {
      var k = 1;
      while (k < times.length - 2 && p > times[k + 1]) {
        k++;
      }
      final h = times[k + 1] - times[k];
      final u = (p - times[k]) / h;
      final u2 = u * u;
      final u3 = u2 * u;
      return (2 * u3 - 3 * u2 + 1) * values[k] +
          (u3 - 2 * u2 + u) * h * m[k] +
          (-2 * u3 + 3 * u2) * values[k + 1] +
          (u3 - u2) * h * m[k + 1];
    };
  }

  static Offset pol(double r, double a) => Offset(
    centre.dx + r * math.cos(a / _degreesPerRadian),
    centre.dy + r * math.sin(a / _degreesPerRadian),
  );

  static double angY(double y) =>
      dipAngle +
      ((y - earDipIconY) * iconScale / ringRadius) * _degreesPerRadian;

  static double backA(double bodyEnd, double dy) =>
      bodyEnd + (dy * iconScale / ringRadius) * _degreesPerRadian;

  static Path arc(double r, double a0, double a1) {
    final start = pol(r, a0);
    return Path()
      ..moveTo(start.dx, start.dy)
      ..arcToPoint(
        pol(r, a1),
        radius: Radius.circular(r),
        largeArc: a1 - a0 > 180,
      );
  }

  static Path silhouette(double bodyEnd) {
    const inner = ringRadius - halfWidth;
    const outer = ringRadius + halfWidth;
    final big = bodyEnd - earAngle > 180;
    final outerEnd = pol(outer, bodyEnd);
    final path = Path()..moveTo(frontEdge.first.dx, frontEdge.first.dy);
    for (final point in frontEdge.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path
      ..arcToPoint(
        pol(inner, bodyEnd),
        radius: const Radius.circular(inner),
        largeArc: big,
      )
      ..lineTo(outerEnd.dx, outerEnd.dy)
      ..arcToPoint(
        pol(outer, earAngle),
        radius: const Radius.circular(outer),
        largeArc: big,
        clockwise: false,
      )
      ..close();
  }

  static Float64List place(double a, double yA, {double s = iconScale}) {
    final origin = pol(ringRadius, a);
    final radians = a / _degreesPerRadian;
    final xx = s * math.cos(radians);
    final xy = s * math.sin(radians);
    return _affine(
      xx,
      xy,
      -xy,
      xx,
      origin.dx - xx * iconCentreX + xy * yA,
      origin.dy - xy * iconCentreX - xx * yA,
    );
  }

  static Float64List rotation(double degrees) {
    final radians = degrees / _degreesPerRadian;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return _affine(
      cos,
      sin,
      -sin,
      cos,
      centre.dx - cos * centre.dx + sin * centre.dy,
      centre.dy - sin * centre.dx - cos * centre.dy,
    );
  }

  static CatLoaderPose poseAt(double p) {
    final spinDegrees = spin(p);
    final end = bodyEnd(p);
    final tummyStart = angY(bellyIconY);
    final tummyEnd =
        backA(end, -17.5) - (16.5 * iconScale / ringRadius) * _degreesPerRadian;
    final tailEnd = backA(end, tailTipIconY - rumpIconY - tailTipIconRadius);
    return (
      spin: spinDegrees,
      bodyEnd: end,
      frame: rotation(spinDegrees),
      silhouette: silhouette(end),
      tummy: tummyEnd > tummyStart
          ? CatLoaderTummyArc(arc(ringRadius, tummyStart, tummyEnd))
          : CatLoaderTummyDot(pol(ringRadius, tummyStart)),
      back: place(backA(end, 1), backPawsIconY),
      tail: arc(ringRadius, backA(end, -1.5), tailEnd),
      tailTip: pol(ringRadius, tailEnd),
      tailLine: arc(ringRadius, backA(end, 3.5), backA(end, 27.5)),
    );
  }

  static Offset _frontEdgePoint(int i) {
    final r = ringRadius + halfWidth - (2 * halfWidth * i) / 24;
    final u = (r - ringRadius).abs() / halfWidth;
    return pol(r, earAngle + earDip * math.sin((math.pi / 2) * (1 - u)));
  }

  static Path _paws({required double top}) =>
      _paw(left: 19.8, top: top)
        ..addPath(_paw(left: 53.8, top: top), Offset.zero);

  static Path _paw({required double left, required double top}) => Path()
    ..moveTo(left, top)
    ..lineTo(left + 13.4, top)
    ..lineTo(left + 13.4, top + 20)
    ..cubicTo(
      left + 13.4,
      top + 22.76,
      left + 11.16,
      top + 25,
      left + 8.4,
      top + 25,
    )
    ..lineTo(left + 5, top + 25)
    ..cubicTo(left + 2.24, top + 25, left, top + 22.76, left, top + 20)
    ..lineTo(left, top)
    ..close();

  static Float64List _affine(
    double a,
    double b,
    double c,
    double d,
    double e,
    double f,
  ) => Float64List.fromList(<double>[
    a,
    b,
    0,
    0,
    c,
    d,
    0,
    0,
    0,
    0,
    1,
    0,
    e,
    f,
    0,
    1,
  ]);
}
