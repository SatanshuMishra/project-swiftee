import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/services/window/window_controls.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/chrome/caption_buttons.dart';
import 'package:swiftie_quiz/ui/chrome/title_bar.dart';
import 'package:swiftie_quiz/ui/overlays/update_badge.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

const Size window = Size(1024, 800);

final class _FakeWindowControls implements WindowControls {
  _FakeWindowControls({this.maximized = false});

  final bool maximized;
  final StreamController<bool> changes = StreamController<bool>.broadcast(
    sync: true,
  );
  List<String> calls = const [];

  Future<void> _record(String call) async => calls = [...calls, call];

  @override
  Future<void> minimize() => _record('minimize');

  @override
  Future<void> toggleMaximize() => _record('toggleMaximize');

  @override
  Future<void> close() => _record('close');

  @override
  Future<bool> isMaximized() async => maximized;

  @override
  Future<void> startDragging() => _record('startDragging');

  @override
  Future<void> startResizing(WindowEdge edge) =>
      _record('startResizing ${edge.name}');

  @override
  Stream<bool> get maximizedChanges => changes.stream;
}

void main() {
  late _FakeWindowControls controls;
  late ProviderContainer container;

  Future<void> pumpBar(
    WidgetTester tester,
    TargetPlatform platform, {
    ThemeData? theme,
    bool maximized = false,
    UpdaterMachineState? updater,
  }) async {
    tester.view
      ..physicalSize = window
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox());
    controls = _FakeWindowControls(maximized: maximized);
    addTearDown(controls.changes.close);
    container = ProviderContainer.test(
      overrides: [
        titleBarPlatformProvider.overrideWithValue(platform),
        windowControlsProvider.overrideWithValue(controls),
      ],
    );
    if (updater != null) {
      container.read(gameControllerProvider.notifier).setUpdaterState(updater);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? AppTheme.dark,
          home: const Material(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTitleBar(),
                Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder bar() => find.byType(AppTitleBar);

  Finder title() => find.text('Project Swiftie');

  TextStyle rendered(WidgetTester tester, Finder text) => tester
      .widget<RichText>(
        find.descendant(of: text, matching: find.byType(RichText)),
      )
      .text
      .style!;

  Color barColor(WidgetTester tester) => tester
      .widget<ColoredBox>(
        find.descendant(of: bar(), matching: find.byType(ColoredBox)).first,
      )
      .color;

  Finder button(CaptionGlyph glyph) => find.byWidgetPredicate(
    (widget) => widget is CaptionButton && widget.glyph == glyph,
  );

  Finder fillOf(CaptionGlyph glyph) => find.descendant(
    of: button(glyph),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.position == DecorationPosition.background,
    ),
  );

  Color fill(WidgetTester tester, CaptionGlyph glyph) =>
      (tester.widget<DecoratedBox>(fillOf(glyph)).decoration as BoxDecoration)
          .color!;

  Color ink(WidgetTester tester, CaptionGlyph glyph) => tester
      .widget<CaptionGlyphIcon>(
        find.descendant(
          of: button(glyph),
          matching: find.byType(CaptionGlyphIcon),
        ),
      )
      .color;

  Finder ringOf(CaptionGlyph glyph) => find.descendant(
    of: button(glyph),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.position == DecorationPosition.foreground &&
          (widget.decoration as BoxDecoration).border != null,
    ),
  );

  Finder badgePill() => find.descendant(
    of: find.byType(UpdateBadge),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color != null &&
          (widget.decoration as BoxDecoration).borderRadius ==
              UpdateBadge.radius,
    ),
  );

  const Offset away = Offset(20, 400);

  Future<TestGesture> mouse(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: away);
    addTearDown(gesture.removePointer);
    return gesture;
  }

  Future<void> doubleTap(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  group('macOS title bar', () {
    testWidgets('the macos title bar is 28 px with the centred title', (
      tester,
    ) async {
      for (final (theme, tokens) in [
        (AppTheme.dark, AppTokens.dark),
        (AppTheme.light, AppTokens.light),
      ]) {
        await pumpBar(tester, TargetPlatform.macOS, theme: theme);

        expect(tester.getSize(bar()), Size(window.width, 28));
        expect(barColor(tester), tokens.bg);
        expect(title(), findsOneWidget);
        expect(tester.getCenter(title()), tester.getCenter(bar()));
        final style = tester.widget<Text>(title()).style!;
        expect(style.fontSize, 13);
        expect(style.height! * style.fontSize!, 16);
        expect(style.fontWeight, FontWeight.w600);
        expect(style.color, tokens.fg.withValues(alpha: 0.8));
        expect(find.byType(CaptionButtons), findsNothing);
        expect(find.byType(CaptionButton), findsNothing);
        expect(
          find.descendant(
            of: bar(),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is DecoratedBox &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).border != null,
            ),
          ),
          findsNothing,
        );
        expect(find.byType(Divider), findsNothing);
      }
    });

    testWidgets('the bar drags the window and a double click zooms it', (
      tester,
    ) async {
      await pumpBar(tester, TargetPlatform.macOS);

      await tester.drag(title(), const Offset(120, 40));
      await tester.pumpAndSettle();
      expect(controls.calls, ['startDragging']);

      await tester.dragFrom(const Offset(120, 14), const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(controls.calls, ['startDragging', 'startDragging']);

      await doubleTap(tester, title());
      expect(controls.calls.last, 'toggleMaximize');
    });

    testWidgets('a single click on the bar does nothing', (tester) async {
      await pumpBar(tester, TargetPlatform.macOS);

      await tester.tap(title());
      await tester.pump(kDoubleTapTimeout);
      await tester.tapAt(const Offset(120, 14));
      await tester.pump(kDoubleTapTimeout);

      expect(controls.calls, isEmpty);
    });

    testWidgets('the badge sits 10 px from the right of the bar', (
      tester,
    ) async {
      await pumpBar(
        tester,
        TargetPlatform.macOS,
        updater: const UpdaterAvailable(
          manifest: UpdateManifest(version: '0.3.1', notes: '', pubDate: ''),
        ),
      );

      final pill = tester.getRect(badgePill());
      expect(pill.right, window.width - 10);
      expect(pill.top, 4);
      expect(pill.height, 20);
      expect(tester.getCenter(title()), tester.getCenter(bar()));

      await tester.tap(find.text('Update available · 0.3.1'));
      await tester.pump();
      expect(container.read(updateDialogOpenProvider), isTrue);
      expect(controls.calls, isEmpty);
    });
  });

  group('Windows title bar', () {
    testWidgets('the windows title bar has three 46 px caption buttons', (
      tester,
    ) async {
      final pointer = await mouse(tester);
      for (final (theme, tokens) in [
        (AppTheme.dark, AppTokens.dark),
        (AppTheme.light, AppTokens.light),
      ]) {
        await pumpBar(tester, TargetPlatform.windows, theme: theme);

        expect(tester.getSize(bar()), Size(window.width, 32));
        expect(barColor(tester), tokens.bg);
        expect(tester.getCenter(title()), tester.getCenter(bar()));
        final style = tester.widget<Text>(title()).style!;
        expect(style.fontSize, 12);
        expect(style.height! * style.fontSize!, 16);
        expect(style.fontWeight, FontWeight.w600);
        expect(style.color, tokens.fg.withValues(alpha: 0.8));
        expect(rendered(tester, title()).fontFamily, 'Segoe UI Variable Text');
        expect(rendered(tester, title()).fontFamilyFallback, ['Segoe UI']);

        expect(
          tester
              .widgetList<CaptionButton>(find.byType(CaptionButton))
              .map((button) => button.glyph),
          [CaptionGlyph.minimize, CaptionGlyph.maximize, CaptionGlyph.close],
        );
        var right = window.width;
        for (final glyph in [
          CaptionGlyph.close,
          CaptionGlyph.maximize,
          CaptionGlyph.minimize,
        ]) {
          final rect = tester.getRect(button(glyph));
          expect(rect, Rect.fromLTWH(right - 46, 0, 46, 32), reason: '$glyph');
          right = rect.left;
        }
        for (final label in ['Minimise', 'Maximise', 'Close']) {
          expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
        }

        await tester.tap(button(CaptionGlyph.minimize));
        await tester.tap(button(CaptionGlyph.maximize));
        await tester.tap(button(CaptionGlyph.close));
        await tester.pump();
        expect(controls.calls, ['minimize', 'toggleMaximize', 'close']);

        expect(fill(tester, CaptionGlyph.close).a, 0);
        expect(ink(tester, CaptionGlyph.close), tokens.fg);
        await pointer.moveTo(tester.getCenter(button(CaptionGlyph.close)));
        await tester.pump();
        await tester.pump(AppMotion.colorShift);
        expect(fill(tester, CaptionGlyph.close), BrandColors.closeHover);
        expect(BrandColors.closeHover, const Color(0xFFC42B1C));
        expect(ink(tester, CaptionGlyph.close), const Color(0xFFFFFFFF));

        for (final glyph in [CaptionGlyph.minimize, CaptionGlyph.maximize]) {
          await pointer.moveTo(tester.getCenter(button(glyph)));
          await tester.pump();
          await tester.pump(AppMotion.colorShift);
          expect(fill(tester, glyph), tokens.hover, reason: '$glyph');
          expect(ink(tester, glyph), tokens.fg, reason: '$glyph');
          expect(fill(tester, CaptionGlyph.close).a, 0);
        }
        await pointer.moveTo(away);
        await tester.pump();
      }
    });

    testWidgets('the maximise button shows restore while the window is '
        'maximised', (tester) async {
      await pumpBar(tester, TargetPlatform.windows, maximized: true);

      expect(button(CaptionGlyph.restore), findsOneWidget);
      expect(button(CaptionGlyph.maximize), findsNothing);
      expect(find.bySemanticsLabel('Restore'), findsOneWidget);

      controls.changes.add(false);
      await tester.pump();
      expect(button(CaptionGlyph.maximize), findsOneWidget);
      expect(button(CaptionGlyph.restore), findsNothing);

      controls.changes.add(true);
      await tester.pump();
      expect(button(CaptionGlyph.restore), findsOneWidget);

      await tester.tap(button(CaptionGlyph.restore));
      await tester.pump();
      expect(controls.calls, ['toggleMaximize']);
    });

    testWidgets('the rest of the bar drags and a double click toggles '
        'maximise', (tester) async {
      await pumpBar(tester, TargetPlatform.windows);

      await tester.drag(title(), const Offset(80, 30));
      await tester.pumpAndSettle();
      expect(controls.calls, ['startDragging']);

      await doubleTap(tester, title());
      expect(controls.calls, ['startDragging', 'toggleMaximize']);
    });

    testWidgets('the caption buttons are reachable by keyboard with a focus '
        'ring', (tester) async {
      await pumpBar(tester, TargetPlatform.windows);
      expect(ringOf(CaptionGlyph.minimize), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(ringOf(CaptionGlyph.minimize), findsOneWidget);
      final ring = tester.widget<DecoratedBox>(ringOf(CaptionGlyph.minimize));
      final border = (ring.decoration as BoxDecoration).border! as Border;
      expect(border.top.color, AppTokens.dark.coral);
      expect(border.top.width, 2);
      expect(border.top.strokeAlign, BorderSide.strokeAlignInside);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(ringOf(CaptionGlyph.maximize), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(controls.calls, ['minimize', 'toggleMaximize']);
    });

    testWidgets('the badge sits 8 px before the caption buttons', (
      tester,
    ) async {
      await pumpBar(
        tester,
        TargetPlatform.windows,
        updater: const UpdaterDownloading(
          manifest: UpdateManifest(version: '0.3.1', notes: '', pubDate: ''),
          progress: 30,
        ),
      );

      final pill = tester.getRect(badgePill());
      expect(pill.height, 22);
      expect(pill.center.dy, 16);
      expect(
        tester.getRect(button(CaptionGlyph.minimize)).left - pill.right,
        8,
      );
      final badge = rendered(tester, find.text('Downloading · 30%'));
      expect(badge.fontFamily, 'Segoe UI Variable Text');
      expect(badge.fontFamilyFallback, ['Segoe UI']);
    });

    testWidgets('screen readers can press each caption button', (tester) async {
      await pumpBar(tester, TargetPlatform.windows);

      for (final (glyph, label) in [
        (CaptionGlyph.minimize, 'Minimise'),
        (CaptionGlyph.maximize, 'Maximise'),
        (CaptionGlyph.close, 'Close'),
      ]) {
        final node = find.semantics.byLabel(label).evaluate().single;
        expect(
          tester.getRect(button(glyph)),
          node.rect.shift(tester.getTopLeft(button(glyph))),
        );
        expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
          reason: label,
        );
        tester.semantics.tap(find.semantics.byLabel(label));
      }
      await tester.pump();

      expect(controls.calls, ['minimize', 'toggleMaximize', 'close']);
    });

    testWidgets('the top edge resizes the window unless it is maximised', (
      tester,
    ) async {
      await pumpBar(tester, TargetPlatform.windows);

      await tester.dragFrom(const Offset(500, 2), const Offset(0, -40));
      await tester.dragFrom(const Offset(3, 2), const Offset(-30, -30));
      await tester.dragFrom(Offset(window.width - 3, 2), const Offset(30, -30));
      await tester.dragFrom(
        Offset(tester.getCenter(button(CaptionGlyph.close)).dx, 2),
        const Offset(0, -20),
      );
      await tester.pumpAndSettle();
      expect(controls.calls, [
        'startResizing top',
        'startResizing topLeft',
        'startResizing topRight',
        'startResizing top',
      ]);

      await tester.tapAt(tester.getCenter(button(CaptionGlyph.close)));
      await tester.dragFrom(const Offset(500, 8), const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(controls.calls.sublist(4), ['close', 'startDragging']);

      controls.changes.add(true);
      await tester.pump();
      await tester.dragFrom(const Offset(500, 2), const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(controls.calls.sublist(6), ['startDragging']);
    });

    testWidgets('hover colours are instant when motion is reduced', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpBar(tester, TargetPlatform.windows);
      final pointer = await mouse(tester);

      await pointer.moveTo(tester.getCenter(button(CaptionGlyph.close)));
      await tester.pump();

      expect(fill(tester, CaptionGlyph.close), BrandColors.closeHover);
      expect(ink(tester, CaptionGlyph.close), const Color(0xFFFFFFFF));
    });
  });

  testWidgets('the macos bar leaves the top edge to the system', (
    tester,
  ) async {
    await pumpBar(tester, TargetPlatform.macOS);

    await tester.dragFrom(const Offset(500, 2), const Offset(0, 40));
    await tester.pumpAndSettle();

    expect(controls.calls, ['startDragging']);
  });

  test('every other platform uses the macOS layout', () {
    for (final platform in [
      TargetPlatform.linux,
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.fuchsia,
    ]) {
      expect(TitleBarLayout.of(platform), TitleBarLayout.mac);
    }
    expect(TitleBarLayout.of(TargetPlatform.macOS), TitleBarLayout.mac);
    expect(TitleBarLayout.of(TargetPlatform.windows), TitleBarLayout.windows);
  });
}
