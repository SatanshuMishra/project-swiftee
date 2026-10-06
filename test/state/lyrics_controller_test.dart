import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/domain/engine/play_order.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/lyrics_controller.dart';
import 'package:swiftie_quiz/state/play_history_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

import '../fixtures/catalogue_fixture.dart';

const Artist _taylor = Artist(id: 12246, name: 'Taylor Swift');
const Album _lover = Album(id: 10, title: 'Lover', coverMedium: null);

final DateTime _now = DateTime.utc(2026, 10, 5, 12);

Track _track(int id, {Album album = _lover, int? position}) => Track(
  id: id,
  title: 'Song $id',
  titleShort: 'Song $id',
  duration: 200,
  preview: 'https://cdnt-preview.dzcdn.net/api/1/1/$id.mp3',
  artist: _taylor,
  album: album,
  trackPosition: position,
);

List<Track> _tracks(Iterable<int> ids) => [for (final id in ids) _track(id)];

TrackLyrics _lyricsOf(int id) => TrackLyrics(
  lrclibId: 1000 + id,
  lines: ['First line of $id', 'Second line of $id'],
  lineCount: 2,
  sourceTrack: 'Song $id',
  sourceAlbum: 'Lover',
);

TrackWithLyrics _entry(int id) =>
    TrackWithLyrics(track: _track(id), lyrics: _lyricsOf(id));

Map<String, Object?> _lrclibRecord(int id) => {
  'id': 1000 + id,
  'trackName': 'Song $id',
  'artistName': 'Taylor Swift',
  'albumName': 'Lover',
  'duration': 200,
  'instrumental': false,
  'plainLyrics': '[Verse 1]\nFirst line of $id\n\nSecond line of $id\n',
  'syncedLyrics': null,
};

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

int? _songId(String? trackName) => trackName == null
    ? null
    : int.tryParse(trackName.replaceFirst('Song ', ''));

