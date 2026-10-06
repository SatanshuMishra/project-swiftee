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
import 'package:swiftie_quiz/data/http_identity.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

const String albumsUrl = 'https://api.deezer.com/artist/12246/albums?limit=100';
const String albumsPage2Url =
    'https://api.deezer.com/artist/12246/albums?limit=100&index=100';
const String releaseTracksUrl =
    'https://api.deezer.com/album/829966251/tracks?limit=100';
const String releaseTracksPage2Url =
    'https://api.deezer.com/album/829966251/tracks?limit=100&index=100';
const String trackUrl = 'https://api.deezer.com/track/3579685431';
const String showgirlCover =
    'https://cdn-images.dzcdn.net/images/cover/3c2f6fd4e2a5d1b3/'
    '250x250-000000-80-0-0.jpg';
const Album showgirl = Album(
  id: 829966251,
  title: 'The Life of a Showgirl',
  coverMedium: showgirlCover,
);
const String expectedUserAgent =
    'SwiftieQuiz/0.3.0 (+https://github.com/SatanshuMishra/project-swiftee)';

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

Map<String, Object?> trackItem(int number) => {
  'id': number,
  'title': 'Track $number',
  'duration': 200,
  'artist': {'id': 12246},
};

http.Response tracksResponse(int from, int count, {String? next}) =>
    jsonResponse(
      jsonEncode({
        'data': [for (var n = from; n < from + count; n++) trackItem(n)],
        'total': from + count - 1,
        'next': ?next,
      }),
    );

final class FakeDeezer {
  FakeDeezer() {
    client = DeezerClient(
      client: MockClient(_handle),
      userAgent: appUserAgent('0.3.0'),
      now: () => start,
    );
  }

  late final DeezerClient client;
  final List<http.Request> requests = [];
  final Map<String, List<http.Response>> _routes = {};

  List<String> get urls => [
    for (final request in requests) request.url.toString(),
  ];

