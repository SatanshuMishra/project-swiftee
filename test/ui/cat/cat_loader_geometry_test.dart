import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader_geometry.dart';

const javascriptReference = <({double p, double spin, double bodyEnd})>[
  (p: 0, spin: 0, bodyEnd: 180),
  (p: 0.1, spin: -80, bodyEnd: 105.9),
  (p: 0.2, spin: -180, bodyEnd: 38.7),
  (p: 0.3, spin: -226.239042, bodyEnd: 5.325),
  (p: 0.4, spin: -245, bodyEnd: -5.7),
  (p: 0.45, spin: -247.677773, bodyEnd: -5.7),
  (p: 0.5, spin: -250, bodyEnd: -5.7),
  (p: 0.65, spin: -281.50349, bodyEnd: 16.7),
  (p: 0.8, spin: -424.390183, bodyEnd: 72.6),
  (p: 0.9, spin: -560, bodyEnd: 139.4),
  (p: 0.99, spin: -707.051818, bodyEnd: 179.3465),
];

const designKeyframeSpin = <(double, double)>[
  (0, 0),
  (0.1, -80),
  (0.2, -180),
  (0.4, -245),
  (0.5, -250),
  (0.68, -300),
  (0.9, -560),
  (1, -720),
];

const designKeyframeBody = <(double, double)>[
  (0, 180),
  (0.1, 105.9),
  (0.2, 38.7),
  (0.4, -5.7),
  (0.5, -5.7),
  (0.65, 16.7),
  (0.8, 72.6),
  (0.9, 139.4),
  (1, 180),
];

const markupTolerance = 0.01;

Offset applyAffine(Float64List matrix, Offset point) => Offset(
  matrix[0] * point.dx + matrix[4] * point.dy + matrix[12],
  matrix[1] * point.dx + matrix[5] * point.dy + matrix[13],
);

Offset pointAlong(Path path, double fraction) {
  final metric = path.computeMetrics().single;
  return metric.getTangentForOffset(metric.length * fraction)!.position;
}

Matcher rectNear(Rect rect) => isA<Rect>()
    .having((r) => r.left, 'left', closeTo(rect.left, 1e-4))
    .having((r) => r.top, 'top', closeTo(rect.top, 1e-4))
    .having((r) => r.right, 'right', closeTo(rect.right, 1e-4))
    .having((r) => r.bottom, 'bottom', closeTo(rect.bottom, 1e-4));

Matcher offsetNear(double x, double y) => isA<Offset>()
    .having((o) => o.dx, 'dx', closeTo(x, markupTolerance))
    .having((o) => o.dy, 'dy', closeTo(y, markupTolerance));

