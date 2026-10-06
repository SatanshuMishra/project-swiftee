import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/catalog/catalog_error.dart';
import 'package:swiftie_quiz/data/catalog/deezer_client.dart';
import 'package:swiftie_quiz/data/catalog/deezer_json.dart';
import 'package:swiftie_quiz/data/catalog/response_cache.dart';
import 'package:swiftie_quiz/data/http_identity.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

const String albumsUrl = 'https://api.deezer.com/artist/12246/albums?limit=100';
const String albumsPage2Url =
    'https://api.deezer.com/artist/12246/albums?limit=100&index=100';
const String albumUrl = 'https://api.deezer.com/album/829966251';
const String topUrl = 'https://api.deezer.com/artist/12246/top?limit=100';
const String trackUrl = 'https://api.deezer.com/track/3579685431';
const String showgirlCover =
    'https://cdn-images.dzcdn.net/images/cover/3c2f6fd4e2a5d1b3/'
    '250x250-000000-80-0-0.jpg';
const Album showgirl = Album(
  id: 829966251,
  title: 'The Life of a Showgirl',
  coverMedium: showgirlCover,
);
const List<String> keptAlbumTitles = [
  'The Fate of Ophelia',
  'Elizabeth Taylor',
  'Opalite',
  'Father Figure',
  'Eldest Daughter',
  'Actually Romantic',
  r'Wi$h Li$t',
];
const List<String> keptTopTitles = [
  'Cruel Summer',
  'Anti-Hero',
  "Love Story (Taylor's Version)",
  "Shake It Off (Taylor's Version)",
  "All Too Well (10 Minute Version) (Taylor's Version) (From The Vault)",
  "Blank Space (Taylor's Version)",
];

final DateTime start = DateTime.utc(2026, 10, 5, 12);

String fixture(String name) =>
    File('test/fixtures/deezer/$name.json').readAsStringSync();

Map<String, Object?> fixtureJson(String name) =>
    jsonDecode(fixture(name)) as Map<String, Object?>;

http.Response jsonResponse(String body, [int status = 200]) =>
    http.Response.bytes(
      utf8.encode(body),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

http.Response fixtureResponse(String name) => jsonResponse(fixture(name));

http.Response errorResponse(String message, int code) => jsonResponse(
  jsonEncode({
    'error': {'type': 'DataException', 'message': message, 'code': code},
  }),
);

final class FakeDeezer {
  FakeDeezer() : clock = start {
    client = DeezerClient(
      client: MockClient(_handle),
      userAgent: appUserAgent('0.3.0'),
      now: () => clock,
    );
  }

  DateTime clock;
  late final DeezerClient client;
  final List<http.Request> requests = [];
  final Map<String, List<http.Response>> _routes = {};

  List<String> get urls => [
    for (final request in requests) request.url.toString(),
  ];

  void on(String url, List<http.Response> responses) {
    _routes[url] = [...responses];
  }

  void advance(Duration duration) {
    clock = clock.add(duration);
  }

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    final queue = _routes[request.url.toString()];
    if (queue == null || queue.isEmpty) {
      return http.Response('not routed', 404);
    }
    return queue.length > 1 ? queue.removeAt(0) : queue.first;
  }
}

Matcher throwsCatalogError(CatalogError expected) => throwsA(
  isA<CatalogError>()
      .having((error) => error, 'error', expected)
      .having((error) => error.message, 'message', expected.message),
);