void main() {
  group('lyrics controller parity', () {
    late Set<int> songsWithLyrics;
    late List<int> lyricsLookups;
    late List<String> catalogRequests;
    late Map<String, http.Response> catalogResponses;
    late bool lrclibDown;
    late Future<void> heldReplies;
    late Set<String> heldCatalogPaths;
    late Set<int> heldSongs;
    late ProviderContainer container;
    late Completer<void> catalogueReady;

    LyricsController lyrics() => container.read(lyricsControllerProvider);

    GameController game() => container.read(gameControllerProvider.notifier);

    GameState read() => container.read(gameControllerProvider);

    Future<http.Response> lrclib(http.Request request) async {
      if (lrclibDown) {
        return http.Response('', 503);
      }
      final id = _songId(request.url.queryParameters['track_name']);
      if (heldSongs.contains(id)) {
        await heldReplies;
      }
      if (request.url.path == '/api/get') {
        lyricsLookups = [...lyricsLookups, ?id];
        return id != null && songsWithLyrics.contains(id)
            ? _json(_lrclibRecord(id))
            : _json({'statusCode': 404}, 404);
      }
      return _json(<Object?>[]);
    }

    setUp(() {
      songsWithLyrics = {};
      lyricsLookups = [];
      catalogRequests = [];
      catalogResponses = {};
      lrclibDown = false;
      heldReplies = Future<void>.value();
      heldCatalogPaths = {};
      heldSongs = {};
      catalogueReady = Completer<void>()..complete();
      container = ProviderContainer.test(
        overrides: [
          catalogueStoreProvider.overrideWithValue(
            fixtureCatalogueStore(
              loadBundled: () async {
                await catalogueReady.future;
                return encodeCatalogue(
                  fixtureReleases,
                  fetchedAt: '2026-10-06T00:00:00Z',
                );
              },
            ),
          ),

          appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
          clockProvider.overrideWithValue(() => _now),
          randomProvider.overrideWithValue(Random(3)),
          httpClientProvider.overrideWithValue(
            MockClient((request) async {
              if (request.url.host == 'lrclib.net') {
                return lrclib(request);
              }
              catalogRequests = [...catalogRequests, request.url.path];
              if (heldCatalogPaths.contains(request.url.path)) {
                await heldReplies;
              }
              return catalogResponses[request.url.path] ??
                  http.Response('', 500);
            }),
          ),
        ],
      );
    });

    test('builds a shuffled pool from the first eight tracks', () async {
      songsWithLyrics = {1, 2, 3, 4, 5, 6, 9};

      final pool = await lyrics().preFetchInitial(
        _tracks([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
      );

      expect(lyricsLookups, unorderedEquals([1, 2, 3, 4, 5, 6, 7, 8]));
      expect(
        pool,
        unorderedEquals([
          for (final id in [1, 2, 3, 4, 5, 6]) _entry(id),
        ]),
      );
      expect(read().lyricsPool, pool);
      expect(read().lyricsPoolIndex, 0);
      expect(read().decoyPool, {
        for (final id in [1, 2, 3, 4, 5, 6]) id: _lyricsOf(id),
      });
      expect(read().lyricsFetchProgress, isNull);
    });

    test('reports fetch progress as the batch completes', () async {
      songsWithLyrics = {1, 2, 3, 4, 5};
      var reported = <LyricsFetchProgress?>[];
      container.listen(
        gameControllerProvider.select((state) => state.lyricsFetchProgress),
        (_, next) => reported = [...reported, next],
      );
      var callbacks = <(int, int)>[];

      await lyrics().preFetchInitial(
        _tracks([1, 2, 3, 4, 5, 6]),
        onProgress: (fetched, total) =>
            callbacks = [...callbacks, (fetched, total)],
      );

      expect(reported, [(fetched: 0, total: 6), (fetched: 6, total: 6), null]);
      expect(callbacks, [(6, 6)]);
    });

    test('keeps a pool of fewer than five songs out of state', () async {
      songsWithLyrics = {2, 4, 6, 8};

      final pool = await lyrics().preFetchInitial(
        _tracks([1, 2, 3, 4, 5, 6, 7, 8]),
      );

      expect(pool, [_entry(2), _entry(4), _entry(6), _entry(8)]);
      expect(read().lyricsPool, isEmpty);
      expect(read().decoyPool.keys, [2, 4, 6, 8]);
      expect(read().lyricsFetchProgress, isNull);
    });

    test('more-fetching takes the next five tracks not in the pool', () async {
      songsWithLyrics = {4, 6, 7, 11};
      game().setLyricsPool([_entry(1), _entry(2), _entry(3)]);

      final fresh = await lyrics().preFetchMore(
        _tracks(List.generate(12, (index) => index + 1)),
        {1, 2, 3},
      );

      expect(lyricsLookups, unorderedEquals([4, 5, 6, 7, 8]));
      expect(fresh, [_entry(4), _entry(6), _entry(7)]);
      expect(read().decoyPool.keys, [4, 6, 7]);
      expect(read().lyricsPool, [_entry(1), _entry(2), _entry(3)]);
    });

    test(
      'more-fetching does nothing when every track is in the pool',
      () async {
        final fresh = await lyrics().preFetchMore(_tracks([1, 2]), {1, 2});

        expect(fresh, isEmpty);
        expect(lyricsLookups, isEmpty);
      },
    );

    test('more-fetching failures are not critical', () async {
      lrclibDown = true;

      final fresh = await lyrics().preFetchMore(_tracks([1, 2, 3]), const {});

      expect(fresh, isEmpty);
      expect(read().decoyPool, isEmpty);
    });

    test('more-fetching survives a lyrics client that cannot start', () async {
      final failing = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          lrclibClientProvider.overrideWith(
            (ref) => Future.error(StateError('no client')),
          ),
        ],
      );

      final fresh = await failing
          .read(lyricsControllerProvider)
          .preFetchMore(_tracks([1, 2, 3]), const {});

      expect(fresh, isEmpty);
    });

    test(
      'extending the pool appends new songs and keeps the place in it',
      () async {
        songsWithLyrics = {1, 2, 3, 4, 5, 6, 8};
        game()
          ..setLyricsAvailableTracks(
            _tracks(List.generate(10, (index) => index + 1)),
          )
          ..setLyricsPool([
            for (final id in [1, 2, 3, 4, 5]) _entry(id),
          ])
          ..nextLyricsTrack()
          ..nextLyricsTrack();

        await lyrics().extendPool();

        expect(lyricsLookups, unorderedEquals([6, 7, 8, 9, 10]));
        expect(read().lyricsPool, [
          for (final id in [1, 2, 3, 4, 5, 6, 8]) _entry(id),
        ]);
        expect(read().lyricsPoolIndex, 2);
      },
    );

    test('two extensions at once fetch each song only once', () async {
      songsWithLyrics = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
      game()
        ..setLyricsAvailableTracks(
          _tracks(List.generate(10, (index) => index + 1)),
        )
        ..setLyricsPool([
          for (final id in [1, 2, 3, 4, 5]) _entry(id),
        ]);

      await Future.wait([lyrics().extendPool(), lyrics().extendPool()]);

      expect(lyricsLookups, unorderedEquals([6, 7, 8, 9, 10]));
      expect(read().lyricsPool, [for (var id = 1; id <= 10; id++) _entry(id)]);
    });

    test(
      'an extension from the last game adds nothing to the next one',
      () async {
        final release = Completer<void>();
        heldReplies = release.future;
        heldSongs = {6, 7, 8, 9, 10};
        songsWithLyrics = {for (var id = 1; id <= 20; id++) id};
        game()
          ..setLyricsAvailableTracks(
            _tracks([for (var id = 1; id <= 10; id++) id]),
          )
          ..setLyricsPool([for (var id = 1; id <= 5; id++) _entry(id)]);
        final lastGame = lyrics().extendPool();
        await pumpEventQueue();

        await lyrics().preFetchInitial(_tracks([11, 12, 13, 14, 15]));
        game().setLyricsAvailableTracks(
          _tracks([for (var id = 11; id <= 20; id++) id]),
        );
        await lyrics().extendPool();
        release.complete();
        await lastGame;

        expect(read().lyricsPool, [
          for (var id = 11; id <= 20; id++) _entry(id),
        ]);
      },
    );

    test(
      'songs with no lyrics are tried once so the pool keeps growing',
      () async {
        songsWithLyrics = {1, 2, 3, 4, 5, 11, 12, 13, 14, 15};
        await lyrics().preFetchInitial(_tracks([1, 2, 3, 4, 5]));
        game().setLyricsAvailableTracks(
          _tracks([for (var id = 1; id <= 15; id++) id]),
        );

        await lyrics().extendPool();
        await lyrics().extendPool();

        expect(read().lyricsPool, [
          for (final id in [1, 2, 3, 4, 5, 11, 12, 13, 14, 15]) _entry(id),
        ]);
      },
    );

    test('the version choice for sound games leaves lyrics alone', () async {
      game()
        ..setMode(GameMode.random)
        ..setVersions(TrackVersions.noLive);

      final tracks = await lyrics().loadSourceTracks();

      final catalogue = container.read(catalogControllerProvider).catalogue;
      expect(tracks.map(songKey).toSet(), {
        for (final track in catalogue.allTracks) songKey(track),
      });
    });

    test(
      'shuffle reads one recording of every song in a random order',
      () async {
        game().setMode(GameMode.random);

        final tracks = await lyrics().loadSourceTracks();

        final catalogue = container.read(catalogControllerProvider).catalogue;
        final songs = {for (final track in catalogue.allTracks) songKey(track)};
        expect(catalogRequests, isEmpty);
        expect(tracks.map(songKey), unorderedEquals(songs));
        expect(tracks.length, lessThan(catalogue.allTracks.length));
        expect(read().lyricsAvailableTracks, tracks);
      },
    );

    test('songs read earlier this session wait at the back', () async {
      game().setMode(GameMode.random);
      final first = await lyrics().loadSourceTracks();
      for (final track in first.take(5)) {
        container.read(playHistoryProvider.notifier).read(track, const []);
      }

      final next = await lyrics().loadSourceTracks();

      final readSongs = {for (final track in first.take(5)) songKey(track)};
      expect(
        next
            .take(next.length - 5)
            .where((track) => readSongs.contains(songKey(track))),
        isEmpty,
      );
    });

    test('picked eras read only their own recordings', () async {
      game()
        ..setMode(GameMode.album)
        ..toggleEra('showgirl')
        ..toggleEra('lover');

      final tracks = await lyrics().loadSourceTracks();

      expect(
        [for (final track in tracks) track.title],
        unorderedEquals(['Cruel Summer', 'The Life of a Showgirl', 'Babylon']),
      );
      expect(read().lyricsAvailableTracks, tracks);
    });

    test(
      'a load whose selection changed while it waited publishes nothing',
      () async {
        catalogueReady = Completer<void>();
        game()
          ..setMode(GameMode.album)
          ..toggleEra('lover');
        final stale = lyrics().loadSourceTracks();
        await pumpEventQueue();

        game()
          ..resetGame()
          ..setMode(GameMode.random);
        catalogueReady.complete();
        await stale;

        expect(read().lyricsAvailableTracks, isEmpty);
      },
    );

    test(
      'a superseded load of the first lyrics leaves the newer pool in place',
      () async {
        final release = Completer<void>();
        heldReplies = release.future;
        heldSongs = {1, 2, 3, 4, 5};
        songsWithLyrics = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
        final stale = lyrics().preFetchInitial(_tracks([1, 2, 3, 4, 5]));
        await pumpEventQueue();

        final fresh = await lyrics().preFetchInitial(_tracks([6, 7, 8, 9, 10]));
        release.complete();
        final staleResult = await stale;

        expect(staleResult, hasLength(5));
        expect(read().lyricsPool, fresh);
        expect(read().decoyPool.keys, unorderedEquals([6, 7, 8, 9, 10]));
        expect(read().lyricsFetchProgress, isNull);
      },
    );

    test('eras with no recordings fail with a clear message', () async {
      game()
        ..setMode(GameMode.album)
        ..toggleEra('folklore');

      await expectLater(
        lyrics().loadSourceTracks(),
        throwsA(
          isA<LyricsSourceError>().having(
            (error) => error.message,
            'message',
            'Could not load tracks for the selected eras. Please try again.',
          ),
        ),
      );
      expect(read().lyricsAvailableTracks, isEmpty);
    });
  });
}
