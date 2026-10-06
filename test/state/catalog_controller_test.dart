import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_store.dart';
import 'package:swiftie_quiz/data/catalog/deezer_client.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

import '../fixtures/catalogue_fixture.dart';

final DateTime _october6 = DateTime.utc(2026, 10, 6, 12);

http.Response _json(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  late Directory folder;
  late List<String> requested;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('catalogue');
    requested = [];
  });
  tearDown(() => folder.deleteSync(recursive: true));

  ProviderContainer container({CatalogueStore? store}) {
    final made = ProviderContainer.test(
      overrides: [
        catalogueStoreProvider.overrideWithValue(
          store ?? fixtureCatalogueStore(folder: folder),
        ),
        clockProvider.overrideWithValue(() => _october6),
        deezerClientProvider.overrideWith(
          (ref) async => DeezerClient(
            userAgent: 'test',
            client: MockClient((request) async {
              requested.add(request.url.path);
              return switch (request.url.path) {
                '/artist/12246/albums' => _json({
                  'data': [
                    {
                      'id': 2001,
                      'title': 'The Life of a Showgirl: The Afterparty',
                      'record_type': 'album',
                      'release_date': '2026-11-20',
                      'cover_medium': null,
                    },
                    {
                      'id': 130721292,
                      'title': 'Red',
                      'record_type': 'album',
                      'release_date': '2012-10-22',
                      'cover_medium': null,
                    },
                  ],
                }),
                '/album/2001/tracks' => _json({
                  'data': [
                    {
                      'id': 3001,
                      'title': 'Afterglow Encore',
                      'duration': 201,
                      'isrc': 'SG99',
                      'preview': 'https://cdnt-preview.dzcdn.net/3001.mp3',
                      'artist': {'id': taylor, 'name': 'Taylor Swift'},
                    },
                  ],
                }),
                _ => _json({
                  'error': {'message': 'unexpected'},
                }),
              };
            }),
          ),
        ),
      ],
    );
    return made;
  }

  group('catalog controller', () {
    test('loading the catalogue publishes every release as an album', () async {
      final scope = container();
      await scope.read(catalogControllerProvider.notifier).loadCatalogue();

      final state = scope.read(catalogControllerProvider);
      expect(state.loading, isFalse);
      expect(state.catalogue.recordings, isNotEmpty);
      expect(
        scope.read(gameControllerProvider).albums.length,
        fixtureReleases.length,
      );
      expect(requested, isEmpty);
    });

    test('shuffle plays from every recording in the catalogue', () async {
      final scope = container();
      scope.read(gameControllerProvider.notifier).beginSetup(GameMode.random);

      final tracks = await scope
          .read(catalogControllerProvider.notifier)
          .loadTrackPool();

      final catalogue = scope.read(catalogControllerProvider).catalogue;
      expect(tracks.allTracks, catalogue.allTracks);
      expect(tracks.pool.toSet(), catalogue.allTracks.toSet());
      expect(scope.read(gameControllerProvider).trackPool, tracks.pool);
    });

    test('picked eras play only their own recordings', () async {
      final scope = container();
      scope.read(gameControllerProvider.notifier)
        ..toggleEra('showgirl')
        ..beginSetup(GameMode.album);

      final tracks = await scope
          .read(catalogControllerProvider.notifier)
          .loadTrackPool();

      expect([
        for (final track in tracks.allTracks) track.title,
      ], unorderedEquals(['The Life of a Showgirl', 'Babylon']));
    });

    test("tonight's era plays the era for today's date", () async {
      final scope = container();
      scope.read(gameControllerProvider.notifier).beginSetup(GameMode.tonight);

      final tracks = await scope
          .read(catalogControllerProvider.notifier)
          .loadTrackPool();

      expect(tracks.allTracks, isNotEmpty);
      expect(tracks.allTracks.every((track) => track.eraKey == 'red'), isTrue);
    });

    test('a failed load reports the error and can be retried', () async {
      var attempts = 0;
      final scope = container(
        store: fixtureCatalogueStore(
          folder: folder,
          loadBundled: () async {
            attempts++;
            if (attempts == 1) {
              throw const FileSystemException('missing');
            }
            return File(bundledCataloguePath).readAsString();
          },
        ),
      );
      final catalog = scope.read(catalogControllerProvider.notifier);

      await catalog.loadCatalogue();
      expect(scope.read(catalogControllerProvider).error, isNotNull);
      expect(scope.read(catalogControllerProvider).catalogue.isEmpty, isTrue);

      await catalog.loadCatalogue();
      expect(scope.read(catalogControllerProvider).error, isNull);
      expect(scope.read(catalogControllerProvider).catalogue.isEmpty, isFalse);
    });

    test(
      'a new release found on Deezer joins the catalogue once a session',
      () async {
        final scope = container();
        final catalog = scope.read(catalogControllerProvider.notifier);

        await catalog.checkForNewReleases();
        await catalog.checkForNewReleases();

        final catalogue = scope.read(catalogControllerProvider).catalogue;
        expect(
          catalogue.tracksFor(['showgirl']).map((track) => track.title),
          contains('Afterglow Encore'),
        );
        expect(catalogue.eraOf(2001)?.key, 'showgirl');
        expect(requested, ['/artist/12246/albums', '/album/2001/tracks']);
        expect(
          File('${folder.path}/$catalogueUpdatesFileName').existsSync(),
          isTrue,
        );
      },
    );

    test('a failed release check leaves the catalogue as it was', () async {
      final scope = ProviderContainer.test(
        overrides: [
          catalogueStoreProvider.overrideWithValue(
            fixtureCatalogueStore(folder: folder),
          ),
          deezerClientProvider.overrideWith(
            (ref) async => DeezerClient(
              userAgent: 'test',
              client: MockClient((request) async => http.Response('', 500)),
            ),
          ),
        ],
      );
      final catalog = scope.read(catalogControllerProvider.notifier);
      await catalog.loadCatalogue();
      final before = scope.read(catalogControllerProvider).catalogue;

      await catalog.checkForNewReleases();

      expect(
        identical(scope.read(catalogControllerProvider).catalogue, before),
        isTrue,
      );
    });
  });
}
