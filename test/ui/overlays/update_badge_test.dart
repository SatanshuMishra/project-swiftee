import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/overlays/update_badge.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';

const Size surface = Size(800, 600);
const UpdateManifest manifest = UpdateManifest(
  version: '0.3.0',
  notes: '',
  pubDate: '',
);

void main() {
  group('update badge parity', () {
    late ProviderContainer container;
    late int clicks;

    setUp(() {
      container = ProviderContainer.test();
      clicks = 0;
    });

    void setState(UpdaterMachineState state) =>
        container.read(gameControllerProvider.notifier).setUpdaterState(state);

    Future<void> pumpBadge(WidgetTester tester, UpdaterMachineState state) {
      setState(state);
      return tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Stack(children: [UpdateBadge(onPressed: () => clicks++)]),
          ),
        ),
      );
    }

    Finder badgeText() => find.descendant(
      of: find.byType(UpdateBadge),
      matching: find.byType(Text),
    );

    Finder badgeBox() => find.descendant(
      of: find.byType(UpdateBadge),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox && widget.decoration is ShapeDecoration,
      ),
    );

    String accessibleLabel(WidgetTester tester) =>
        tester.getSemantics(badgeBox()).label;

    void expectRendersNothing(WidgetTester tester) {
      expect(tester.getSize(find.byType(UpdateBadge)), Size.zero);
      expect(badgeText(), findsNothing);
      expect(
        find.semantics.byPredicate(
          (node) => node.getSemanticsData().flagsCollection.isButton,
        ),
        findsNothing,
      );
    }

    testWidgets('renders nothing when state is idle', (tester) async {
      await pumpBadge(tester, const UpdaterIdle());
      expectRendersNothing(tester);
    });

    testWidgets('renders nothing when state is checking', (tester) async {
      await pumpBadge(tester, const UpdaterChecking());
      expectRendersNothing(tester);
    });

    testWidgets('renders nothing when state is up-to-date', (tester) async {
      await pumpBadge(tester, const UpdaterUpToDate());
      expectRendersNothing(tester);
    });

    testWidgets("renders 'Update available' text when state is available", (
      tester,
    ) async {
      await pumpBadge(tester, const UpdaterAvailable(manifest: manifest));

      expect(
        find.textContaining(RegExp('update available', caseSensitive: false)),
        findsOneWidget,
      );
      expect(find.textContaining(RegExp(r'0\.3\.0')), findsOneWidget);
    });

    testWidgets('renders progress percentage when downloading', (tester) async {
      await pumpBadge(
        tester,
        const UpdaterDownloading(manifest: manifest, progress: 47),
      );

      expect(find.textContaining('47'), findsOneWidget);
    });

    testWidgets("renders 'Restart to install' when ready", (tester) async {
      await pumpBadge(tester, const UpdaterReady(manifest: manifest));

      expect(
        find.textContaining(RegExp('restart to install', caseSensitive: false)),
        findsOneWidget,
      );
    });

    testWidgets('renders an issue label when state is error', (tester) async {
      await pumpBadge(
        tester,
        const UpdaterError(
          subtype: UpdaterErrorSubtype.download,
          message: 'network',
        ),
      );

      expect(
        find.textContaining(RegExp('issue', caseSensitive: false)),
        findsOneWidget,
      );
    });

    testWidgets('renders nothing when state is installing', (tester) async {
      await pumpBadge(tester, const UpdaterInstalling());
      expectRendersNothing(tester);
    });

    testWidgets('renders nothing when state is installed', (tester) async {
      await pumpBadge(tester, const UpdaterInstalled(manifest: manifest));
      expectRendersNothing(tester);
    });

    testWidgets('calls onClick when clicked', (tester) async {
      await pumpBadge(tester, const UpdaterAvailable(manifest: manifest));

      await tester.tap(badgeBox());

      expect(clicks, 1);
    });

    testWidgets('has an accessible label per state', (tester) async {
      await pumpBadge(tester, const UpdaterAvailable(manifest: manifest));

      final node = tester.getSemantics(badgeBox());
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(node.label, matches(RegExp('update', caseSensitive: false)));
    });

    testWidgets("shows today's label, colour and icon for each visible state", (
      tester,
    ) async {
      final cases = <(UpdaterMachineState, String, Color, LucideGlyph)>[
        (
          const UpdaterAvailable(manifest: manifest),
          'Update available (0.3.0)',
          const Color(0xFF7F22FE),
          LucideGlyph.download,
        ),
        (
          const UpdaterDownloading(manifest: manifest, progress: 47),
          'Downloading update… 47%',
          const Color(0xFF155DFC),
          LucideGlyph.loaderCircle,
        ),
        (
          const UpdaterReady(manifest: manifest),
          'Restart to install 0.3.0',
          const Color(0xFF009966),
          LucideGlyph.refreshCcw,
        ),
        (
          const UpdaterError(
            subtype: UpdaterErrorSubtype.check,
            message: 'offline',
          ),
          'Update issue — click for details',
          const Color(0xFFD08700),
          LucideGlyph.circleAlert,
        ),
      ];
      for (final (state, label, color, glyph) in cases) {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpBadge(tester, state);

        expect(find.text(label), findsOneWidget, reason: label);
        expect(accessibleLabel(tester), label);
        final decoration =
            tester.widget<DecoratedBox>(badgeBox()).decoration
                as ShapeDecoration;
        expect(decoration.color, color, reason: label);
        expect(decoration.shape, const StadiumBorder());
        expect(decoration.shadows, AppShadows.lg);
        final icon = tester.widget<AppIcon>(find.byType(AppIcon));
        expect(icon.glyph, glyph, reason: label);
        expect(icon.size, 16);
        expect(icon.color, AppPalette.white);
        final text = tester.widget<Text>(find.text(label)).style!;
        expect(text.fontSize, 14);
        expect(text.color, AppPalette.white);
      }
    });

    testWidgets('sits 24 px from the bottom right as a 36 px pill', (
      tester,
    ) async {
      await pumpBadge(tester, const UpdaterAvailable(manifest: manifest));

      final rect = tester.getRect(badgeBox());
      expect(rect.right, surface.width - UpdateBadge.inset);
      expect(rect.bottom, surface.height - UpdateBadge.inset);
      expect(rect.height, 36);
      expect(tester.getTopLeft(find.byType(AppIcon)).dx - rect.left, 16);
      expect(
        tester.getTopLeft(badgeText()).dx -
            tester.getTopRight(find.byType(AppIcon)).dx,
        8,
      );
    });

    testWidgets('fades between state colours over 150 ms', (tester) async {
      await pumpBadge(tester, const UpdaterAvailable(manifest: manifest));
      setState(const UpdaterDownloading(manifest: manifest, progress: 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));

      Color badgeColor() =>
          (tester.widget<DecoratedBox>(badgeBox()).decoration
                  as ShapeDecoration)
              .color!;
      expect(badgeColor(), isNot(AppPalette.violet600));
      expect(badgeColor(), isNot(AppPalette.blue600));

      await tester.pump(const Duration(milliseconds: 75));
      expect(badgeColor(), AppPalette.blue600);
    });

    testWidgets('the downloading spinner turns once a second', (tester) async {
      await pumpBadge(
        tester,
        const UpdaterDownloading(manifest: manifest, progress: 10),
      );
      final spinner = find.ancestor(
        of: find.byType(AppIcon),
        matching: find.byType(RotationTransition),
      );

      expect(spinner, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        tester.widget<RotationTransition>(spinner).turns.value,
        moreOrLessEquals(0.25),
      );
      await tester.pump(const Duration(milliseconds: 750));
      expect(
        tester.widget<RotationTransition>(spinner).turns.value,
        moreOrLessEquals(0, epsilon: 1e-6),
      );

      setState(const UpdaterReady(manifest: manifest));
      await tester.pump(const Duration(milliseconds: 150));
      expect(spinner, findsNothing);
    });

    testWidgets('the spinner stands still when the platform reduces motion', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpBadge(
        tester,
        const UpdaterDownloading(manifest: manifest, progress: 10),
      );

      expect(
        find.ancestor(
          of: find.byType(AppIcon),
          matching: find.byType(RotationTransition),
        ),
        findsNothing,
      );
      expect(
        tester.widget<AppIcon>(find.byType(AppIcon)).glyph,
        LucideGlyph.loaderCircle,
      );
    });

    testWidgets('clicks elsewhere reach the screen beneath', (tester) async {
      var screenTaps = 0;
      setState(const UpdaterAvailable(manifest: manifest));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => screenTaps++,
                  ),
                ),
                UpdateBadge(onPressed: () => clicks++),
              ],
            ),
          ),
        ),
      );

      await tester.tapAt(const Offset(20, 20));
      await tester.tapAt(const Offset(780, 590));
      await tester.tap(badgeBox());

      expect(screenTaps, 2);
      expect(clicks, 1);
    });

    testWidgets('tapping the badge opens the update dialog; Escape closes it', (
      tester,
    ) async {
      setState(const UpdaterAvailable(manifest: manifest));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Stack(children: [UpdateOverlay()]),
          ),
        ),
      );

      expect(find.text('Version 0.3.0 available'), findsNothing);

      await tester.tap(badgeBox());
      await tester.pumpAndSettle();
      expect(find.text('Version 0.3.0 available'), findsOneWidget);
      expect(
        find.semantics.byPredicate(
          (node) => node.getSemanticsData().role == SemanticsRole.dialog,
        ),
        findsOne,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Version 0.3.0 available'), findsNothing);
      expect(find.text('Update available (0.3.0)'), findsOneWidget);
    });

    testWidgets('a layer below the dialog sits above the badge', (
      tester,
    ) async {
      var layerTaps = 0;
      setState(const UpdaterAvailable(manifest: manifest));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Stack(
              children: [
                UpdateOverlay(
                  belowDialog: Align(
                    alignment: Alignment.bottomRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => layerTaps++,
                      child: const SizedBox(width: 60, height: 60),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final badge = tester.getRect(badgeBox());

      await tester.tapAt(badge.centerRight - const Offset(4, 0));
      await tester.pumpAndSettle();
      expect(layerTaps, 1);
      expect(find.text('Version 0.3.0 available'), findsNothing);

      await tester.tapAt(badge.centerLeft + const Offset(4, 0));
      await tester.pumpAndSettle();
      expect(find.text('Version 0.3.0 available'), findsOneWidget);

      await tester.tapAt(badge.centerRight - const Offset(4, 0));
      await tester.pumpAndSettle();
      expect(layerTaps, 1);
      expect(find.text('Version 0.3.0 available'), findsNothing);
    });
  });
}
