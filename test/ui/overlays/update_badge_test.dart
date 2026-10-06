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
import 'package:swiftie_quiz/ui/widgets/above_app_chrome.dart';

const UpdateManifest manifest = UpdateManifest(
  version: '0.3.0',
  notes: '',
  pubDate: '',
);

const List<UpdaterMachineState> quietStates = [
  UpdaterIdle(),
  UpdaterChecking(),
  UpdaterUpToDate(),
  UpdaterInstalling(),
  UpdaterInstalled(manifest: manifest),
];

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer.test());

  void setUpdater(UpdaterMachineState state) =>
      container.read(gameControllerProvider.notifier).setUpdaterState(state);

  bool dialogOpen() => container.read(updateDialogOpenProvider);

  Future<void> pumpShell(
    WidgetTester tester, {
    UpdateBadgeSize size = UpdateBadgeSize.mac,
    ThemeData? theme,
    Widget? screen,
    Widget? belowDialog,
  }) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme ?? AppTheme.dark,
        home: Material(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              UpdateBadge(size: size),
              Expanded(
                child: UpdateOverlay(screen: screen, belowDialog: belowDialog),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Finder pill() => find.descendant(
    of: find.byType(UpdateBadge),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).borderRadius ==
              UpdateBadge.radius &&
          (widget.decoration as BoxDecoration).color != null,
    ),
  );

  Finder dot() => find.descendant(
    of: find.byType(UpdateBadge),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle,
    ),
  );

  Finder focusRing() => find.descendant(
    of: find.byType(UpdateBadge),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.position == DecorationPosition.foreground &&
          (widget.decoration as BoxDecoration).border != null,
    ),
  );

  Color pillColor(WidgetTester tester) =>
      (tester.widget<DecoratedBox>(pill()).decoration as BoxDecoration).color!;

  group('update badge in the title bar', () {
    testWidgets(
      'the title bar badge reads the design copy for each updater state',
      (tester) async {
        for (final tokens in [AppTokens.dark, AppTokens.light]) {
          final looks = [
            UpdateBadge.lookFor(
              const UpdaterAvailable(
                manifest: UpdateManifest(
                  version: '0.3.1',
                  notes: '',
                  pubDate: '',
                ),
              ),
              tokens,
            ),
            UpdateBadge.lookFor(
              const UpdaterDownloading(manifest: manifest, progress: 47),
              tokens,
            ),
            UpdateBadge.lookFor(const UpdaterReady(manifest: manifest), tokens),
            UpdateBadge.lookFor(
              const UpdaterError(
                subtype: UpdaterErrorSubtype.download,
                message: 'network',
              ),
              tokens,
            ),
          ];
          expect(looks, [
            (
              label: 'Update available · 0.3.1',
              background: tokens.coral,
              foreground: tokens.onCoral,
            ),
            (
              label: 'Downloading · 47%',
              background: tokens.btn,
              foreground: tokens.onBtn,
            ),
            (
              label: 'Restart to update',
              background: tokens.coral,
              foreground: tokens.onCoral,
            ),
            (
              label: 'Update issue',
              background: tokens.roseBg,
              foreground: tokens.rose,
            ),
          ]);
          for (final state in quietStates) {
            expect(
              UpdateBadge.lookFor(state, tokens),
              isNull,
              reason: '$state',
            );
          }
        }

        setUpdater(const UpdaterAvailable(manifest: manifest));
        await pumpShell(tester);
        expect(find.text('Update available · 0.3.0'), findsOneWidget);
        expect(pillColor(tester), AppTokens.dark.coral);
        expect(dialogOpen(), isFalse);
        expect(find.text('Version 0.3.0 available'), findsNothing);

        await tester.tap(find.text('Update available · 0.3.0'));
        await tester.pumpAndSettle();

        expect(dialogOpen(), isTrue);
        expect(find.text('Version 0.3.0 available'), findsOneWidget);
      },
    );

    testWidgets('no badge shows while no update needs attention', (
      tester,
    ) async {
      for (final state in quietStates) {
        setUpdater(state);
        await pumpShell(tester);

        expect(tester.getSize(find.byType(UpdateBadge)), Size.zero);
        expect(pill(), findsNothing);
        expect(
          find.semantics.byPredicate(
            (node) => node.getSemanticsData().flagsCollection.isButton,
          ),
          findsNothing,
          reason: '$state',
        );
      }
    });

    testWidgets('the macos pill is 20 px tall at 11/20 weight 600', (
      tester,
    ) async {
      setUpdater(const UpdaterReady(manifest: manifest));
      await pumpShell(tester);

      final pillRect = tester.getRect(pill());
      expect(pillRect.height, 20);
      final text = tester.widget<Text>(find.text('Restart to update')).style!;
      expect(text.fontSize, 11);
      expect(text.height! * text.fontSize!, 20);
      expect(text.fontWeight, FontWeight.w600);
      expect(text.color, AppTokens.dark.onCoral);
      final dotRect = tester.getRect(dot());
      expect(dotRect.size, const Size.square(6));
      expect(dotRect.left - pillRect.left, 10);
      expect(dotRect.center.dy, pillRect.center.dy);
      expect(
        tester.getTopLeft(find.text('Restart to update')).dx - dotRect.right,
        6,
      );
      expect(
        pillRect.right - tester.getTopRight(find.text('Restart to update')).dx,
        10,
      );
      expect(
        (tester.widget<DecoratedBox>(dot()).decoration as BoxDecoration).color,
        AppTokens.dark.onCoral.withValues(alpha: 0.8),
      );
    });

    testWidgets('the windows pill is 22 px tall at 12/22 weight 600', (
      tester,
    ) async {
      setUpdater(const UpdaterDownloading(manifest: manifest, progress: 12));
      await pumpShell(tester, size: UpdateBadgeSize.windows);

      expect(tester.getRect(pill()).height, 22);
      final text = tester.widget<Text>(find.text('Downloading · 12%')).style!;
      expect(text.fontSize, 12);
      expect(text.height! * text.fontSize!, 22);
      expect(text.fontWeight, FontWeight.w600);
      expect(text.color, AppTokens.dark.onBtn);
      expect(pillColor(tester), AppTokens.dark.btn);
    });

    testWidgets('the badge colours follow the light theme', (tester) async {
      setUpdater(
        const UpdaterError(subtype: UpdaterErrorSubtype.check, message: ''),
      );
      await pumpShell(tester, theme: AppTheme.light);

      expect(pillColor(tester), AppTokens.light.roseBg);
      expect(
        tester.widget<Text>(find.text('Update issue')).style!.color,
        AppTokens.light.rose,
      );
    });

    testWidgets('the badge is a labelled button with a 24 px tall target', (
      tester,
    ) async {
      setUpdater(const UpdaterAvailable(manifest: manifest));
      await pumpShell(tester);

      final node = tester.getSemantics(pill());
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(node.label, 'Update available · 0.3.0');
      expect(tester.getSize(find.byType(UpdateBadge)).height, 24);

      await tester.tapAt(tester.getRect(pill()).topCenter - const Offset(0, 1));
      await tester.pump();
      expect(dialogOpen(), isTrue);
    });

    testWidgets('the keyboard reaches the badge, rings it and opens the '
        'dialog', (tester) async {
      setUpdater(const UpdaterAvailable(manifest: manifest));
      await pumpShell(tester);
      expect(focusRing(), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusRing(), findsOneWidget);
      expect(
        (tester.widget<DecoratedBox>(focusRing()).decoration as BoxDecoration)
            .border!
            .top
            .color,
        AppTokens.dark.coral,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(dialogOpen(), isTrue);
      expect(find.text('Version 0.3.0 available'), findsOneWidget);
    });
  });

  group('the update overlay hosts the dialog', () {
    testWidgets('the dialog opens and closes only through the provider', (
      tester,
    ) async {
      setUpdater(const UpdaterAvailable(manifest: manifest));
      await pumpShell(tester);
      expect(find.text('Version 0.3.0 available'), findsNothing);

      container.read(updateDialogOpenProvider.notifier).open();
      await tester.pumpAndSettle();
      expect(find.text('Version 0.3.0 available'), findsOneWidget);
      expect(
        find.semantics.byPredicate(
          (node) => node.getSemanticsData().role == SemanticsRole.dialog,
        ),
        findsOne,
      );

      container.read(updateDialogOpenProvider.notifier).close();
      await tester.pumpAndSettle();
      expect(find.text('Version 0.3.0 available'), findsNothing);
    });

    testWidgets('Escape closes the dialog and the badge stays', (tester) async {
      setUpdater(const UpdaterAvailable(manifest: manifest));
      await pumpShell(tester);
      await tester.tap(find.text('Update available · 0.3.0'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(dialogOpen(), isFalse);
      expect(find.text('Version 0.3.0 available'), findsNothing);
      expect(find.text('Update available · 0.3.0'), findsOneWidget);
    });

    testWidgets('a screen layer floated above the app chrome stays below the '
        'toasts', (tester) async {
      var coverTaps = 0;
      var toastTaps = 0;
      await pumpShell(
        tester,
        screen: Stack(
          children: [
            AboveAppChrome(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => coverTaps++,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
        belowDialog: Align(
          alignment: Alignment.topLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => toastTaps++,
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
      );

      await tester.tapAt(const Offset(400, 300));
      await tester.tapAt(const Offset(30, 30));

      expect(coverTaps, 1);
      expect(toastTaps, 1);
    });
  });
}
