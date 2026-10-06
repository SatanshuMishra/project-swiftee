import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/state/misu_controller.dart';
import 'package:swiftie_quiz/ui/cat/cat_icon.dart';
import 'package:swiftie_quiz/ui/kit/modal_stack.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/misu/misu_host.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

const Size _screen = Size(1200, 800);

const MisuVisit _greeting = MisuVisit(
  text: 'Misu saved you a spot on the couch, Sam.',
  side: MisuSide.right,
  long: false,
);

const MisuVisit _streak = MisuVisit(
  text: "Twenty-five in a row, Sam. Misu's tail is doing the thing.",
  side: MisuSide.left,
  long: false,
);

class _FakeMisu extends MisuController {
  int dismissals = 0;

  @override
  MisuState build() => const MisuState();

  void show(MisuVisit visit) => state = state.copyWith(visit: visit);

  @override
  void dismiss() {
    dismissals += 1;
    state = state.copyWith(visit: null);
  }
}

Future<_FakeMisu> _pumpHost(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
  bool reducedMotion = false,
  VoidCallback? onBackgroundTap,
}) async {
  final misu = _FakeMisu();
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [misuControllerProvider.overrideWith(() => misu)],
      child: MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        themeAnimationDuration: Duration.zero,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reducedMotion),
          child: app!,
        ),
        home: Material(
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBackgroundTap,
              ),
              const MisuHost(),
            ],
          ),
        ),
      ),
    ),
  );
  ProviderScope.containerOf(tester.element(find.byType(MisuHost)))
      .read(misuControllerProvider);
  return misu;
}

Finder get _catWindow => find
    .ancestor(of: find.byType(CatIcon), matching: find.byType(ClipRect))
    .first;

Finder _bubbleOf(String line) => find
    .ancestor(of: find.text(line), matching: find.byType(DecoratedBox))
    .first;