void main() {
  group('albums follow the next link', () {
    late FakeDeezer fake;

    setUp(() {
      fake = FakeDeezer()
        ..on(albumsUrl, [fixtureResponse('artist_albums_page1')])
        ..on(albumsPage2Url, [fixtureResponse('artist_albums_page2')]);
    });

    test('a 100 album page and an 18 album page give 118 albums', () async {
      final albums = await fake.client.fetchAlbums();

      expect(albums, hasLength(118));
      expect(albums.map((album) => album.id), [
        for (var n = 1; n <= 118; n++) 1000000 + n,
      ]);
      expect(fake.urls, [albumsUrl, albumsPage2Url]);
    });

    test('albums keep their title and cover, missing cover is null', () async {
      final albums = await fake.client.fetchAlbums();

      expect(
        albums.first,
        const Album(
          id: 1000001,
          title: 'Album 001',
          coverMedium:
              'https://cdn-images.dzcdn.net/images/cover/'
              '00000000000000000000000000000001/250x250-000000-80-0-0.jpg',
        ),
      );
      expect(
        albums.last,
        const Album(id: 1000118, title: 'Album 118', coverMedium: null),
      );
    });

    test('every page request sends the app user agent', () async {
      await fake.client.fetchAlbums();

      expect(
        fake.requests.map((request) => request.headers['User-Agent']),
        everyElement(
          'SwiftieQuiz/0.3.0 (+https://github.com/SatanshuMishra/project-swiftee)',
        ),
      );
    });

    test('albums are cached under no expiry', () async {
      final first = await fake.client.fetchAlbums();
      fake.advance(const Duration(days: 30));
      final second = await fake.client.fetchAlbums();

      expect(second, same(first));
      expect(fake.urls, [albumsUrl, albumsPage2Url]);
    });

    test('exactly 100 albums with no next link make one request', () async {
      final page = {
        for (final entry in fixtureJson('artist_albums_page1').entries)
          if (entry.key != 'next') entry.key: entry.value,
      };
      fake.on(albumsUrl, [jsonResponse(jsonEncode(page))]);

      final albums = await fake.client.fetchAlbums();

      expect(albums, hasLength(100));
      expect(fake.urls, [albumsUrl]);
    });

    test(
      'a next link to another host, scheme or port is not followed',
      () async {
        for (final next in [
          'https://api.deezer.com.evil.example/artist/12246/albums?index=100',
          'http://api.deezer.com/artist/12246/albums?limit=100&index=100',
          'https://api.deezer.com:8443/artist/12246/albums?index=100',
          'not a url %%',
        ]) {
          final local = FakeDeezer()
            ..on(albumsUrl, [
              jsonResponse(
                jsonEncode({
                  ...fixtureJson('artist_albums_page1'),
                  'next': next,
                }),
              ),
            ]);

          final albums = await local.client.fetchAlbums();

          expect(albums, hasLength(100), reason: next);
          expect(local.urls, [albumsUrl], reason: next);
        }
      },
    );

    test('a next link already requested is not requested again', () async {
      fake.on(albumsPage2Url, [
        jsonResponse(
          jsonEncode({
            ...fixtureJson('artist_albums_page2'),
            'next': albumsUrl,
          }),
        ),
      ]);

      final albums = await fake.client.fetchAlbums();

      expect(albums, hasLength(118));
      expect(fake.urls, [albumsUrl, albumsPage2Url]);
    });

    test('zero albums give an empty list', () async {
      fake.on(albumsUrl, [jsonResponse('{"data":[],"total":0}')]);

      expect(await fake.client.fetchAlbums(), isEmpty);
    });
  });

  group('deezer error bodies are failures', () {
    late FakeDeezer fake;

    setUp(() {
      fake = FakeDeezer();
    });

    test('quota code 4 with HTTP 200 is the rate limit message', () async {
      fake
        ..on(albumsUrl, [fixtureResponse('quota_error')])
        ..on(albumUrl, [fixtureResponse('quota_error')])
        ..on(topUrl, [fixtureResponse('quota_error')])
        ..on(trackUrl, [fixtureResponse('quota_error')]);
      final calls = <Future<Object> Function()>[
        fake.client.fetchAlbums,
        () => fake.client.fetchAlbumTracks(829966251),
        fake.client.fetchTopTracks,
        () => fake.client.refreshTrack(3579685431),
      ];

      for (final call in calls) {
        await expectLater(call(), throwsCatalogError(const RateLimited()));
      }
      expect(
        const RateLimited().message,
        'Taking a breather — try again in a moment.',
      );
      expect(fake.urls, [albumsUrl, albumUrl, topUrl, trackUrl]);
    });

    test('a quota error is not cached, so a retry hits the network', () async {
      fake.on(topUrl, [
        fixtureResponse('quota_error'),
        fixtureResponse('artist_top'),
      ]);

      await expectLater(
        fake.client.fetchTopTracks(),
        throwsCatalogError(const RateLimited()),
      );
      final tracks = await fake.client.fetchTopTracks();
      final cached = await fake.client.fetchTopTracks();

      expect(tracks.map((track) => track.title), keptTopTitles);
      expect(cached, same(tracks));
      expect(fake.urls, [topUrl, topUrl]);
    });

    test('another error is an api error with its message', () async {
      fake.on(albumUrl, [errorResponse('no data', 800)]);

      await expectLater(
        fake.client.fetchAlbumTracks(829966251),
        throwsCatalogError(const ApiError('no data')),
      );
      await expectLater(
        fake.client.fetchAlbumTracks(829966251),
        throwsA(
          isA<ApiError>().having(
            (error) => error.message,
            'message',
            'API error: no data',
          ),
        ),
      );
      expect(fake.urls, [albumUrl, albumUrl]);
    });

    test('an error on a later album page caches nothing', () async {
      fake
        ..on(albumsUrl, [fixtureResponse('artist_albums_page1')])
        ..on(albumsPage2Url, [
          fixtureResponse('quota_error'),
          fixtureResponse('artist_albums_page2'),
        ]);

      await expectLater(
        fake.client.fetchAlbums(),
        throwsCatalogError(const RateLimited()),
      );
      final albums = await fake.client.fetchAlbums();

      expect(albums, hasLength(118));
      expect(fake.urls, [albumsUrl, albumsPage2Url, albumsUrl, albumsPage2Url]);
    });

    test('an error body with an error status keeps its mapping', () async {
      fake.on(trackUrl, [
        jsonResponse(fixture('quota_error'), 429),
        jsonResponse('{"error":{"type":"OAuthException","code":300}}', 400),
      ]);

      await expectLater(
        fake.client.refreshTrack(3579685431),
        throwsCatalogError(const RateLimited()),
      );
      await expectLater(
        fake.client.refreshTrack(3579685431),
        throwsCatalogError(
          const ApiError('{"type":"OAuthException","code":300}'),
        ),
      );
    });
  });

  group('cached tracks expire with their preview token', () {
    late FakeDeezer fake;

    setUp(() {
      fake = FakeDeezer()
        ..on(albumUrl, [fixtureResponse('album')])
        ..on(topUrl, [fixtureResponse('artist_top')])
        ..on(trackUrl, [fixtureResponse('track')]);
    });

    test(
      'album tracks are served from cache until 60 s before the earliest exp',
      () async {
        final first = await fake.client.fetchAlbumTracks(829966251);
        fake.clock = DateTime.fromMillisecondsSinceEpoch(
          (1791202500 - 61) * 1000,
          isUtc: true,
        );
        final cached = await fake.client.fetchAlbumTracks(829966251);

        expect(cached, same(first));
        expect(fake.urls, [albumUrl]);

        fake.advance(const Duration(seconds: 1));
        final refetched = await fake.client.fetchAlbumTracks(829966251);

        expect(refetched, isNot(same(first)));
        expect(refetched, first);
        expect(fake.urls, [albumUrl, albumUrl]);
      },
    );

    test(
      'top tracks are served from cache until 60 s before the earliest exp',
      () async {
        final first = await fake.client.fetchTopTracks();
        fake.clock = DateTime.fromMillisecondsSinceEpoch(
          (1791202480 - 61) * 1000,
          isUtc: true,
        );

        expect(await fake.client.fetchTopTracks(), same(first));
        expect(fake.urls, [topUrl]);

        fake.advance(const Duration(seconds: 1));
        await fake.client.fetchTopTracks();

        expect(fake.urls, [topUrl, topUrl]);
      },
    );

    test('a preview without an hdnea token is cached for 10 minutes', () async {
      final unsigned = fixture('artist_top')
          .replaceAll(RegExp(r'\?hdnea=[^"]*'), '');
      fake.on(topUrl, [jsonResponse(unsigned)]);

      final first = await fake.client.fetchTopTracks();
      fake.advance(const Duration(minutes: 9, seconds: 59));

      expect(first.first.preview, isNot(contains('hdnea')));
      expect(await fake.client.fetchTopTracks(), same(first));
      expect(fake.urls, [topUrl]);

      fake.advance(const Duration(seconds: 1));
      await fake.client.fetchTopTracks();

      expect(fake.urls, [topUrl, topUrl]);
    });

    test('a token already inside its last minute forces a refetch', () async {
      fake.clock = DateTime.fromMillisecondsSinceEpoch(
        (1791202500 - 60) * 1000,
        isUtc: true,
      );

      await fake.client.fetchAlbumTracks(829966251);
      await fake.client.fetchAlbumTracks(829966251);

      expect(fake.urls, [albumUrl, albumUrl]);
    });

    test('refreshTrack requests /track/{id} for a new preview link', () async {
      final albumTracks = await fake.client.fetchAlbumTracks(829966251);
      final stale = albumTracks.tracks.first;

      final fresh = await fake.client.refreshTrack(stale.id);

      expect(fake.urls, [albumUrl, trackUrl]);
      expect(fresh.id, stale.id);
      expect(fresh.preview, isNot(stale.preview));
      expect(
        fresh,
        const Track(
          id: 3579685431,
          title: 'The Fate of Ophelia',
          titleShort: 'The Fate of Ophelia',
          duration: 226,
          preview:
              'https://cdnt-preview.dzcdn.net/api/1/1/x/y/z/0/abc.mp3'
              '?hdnea=exp=1791203400~acl=/api/1/1/x/y/z/0/abc.mp3*'
              '~data=user_id=0,application_id=42~hmac=00',
          artist: Artist(id: 12246, name: 'Taylor Swift'),
          album: showgirl,
        ),
      );
    });

    test('refreshTrack is never cached', () async {
      await fake.client.refreshTrack(3579685431);
      await fake.client.refreshTrack(3579685431);

      expect(fake.urls, [trackUrl, trackUrl]);
    });
  });

  group('deezer client parity', () {
    late FakeDeezer fake;

    setUp(() {
      fake = FakeDeezer()
        ..on(albumUrl, [fixtureResponse('album')])
        ..on(topUrl, [fixtureResponse('artist_top')])
        ..on(trackUrl, [fixtureResponse('track')]);
    });

    test('album id 0 is rejected without a request', () async {
      await expectLater(
        fake.client.fetchAlbumTracks(0),
        throwsA(
          isA<ApiError>().having(
            (error) => error.message,
            'message',
            'API error: Invalid album ID',
          ),
        ),
      );
      expect(fake.requests, isEmpty);
    });

    test('album tracks carry the album and keep only playable songs', () async {
      final albumTracks = await fake.client.fetchAlbumTracks(829966251);

      expect(fake.urls, [albumUrl]);
      expect(albumTracks.tracks.map((track) => track.title), keptAlbumTitles);
      expect(albumTracks.totalTracks, 7);
      expect(
        albumTracks.tracks.map((track) => track.album),
        everyElement(showgirl),
      );
      expect(
        albumTracks.tracks.first,
        const Track(
          id: 3579685431,
          title: 'The Fate of Ophelia',
          titleShort: 'The Fate of Ophelia',
          duration: 226,
          preview:
              'https://cdnt-preview.dzcdn.net/api/1/1/x/y/z/0/abc.mp3'
              '?hdnea=exp=1791202520~acl=/api/1/1/x/y/z/0/abc.mp3*'
              '~data=user_id=0,application_id=42~hmac=00',
          artist: Artist(id: 12246, name: 'Taylor Swift'),
          album: showgirl,
          trackPosition: 1,
        ),
      );
      expect(albumTracks.tracks.map((track) => track.trackPosition), [
        1,
        2,
        3,
        4,
        5,
        8,
        12,
      ]);
    });

    test('album tracks carry their position on the album', () async {
      final album = fixtureJson('album');
      final entries =
          (album['tracks']! as Map<String, Object?>)['data']! as List<Object?>;
      final intro = entries.singleWhere(
        (entry) =>
            (entry! as Map<String, Object?>)['title'] == 'Showgirl Intro',
      );
      fake.on('https://api.deezer.com/album/77', [
        jsonResponse(
          jsonEncode({
            ...album,
            'id': 77,
            'tracks': {
              'data': [entries[0], entries[1], intro, entries[3], entries[4]],
            },
          }),
        ),
      ]);

      final albumTracks = await fake.client.fetchAlbumTracks(77);
      final topTracks = await fake.client.fetchTopTracks();

      expect(albumTracks.tracks.map((track) => track.title), [
        'The Fate of Ophelia',
        'Elizabeth Taylor',
        'Father Figure',
        'Eldest Daughter',
      ]);
      expect(albumTracks.tracks.map((track) => track.trackPosition), [
        1,
        2,
        4,
        5,
      ]);
      expect(topTracks, isNotEmpty);
      expect(
        topTracks.map((track) => track.trackPosition),
        everyElement(isNull),
      );
    });

    test('album tracks are cached under their album id', () async {
      fake.on('https://api.deezer.com/album/42', [fixtureResponse('album')]);

      await fake.client.fetchAlbumTracks(829966251);
      await fake.client.fetchAlbumTracks(829966251);
      await fake.client.fetchAlbumTracks(42);

      expect(fake.urls, [albumUrl, 'https://api.deezer.com/album/42']);
    });

    test('top tracks request the top 100 and keep playable songs', () async {
      final tracks = await fake.client.fetchTopTracks();

      expect(fake.urls, [topUrl]);
      expect(tracks.map((track) => track.title), keptTopTitles);
      expect(
        tracks.first.album,
        const Album(
          id: 81763,
          title: 'Lover',
          coverMedium:
              'https://cdn-images.dzcdn.net/images/cover/'
              '6e58a99f59a9e40aa4ef4d4f9a3c4f7d/250x250-000000-80-0-0.jpg',
        ),
      );
    });

    test('returned collections are unmodifiable', () async {
      final albumTracks = await fake.client.fetchAlbumTracks(829966251);
      final tracks = await fake.client.fetchTopTracks();

      expect(() => albumTracks.tracks.clear(), throwsUnsupportedError);
      expect(() => tracks.clear(), throwsUnsupportedError);
    });

    test(
      '50 requests per window, cache hits take no token, refill after 60 s',
      () async {
        await fake.client.fetchTopTracks();
        for (var i = 0; i < 49; i++) {
          await fake.client.refreshTrack(3579685431);
        }

        expect(await fake.client.fetchTopTracks(), hasLength(6));
        await expectLater(
          fake.client.refreshTrack(3579685431),
          throwsCatalogError(const RateLimited()),
        );
        expect(fake.requests, hasLength(50));

        fake.advance(const Duration(seconds: 60));
        await fake.client.refreshTrack(3579685431);

        expect(fake.requests, hasLength(51));
      },
    );

    test('transport failures are network errors', () async {
      final client = DeezerClient(
        client: MockClient(
          (request) async =>
              throw http.ClientException('Connection refused', request.url),
        ),
        userAgent: appUserAgent('0.3.0'),
        now: () => start,
      );

      await expectLater(
        client.fetchTopTracks(),
        throwsCatalogError(const NetworkError('Connection refused')),
      );
      expect(
        const NetworkError('Connection refused').message,
        'Network error: Connection refused',
      );
    });

    test('requests time out after 10 s', () {
      fakeAsync((async) {
        final client = DeezerClient(
          client: MockClient((request) => Completer<http.Response>().future),
          userAgent: appUserAgent('0.3.0'),
          now: () => start,
        );
        Object? failure;
        client.fetchTopTracks().then<void>(
          (tracks) {},
          onError: (Object error) {
            failure = error;
          },
        );

        async.elapse(const Duration(seconds: 9, milliseconds: 999));
        expect(failure, isNull);

        async.elapse(const Duration(milliseconds: 1));
        expect(failure, const NetworkError('request timed out'));
      });
    });

    test('a body that is not JSON is a parse error', () async {
      fake.on(topUrl, [jsonResponse('<html>busy</html>')]);

      await expectLater(
        fake.client.fetchTopTracks(),
        throwsA(
          isA<ParseError>().having(
            (error) => error.message,
            'message',
            startsWith('Parse error: '),
          ),
        ),
      );
    });

    test('a body missing a required field is a parse error', () async {
      fake.on(topUrl, [jsonResponse('{"data":[{"id":1}]}')]);

      await expectLater(
        fake.client.fetchTopTracks(),
        throwsCatalogError(const ParseError('missing field `title`')),
      );
    });

    test('an error status without an error body is a network error', () async {
      fake.on(topUrl, [jsonResponse('<html>unavailable</html>', 503)]);

      await expectLater(
        fake.client.fetchTopTracks(),
        throwsCatalogError(const NetworkError('HTTP 503')),
      );
    });

    test('a failed fetch caches nothing', () async {
      fake.on(topUrl, [
        jsonResponse('<html>unavailable</html>', 503),
        fixtureResponse('artist_top'),
      ]);

      await expectLater(
        fake.client.fetchTopTracks(),
        throwsA(isA<NetworkError>()),
      );
      expect(await fake.client.fetchTopTracks(), hasLength(6));
      expect(fake.urls, [topUrl, topUrl]);
    });
  });

  group('deezer json parity', () {
    test('track deserializes from deezer json', () {
      final track = parseDeezerTrack(
        jsonDecode('''{
          "id": 1234,
          "title": "Enchanted (Taylor's Version)",
          "title_short": "Enchanted",
          "duration": 319,
          "preview": "https://cdns-preview-d.dzcdn.net/stream/c-123.mp3",
          "artist": {"id": 12246, "name": "Taylor Swift"},
          "album": {"id": 567, "title": "Speak Now (Taylor's Version)", "cover_medium": "https://example.com/cover.jpg"}
        }'''),
      ).track;

      expect(track.id, 1234);
      expect(track.titleShort, 'Enchanted');
      expect(track.artist.name, 'Taylor Swift');
      expect(track.album.coverMedium, 'https://example.com/cover.jpg');
    });

    test('track maps snake case title_short to titleShort', () {
      final track = parseDeezerTrack(
        jsonDecode(
          '{"id": 1, "title": "Test", "title_short": "Short", "duration": 30,'
          ' "preview": "https://example.com",'
          ' "artist": {"id": 1, "name": "Artist"},'
          ' "album": {"id": 1, "title": "Album", "cover_medium": null}}',
        ),
      ).track;

      expect(track.titleShort, 'Short');
      expect(track.album.coverMedium, isNull);
    });

    test('album missing cover defaults to null', () {
      final album = parseAlbum(jsonDecode('{"id": 1, "title": "Test Album"}'));

      expect(album.coverMedium, isNull);
    });

    test('deezer response deserializes', () {
      final response = parseDeezerPage(
        jsonDecode(
          '{"data": [{"id": 1, "title": "Album One"},'
          ' {"id": 2, "title": "Album Two"}]}',
        ),
        parseAlbum,
      );

      expect(response.data, hasLength(2));
      expect(response.data[0].title, 'Album One');
      expect(response.next, isNull);
    });

    test('track deserializes without album field', () {
      final track = parseDeezerTrack(
        jsonDecode('''{
          "id": 3579685431,
          "title": "The Fate of Ophelia",
          "title_short": "The Fate of Ophelia",
          "duration": 226,
          "preview": "https://cdnt-preview.dzcdn.net/stream/c-123.mp3",
          "artist": {"id": 12246, "name": "Taylor Swift"}
        }'''),
      ).track;

      expect(track.id, 3579685431);
      expect(track.titleShort, 'The Fate of Ophelia');
      expect(track.album.id, 0);
      expect(track.album.title, '');
    });

    test('album detail deserializes', () {
      final detail = parseAlbumDetail(
        jsonDecode('''{
          "id": 829966251,
          "title": "The Life of a Showgirl",
          "cover_medium": "https://e.dzcdn.net/images/cover/abc/250x250.jpg",
          "nb_tracks": 12,
          "tracks": {
            "data": [
              {
                "id": 111,
                "title": "Track One",
                "title_short": "Track One",
                "duration": 200,
                "preview": "https://cdnt-preview.dzcdn.net/stream/c-111.mp3",
                "artist": {"id": 12246, "name": "Taylor Swift"}
              }
            ]
          }
        }'''),
      );

      expect(detail.album.id, 829966251);
      expect(detail.album.title, 'The Life of a Showgirl');
      expect(detail.nbTracks, 12);
      expect(detail.tracks, hasLength(1));
      expect(detail.tracks[0].track.title, 'Track One');
    });

    test('track with album enrichment', () {
      final track = parseDeezerTrack(
        jsonDecode('''{
          "id": 111,
          "title": "Track One",
          "title_short": "Track One",
          "duration": 200,
          "preview": "https://example.com/preview.mp3",
          "artist": {"id": 12246, "name": "Taylor Swift"}
        }'''),
      ).track;

      final enriched = track.copyWith(
        album: const Album(
          id: 999,
          title: 'Test Album',
          coverMedium: 'https://example.com/cover.jpg',
        ),
      );

      expect(enriched.album.id, 999);
      expect(enriched.album.title, 'Test Album');
      expect(enriched.album.coverMedium, 'https://example.com/cover.jpg');
    });

    test('track null preview deserializes to empty string', () {
      final track = parseDeezerTrack(
        jsonDecode('''{
          "id": 9999,
          "title": "Restricted Track",
          "title_short": "Restricted",
          "duration": 180,
          "preview": null,
          "artist": {"id": 12246, "name": "Taylor Swift"},
          "album": {"id": 1, "title": "Some Album", "cover_medium": null}
        }'''),
      ).track;

      expect(track.id, 9999);
      expect(track.preview, '');
    });

    test('title version stays out of the domain track', () {
      Object? json(String titleVersion) => jsonDecode(
        '{"id": 1, "title": "Test", "title_short": "Test",'
        ' "title_version": "$titleVersion", "duration": 200,'
        ' "preview": "https://example.com",'
        ' "artist": {"id": 1, "name": "Artist"},'
        ' "album": {"id": 1, "title": "Album", "cover_medium": null}}',
      );

      final remix = parseDeezerTrack(json('(The Chainsmokers Remix)'));
      final plain = parseDeezerTrack(json(''));

      expect(remix.titleVersion, '(The Chainsmokers Remix)');
      expect(remix.track, plain.track);
    });

    test('title version deserializes', () {
      final track = parseDeezerTrack(
        jsonDecode('''{
          "id": 999,
          "title": "The Fate of Ophelia (The Chainsmokers Remix)",
          "title_short": "The Fate of Ophelia",
          "title_version": "(The Chainsmokers Remix)",
          "duration": 226,
          "preview": "https://cdnt-preview.dzcdn.net/stream/c-999.mp3",
          "artist": {"id": 12246, "name": "Taylor Swift"}
        }'''),
      );

      expect(track.titleVersion, '(The Chainsmokers Remix)');
    });

    test('missing title version defaults to empty', () {
      final track = parseDeezerTrack(
        jsonDecode('''{
          "id": 1234,
          "title": "Enchanted (Taylor's Version)",
          "title_short": "Enchanted",
          "duration": 319,
          "preview": "https://cdns-preview-d.dzcdn.net/stream/c-123.mp3",
          "artist": {"id": 12246, "name": "Taylor Swift"}
        }'''),
      );

      expect(track.titleVersion, '');
    });

    test('null title version defaults to empty', () {
      final track = parseDeezerTrack(
        jsonDecode('''{
          "id": 1234,
          "title": "Cruel Summer",
          "title_short": "Cruel Summer",
          "title_version": null,
          "duration": 179,
          "preview": "https://example.com/preview.mp3",
          "artist": {"id": 12246, "name": "Taylor Swift"}
        }'''),
      );

      expect(track.titleVersion, '');
    });

    test('deezer response with null preview track', () {
      final response = parseDeezerPage(
        jsonDecode('''{"data": [
          {
            "id": 1,
            "title": "Good Track",
            "title_short": "Good",
            "duration": 200,
            "preview": "https://example.com/preview.mp3",
            "artist": {"id": 1, "name": "Artist"}
          },
          {
            "id": 2,
            "title": "Restricted Track",
            "title_short": "Restricted",
            "duration": 180,
            "preview": null,
            "artist": {"id": 1, "name": "Artist"}
          }
        ]}'''),
        parseDeezerTrack,
      );

      expect(response.data, hasLength(2));
      expect(response.data[0].track.preview, 'https://example.com/preview.mp3');
      expect(response.data[1].track.preview, '');
    });
  });

  group('response cache parity', () {
    late DateTime clock;
    late ResponseCache cache;

    setUp(() {
      clock = start;
      cache = ResponseCache(now: () => clock);
    });

    test('cache miss returns null', () {
      expect(cache.get<Object>('missing'), isNull);
    });

    test('cache hit returns value', () {
      final value = {
        'data': [1, 2, 3],
      };
      cache.put('albums', value);

      expect(cache.get<Map<String, List<int>>>('albums'), same(value));
    });

    test('an entry misses from its expiry on', () {
      cache.put('top_tracks', 'tracks', expiresAt: start.add(_minute));

      clock = start.add(_minute - const Duration(milliseconds: 1));
      expect(cache.get<String>('top_tracks'), 'tracks');

      clock = start.add(_minute);
      expect(cache.get<String>('top_tracks'), isNull);
    });

    test('an entry without expiry never misses', () {
      cache.put('albums', 'albums');
      clock = start.add(const Duration(days: 3650));

      expect(cache.get<String>('albums'), 'albums');
    });

    test('a lookup for another type misses', () {
      cache.put('albums', 'albums');

      expect(cache.get<int>('albums'), isNull);
    });
  });
}

const Duration _minute = Duration(minutes: 1);
