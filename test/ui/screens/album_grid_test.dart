import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/screens/album_grid.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';

final List<Album> eraAlbums = List.unmodifiable([
  for (final era in curatedEras)
    Album(id: era.deezerAlbumId, title: era.eraName, coverMedium: null),
]);

Album albumOf(String eraKey) =>
    eraAlbums.firstWhere((album) => eraForAlbumId(album.id)?.key == eraKey);

class FakeCatalog extends CatalogController {
  FakeCatalog(this.initial);

  final CatalogState initial;
  int loadRequests = 0;

  @override
  CatalogState build() => initial;

  @override
  Future<void> loadAlbums() async => loadRequests++;
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
  List<Album>? cached,
  List<int> selected = const [],
  CatalogState catalogState = CatalogState.initial,
  Size size = const Size(1024, 800),
  bool reduceMotion = false,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final catalog = FakeCatalog(catalogState);
  final game = RecordingGame();
  final container = ProviderContainer.test(
    overrides: [
      catalogControllerProvider.overrideWith(() => catalog),
      gameControllerProvider.overrideWith(() => game),
    ],
  );
  container.read(gameControllerProvider.notifier)
    ..setAlbums(cached ?? eraAlbums)
    ..setPhase(GamePhase.albumSelect);
  selected.forEach(game.toggleAlbum);
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

List<int> selectedIds(ProviderContainer container) =>
    container.read(gameControllerProvider).selectedAlbumIds;

GamePhase phaseOf(ProviderContainer container) =>
    container.read(gameControllerProvider).phase;

Finder tile(int albumId) => find.byKey(ValueKey(albumId));

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
    testWidgets('the eras grid shows the twelve curated eras', (tester) async {
      await pumpAlbumGrid(
        tester,
        cached: const [],
        catalogState: CatalogState.initial.copyWith(albumsLoading: true),
        settle: false,
      );
      expect(find.text('Pick your eras'), findsOneWidget);
      expect(find.byType(CatLoader), findsOneWidget);
      expect(find.text('Loading albums...'), findsOneWidget);
      expect(find.text('The record store is closed.'), findsNothing);

      await pumpAlbumGrid(
        tester,
        cached: const [],
        catalogState: CatalogState.initial.copyWith(albumsError: 'HTTP 500'),
      );
      expect(find.text('The record store is closed.'), findsOneWidget);
      expect(find.widgetWithText(PillButton, 'Try again'), findsOneWidget);
      expect(find.widgetWithText(PillButton, 'Back to menu'), findsOneWidget);
      expect(find.byType(CatLoader), findsNothing);

      await pumpAlbumGrid(tester);
      final tiles = [for (final album in eraAlbums) tile(album.id)];
      for (final (index, era) in curatedEras.indexed) {
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
          matching: find.text('The Life of a Showgirl'),
        ),
        findsOneWidget,
      );
      final lefts = {for (final t in tiles) tester.getTopLeft(t).dx}
          .sorted((a, b) => a.compareTo(b));
      final tops = {for (final t in tiles) tester.getTopLeft(t).dy}
          .sorted((a, b) => a.compareTo(b));
      expect(lefts, hasLength(4));
      expect(tops, hasLength(3));
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
      final red = albumOf('red');
      final folklore = albumOf('folklore');
      expect(find.text('Pick at least one era'), findsOneWidget);
      expect(find.text('Clear'), findsNothing);
      expect(continueOpacity(tester), 0.45);

      await tapAndSettle(tester, find.text('Continue →'));
      expect(harness.game.setups, isEmpty);
      expect(phaseOf(harness.container), GamePhase.albumSelect);

      await tapAndSettle(tester, tile(red.id));
      await tapAndSettle(tester, tile(folklore.id));
      expect(selectedIds(harness.container), [red.id, folklore.id]);
      expect(find.text('2 eras'), findsOneWidget);
      expect(continueOpacity(tester), 1);

      await tapAndSettle(tester, find.text('Clear'));
      expect(selectedIds(harness.container), isEmpty);
      expect(find.text('Pick at least one era'), findsOneWidget);
      expect(find.text('Clear'), findsNothing);
      expect(continueOpacity(tester), 0.45);

      await tapAndSettle(tester, find.text('Continue →'));
      expect(harness.game.setups, isEmpty);
      expect(phaseOf(harness.container), GamePhase.albumSelect);

      await tapAndSettle(tester, tile(red.id));
      expect(find.text('1 era'), findsOneWidget);
      await tapAndSettle(tester, find.text('Continue →'));
      expect(harness.game.setups, [GameMode.album]);
      expect(phaseOf(harness.container), GamePhase.setup);
      expect(selectedIds(harness.container), [red.id]);
    });

    testWidgets('the bar adds the songs once every chosen total is known', (
      tester,
    ) async {
      final debut = albumOf('ts');
      final red = albumOf('red');
      final folklore = albumOf('folklore');
      await pumpAlbumGrid(
        tester,
        catalogState: CatalogState.initial.copyWith(
          albumTrackTotals: {debut.id: 15, red.id: 30},
        ),
      );

      await tapAndSettle(tester, tile(debut.id));
      expect(find.text('1 era · 15 songs'), findsOneWidget);

      await tapAndSettle(tester, tile(red.id));
      expect(find.text('2 eras · 45 songs'), findsOneWidget);

      await tapAndSettle(tester, tile(folklore.id));
      expect(find.text('3 eras'), findsOneWidget);
    });

    testWidgets('a chosen tile slides its disc out, rings it and checks it', (
      tester,
    ) async {
      final lover = albumOf('lover');
      await pumpAlbumGrid(tester, reduceMotion: true);
      Offset slide() => tester
          .widget<FractionalTranslation>(
            find.descendant(
              of: tile(lover.id),
              matching: find.byType(FractionalTranslation),
            ),
          )
          .translation;
      Decoration? ring() => tester
          .widget<AnimatedContainer>(
            find.descendant(
              of: tile(lover.id),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .foregroundDecoration;
      Finder check() =>
          find.descendant(of: tile(lover.id), matching: find.text('✓'));
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

      await tester.tap(tile(lover.id));
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
          for (final album in eraAlbums) tester.getTopLeft(tile(album.id)).dx,
        };
        expect(lefts, hasLength(columns), reason: '$size');
      }
    });

    testWidgets('opening requests albums only when none are cached', (
      tester,
    ) async {
      final empty = await pumpAlbumGrid(
        tester,
        cached: const [],
        catalogState: CatalogState.initial.copyWith(albumsLoading: true),
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
        cached: const [],
        catalogState: CatalogState.initial.copyWith(albumsError: 'HTTP 500'),
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
      final last = eraAlbums.last;

      for (var press = 0; press <= eraAlbums.length; press++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      }
      await tester.pumpAndSettle();

      final bar = find.ancestor(
        of: find.text('Pick at least one era'),
        matching: find.byType(BackdropFilter),
      );
      expect(
        Focus.of(tester.element(find.text(curatedEras.last.eraName))).hasFocus,
        isTrue,
      );
      expect(
        tester.getBottomLeft(tile(last.id)).dy,
        lessThanOrEqualTo(tester.getTopLeft(bar).dy),
      );
    });

    testWidgets('tiles keep their state when the width class changes', (
      tester,
    ) async {
      await pumpAlbumGrid(tester);
      final moved = eraAlbums[4];

      tester.view.physicalSize = const Size(1280, 900);
      await tester.pump();

      expect(
        tester
            .widget<Opacity>(
              find.descendant(
                of: tile(moved.id),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        1,
      );
      final lefts = {
        for (final album in eraAlbums) tester.getTopLeft(tile(album.id)).dx,
      };
      expect(lefts, hasLength(6));
    });

    testWidgets('the check mark stays out of the tile label', (tester) async {
      final semantics = tester.ensureSemantics();
      final red = albumOf('red');
      await pumpAlbumGrid(tester, selected: [red.id]);

      expect(find.bySemanticsLabel(RegExp('✓')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Red')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('tiles toggle from the keyboard', (tester) async {
      final harness = await pumpAlbumGrid(tester);
      final debut = albumOf('ts');

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(selectedIds(harness.container), [debut.id]);
    });
  });
}
