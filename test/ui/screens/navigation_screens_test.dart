import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/backup_entry.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/persistence_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/cat/cat_icon_button.dart';
import 'package:swiftie_quiz/ui/overlays/birthday_card.dart';
import 'package:swiftie_quiz/ui/screens/album_grid.dart';
import 'package:swiftie_quiz/ui/screens/main_menu.dart';
import 'package:swiftie_quiz/ui/screens/settings_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/widgets/selection_card.dart';

final DateTime afterBirthdayPeriod = DateTime(2026, 10, 5, 12);
final DateTime duringBirthdayPeriod = DateTime(2026, 2, 19, 12);

class IdleCatalog extends CatalogController {
  @override
  CatalogState build() => CatalogState.initial;

  @override
  Future<void> loadAlbums() async {}
}

class NoBackups extends PersistenceController {
  @override
  PersistenceStatus build() => PersistenceStatus.loaded;

  @override
  Future<List<BackupEntry>> listBackups() async => const [];
}

typedef Setup = void Function(GameController game);

Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Setup? setup,
  DateTime? now,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer.test(
    overrides: [
      clockProvider.overrideWithValue(() => now ?? afterBirthdayPeriod),
      catalogControllerProvider.overrideWith(IdleCatalog.new),
      persistenceControllerProvider.overrideWith(NoBackups.new),
      appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
    ],
  );
  setup?.call(container.read(gameControllerProvider.notifier));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      key: ObjectKey(container),
      container: container,
      child: MaterialApp(theme: AppTheme.dark, home: screen),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
  return container;
}

GameState gameOf(ProviderContainer container) =>
    container.read(gameControllerProvider);

Finder card(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(SelectionCard));

Finder featureOf(String difficulty, String feature) =>
    find.descendant(of: card(difficulty), matching: find.text(feature));

Future<void> tapBack(WidgetTester tester) async {
  await tester.tap(find.text('Back'));
  await tester.pump();
}

void main() {
  group('menu and selection navigation', () {
    testWidgets('Random Mode picks random mode and opens set up', (
      tester,
    ) async {
      final container = await pumpScreen(
        tester,
        const MainMenu(),
        setup: (game) => game.setMode(GameMode.album),
      );

      await tester.tap(find.text('Random Mode'));

      expect(gameOf(container).mode, GameMode.random);
      expect(gameOf(container).phase, GamePhase.setup);
    });

    testWidgets('Pick Albums picks album mode and opens album select', (
      tester,
    ) async {
      final container = await pumpScreen(tester, const MainMenu());

      await tester.tap(find.text('Pick Albums'));

      expect(gameOf(container).mode, GameMode.album);
      expect(gameOf(container).phase, GamePhase.albumSelect);
    });

    testWidgets('Cat Gallery and Settings cards open the shelf and settings', (
      tester,
    ) async {
      final container = await pumpScreen(tester, const MainMenu());

      await tester.tap(find.text('Cat Gallery'));
      expect(gameOf(container).phase, GamePhase.recordShelf);

      await tester.tap(find.text('Settings'));
      expect(gameOf(container).phase, GamePhase.settings);
    });

    testWidgets('main menu shows the title, subtitle and four cards', (
      tester,
    ) async {
      await pumpScreen(tester, const MainMenu());

      expect(find.text('Swiftie Quiz'), findsOneWidget);
      expect(find.text("How well do you know Taylor's music?"), findsOneWidget);
      for (final (title, description) in [
        ('Random Mode', 'All songs, shuffled randomly'),
        ('Pick Albums', 'Choose your favorite albums'),
        ('Cat Gallery', 'View your achievements'),
        ('Settings', 'Theme, volume & more'),
      ]) {
        expect(
          find.descendant(of: card(title), matching: find.text(description)),
          findsOneWidget,
        );
      }
    });

    testWidgets('album select and settings go back to the menu', (
      tester,
    ) async {
      for (final screen in const [AlbumGrid(), SettingsScreen()]) {
        final container = await pumpScreen(
          tester,
          screen,
          setup: (game) => game.setPhase(GamePhase.settings),
        );
        expect(gameOf(container).phase, GamePhase.settings);

        await tapBack(tester);

        expect(
          gameOf(container).phase,
          GamePhase.menu,
          reason: '${screen.runtimeType}',
        );
      }
    });
  });

  group('main menu birthday card', () {
    testWidgets('opens one second after the menu during the birthday period', (
      tester,
    ) async {
      final container = await pumpScreen(
        tester,
        const MainMenu(),
        now: duringBirthdayPeriod,
        settle: false,
      );

      await tester.pump(const Duration(milliseconds: 999));
      expect(find.text('Happy Birthday!'), findsNothing);
      expect(container.read(birthdayCardSessionProvider), isFalse);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Happy Birthday!'), findsOneWidget);
      expect(container.read(birthdayCardSessionProvider), isTrue);
    });

    testWidgets('does not open again once shown this session', (tester) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer.test(
        overrides: [
          clockProvider.overrideWithValue(() => duringBirthdayPeriod),
        ],
      );
      container.read(birthdayCardSessionProvider.notifier).markShown();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.dark, home: const MainMenu()),
        ),
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Happy Birthday!'), findsNothing);
    });

    testWidgets('does not open after the birthday period', (tester) async {
      final container = await pumpScreen(tester, const MainMenu());

      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Happy Birthday!'), findsNothing);
      expect(container.read(birthdayCardSessionProvider), isFalse);
    });

    testWidgets(
      'the cat button opens the card and its close button closes it',
      (tester) async {
        await pumpScreen(tester, const MainMenu());

        await tester.tap(find.byType(CatIconButton));
        await tester.pumpAndSettle();
        expect(find.text('Happy Birthday!'), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(BirthdayCard),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && (widget.properties.button ?? false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Happy Birthday!'), findsNothing);
      },
    );

    testWidgets('the cat sits 24 px from the top right at 64 px', (
      tester,
    ) async {
      await pumpScreen(tester, const MainMenu());

      final cat = tester.getRect(find.byType(CatIconButton));
      expect(cat.top, 24);
      expect(cat.right, 1024 - 24);
      expect(cat.height, 64);
    });

    testWidgets('hovering the cat fades the Birthday Card tooltip in', (
      tester,
    ) async {
      await pumpScreen(tester, const MainMenu());
      double tooltipOpacity() => tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.text('Birthday Card'),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;
      expect(tooltipOpacity(), 0);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(CatIconButton)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(tooltipOpacity(), inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 75));
      expect(tooltipOpacity(), 1);
    });
  });
}