double _bubbleOpacity(WidgetTester tester, String line) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(line), matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  group('misu visits', () {
    testWidgets('misu rises with her line and a click sends her away', (
      tester,
    ) async {
      final misu = await _pumpHost(tester);
      expect(find.byType(CatIcon), findsNothing);

      misu.show(_greeting);
      await tester.pumpAndSettle();
      expect(find.byType(CatIcon), findsOneWidget);
      expect(find.text(_greeting.text), findsOneWidget);

      final cat = tester.getRect(_catWindow);
      expect(cat.size, const Size(76, 62));
      expect(cat.bottomRight, Offset(_screen.width - 48, _screen.height));
      expect(tester.getSize(find.byType(CatIcon)), const Size(76, 152));
      expect(tester.getTopLeft(find.byType(CatIcon)), cat.topLeft);

      final bubble = tester.getRect(_bubbleOf(_greeting.text));
      final line = tester.getRect(find.text(_greeting.text));
      expect(line.width, 340);
      expect(line.topLeft - bubble.topLeft, const Offset(16, 12));
      expect(bubble.right, cat.left - 10);
      expect(bubble.bottom, _screen.height - 44);

      final type = tester.widget<Text>(find.text(_greeting.text)).style!;
      expect(type.fontFamily, 'Instrument Serif');
      expect(type.fontSize, 20);
      expect(type.fontSize! * type.height!, closeTo(24, 0.001));

      await tester.tap(_catWindow);
      expect(misu.dismissals, 1);
      await tester.pumpAndSettle();
      expect(find.byType(CatIcon), findsNothing);
      expect(find.text(_greeting.text), findsNothing);

      misu.show(_streak);
      await tester.pumpAndSettle();

      final leftCat = tester.getRect(_catWindow);
      expect(leftCat.bottomLeft, Offset(40, _screen.height));
      final leftBubble = tester.getRect(_bubbleOf(_streak.text));
      expect(tester.getSize(find.text(_streak.text)).width, 340);
      expect(leftBubble.left, leftCat.right + 10);
      expect(leftBubble.bottom, _screen.height - 44);
    });

    testWidgets('the bubble takes the bubble colours of each theme', (
      tester,
    ) async {
      for (final (brightness, tokens) in [
        (Brightness.dark, AppTokens.dark),
        (Brightness.light, AppTokens.light),
      ]) {
        final misu = await _pumpHost(tester, brightness: brightness);
        misu.show(_greeting);
        await tester.pumpAndSettle();

        final fill =
            tester.widget<DecoratedBox>(_bubbleOf(_greeting.text)).decoration
                as BoxDecoration;
        expect(fill.color, tokens.bubble);
        expect(
          tester.widget<Text>(find.text(_greeting.text)).style!.color,
          tokens.bubbleFg,
        );
      }
    });

    testWidgets('her line follows 120 ms after she starts rising', (
      tester,
    ) async {
      final misu = await _pumpHost(tester);
      misu.show(_greeting);
      await tester.pump();
      final window = tester.getRect(_catWindow);
      final hidden = tester.getRect(_bubbleOf(_greeting.text));
      expect(
        tester.getTopLeft(find.byType(CatIcon)).dy,
        closeTo(window.top + 1.1 * 152, 0.01),
      );
      expect(_bubbleOpacity(tester, _greeting.text), 0);

      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getTopLeft(find.byType(CatIcon)).dy,
        lessThan(window.top + 1.1 * 152),
      );
      expect(_bubbleOpacity(tester, _greeting.text), 0);
      expect(tester.getRect(_bubbleOf(_greeting.text)), hidden);

      await tester.pump(const Duration(milliseconds: 60));
      expect(_bubbleOpacity(tester, _greeting.text), greaterThan(0));

      await tester.pumpAndSettle();
      final shown = tester.getRect(_bubbleOf(_greeting.text));
      expect(_bubbleOpacity(tester, _greeting.text), 1);
      expect(tester.getTopLeft(find.byType(CatIcon)).dy, window.top);
      expect(hidden.width, closeTo(shown.width * 0.96, 0.01));
      expect(hidden.center.dy, closeTo(shown.center.dy + 8, 0.01));
    });

    testWidgets('misu sinks away before she leaves the screen', (tester) async {
      final misu = await _pumpHost(tester);
      misu.show(_greeting);
      await tester.pumpAndSettle();
      final window = tester.getRect(_catWindow);

      await tester.tap(_catWindow);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_bubbleOpacity(tester, _greeting.text), 1);

      await tester.pump(const Duration(milliseconds: 300));
      expect(_bubbleOpacity(tester, _greeting.text), lessThan(0.05));
      expect(
        tester.getTopLeft(find.byType(CatIcon)).dy,
        greaterThan(window.bottom),
      );

      await tester.pump(const Duration(milliseconds: 30));
      expect(find.byType(CatIcon), findsNothing);
      expect(find.text(_greeting.text), findsNothing);
    });

    testWidgets('a new visit during the sink brings her straight back', (
      tester,
    ) async {
      final misu = await _pumpHost(tester);
      misu.show(_greeting);
      await tester.pumpAndSettle();

      await tester.tap(_catWindow);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      misu.show(_streak);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text(_greeting.text), findsNothing);
      expect(find.text(_streak.text), findsOneWidget);
      expect(_bubbleOpacity(tester, _streak.text), 1);
      final window = tester.getRect(_catWindow);
      expect(window.bottomLeft, Offset(40, _screen.height));
      expect(tester.getTopLeft(find.byType(CatIcon)).dy, window.top);
    });

    testWidgets('misu leaves no timer behind when the shell goes mid-sink', (
      tester,
    ) async {
      final misu = await _pumpHost(tester);
      misu.show(_greeting);
      await tester.pumpAndSettle();

      await tester.tap(_catWindow);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      expect(find.byType(CatIcon), findsNothing);
    });

    testWidgets('the cat is reachable by keyboard with a focus ring', (
      tester,
    ) async {
      final misu = await _pumpHost(tester);
      misu.show(_greeting);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(Pressable),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).border?.top.color ==
                    AppTokens.dark.coral,
          ),
        ),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(misu.dismissals, 1);
    });

    testWidgets('esc sends misu away only while no dialog is open', (
      tester,
    ) async {
      final misu = await _pumpHost(tester);
      misu.show(_streak);
      await tester.pumpAndSettle();
      final modals = ProviderScope.containerOf(
        tester.element(find.byType(MisuHost)),
      ).read(modalStackProvider.notifier);
      final dialog = Object();

      modals.push(dialog);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(misu.dismissals, 0);
      expect(find.text(_streak.text), findsOneWidget);

      modals.remove(dialog);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(misu.dismissals, 1);
      expect(find.text(_streak.text), findsNothing);
    });

    testWidgets('only the cat and the bubble take clicks', (tester) async {
      var backgroundTaps = 0;
      final misu = await _pumpHost(
        tester,
        onBackgroundTap: () => backgroundTaps += 1,
      );
      misu.show(_greeting);
      await tester.pumpAndSettle();
      final cat = tester.getRect(_catWindow);

      await tester.tapAt(const Offset(600, 300));
      await tester.tapAt(Offset(cat.left - 5, _screen.height - 10));
      expect(backgroundTaps, 2);

      await tester.tap(_bubbleOf(_greeting.text));
      expect(backgroundTaps, 2);
      expect(misu.dismissals, 0);
    });

    testWidgets('reduced motion shows and hides misu instantly', (
      tester,
    ) async {
      final misu = await _pumpHost(tester, reducedMotion: true);
      misu.show(_greeting);
      await tester.pump();

      final window = tester.getRect(_catWindow);
      expect(tester.getTopLeft(find.byType(CatIcon)).dy, window.top);
      expect(_bubbleOpacity(tester, _greeting.text), 1);

      await tester.tap(_catWindow);
      await tester.pump();
      expect(find.byType(CatIcon), findsNothing);
      expect(find.text(_greeting.text), findsNothing);
    });
  });
}
