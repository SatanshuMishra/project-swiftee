import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader_geometry.dart';

const referencePhases = <double>[
  0,
  0.1,
  0.2,
  0.3,
  0.4,
  0.45,
  0.5,
  0.65,
  0.8,
  0.9,
  0.99,
];

Widget host(Widget child, {bool disableAnimations = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: disableAnimations),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  ),
);

Finder art() => find.descendant(
  of: find.byType(CatLoader),
  matching: find.byType(CustomPaint),
);

CatLoaderPainter painterOf(WidgetTester tester) =>
    tester.widget<CustomPaint>(art()).painter! as CatLoaderPainter;

void main() {
  group('cat loader follows the v2 design', () {
    testWidgets('lg centres 300 x 300 art in a 480 x 360 box', (tester) async {
      await tester.pumpWidget(host(const CatLoader(phase: 0)));

      expect(tester.getSize(find.byType(CatLoader)), const Size(480, 360));
      expect(tester.getSize(art()), const Size(300, 300));
      expect(tester.getCenter(art()), tester.getCenter(find.byType(CatLoader)));
      expect(painterOf(tester).variant, CatLoaderGeometry.large);
    });

    testWidgets('lg is the default size', (tester) async {
      await tester.pumpWidget(host(const CatLoader(phase: 0)));

      expect(
        tester.widget<CatLoader>(find.byType(CatLoader)).size,
        CatLoaderSize.lg,
      );
    });

    testWidgets('sm is an 80 x 80 box with the heavier outline', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const CatLoader(size: CatLoaderSize.sm, phase: 0)),
      );

      expect(tester.getSize(find.byType(CatLoader)), const Size(80, 80));
      expect(tester.getSize(art()), const Size(80, 80));
      expect(painterOf(tester).variant, CatLoaderGeometry.small);
      expect(CatLoaderGeometry.small.outline, 16);
      expect(CatLoaderGeometry.large.outline, 10);
      expect(
        art(),
        paints
          ..path(
            color: CatLoaderPalette.dark,
            style: PaintingStyle.stroke,
            strokeWidth: 16,
          )
          ..path(color: CatLoaderPalette.cream, style: PaintingStyle.fill),
      );
    });

    testWidgets('px overrides both the box and the art', (tester) async {
      await tester.pumpWidget(host(const CatLoader(px: 120, phase: 0)));

      expect(tester.getSize(find.byType(CatLoader)), const Size(120, 120));
      expect(tester.getSize(art()), const Size(120, 120));

      await tester.pumpWidget(
        host(const CatLoader(size: CatLoaderSize.sm, px: 48, phase: 0)),
      );

      expect(tester.getSize(find.byType(CatLoader)), const Size(48, 48));
      expect(tester.getSize(art()), const Size(48, 48));
    });

    testWidgets('label sits 16 px below the box in 14 px weight 500', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const CatLoader(label: 'Loading albums...', phase: 0)),
      );

      final label = find.text('Loading albums...');
      expect(label, findsOneWidget);
      expect(
        tester.getTopLeft(label).dy -
            tester.getTopLeft(find.byType(CatLoader)).dy,
        360 + 16,
      );
      expect(tester.getSize(label).height, 20);
      final style = tester.widget<Text>(label).style!;
      expect(style.fontSize, 14);
      expect(style.fontWeight, FontWeight.w500);
      expect(style.height, 20 / 14);
      expect(style.color, const Color(0xFFA1A1A1));
    });

    testWidgets('label sits 16 px below the sm box', (tester) async {
      await tester.pumpWidget(
        host(
          const CatLoader(size: CatLoaderSize.sm, label: 'Loading', phase: 0),
        ),
      );

      expect(
        tester.getTopLeft(find.text('Loading')).dy -
            tester.getTopLeft(find.byType(CatLoader)).dy,
        80 + 16,
      );
    });

    testWidgets('label style can be overridden', (tester) async {
      const themed = TextStyle(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF717182),
      );
      await tester.pumpWidget(
        host(const CatLoader(label: 'Loading', labelStyle: themed, phase: 0)),
      );

      expect(tester.widget<Text>(find.text('Loading')).style, themed);
    });

    testWidgets('no label is rendered when it is null or empty', (
      tester,
    ) async {
      await tester.pumpWidget(host(const CatLoader(phase: 0)));

      expect(find.byType(Text), findsNothing);
      expect(tester.getSize(find.byType(CatLoader)), const Size(480, 360));

      await tester.pumpWidget(host(const CatLoader(label: '', phase: 0)));

      expect(find.byType(Text), findsNothing);
      expect(tester.getSize(find.byType(CatLoader)), const Size(480, 360));
    });

    testWidgets('the cycle is 2740 ms', (tester) async {
      await tester.pumpWidget(host(const CatLoader()));
      await tester.pump();

      expect(painterOf(tester).phase.value, closeTo(0, 1e-9));
      await tester.pump(const Duration(milliseconds: 685));
      expect(painterOf(tester).phase.value, closeTo(0.25, 1e-6));
      await tester.pump(const Duration(milliseconds: 685));
      expect(painterOf(tester).phase.value, closeTo(0.5, 1e-6));
      await tester.pump(const Duration(milliseconds: 2740));
      expect(painterOf(tester).phase.value, closeTo(0.5, 1e-6));
    });

    testWidgets('the cycle is 6850 ms when the platform reduces motion', (
      tester,
    ) async {
      await tester.pumpWidget(host(const CatLoader(), disableAnimations: true));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 1370));
      expect(painterOf(tester).phase.value, closeTo(0.2, 1e-6));
      await tester.pump(const Duration(milliseconds: 6850));
      expect(painterOf(tester).phase.value, closeTo(0.2, 1e-6));
    });

    testWidgets('turning reduce motion on slows the running cycle', (
      tester,
    ) async {
      await tester.pumpWidget(host(const CatLoader()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 685));
      expect(painterOf(tester).phase.value, closeTo(0.25, 1e-6));

      await tester.pumpWidget(host(const CatLoader(), disableAnimations: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1370));

      expect(painterOf(tester).phase.value, closeTo(0.45, 1e-6));
    });

    testWidgets('a phase override holds the drawing still', (tester) async {
      await tester.pumpWidget(host(const CatLoader(phase: 0.3)));
      await tester.pump(const Duration(seconds: 1));

      expect(painterOf(tester).phase.value, 0.3);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('the controller stops when the loader is disposed', (
      tester,
    ) async {
      await tester.pumpWidget(host(const CatLoader()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(host(const SizedBox()));

      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });

    test('the painter paints at every reference phase for both sizes', () {
      for (final variant in <CatLoaderVariant>[
        CatLoaderGeometry.large,
        CatLoaderGeometry.small,
      ]) {
        for (final phase in referencePhases) {
          final recorder = ui.PictureRecorder();
          CatLoaderPainter(
            variant: variant,
            phase: AlwaysStoppedAnimation<double>(phase),
          ).paint(Canvas(recorder), const Size(300, 300));
          recorder.endRecording().dispose();
        }
      }
    });

    testWidgets('both sizes render at every reference phase', (tester) async {
      for (final size in CatLoaderSize.values) {
        for (final phase in referencePhases) {
          await tester.pumpWidget(host(CatLoader(size: size, phase: phase)));
          expect(tester.takeException(), isNull);
          expect(painterOf(tester).phase.value, phase);
        }
      }
    });

    testWidgets('lg paints the outline behind the fill with the lg face', (
      tester,
    ) async {
      await tester.pumpWidget(host(const CatLoader(phase: 0.3)));

      expect(
        art(),
        paints
          ..path(
            color: CatLoaderPalette.dark,
            style: PaintingStyle.stroke,
            strokeWidth: 10,
          )
          ..path(color: CatLoaderPalette.cream, style: PaintingStyle.fill)
          ..path(color: CatLoaderPalette.belly, style: PaintingStyle.stroke)
          ..circle(color: CatLoaderPalette.pink, radius: 15 * 0.8),
      );
      expect(art(), paintsExactlyCountTimes(#drawPath, 7));
      expect(art(), paintsExactlyCountTimes(#drawLine, 8));
      expect(art(), paintsExactlyCountTimes(#drawCircle, 6));
      expect(art(), paintsExactlyCountTimes(#drawOval, 1));
    });

    testWidgets('sm drops the toes, tail line and mouth circles', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const CatLoader(size: CatLoaderSize.sm, phase: 0.3)),
      );

      expect(art(), paintsExactlyCountTimes(#drawPath, 6));
      expect(art(), paintsExactlyCountTimes(#drawLine, 4));
      expect(art(), paintsExactlyCountTimes(#drawCircle, 4));
      expect(art(), paintsExactlyCountTimes(#drawOval, 1));
    });
  });
}
