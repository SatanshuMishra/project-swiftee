import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/widgets/swiftie_logo.dart';

const brandCoral = Color(0xFFE97F6A);
const white = Color(0xFFFFFFFF);

PaintPattern logoDrawing({required double scale}) => paints
  ..save()
  ..scale(x: scale, y: scale)
  ..circle(x: 32, y: 32, radius: 32, color: brandCoral)
  ..translate(x: 18, y: 12)
  ..rrect(
    rrect: RRect.fromLTRBR(20, 0, 24, 28, const Radius.circular(2)),
    color: white,
  )
  ..circle(x: 8, y: 34, radius: 8, color: white)
  ..rrect(
    rrect: RRect.fromLTRBR(20, 0, 30, 4, const Radius.circular(2)),
    color: white,
  )
  ..restore();

void main() {
  group('swiftie logo parity', () {
    testWidgets('renders the 64-unit coral circle and white note', (
      tester,
    ) async {
      await tester.pumpWidget(const Center(child: SwiftieLogo()));

      expect(find.byType(SwiftieLogo), logoDrawing(scale: 80 / 64));
    });

    testWidgets('uses default size of 80', (tester) async {
      await tester.pumpWidget(const Center(child: SwiftieLogo()));

      expect(tester.getSize(find.byType(SwiftieLogo)), const Size(80, 80));
    });

    testWidgets('accepts custom size', (tester) async {
      await tester.pumpWidget(const Center(child: SwiftieLogo(size: 32)));

      expect(tester.getSize(find.byType(SwiftieLogo)), const Size(32, 32));
      expect(find.byType(SwiftieLogo), logoDrawing(scale: 0.5));
    });

    testWidgets('applies the drop-shadow-2xl styling a caller passes', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Center(child: SwiftieLogo(shadows: AppShadows.drop2xl)),
      );

      expect(
        find.byType(SwiftieLogo),
        paints
          ..circle(
            x: 32,
            y: 32 + 25 / (80 / 64),
            radius: 32,
            color: const Color.from(alpha: 0.15, red: 0, green: 0, blue: 0),
            hasMaskFilter: true,
          )
          ..circle(x: 32, y: 32, radius: 32, color: brandCoral),
      );
      expect(AppShadows.drop2xl.single.blurSigma, closeTo(25, 1e-9));
    });

    testWidgets('is hidden from accessibility', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        Semantics(container: true, child: const Center(child: SwiftieLogo())),
      );

      expect(
        tester.getSemantics(find.byType(SwiftieLogo)),
        matchesSemantics(label: '', isImage: false),
      );
      handle.dispose();
    });
  });
}
