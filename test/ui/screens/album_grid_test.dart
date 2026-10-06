import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_store.dart';
import 'package:swiftie_quiz/domain/engine/catalogue_rules.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/screens/album_grid.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';

final Catalogue bundled = buildCatalogue(
  decodeCatalogue(File(bundledCataloguePath).readAsStringSync()),
);

class FakeCatalog extends CatalogController {
  FakeCatalog(this.initial);

  final CatalogState initial;
  int loadRequests = 0;

  @override
  CatalogState build() => initial;

  @override
  Future<void> loadCatalogue() async => loadRequests++;
}

class RecordingGame extends GameController {
  List<GameMode> setups = const [];

  @override
  void beginSetup(GameMode mode) {
    setups = [...setups, mode];
    super.beginSetup(mode);
  }
}

typedef AlbumGridHarness = ({
  ProviderContainer container,
  FakeCatalog catalog,
  RecordingGame game,
});

Future<AlbumGridHarness> pumpAlbumGrid(
  WidgetTester tester, {
  Catalogue? catalogue,
  List<String> selected = const [],
  CatalogState? catalogState,
  Size size = const Size(1024, 800),
  bool reduceMotion = false,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final catalog = FakeCatalog(
    (catalogState ?? CatalogState.initial).copyWith(
      catalogue: catalogue ?? bundled,
    ),
  );
  final game = RecordingGame();
  final container = ProviderContainer.test(
    overrides: [
      catalogControllerProvider.overrideWith(() => catalog),
      gameControllerProvider.overrideWith(() => game),
    ],
  );
  container.read(gameControllerProvider.notifier)
    ..setAlbums((catalogue ?? bundled).albums)
    ..setPhase(GamePhase.albumSelect);
  selected.forEach(game.toggleEra);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      key: ObjectKey(container),
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const AlbumGrid(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
  return (container: container, catalog: catalog, game: game);
}

List<String> selectedKeys(ProviderContainer container) =>
    container.read(gameControllerProvider).selectedEraKeys;

GamePhase phaseOf(ProviderContainer container) =>
    container.read(gameControllerProvider).phase;

Finder tile(String eraKey) => find.byKey(ValueKey(eraKey));

Finder continueButton() => find.widgetWithText(PillButton, 'Continue →');

double continueOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.descendant(
        of: continueButton(),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('eras grid', () {
    test('the selection bar counts eras and tracks in words', () {
      expect(AlbumGrid.selectionLabel(0, 0), 'Pick at least one era');
      expect(AlbumGrid.selectionLabel(1, 1), '1 era · 1 track');
      expect(AlbumGrid.selectionLabel(3, 98), '3 eras · 98 tracks');
    });

    testWidgets('the eras grid shows the twelve eras and the singles', (
      tester,
    ) async {
      await pumpAlbumGrid(
        tester,
        catalogue: Catalogue.empty,
        catalogState: CatalogState.initial.copyWith(loading: true),
        settle: false,
      );
      expect(find.text('Pick your eras'), findsOneWidget);
      expect(find.byType(CatLoader), findsOneWidget);
      expect(find.text('Loading albums...'), findsOneWidget);
      expect(find.text('The record store is closed.'), findsNothing);

      await pumpAlbumGrid(
        tester,
        catalogue: Catalogue.empty,
        catalogState: CatalogState.initial.copyWith(error: 'HTTP 500'),
      );
      expect(find.text('The record store is closed.'), findsOneWidget);
      expect(find.widgetWithText(PillButton, 'Try again'), findsOneWidget);
      expect(find.widgetWithText(PillButton, 'Back to menu'), findsOneWidget);
      expect(find.byType(CatLoader), findsNothing);

      await pumpAlbumGrid(tester);
      final tiles = [for (final era in eraGroups) tile(era.key)];
      for (final (index, era) in eraGroups.indexed) {
        expect(tiles[index], findsOneWidget);
        expect(
          find.descendant(of: tiles[index], matching: find.text(era.eraName)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tiles[index], matching: find.text(era.subLabel)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: tiles.first, matching: find.text('Taylor Swift')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tiles.last,
          matching: find.text('Singles & soundtracks'),
        ),
        findsOneWidget,
      );
      final lefts = {for (final t in tiles) tester.getTopLeft(t).dx}
          .sorted((a, b) => a.compareTo(b));
      final tops = {for (final t in tiles) tester.getTopLeft(t).dy}
          .sorted((a, b) => a.compareTo(b));
      expect(lefts, hasLength(4));
      expect(tops, hasLength(4));
      for (final (index, t) in tiles.indexed) {
        expect(
          tester.getTopLeft(t),
          Offset(lefts[index % 4], tops[index ~/ 4]),
        );
      }
    });

    testWidgets('choosing eras updates the bar and continue opens set up', (
      tester,
    ) async {
      final harness = await pumpAlbumGrid(tester);
      expect(find.text('Pick at least one era'), findsOneWidget);
      expect(find.text('Clear'), findsNothing);
      expect(continueOpacity(tester), 0.45);

      await tapAndSettle(tester, find.text('Continue →'));
      expect(harness.game.setups, isEmpty);
      expect(phaseOf(harness.container), GamePhase.albumSelect);

      await tapAndSettle(tester, tile('red'));
      await tapAndSettle(tester, tile('folklore'));
      expect(selectedKeys(harness.container), ['red', 'folklore']);
      expect(find.text('2 eras · 95 tracks'), findsOneWidget);
      expect(continueOpacity(tester), 1);

      await tapAndSettle(tester, find.text('Clear'));
      expect(selectedKeys(harness.container), isEmpty);
      expect(find.text('Pick at least one era'), findsOneWidget);
      expect(find.text('Clear'), findsNothing);
      expect(continueOpacity(tester), 0.45);

      await tapAndSettle(tester, find.text('Continue →'));
      expect(harness.game.setups, isEmpty);
      expect(phaseOf(harness.container), GamePhase.albumSelect);

      await tapAndSettle(tester, tile('red'));
      expect(find.text('1 era · 58 tracks'), findsOneWidget);
      await tapAndSettle(tester, find.text('Continue →'));
      expect(harness.game.setups, [GameMode.album]);
      expect(phaseOf(harness.container), GamePhase.setup);
      expect(selectedKeys(harness.container), ['red']);
    });

    testWidgets('the bar counts the tracks in the chosen eras', (tester) async {
      await pumpAlbumGrid(tester);

      await tapAndSettle(tester, tile('ts'));
      expect(find.text('1 era · 14 tracks'), findsOneWidget);

      await tapAndSettle(tester, tile('red'));
      expect(find.text('2 eras · 72 tracks'), findsOneWidget);
    });

    testWidgets('a chosen tile slides its disc out, rings it and checks it', (
      tester,
    ) async {
      await pumpAlbumGrid(tester, reduceMotion: true);
      Offset slide() => tester
          .widget<FractionalTranslation>(
            find.descendant(
              of: tile('lover'),
              matching: find.byType(FractionalTranslation),
            ),
          )
          .translation;
      Decoration? ring() => tester
          .widget<AnimatedContainer>(
            find.descendant(
              of: tile('lover'),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .foregroundDecoration;
      Finder check() =>
          find.descendant(of: tile('lover'), matching: find.text('✓'));
      double checkOpacity() => tester
          .widget<AnimatedOpacity>(
            find.ancestor(of: check(), matching: find.byType(AnimatedOpacity)),
          )
          .opacity;
      double checkScale() => tester
          .widget<AnimatedScale>(
            find.ancestor(of: check(), matching: find.byType(AnimatedScale)),
          )
          .scale;
      expect(slide(), Offset.zero);
      expect(checkOpacity(), 0);
      expect(checkScale(), 0);
      expect(
        (ring()! as BoxDecoration).border,
        isA<Border>().having(
          (border) => border.top.style,
          'style',
          BorderStyle.none,
        ),
      );

      await tester.tap(tile('lover'));
      await tester.pump();

      expect(slide(), const Offset(0.34, 0));
      expect(checkOpacity(), 1);
      expect(checkScale(), 1);
      final border = (ring()! as BoxDecoration).border! as Border;
      expect(border.top.width, 2);
      expect(border.top.color, const Color(0xFFE97F6A));
      expect(border.top.strokeAlign, BorderSide.strokeAlignOutside);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the grid uses three columns narrow and six large', (
      tester,
    ) async {
      for (final (size, columns) in const [
        (Size(686, 800), 3),
        (Size(1280, 900), 6),
      ]) {
        await pumpAlbumGrid(tester, size: size);
        final lefts = {
          for (final era in eraGroups) tester.getTopLeft(tile(era.key)).dx,
        };
        expect(lefts, hasLength(columns), reason: '$size');
      }
    });

    testWidgets('opening loads the catalogue only when it is empty', (
      tester,
    ) async {
      final empty = await pumpAlbumGrid(
        tester,
        catalogue: Catalogue.empty,
        catalogState: CatalogState.initial.copyWith(loading: true),
        settle: false,
      );
      expect(empty.catalog.loadRequests, 1);

      final cached = await pumpAlbumGrid(tester);
      expect(cached.catalog.loadRequests, 0);
    });

    testWidgets('try again reloads and back to menu leaves the closed store', (
      tester,
    ) async {
      final harness = await pumpAlbumGrid(
        tester,
        catalogue: Catalogue.empty,
        catalogState: CatalogState.initial.copyWith(error: 'HTTP 500'),
      );
      expect(harness.catalog.loadRequests, 1);

      await tapAndSettle(tester, find.text('Try again'));
      expect(harness.catalog.loadRequests, 2);

      await tapAndSettle(tester, find.text('Back to menu'));
      expect(phaseOf(harness.container), GamePhase.menu);
    });

    testWidgets('back returns to the menu', (tester) async {
      final harness = await pumpAlbumGrid(tester);

      await tapAndSettle(tester, find.text('Back'));

      expect(phaseOf(harness.container), GamePhase.menu);
    });

    testWidgets('a tile focused from the keyboard scrolls clear of the bar', (
      tester,
    ) async {
      await pumpAlbumGrid(tester);
      for (var press = 0; press <= eraGroups.length; press++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      }
      await tester.pumpAndSettle();

      final bar = find.ancestor(
        of: find.text('Pick at least one era'),
        matching: find.byType(BackdropFilter),
      );
      expect(
        Focus.of(tester.element(find.text(eraGroups.last.eraName))).hasFocus,
        isTrue,
      );
      expect(
        tester.getBottomLeft(tile(eraGroups.last.key)).dy,
        lessThanOrEqualTo(tester.getTopLeft(bar).dy),
      );
    });

    testWidgets('tiles keep their state when the width class changes', (
      tester,
    ) async {
      await pumpAlbumGrid(tester);
      final moved = eraGroups[4].key;

      tester.view.physicalSize = const Size(1280, 900);
      await tester.pump();

      expect(
        tester
            .widget<Opacity>(
              find.descendant(of: tile(moved), matching: find.byType(Opacity)),
            )
            .opacity,
        1,
      );
      final lefts = {
        for (final era in eraGroups) tester.getTopLeft(tile(era.key)).dx,
      };
      expect(lefts, hasLength(6));
    });

    testWidgets('the check mark stays out of the tile label', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpAlbumGrid(tester, selected: ['red']);

      expect(find.bySemanticsLabel(RegExp('✓')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Red')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('tiles toggle from the keyboard', (tester) async {
      final harness = await pumpAlbumGrid(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(selectedKeys(harness.container), ['ts']);
    });
  });
}
