import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/lyrics_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

const Artist _taylor = Artist(id: 12246, name: 'Taylor Swift');
const Album _lover = Album(id: 10, title: 'Lover', coverMedium: null);
const Album _folklore = Album(id: 20, title: 'folklore', coverMedium: null);

final DateTime _now = DateTime.utc(2026, 10, 5, 12);

Track _track(int id, {Album album = _lover}) => Track(
  id: id,
  title: 'Song $id',
  titleShort: 'Song $id',
  duration: 200,
  preview: 'https://cdnt-preview.dzcdn.net/api/1/1/$id.mp3',
  artist: _taylor,
  album: album,
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

Map<String, Object?> _deezerTrackJson(int id) => {
  'id': id,
  'title': 'Song $id',
  'title_short': 'Song $id',
  'title_version': '',
  'duration': 200,
  'preview': 'https://cdnt-preview.dzcdn.net/api/1/1/$id.mp3',
  'artist': {'id': _taylor.id, 'name': _taylor.name},
};

Map<String, Object?> _albumDetailJson(Album album, List<int> trackIds) => {
  'id': album.id,
  'title': album.title,
  'cover_medium': album.coverMedium,
  'nb_tracks': trackIds.length,
  'tracks': {
    'data': [for (final id in trackIds) _deezerTrackJson(id)],
  },
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
      container = ProviderContainer.test(
        overrides: [
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
      'extending the pool appends new songs and restarts the index',
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
        expect(read().lyricsPoolIndex, 0);
      },
    );

    test('random mode takes the top tracks as the source', () async {
      catalogResponses = {
        '/artist/12246/top': _json({
          'data': [
            {
              ..._deezerTrackJson(1),
              'album': {'id': 10, 'title': 'Lover'},
            },
            {
              ..._deezerTrackJson(2),
              'album': {'id': 10, 'title': 'Lover'},
            },
          ],
        }),
      };

      final tracks = await lyrics().loadSourceTracks();

      expect(catalogRequests, ['/artist/12246/top']);
      expect(tracks, [
        _track(
          1,
          album: const Album(id: 10, title: 'Lover', coverMedium: null),
        ),
        _track(
          2,
          album: const Album(id: 10, title: 'Lover', coverMedium: null),
        ),
      ]);
      expect(read().lyricsAvailableTracks, tracks);
    });

    test('album mode gathers the selected albums and skips failures', () async {
      catalogResponses = {
        '/album/10': _json(_albumDetailJson(_lover, [11, 12])),
      };
      game()
        ..setMode(GameMode.album)
        ..toggleAlbum(10)
        ..toggleAlbum(20);

      final tracks = await lyrics().loadSourceTracks();

      expect(catalogRequests, unorderedEquals(['/album/10', '/album/20']));
      expect(tracks, [_track(11), _track(12)]);
      expect(read().lyricsAvailableTracks, tracks);
      expect(container.read(catalogControllerProvider).albumTrackTotals, {
        10: 2,
      });
    });

    test('album mode keeps the selection order across albums', () async {
      catalogResponses = {
        '/album/20': _json(_albumDetailJson(_folklore, [21])),
        '/album/10': _json(_albumDetailJson(_lover, [11])),
      };
      game()
        ..setMode(GameMode.album)
        ..toggleAlbum(20)
        ..toggleAlbum(10);

      final tracks = await lyrics().loadSourceTracks();

      expect(tracks, [_track(21, album: _folklore), _track(11)]);
    });

    test(
      'a superseded load leaves the newer available tracks in place',
      () async {
        final release = Completer<void>();
        heldReplies = release.future;
        heldCatalogPaths = {'/album/10'};
        catalogResponses = {
          '/album/10': _json(_albumDetailJson(_lover, [11])),
          '/artist/12246/top': _json({
            'data': [
              {
                ..._deezerTrackJson(1),
                'album': {'id': 10, 'title': 'Lover'},
              },
            ],
          }),
        };
        game()
          ..setMode(GameMode.album)
          ..toggleAlbum(10);
        final stale = lyrics().loadSourceTracks();
        await pumpEventQueue();

        game()
          ..resetGame()
          ..setMode(GameMode.random);
        final fresh = await lyrics().loadSourceTracks();
        release.complete();
        await stale;

        expect(read().lyricsAvailableTracks, fresh);
        expect(read().lyricsAvailableTracks.single.id, 1);
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

    test('album mode fails when no selected album loads', () async {
      game()
        ..setMode(GameMode.album)
        ..toggleAlbum(10)
        ..toggleAlbum(20);

      await expectLater(
        lyrics().loadSourceTracks(),
        throwsA(
          isA<LyricsSourceError>().having(
            (error) => error.message,
            'message',
            'Could not load tracks for the selected albums. Please try again.',
          ),
        ),
      );
      expect(read().lyricsAvailableTracks, isEmpty);
    });
  });
}
