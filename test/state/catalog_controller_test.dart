import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/catalog/catalog_error.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

const String _albumsPath = '/artist/12246/albums';
const String _topPath = '/artist/12246/top';
const Artist _taylor = Artist(id: 12246, name: 'Taylor Swift');
const Album _lover = Album(id: 10, title: 'Lover', coverMedium: null);
const Album _folklore = Album(id: 20, title: 'folklore', coverMedium: null);

final DateTime _now = DateTime.utc(2026, 10, 5, 12);

Map<String, Object?> _albumJson(Album album) => {
  'id': album.id,
  'title': album.title,
  'cover_medium': album.coverMedium,
};

Map<String, Object?> _trackJson(
  int id, {
  Album? album,
  int duration = 200,
  String? preview,
  String title = '',
}) => {
  'id': id,
  'title': title.isEmpty ? 'Song $id' : title,
  'title_short': title.isEmpty ? 'Song $id' : title,
  'title_version': '',
  'duration': duration,
  'preview': preview ?? 'https://cdnt-preview.dzcdn.net/api/1/1/$id.mp3',
  'artist': {'id': _taylor.id, 'name': _taylor.name},
  if (album != null) 'album': _albumJson(album),
};

Track _track(int id, Album album, {String? preview}) => Track(
  id: id,
  title: 'Song $id',
  titleShort: 'Song $id',
  duration: 200,
  preview: preview ?? 'https://cdnt-preview.dzcdn.net/api/1/1/$id.mp3',
  artist: _taylor,
  album: album,
);

