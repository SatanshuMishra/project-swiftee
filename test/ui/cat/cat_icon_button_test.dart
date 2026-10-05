import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/cat/cat_icon.dart';
import 'package:swiftie_quiz/ui/cat/cat_icon_button.dart';

Matcher sizeNear(double width, double height) => isA<Size>()
    .having((s) => s.width, 'width', closeTo(width, 1e-9))
    .having((s) => s.height, 'height', closeTo(height, 1e-9));

Widget host(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => Center(child: child),
);

void main() {
  group('cat icon button uses the v2 icon', () {
    testWidgets('renders an SVG picture of the v2 cat icon asset', (
      tester,
    ) async {
      await tester.pumpWidget(host(CatIconButton(onTap: () {})));

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svg.bytesLoader, isA<SvgAssetLoader>());
      expect(
        (svg.bytesLoader as SvgAssetLoader).assetName,
        'assets/cat/cat-icon.svg',
      );
      expect(CatIcon.asset, 'assets/cat/cat-icon.svg');
    });

    testWidgets('uses default size of 44', (tester) async {
      await tester.pumpWidget(host(CatIconButton(onTap: () {})));

      expect(tester.getSize(find.byType(SvgPicture)), sizeNear(22, 44));
    });

    testWidgets('accepts custom size', (tester) async {
      await tester.pumpWidget(host(CatIconButton(onTap: () {}, size: 60)));

      expect(tester.getSize(find.byType(SvgPicture)), sizeNear(30, 60));
    });

    testWidgets('the main menu size draws a 32 x 64 icon', (tester) async {
      await tester.pumpWidget(host(CatIconButton(onTap: () {}, size: 64)));

      expect(tester.getSize(find.byType(SvgPicture)), sizeNear(32, 64));
      expect(tester.getSize(find.byType(CatIconButton)), const Size(44, 64));
    });

    testWidgets('SVG is hidden from accessibility', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(CatIconButton(onTap: () {})));

      expect(
        tester.widget<SvgPicture>(find.byType(SvgPicture)).excludeFromSemantics,
        isTrue,
      );
      expect(find.bySemanticsLabel('Open birthday card'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('button has the birthday card semantics label', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(CatIconButton(onTap: () {})));

      expect(
        tester.getSemantics(find.byType(CatIconButton)),
        isSemantics(
          label: 'Open birthday card',
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('calls onTap when clicked', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(CatIconButton(onTap: () => taps++)));

      await tester.tap(find.byType(CatIconButton));

      expect(taps, 1);
    });

    testWidgets('button has minimum 44px tap target width and height', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(CatIconButton(onTap: () => taps++, size: 20)),
      );

      expect(tester.getSize(find.byType(SvgPicture)), sizeNear(10, 20));
      final button = tester.getRect(find.byType(CatIconButton));
      expect(button.size, const Size(44, 44));

      await tester.tapAt(button.topLeft + const Offset(1, 1));
      await tester.tapAt(button.bottomRight - const Offset(1, 1));

      expect(taps, 2);
    });

    testWidgets('default button hit area is 44 x 44', (tester) async {
      await tester.pumpWidget(host(CatIconButton(onTap: () {})));

      expect(tester.getSize(find.byType(CatIconButton)), const Size(44, 44));
    });

    testWidgets('shows the click cursor on hover', (tester) async {
      await tester.pumpWidget(host(CatIconButton(onTap: () {})));
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 1,
      );
      await gesture.addPointer(
        location: tester.getCenter(find.byType(CatIconButton)),
      );
      addTearDown(gesture.removePointer);
      await tester.pump();

      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.click,
      );
    });

    testWidgets('activates from the keyboard like a button', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          FocusScope(
            autofocus: true,
            child: CatIconButton(onTap: () => taps++),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);

      expect(taps, 2);
    });

    testWidgets('does not scale itself', (tester) async {
      await tester.pumpWidget(host(CatIconButton(onTap: () {})));

      expect(
        find.descendant(
          of: find.byType(CatIconButton),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });

    testWidgets('renders Siamese color palette elements', (tester) async {
      final svg = await rootBundle.loadString(CatIcon.asset);

      expect(svg, contains('fill="#6FA8DC"'));
      expect(svg, contains('fill="#D4A0A0"'));
      expect(svg, contains('fill="#3B2F2F"'));
      expect(svg, contains('viewBox="0 0 87 174"'));
    });
  });
}