  void on(String url, List<http.Response> responses) {
    _routes[url] = [...responses];
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
  group('release summaries follow the next link', () {
    late FakeDeezer fake;

    setUp(() {
      fake = FakeDeezer()
        ..on(albumsUrl, [fixtureResponse('artist_albums_page1')])
        ..on(albumsPage2Url, [fixtureResponse('artist_albums_page2')]);
    });

    test('a 100 item page and an 18 item page give 118 releases', () async {
      final releases = await fake.client.fetchReleaseSummaries();

      expect(releases, hasLength(118));
      expect(releases.map((release) => release.id), [
        for (var n = 1; n <= 118; n++) 1000000 + n,
      ]);
      expect(fake.urls, [albumsUrl, albumsPage2Url]);
    });

    test('releases keep their fields, missing cover is null', () async {
      final releases = await fake.client.fetchReleaseSummaries();

      expect(releases.first.title, 'Album 001');
      expect(releases.first.kind, ReleaseKind.album);
      expect(releases.first.releaseDate, '2025-02-02');
      expect(
        releases.first.coverMedium,
        'https://cdn-images.dzcdn.net/images/cover/'
        '00000000000000000000000000000001/250x250-000000-80-0-0.jpg',
      );
      expect(releases.last.id, 1000118);
      expect(releases.last.coverMedium, isNull);
    });

    test('every page request sends the app user agent', () async {
      await fake.client.fetchReleaseSummaries();

      expect(fake.requests, hasLength(2));
      expect(
        fake.requests.map((request) => request.headers['User-Agent']),
        everyElement(expectedUserAgent),
      );
    });

    test('exactly 100 releases with no next link make one request', () async {
      final page = {
        for (final entry in fixtureJson('artist_albums_page1').entries)
          if (entry.key != 'next') entry.key: entry.value,
      };
      fake.on(albumsUrl, [jsonResponse(jsonEncode(page))]);

      final releases = await fake.client.fetchReleaseSummaries();

      expect(releases, hasLength(100));
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

          final releases = await local.client.fetchReleaseSummaries();

          expect(releases, hasLength(100), reason: next);
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

      final releases = await fake.client.fetchReleaseSummaries();

      expect(releases, hasLength(118));
      expect(fake.urls, [albumsUrl, albumsPage2Url]);
    });

    test('zero releases give an empty list', () async {
      fake.on(albumsUrl, [jsonResponse('{"data":[],"total":0}')]);

      expect(await fake.client.fetchReleaseSummaries(), isEmpty);
    });

    test('returned collections are unmodifiable', () async {
      final releases = await fake.client.fetchReleaseSummaries();

      expect(() => releases.clear(), throwsUnsupportedError);
    });
  });

  group('release tracks follow the next link', () {
    late FakeDeezer fake;

    setUp(() {
      fake = FakeDeezer()
        ..on(releaseTracksUrl, [
          tracksResponse(1, 100, next: releaseTracksPage2Url),
        ])
        ..on(releaseTracksPage2Url, [tracksResponse(101, 18)]);
    });

    test('a 100 item page and an 18 item page give 118 tracks', () async {
      final tracks = await fake.client.fetchReleaseTracks(829966251);

      expect(tracks.map((track) => track.id), [
        for (var n = 1; n <= 118; n++) n,
      ]);
      expect(fake.urls, [releaseTracksUrl, releaseTracksPage2Url]);
    });

    test('every page request sends the app user agent', () async {
      await fake.client.fetchReleaseTracks(829966251);

      expect(fake.requests, hasLength(2));
      expect(
        fake.requests.map((request) => request.headers['User-Agent']),
        everyElement(expectedUserAgent),
      );
    });

    test('exactly 100 tracks with no next link make one request', () async {
      fake.on(releaseTracksUrl, [tracksResponse(1, 100)]);

      final tracks = await fake.client.fetchReleaseTracks(829966251);

      expect(tracks, hasLength(100));
      expect(fake.urls, [releaseTracksUrl]);
    });

    test('a next link already requested is not requested again', () async {
      fake.on(releaseTracksPage2Url, [
        tracksResponse(101, 18, next: releaseTracksUrl),
      ]);

      final tracks = await fake.client.fetchReleaseTracks(829966251);

      expect(tracks, hasLength(118));
      expect(fake.urls, [releaseTracksUrl, releaseTracksPage2Url]);
    });

    test('zero tracks give an empty list', () async {
      fake.on(releaseTracksUrl, [jsonResponse('{"data":[],"total":0}')]);

      expect(await fake.client.fetchReleaseTracks(829966251), isEmpty);
    });

    test('tracks keep their optional fields and default the rest', () async {
      fake.on(releaseTracksUrl, [
        jsonResponse(
          jsonEncode({
            'data': [
              {
                ...trackItem(1),
                'title_short': 'Short',
                'title_version': '(Live)',
                'isrc': 'USUM71900001',
                'preview': 'https://example.com/preview.mp3',
              },
              trackItem(2),
            ],
          }),
        ),
      ]);

      final tracks = await fake.client.fetchReleaseTracks(829966251);

      expect(tracks.first.titleShort, 'Short');
      expect(tracks.first.titleVersion, '(Live)');
      expect(tracks.first.isrc, 'USUM71900001');
      expect(tracks.first.hasPreview, isTrue);
      expect(tracks.last.titleShort, 'Track 2');
      expect(tracks.last.titleVersion, '');
      expect(tracks.last.isrc, '');
      expect(tracks.last.hasPreview, isFalse);
    });

    test('release id 0 is rejected without a request', () async {
      await expectLater(
        fake.client.fetchReleaseTracks(0),
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

    test('returned collections are unmodifiable', () async {
      final tracks = await fake.client.fetchReleaseTracks(829966251);

      expect(() => tracks.clear(), throwsUnsupportedError);
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
        ..on(releaseTracksUrl, [fixtureResponse('quota_error')])
        ..on(trackUrl, [fixtureResponse('quota_error')]);
      final calls = <Future<Object> Function()>[
        fake.client.fetchReleaseSummaries,
        () => fake.client.fetchReleaseTracks(829966251),
        () => fake.client.refreshTrack(3579685431),
      ];

      for (final call in calls) {
        await expectLater(call(), throwsCatalogError(const RateLimited()));
      }
      expect(
        const RateLimited().message,
        'Taking a breather — try again in a moment.',
      );
      expect(fake.urls, [albumsUrl, releaseTracksUrl, trackUrl]);
    });

    test('another error is an api error with its message', () async {
      fake.on(releaseTracksUrl, [errorResponse('no data', 800)]);

      await expectLater(
        fake.client.fetchReleaseTracks(829966251),
        throwsCatalogError(const ApiError('no data')),
      );
      await expectLater(
        fake.client.fetchReleaseTracks(829966251),
        throwsA(
          isA<ApiError>().having(
            (error) => error.message,
            'message',
            'API error: no data',
          ),
        ),
      );
      expect(fake.urls, [releaseTracksUrl, releaseTracksUrl]);
    });

    test('an error on a later page fails the whole fetch', () async {
      fake
        ..on(albumsUrl, [fixtureResponse('artist_albums_page1')])
        ..on(albumsPage2Url, [fixtureResponse('quota_error')]);

      await expectLater(
        fake.client.fetchReleaseSummaries(),
        throwsCatalogError(const RateLimited()),
      );
      expect(fake.urls, [albumsUrl, albumsPage2Url]);
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

  group('refreshTrack', () {
    late FakeDeezer fake;

    setUp(() {
      fake = FakeDeezer()..on(trackUrl, [fixtureResponse('track')]);
    });

    test('requests /track/{id} for a new preview link', () async {
      final fresh = await fake.client.refreshTrack(3579685431);

      expect(fake.urls, [trackUrl]);
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

    test('each call requests /track/{id} again', () async {
      await fake.client.refreshTrack(3579685431);
      await fake.client.refreshTrack(3579685431);

      expect(fake.urls, [trackUrl, trackUrl]);
    });
  });

  group('request failures', () {
    late FakeDeezer fake;

    setUp(() {
      fake = FakeDeezer();
    });

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
        client.fetchReleaseSummaries(),
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
        client.fetchReleaseSummaries().then<void>(
          (releases) {},
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
      fake.on(albumsUrl, [jsonResponse('<html>busy</html>')]);

      await expectLater(
        fake.client.fetchReleaseSummaries(),
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
      fake
        ..on(albumsUrl, [jsonResponse('{"data":[{"id":1}]}')])
        ..on(releaseTracksUrl, [jsonResponse('{"data":[{"id":1}]}')]);

      await expectLater(
        fake.client.fetchReleaseSummaries(),
        throwsCatalogError(const ParseError('expected a release')),
      );
      await expectLater(
        fake.client.fetchReleaseTracks(829966251),
        throwsCatalogError(const ParseError('expected a track')),
      );
    });

    test('an error status without an error body is a network error', () async {
      fake.on(albumsUrl, [jsonResponse('<html>unavailable</html>', 503)]);

      await expectLater(
        fake.client.fetchReleaseSummaries(),
        throwsCatalogError(const NetworkError('HTTP 503')),
      );
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
}
