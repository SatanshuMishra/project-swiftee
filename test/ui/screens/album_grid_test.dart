import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/screens/album_grid.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';

const List<Album> albums = [
  Album(id: 1, title: 'folklore', coverMedium: null),
  Album(id: 2, title: 'Lover', coverMedium: null),
  Album(
    id: 3,
    title: 'Midnights',
    coverMedium: 'https://e-cdns-images.dzcdn.net/images/cover/m.jpg',
  ),
];

class FakeCatalog extends CatalogController {
  FakeCatalog(this.initial);

  final CatalogState initial;
  int loadRequests = 0;

  @override
  CatalogState build() => initial;

  @override
  Future<void> loadAlbums() async => loadRequests++;
}

typedef AlbumGridHarness = ({ProviderContainer container, FakeCatalog catalog});

Future<AlbumGridHarness> pumpAlbumGrid(
  WidgetTester tester, {
  List<Album> cached = albums,
  List<int> selected = const [],
  CatalogState catalogState = CatalogState.initial,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final catalog = FakeCatalog(catalogState);
  final container = ProviderContainer.test(
    overrides: [catalogControllerProvider.overrideWith(() => catalog)],
  );
  final game = container.read(gameControllerProvider.notifier);
  game.setAlbums(cached);
  selected.forEach(game.toggleAlbum);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      key: ObjectKey(container),
      container: container,
      child: MaterialApp(theme: AppTheme.dark, home: const AlbumGrid()),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 500));
  }
  return (container: container, catalog: catalog);
}

List<int> selectedIds(ProviderContainer container) =>
    container.read(gameControllerProvider).selectedAlbumIds;

Finder tile(int albumId) => find.byKey(ValueKey(albumId));

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('album grid parity', () {
    testWidgets('shows the large cat loader while albums load', (tester) async {
      await pumpAlbumGrid(
        tester,
        cached: const [],
        catalogState: CatalogState.initial.copyWith(albumsLoading: true),
        settle: false,
      );

      expect(find.text('Pick Albums'), findsOneWidget);
      expect(
        find.text('Tap one or more albums, then start your quiz'),
        findsOneWidget,
      );
      expect(
        tester.widget<CatLoader>(find.byType(CatLoader)).size,
        CatLoaderSize.lg,
      );
      expect(find.text('Loading albums...'), findsOneWidget);
    });

    testWidgets('requests albums on open only when none are cached', (
      tester,
    ) async {
      final empty = await pumpAlbumGrid(tester, cached: const []);
      expect(empty.catalog.loadRequests, 1);

      final cached = await pumpAlbumGrid(tester);
      expect(cached.catalog.loadRequests, 0);
    });

    testWidgets('tapping a tile toggles its selection', (tester) async {
      final harness = await pumpAlbumGrid(tester);

      await tapAndSettle(tester, tile(2));
      expect(selectedIds(harness.container), [2]);

      await tapAndSettle(tester, tile(3));
      expect(selectedIds(harness.container), [2, 3]);

      await tapAndSettle(tester, tile(2));
      expect(selectedIds(harness.container), [3]);
    });

    testWidgets('the footer counts the selected albums', (tester) async {
      await pumpAlbumGrid(tester);
      expect(find.textContaining('Start Quiz'), findsNothing);

      await tapAndSettle(tester, tile(1));
      expect(find.text('Start Quiz (1 album)'), findsOneWidget);
      expect(find.text('Clear all'), findsOneWidget);

      await tapAndSettle(tester, tile(2));
      expect(find.text('Start Quiz (2 albums)'), findsOneWidget);

      await tapAndSettle(tester, tile(1));
      await tapAndSettle(tester, tile(2));
      expect(find.textContaining('Start Quiz'), findsNothing);
    });

    testWidgets('Clear all empties the selection and hides the footer', (
      tester,
    ) async {
      final harness = await pumpAlbumGrid(tester, selected: const [1, 3]);
      expect(find.text('Start Quiz (2 albums)'), findsOneWidget);

      await tapAndSettle(tester, find.text('Clear all'));

      expect(selectedIds(harness.container), isEmpty);
      expect(find.text('Clear all'), findsNothing);
    });

    testWidgets('Start Quiz opens quiz type select', (tester) async {
      final harness = await pumpAlbumGrid(tester, selected: const [2]);

      await tapAndSettle(tester, find.text('Start Quiz (1 album)'));

      expect(
        harness.container.read(gameControllerProvider).phase,
        GamePhase.setup,
      );
    });

    testWidgets('the footer stays hidden while albums are loading', (
      tester,
    ) async {
      await pumpAlbumGrid(
        tester,
        selected: const [1],
        catalogState: CatalogState.initial.copyWith(albumsLoading: true),
      );

      expect(find.textContaining('Start Quiz'), findsNothing);
    });

    testWidgets('a cover tile shows its title, a bare tile the note', (
      tester,
    ) async {
      await pumpAlbumGrid(tester);

      expect(
        find.descendant(of: tile(3), matching: find.text('Midnights')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile(1), matching: find.text('♫')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile(1), matching: find.text('folklore')),
        findsNothing,
      );
    });

    testWidgets('shows the catalog error', (tester) async {
      await pumpAlbumGrid(
        tester,
        cached: const [],
        catalogState: CatalogState.initial.copyWith(
          albumsError: 'API error: Quota exceeded',
        ),
      );

      expect(find.text('API error: Quota exceeded'), findsOneWidget);
    });
  });
}