Map<String, Object?> _albumDetailJson(Album album, List<int> trackIds) => {
  ..._albumJson(album),
  'nb_tracks': trackIds.length,
  'tracks': {
    'data': [for (final id in trackIds) _trackJson(id)],
  },
};

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('catalog controller parity', () {
    late List<String> requested;
    late Future<http.Response> Function(http.Request request) respond;
    late ProviderContainer container;

    CatalogController catalog() =>
        container.read(catalogControllerProvider.notifier);

    GameController game() => container.read(gameControllerProvider.notifier);

    setUp(() {
      requested = [];
      respond = (request) async => _json({'error': 'unexpected'}, 404);
      container = ProviderContainer.test(
        overrides: [
          appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
          clockProvider.overrideWithValue(() => _now),
          randomProvider.overrideWithValue(Random(7)),
          httpClientProvider.overrideWithValue(
            MockClient((request) {
              requested = [...requested, request.url.path];
              return respond(request);
            }),
          ),
        ],
      );
    });

    test('loads albums when the album cache in state is empty', () async {
      respond = (request) async => _json({
        'data': [_albumJson(_lover), _albumJson(_folklore)],
      });

      await catalog().loadAlbums();

      expect(requested, [_albumsPath]);
      expect(container.read(gameControllerProvider).albums, [
        _lover,
        _folklore,
      ]);
      expect(container.read(catalogControllerProvider).albumsLoading, isFalse);
      expect(container.read(catalogControllerProvider).albumsError, isNull);
    });

    test('uses the album cache in state instead of the network', () async {
      game().setAlbums([_lover]);

      await catalog().loadAlbums();

      expect(requested, isEmpty);
      expect(container.read(gameControllerProvider).albums, [_lover]);
    });

    test('a second album load reuses the albums in state', () async {
      respond = (request) async => _json({
        'data': [_albumJson(_lover)],
      });

      await catalog().loadAlbums();
      await catalog().loadAlbums();

      expect(requested, [_albumsPath]);
    });

    test('reports loading while albums load and starts one request', () async {
      final reply = Completer<http.Response>();
      respond = (request) => reply.future;

      final first = catalog().loadAlbums();
      await pumpEventQueue();
      expect(container.read(catalogControllerProvider).albumsLoading, isTrue);
      final second = catalog().loadAlbums();

      reply.complete(
        _json({
          'data': [_albumJson(_lover)],
        }),
      );
      await Future.wait([first, second]);

      expect(requested, [_albumsPath]);
      expect(container.read(catalogControllerProvider).albumsLoading, isFalse);
      expect(container.read(gameControllerProvider).albums, [_lover]);
    });

    test('album errors carry the client message and clear on retry', () async {
      respond = (request) async => _json({
        'error': {
          'type': 'Exception',
          'message': 'Quota limit exceeded',
          'code': 4,
        },
      });

      await catalog().loadAlbums();

      expect(
        container.read(catalogControllerProvider).albumsError,
        'Taking a breather — try again in a moment.',
      );
      expect(container.read(catalogControllerProvider).albumsLoading, isFalse);
      expect(container.read(gameControllerProvider).albums, isEmpty);

      respond = (request) async => _json({
        'data': [_albumJson(_lover)],
      });
      await catalog().loadAlbums();

      expect(container.read(catalogControllerProvider).albumsError, isNull);
      expect(container.read(gameControllerProvider).albums, [_lover]);
    });

    test('random mode builds the track pool from top tracks', () async {
      respond = (request) async => _json({
        'data': [
          _trackJson(1, album: _lover),
          _trackJson(2, album: _folklore),
          _trackJson(3, album: _lover, duration: 30),
          _trackJson(4, album: _lover, preview: ''),
          _trackJson(5, album: _folklore),
        ],
      });

      final result = await catalog().loadTrackPool();

      expect(requested, [_topPath]);
      expect(result.allTracks, [
        _track(1, _lover),
        _track(2, _folklore),
        _track(4, _lover, preview: ''),
        _track(5, _folklore),
      ]);
      expect(
        result.pool,
        unorderedEquals([
          _track(1, _lover),
          _track(2, _folklore),
          _track(5, _folklore),
        ]),
      );
      expect(container.read(gameControllerProvider).trackPool, result.pool);
      expect(
        container.read(catalogControllerProvider).albumTrackTotals,
        isEmpty,
      );
    });

    test(
      "album mode builds the track pool from the selected albums' tracks",
      () async {
        respond = (request) async => switch (request.url.path) {
          '/album/10' => _json(_albumDetailJson(_lover, [11, 12, 13])),
          '/album/20' => _json(_albumDetailJson(_folklore, [21, 22])),
          _ => _json({'error': 'unexpected'}, 404),
        };
        game()
          ..setMode(GameMode.album)
          ..toggleAlbum(10)
          ..toggleAlbum(20);

        final result = await catalog().loadTrackPool();

        expect(requested, ['/album/10', '/album/20']);
        expect(result.allTracks, [
          _track(11, _lover),
          _track(12, _lover),
          _track(13, _lover),
          _track(21, _folklore),
          _track(22, _folklore),
        ]);
        expect(result.pool, unorderedEquals(result.allTracks));
        expect(container.read(gameControllerProvider).trackPool, result.pool);
      },
    );

    test('records per-album totals for the album completionist', () async {
      respond = (request) async => switch (request.url.path) {
        '/album/10' => _json(_albumDetailJson(_lover, [11, 12, 13])),
        '/album/20' => _json(_albumDetailJson(_folklore, [21, 22])),
        _ => _json({'error': 'unexpected'}, 404),
      };

      final lover = await catalog().fetchAlbumTracks(10);
      await catalog().fetchAlbumTracks(20);

      expect(lover.totalTracks, 3);
      expect(container.read(catalogControllerProvider).albumTrackTotals, {
        10: 3,
        20: 2,
      });
    });

    test('a superseded load leaves the newer track pool in place', () async {
      final staleReply = Completer<http.Response>();
      respond = (request) => switch (request.url.path) {
        '/album/10' => staleReply.future,
        _topPath => Future.value(
          _json({
            'data': [
              _trackJson(1, album: _lover),
              _trackJson(2, album: _lover),
            ],
          }),
        ),
        _ => Future.value(_json({'error': 'unexpected'}, 404)),
      };
      game()
        ..setMode(GameMode.album)
        ..toggleAlbum(10);
      final stale = catalog().loadTrackPool();
      await pumpEventQueue();

      game()
        ..resetGame()
        ..setMode(GameMode.random);
      final fresh = await catalog().loadTrackPool();
      staleReply.complete(_json(_albumDetailJson(_lover, [11])));
      await stale;

      expect(container.read(gameControllerProvider).trackPool, fresh.pool);
      expect(
        container.read(gameControllerProvider).trackPool,
        unorderedEquals([_track(1, _lover), _track(2, _lover)]),
      );
    });

    test(
      'a superseded load abandoned by resetGame leaves the pool empty',
      () async {
        final staleReply = Completer<http.Response>();
        respond = (request) => staleReply.future;
        game()
          ..setMode(GameMode.album)
          ..toggleAlbum(10);
        final stale = catalog().loadTrackPool();
        await pumpEventQueue();

        game().resetGame();
        staleReply.complete(_json(_albumDetailJson(_lover, [11])));
        await stale;

        expect(container.read(gameControllerProvider).trackPool, isEmpty);
      },
    );

    test('a failed track load throws and leaves the pool alone', () async {
      respond = (request) async => http.Response('', 500);
      game()
        ..setMode(GameMode.album)
        ..toggleAlbum(10)
        ..setTrackPool([_track(1, _lover)]);

      await expectLater(
        catalog().loadTrackPool(),
        throwsA(const NetworkError('HTTP 500')),
      );

      expect(container.read(gameControllerProvider).trackPool, [
        _track(1, _lover),
      ]);
    });

    test('requests identify the app', () async {
      late String? userAgent;
      respond = (request) async {
        userAgent = request.headers['User-Agent'];
        return _json({'data': <Object?>[]});
      };

      await catalog().loadAlbums();

      expect(
        userAgent,
        'SwiftieQuiz/0.3.0 (+https://github.com/SatanshuMishra/project-swiftee)',
      );
    });
  });
}