void main() {
  group('loader spline matches the design keyframes', () {
    test('spin equals the SPIN keyframe values at keyframe times', () {
      for (final (time, value) in designKeyframeSpin) {
        expect(CatLoaderGeometry.spin(time), closeTo(value, 1e-9));
      }
    });

    test('bodyEnd equals the BODY keyframe values at keyframe times', () {
      for (final (time, value) in designKeyframeBody) {
        expect(CatLoaderGeometry.bodyEnd(time), closeTo(value, 1e-9));
      }
    });

    test('spin matches the JavaScript spline within 0.01 degrees', () {
      for (final reference in javascriptReference) {
        expect(
          CatLoaderGeometry.spin(reference.p),
          closeTo(reference.spin, 0.01),
          reason: 'spin at p = ${reference.p}',
        );
      }
    });

    test('bodyEnd matches the JavaScript spline within 0.01 degrees', () {
      for (final reference in javascriptReference) {
        expect(
          CatLoaderGeometry.bodyEnd(reference.p),
          closeTo(reference.bodyEnd, 0.01),
          reason: 'bodyEnd at p = ${reference.p}',
        );
      }
    });

    test('the tables are the design keyframes', () {
      expect(CatLoaderGeometry.spinKeyframes.times, <double>[
        for (final (time, _) in designKeyframeSpin) time,
      ]);
      expect(CatLoaderGeometry.spinKeyframes.values, <double>[
        for (final (_, value) in designKeyframeSpin) value,
      ]);
      expect(CatLoaderGeometry.spinKeyframes.shift, -720);
      expect(CatLoaderGeometry.bodyKeyframes.times, <double>[
        for (final (time, _) in designKeyframeBody) time,
      ]);
      expect(CatLoaderGeometry.bodyKeyframes.values, <double>[
        for (final (_, value) in designKeyframeBody) value,
      ]);
      expect(CatLoaderGeometry.bodyKeyframes.shift, 0);
    });
  });

  group('loader geometry matches the design markup', () {
    test('constants are the design values', () {
      expect(CatLoaderGeometry.cycle, const Duration(milliseconds: 2740));
      expect(
        CatLoaderGeometry.reducedMotionCycle,
        const Duration(milliseconds: 6850),
      );
      expect(CatLoaderGeometry.ringRadius, 90);
      expect(CatLoaderGeometry.halfWidth, 24);
      expect(CatLoaderGeometry.iconScale, 0.8);
      expect(CatLoaderGeometry.earAngle, -72);
      expect(CatLoaderGeometry.earDip, 4.6);
      expect(
        CatLoaderGeometry.viewBox,
        const Rect.fromLTWH(-30, -30, 300, 300),
      );
      expect(CatLoaderPalette.dark, const Color(0xFF3B2F2F));
      expect(CatLoaderPalette.cream, const Color(0xFFF5E5D4));
      expect(CatLoaderPalette.belly, const Color(0xFFFBF0E6));
      expect(CatLoaderPalette.eye, const Color(0xFF6FA8DC));
      expect(CatLoaderPalette.pink, const Color(0xFFD4A0A0));
      expect(CatLoaderPalette.line, const Color(0xFFEBE9E9));
    });

    test('the front edge runs ear to ear through the dip', () {
      final edge = CatLoaderGeometry.frontEdge;
      expect(edge, hasLength(25));
      expect(edge.first, offsetNear(155.23, 11.58));
      expect(edge[1], offsetNear(155.72, 13.85));
      expect(edge[12], offsetNear(154.59, 36.91));
      expect(edge.last, offsetNear(140.40, 57.23));
    });

    test('ring angles follow angY and backA', () {
      expect(CatLoaderGeometry.angY(67), closeTo(-40.40732165161455, 1e-9));
      expect(CatLoaderGeometry.angY(87.5), closeTo(-29.966757384786213, 1e-9));
      expect(CatLoaderGeometry.angY(36), closeTo(-56.195492006330575, 1e-9));
      expect(CatLoaderGeometry.bellyCentre, offsetNear(188.53, 61.66));
    });

    test('front paws and face are placed as the markup places them', () {
      expect(
        applyAffine(
          CatLoaderGeometry.frontPawsPlacement,
          const Offset(43.5, 87.5),
        ),
        offsetNear(197.97, 75.05),
      );
      expect(
        applyAffine(CatLoaderGeometry.facePlacement, const Offset(43.5, 36)),
        offsetNear(170.07, 45.22),
      );
      final scaledRight = applyAffine(
        CatLoaderGeometry.facePlacement,
        const Offset(44.5, 36),
      );
      final origin = applyAffine(
        CatLoaderGeometry.facePlacement,
        const Offset(43.5, 36),
      );
      expect((scaledRight - origin).distance, closeTo(0.8, 1e-9));
      expect(
        (scaledRight - origin).direction * 180 / 3.141592653589793,
        closeTo(-56.20, markupTolerance),
      );
    });

    test('the pose at p = 0.3 matches the markup', () {
      final pose = CatLoaderGeometry.poseAt(0.3);
      expect(pose.spin, closeTo(-226.2390421946376, 1e-9));
      expect(pose.bodyEnd, closeTo(5.325000000000008, 1e-9));
      expect(
        applyAffine(pose.frame, const Offset(120, 120)),
        offsetNear(120, 120),
      );
      expect(
        applyAffine(pose.back, const Offset(43.5, 142.5)),
        offsetNear(209.53, 129.15),
      );
      final tummy = pose.tummy as CatLoaderTummyArc;
      expect(pointAlong(tummy.path, 0), offsetNear(188.53, 61.66));
      expect(pointAlong(tummy.path, 1), offsetNear(208.04, 101.30));
      expect(pointAlong(pose.tail, 0), offsetNear(209.71, 127.16));
      expect(pointAlong(pose.tail, 1), offsetNear(205.32, 148.66));
      expect(pose.tailTip, offsetNear(205.32, 148.66));
      expect(pointAlong(pose.tailLine, 0), offsetNear(209.31, 131.14));
      expect(pointAlong(pose.tailLine, 1), offsetNear(204.93, 149.79));
    });

    test('ring arcs bend clockwise along the centre line', () {
      for (final p in javascriptReference.map((r) => r.p)) {
        final end = CatLoaderGeometry.bodyEnd(p);
        final pose = CatLoaderGeometry.poseAt(p);
        for (final (path, from, to) in <(Path, double, double)>[
          (pose.tail, -1.5, 26),
          (pose.tailLine, 3.5, 27.5),
        ]) {
          final a0 = CatLoaderGeometry.backA(end, from);
          final a1 = CatLoaderGeometry.backA(end, to);
          final start = CatLoaderGeometry.pol(90, a0);
          final middle = CatLoaderGeometry.pol(90, (a0 + a1) / 2);
          final finish = CatLoaderGeometry.pol(90, a1);
          expect(pointAlong(path, 0), offsetNear(start.dx, start.dy));
          expect(
            pointAlong(path, 0.5),
            isA<Offset>().having(
              (o) => (o - middle).distance,
              'distance from the ring midpoint',
              lessThan(0.05),
            ),
            reason: 'midpoint at p = $p',
          );
          expect(pointAlong(path, 1), offsetNear(finish.dx, finish.dy));
        }
      }
    });

    test('the silhouette covers the ring from the ears to the body end', () {
      final short = CatLoaderGeometry.poseAt(0.3).silhouette;
      expect(short.contains(CatLoaderGeometry.pol(90, -20)), isTrue);
      expect(short.contains(CatLoaderGeometry.pol(90, 20)), isFalse);
      expect(short.contains(CatLoaderGeometry.pol(60, -20)), isFalse);
      expect(short.contains(CatLoaderGeometry.pol(118, -20)), isFalse);

      final long = CatLoaderGeometry.poseAt(0).silhouette;
      expect(long.contains(CatLoaderGeometry.pol(90, 170)), isTrue);
      expect(long.contains(CatLoaderGeometry.pol(90, 90)), isTrue);
      expect(long.contains(CatLoaderGeometry.pol(90, -100)), isFalse);
      expect(long.contains(CatLoaderGeometry.pol(90, -160)), isFalse);
    });

    test('the paws are the icon paws', () {
      expect(
        CatLoaderGeometry.frontPaws.getBounds(),
        rectNear(const Rect.fromLTRB(19.8, 75, 67.2, 100)),
      );
      expect(
        CatLoaderGeometry.backPaws.getBounds(),
        rectNear(const Rect.fromLTRB(19.8, 130, 67.2, 155)),
      );
    });
  });
}
