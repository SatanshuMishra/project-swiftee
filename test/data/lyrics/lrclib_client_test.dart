import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/http_identity.dart';
import 'package:swiftie_quiz/data/lyrics/lrclib_client.dart';
import 'package:swiftie_quiz/data/lyrics/lyrics_error.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

final String _userAgent = appUserAgent('0.3.0');
final DateTime _fixedNow = DateTime.utc(2026, 10, 5, 12);

typedef _Handler = FutureOr<http.Response> Function(http.Request request);

typedef _FakeLrclib = ({MockClient client, List<http.Request> requests});

_FakeLrclib _lrclibServer({_Handler? get, _Handler? search}) {
  final requests = <http.Request>[];
  final client = MockClient((request) async {
    requests.add(request);
    final handler = switch (request.url.path) {
      '/api/get' => get,
      '/api/search' => search,
      _ => null,
    };
    return handler == null ? http.Response('', 404) : await handler(request);
  });
  return (client: client, requests: requests);
}

LrclibClient _lrclib(
  http.Client client, {
  List<Duration>? delays,
  DateTime Function()? now,
}) => LrclibClient(
  client: client,
  userAgent: _userAgent,
  delay: (duration) async => delays?.add(duration),
  now: now ?? () => _fixedNow,
);

Track _track({
  int id = 1,
  String title = 'Enchanted',
  int duration = 352,
  String album = 'Speak Now',
}) => Track(
  id: id,
  title: title,
  titleShort: title,
  duration: duration,
  preview: 'https://cdnt-preview.dzcdn.net/api/1/1/a/b/c/0/abc.mp3',
  artist: const Artist(id: 12246, name: 'Taylor Swift'),
  album: Album(id: 10, title: album, coverMedium: null),
);

Map<String, Object?> _record({
  int id = 7,
  String trackName = 'Enchanted',
  String albumName = 'Speak Now',
  num duration = 352,
  bool instrumental = false,
  String? plainLyrics = 'There I was again tonight\nForcing laughter',
}) => {
  'id': id,
  'name': trackName,
  'trackName': trackName,
  'artistName': 'Taylor Swift',
  'albumName': albumName,
  'duration': duration,
  'instrumental': instrumental,
  'plainLyrics': plainLyrics,
  'syncedLyrics': null,
};

TrackLyrics _lyrics({
  int lrclibId = 7,
  List<String> lines = const ['There I was again tonight', 'Forcing laughter'],
  String sourceTrack = 'Enchanted',
  String sourceAlbum = 'Speak Now',
}) => TrackLyrics(
  lrclibId: lrclibId,
  lines: lines,
  lineCount: lines.length,
  sourceTrack: sourceTrack,
  sourceAlbum: sourceAlbum,
);

http.Response _json(Object? body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: const {'content-type': 'application/json'},
);

http.Response _tooManyRequests([Map<String, String> headers = const {}]) =>
    http.Response('{"message": "slow down"}', 429, headers: headers);

Matcher _throwsLyricsError<T extends LyricsError>(String message) =>
    throwsA(isA<T>().having((error) => error.message, 'message', message));

const String _notFoundMessage = 'Lyrics not found for this track.';
const String _unavailableMessage =
    'Lyrics service unavailable — try again later.';

void main() {
  group('lrclib client parity', () {
    group('normaliseTitle', () {
      test('test_normalise_title_no_parens', () {
        expect(normaliseTitle('Cruel Summer'), 'Cruel Summer');
      });

      test('test_normalise_title_single_paren', () {
        expect(normaliseTitle("Enchanted (Taylor's Version)"), 'Enchanted');
      });

      test('test_normalise_title_multiple_parens', () {
        expect(
          normaliseTitle(
            "All Too Well (10 Minute Version) (Taylor's Version) "
            '(From The Vault)',
          ),
          'All Too Well',
        );
      });

      test('test_normalise_title_feat', () {
        expect(normaliseTitle('22 (feat. Ed Sheeran)'), '22');
      });

      test('test_normalise_title_lowercase', () {
        expect(
          normaliseTitle('willow (dancing witch version) (bonus track)'),
          'willow',
        );
      });
    });

    group('processPlainLyrics', () {
      test('test_process_plain_lyrics_basic', () {
        expect(processPlainLyrics('Line one\nLine two\n\nLine three'), [
          'Line one',
          'Line two',
          'Line three',
        ]);
      });

      test('test_process_plain_lyrics_strips_headers', () {
        expect(
          processPlainLyrics(
            '[Verse 1]\nFirst line\n[Chorus]\nChorus line\n[Outro]\nLast line',
          ),
          ['First line', 'Chorus line', 'Last line'],
        );
      });

      test('test_process_plain_lyrics_trims_whitespace', () {
        expect(processPlainLyrics('  hello  \n  world  \n   \n  foo  '), [
          'hello',
          'world',
          'foo',
        ]);
      });
    });

    group('fetchLyrics', () {
      test('asks /get with track, artist, album and duration first', () async {
        final server = _lrclibServer(get: (_) => _json(_record()));

        final lyrics = await _lrclib(server.client).fetchLyrics(_track());

        expect(lyrics, _lyrics());
        final request = server.requests.single;
        expect(request.method, 'GET');
        expect(request.url.scheme, 'https');
        expect(request.url.host, 'lrclib.net');
        expect(request.url.path, '/api/get');
        expect(request.url.queryParameters, {
          'track_name': 'Enchanted',
          'artist_name': 'Taylor Swift',
          'album_name': 'Speak Now',
          'duration': '352',
        });
      });

      test('tries /get then /search with the normalised title', () async {
        final server = _lrclibServer(
          search: (_) => _json([
            _record(id: 9, trackName: "Enchanted (Taylor's Version)"),
          ]),
        );

        final lyrics = await _lrclib(server.client)
            .fetchLyrics(_track(title: "Enchanted (Taylor's Version)"));

        expect(
          lyrics,
          _lyrics(lrclibId: 9, sourceTrack: "Enchanted (Taylor's Version)"),
        );
        expect(server.requests.map((request) => request.url.path), [
          '/api/get',
          '/api/search',
        ]);
        expect(
          server.requests.first.url.queryParameters['track_name'],
          "Enchanted (Taylor's Version)",
        );
        expect(server.requests.last.url.queryParameters, {
          'track_name': 'Enchanted',
          'artist_name': 'Taylor Swift',
        });
      });

      test(
        'picks the search result whose rounded duration is closest',
        () async {
          final server = _lrclibServer(
            search: (_) => _json([
              _record(id: 1, duration: 200.4, albumName: 'Far'),
              _record(id: 2, duration: 241.6, albumName: 'Closest'),
              _record(id: 3, duration: 236.5, albumName: 'Near'),
            ]),
          );

          final lyrics = await _lrclib(server.client)
              .fetchLyrics(_track(duration: 240));

          expect(lyrics.lrclibId, 2);
          expect(lyrics.sourceAlbum, 'Closest');
        },
      );

      test('keeps the first of equally close search results', () async {
        final server = _lrclibServer(
          search: (_) => _json([
            _record(id: 1, duration: 300),
            _record(id: 2, duration: 238),
            _record(id: 3, duration: 242),
          ]),
        );

        final lyrics = await _lrclib(server.client)
            .fetchLyrics(_track(duration: 240));

        expect(lyrics.lrclibId, 2);
      });

      test(
        'skips instrumental and lyric-less search results even when closer',
        () async {
          final server = _lrclibServer(
            search: (_) => _json([
              _record(id: 1, duration: 240, instrumental: true),
              _record(id: 2, duration: 240, plainLyrics: '   '),
              _record(id: 3, duration: 240, plainLyrics: null),
              _record(id: 4, duration: 100),
            ]),
          );

          final lyrics = await _lrclib(server.client)
              .fetchLyrics(_track(duration: 240));

          expect(lyrics.lrclibId, 4);
        },
      );

      test(
        'falls back to search when the exact match is instrumental',
        () async {
          final server = _lrclibServer(
            get: (_) => _json(_record(id: 1, instrumental: true)),
            search: (_) => _json([_record(id: 2)]),
          );

          final lyrics = await _lrclib(server.client).fetchLyrics(_track());

          expect(lyrics.lrclibId, 2);
        },
      );

      test(
        'falls back to search when the exact match has no usable lines',
        () async {
          for (final plain in <String?>[null, '  \n ', '[Instrumental]']) {
            final server = _lrclibServer(
              get: (_) => _json(_record(id: 1, plainLyrics: plain)),
              search: (_) => _json([_record(id: 2)]),
            );

            final lyrics = await _lrclib(server.client).fetchLyrics(_track());

            expect(lyrics.lrclibId, 2, reason: 'plainLyrics: $plain');
          }
        },
      );

      test('falls back to search when /get returns another 4xx', () async {
        final server = _lrclibServer(
          get: (_) => http.Response('', 400),
          search: (_) => _json([_record(id: 2)]),
        );

        final lyrics = await _lrclib(server.client).fetchLyrics(_track());

        expect(lyrics.lrclibId, 2);
      });

      test(
        'falls back to search when the /get body does not match the schema',
        () async {
          final bodies = <http.Response>[
            http.Response('{not json', 200),
            _json({..._record(), 'albumName': null}),
            _json({..._record(), 'id': -1}),
            _json({..._record(), 'duration': '352'}),
            _json({..._record(), 'plainLyrics': 42}),
            _json([_record()]),
          ];
          for (final body in bodies) {
            final server = _lrclibServer(
              get: (_) => body,
              search: (_) => _json([_record(id: 2)]),
            );

            final lyrics = await _lrclib(server.client).fetchLyrics(_track());

            expect(lyrics.lrclibId, 2, reason: body.body);
          }
        },
      );

      test('drops section headers from the processed lines', () async {
        final server = _lrclibServer(
          get: (_) => _json(
            _record(plainLyrics: '[Verse 1]\n  First line \n\n[Chorus]\nHook'),
          ),
        );

        final lyrics = await _lrclib(server.client).fetchLyrics(_track());

        expect(lyrics.lines, ['First line', 'Hook']);
        expect(lyrics.lineCount, 2);
      });

      test(
        'decodes the body as UTF-8 whatever the content type says',
        () async {
          final server = _lrclibServer(
            get: (_) => http.Response.bytes(
              utf8.encode(
                jsonEncode(_record(plainLyrics: 'Don’t you think — I was')),
              ),
              200,
              headers: const {'content-type': 'application/json'},
            ),
          );

          final lyrics = await _lrclib(server.client).fetchLyrics(_track());

          expect(lyrics.lines, ['Don’t you think — I was']);
        },
      );

      test('a server error on /get is retried once, then unavailable without '
          'searching', () async {
        final delays = <Duration>[];
        final server = _lrclibServer(
          get: (_) => http.Response('', 503),
          search: (_) => _json([_record()]),
        );

        await expectLater(
          _lrclib(server.client, delays: delays).fetchLyrics(_track()),
          _throwsLyricsError<LyricsUnavailable>(_unavailableMessage),
        );
        expect(server.requests.map((request) => request.url.path), [
          '/api/get',
          '/api/get',
        ]);
        expect(delays, [const Duration(seconds: 1)]);
      });

      test(
        'a server error on search is retried once, then unavailable',
        () async {
          final server = _lrclibServer(search: (_) => http.Response('', 500));

          await expectLater(
            _lrclib(server.client).fetchLyrics(_track()),
            _throwsLyricsError<LyricsUnavailable>(_unavailableMessage),
          );
          expect(server.requests.map((request) => request.url.path), [
            '/api/get',
            '/api/search',
            '/api/search',
          ]);
        },
      );

      test(
        'a server error that clears on the retry returns the lyrics',
        () async {
          var attempts = 0;
          final server = _lrclibServer(
            get: (_) =>
                ++attempts == 1 ? http.Response('', 502) : _json(_record()),
          );

          expect(await _lrclib(server.client).fetchLyrics(_track()), _lyrics());
          expect(server.requests, hasLength(2));
        },
      );

      test('a failed search is not found', () async {
        for (final response in [
          http.Response('', 404),
          http.Response('[{', 200),
          _json(<Object?>[]),
          _json([_record(), _record(id: 8)..remove('trackName')]),
          _json([_record(instrumental: true)]),
          _json([_record(plainLyrics: '[Chorus]')]),
        ]) {
          final server = _lrclibServer(search: (_) => response);

          await expectLater(
            _lrclib(server.client).fetchLyrics(_track()),
            _throwsLyricsError<LyricsNotFound>(_notFoundMessage),
            reason: response.body,
          );
        }
      });

      test('a transport failure is retried once, then unavailable', () async {
        var attempts = 0;
        final delays = <Duration>[];
        final client = MockClient((request) async {
          attempts++;
          throw http.ClientException('offline', request.url);
        });

        await expectLater(
          _lrclib(client, delays: delays).fetchLyrics(_track()),
          _throwsLyricsError<LyricsUnavailable>(_unavailableMessage),
        );
        expect(attempts, 2);
        expect(delays, [const Duration(seconds: 1)]);
      });

      test(
        'a transport failure that clears on the retry returns the lyrics',
        () async {
          var attempts = 0;
          final client = MockClient((request) async {
            if (++attempts == 1) {
              throw const HandshakeException('CERTIFICATE_VERIFY_FAILED');
            }
            return _json(_record());
          });

          expect(await _lrclib(client).fetchLyrics(_track()), _lyrics());
          expect(attempts, 2);
        },
      );

      test('gives up after 10 s and aborts the request', () {
        fakeAsync((async) {
          final triggers = <Future<void>?>[];
          final client = MockClient.streaming((request, bodyStream) {
            triggers.add(
              request is http.Abortable ? request.abortTrigger : null,
            );
            return Completer<http.StreamedResponse>().future;
          });
          Object? failure;
          var aborted = false;

          _lrclib(client)
              .fetchLyrics(_track())
              .then<void>((_) {}, onError: (Object error) => failure = error);
          async.flushMicrotasks();
          triggers.single!.then((_) => aborted = true);

          async.elapse(const Duration(milliseconds: 9999));
          expect(failure, isNull);
          expect(aborted, isFalse);

          async.elapse(const Duration(milliseconds: 1));
          expect(failure, isA<LyricsUnavailable>());
          expect(aborted, isTrue);
        });
      });

      test('sends the SwiftieQuiz User-Agent on every request', () async {
        final server = _lrclibServer(search: (_) => _json([_record()]));

        await _lrclib(server.client).fetchLyrics(_track());

        expect(server.requests, hasLength(2));
        expect(
          server.requests.map((request) => request.headers['user-agent']),
          everyElement(
            'SwiftieQuiz/0.3.0 '
            '(+https://github.com/SatanshuMishra/project-swiftee)',
          ),
        );
      });

      test('serves found lyrics from the cache by track id', () async {
        final server = _lrclibServer(get: (_) => _json(_record()));
        final lrclib = _lrclib(server.client);

        final first = await lrclib.fetchLyrics(_track());
        final second = await lrclib.fetchLyrics(_track());

        expect(second, first);
        expect(server.requests, hasLength(1));
      });

      test('remembers not found for the track id', () async {
        final server = _lrclibServer();
        final lrclib = _lrclib(server.client);

        await expectLater(
          lrclib.fetchLyrics(_track()),
          _throwsLyricsError<LyricsNotFound>(_notFoundMessage),
        );
        await expectLater(
          lrclib.fetchLyrics(_track()),
          _throwsLyricsError<LyricsNotFound>(_notFoundMessage),
        );

        expect(server.requests, hasLength(2));
      });

      test('does not cache a service failure', () async {
        var available = false;
        final server = _lrclibServer(
          get: (_) => available ? _json(_record()) : http.Response('', 502),
        );
        final lrclib = _lrclib(server.client);

        await expectLater(
          lrclib.fetchLyrics(_track()),
          throwsA(isA<LyricsUnavailable>()),
        );
        available = true;

        expect(await lrclib.fetchLyrics(_track()), _lyrics());
        expect(server.requests, hasLength(3));
      });
    });

    group('fetchLyricsBatch', () {
      test('fetches five tracks at a time', () async {
        final events = <String>[];
        var inFlight = 0;
        var peak = 0;
        final client = MockClient((request) async {
          final title = request.url.queryParameters['track_name']!;
          inFlight++;
          peak = math.max(peak, inFlight);
          events.add('start $title');
          await Future<void>.delayed(Duration.zero);
          inFlight--;
          events.add('end $title');
          return _json(_record(trackName: title));
        });
        final tracks = [
          for (var id = 1; id <= 7; id++) _track(id: id, title: 'Song $id'),
        ];

        final results = await _lrclib(client).fetchLyricsBatch(tracks);

        expect(results.keys, unorderedEquals([1, 2, 3, 4, 5, 6, 7]));
        expect(results[6]?.sourceTrack, 'Song 6');
        expect(peak, 5);
        final secondChunkStart = events.indexOf('start Song 6');
        for (var id = 1; id <= 5; id++) {
          expect(events.indexOf('end Song $id'), lessThan(secondChunkStart));
        }
        expect(
          events.indexOf('start Song 7'),
          lessThan(events.indexOf('end Song 6')),
        );
      });

      test('maps each checked track id to its lyrics or null and leaves out '
          'tracks it could not check', () async {
        final server = _lrclibServer(
          get: (request) => switch (request.url.queryParameters['track_name']) {
            'Found' => _json(_record(trackName: 'Found')),
            'Broken' => http.Response('', 500),
            _ => http.Response('', 404),
          },
        );

        final results = await _lrclib(server.client).fetchLyricsBatch([
          _track(id: 1, title: 'Found'),
          _track(id: 2, title: 'Missing'),
          _track(id: 3, title: 'Broken'),
        ]);

        expect(results, {1: _lyrics(sourceTrack: 'Found'), 2: null});
        expect(() => results[4] = null, throwsUnsupportedError);
      });

      test(
        'caches found and not-found results but not service failures',
        () async {
          final server = _lrclibServer(
            get: (request) =>
                switch (request.url.queryParameters['track_name']) {
                  'Found' => _json(_record(trackName: 'Found')),
                  'Broken' => http.Response('', 500),
                  _ => http.Response('', 404),
                },
          );
          final lrclib = _lrclib(server.client);
          final tracks = [
            _track(id: 1, title: 'Found'),
            _track(id: 2, title: 'Missing'),
            _track(id: 3, title: 'Broken'),
          ];

          await lrclib.fetchLyricsBatch(tracks);
          final firstPass = server.requests.length;
          final again = await lrclib.fetchLyricsBatch(tracks);

          expect(again, {1: _lyrics(sourceTrack: 'Found'), 2: null});
          expect(
            server.requests
                .skip(firstPass)
                .map((request) => request.url.queryParameters['track_name']),
            ['Broken', 'Broken'],
          );
          await expectLater(
            lrclib.fetchLyrics(tracks[1]),
            throwsA(isA<LyricsNotFound>()),
          );
          expect(
            await lrclib.fetchLyrics(tracks[0]),
            _lyrics(sourceTrack: 'Found'),
          );
        },
      );

      test('shares its cache with single fetches', () async {
        final server = _lrclibServer(get: (_) => _json(_record()));
        final lrclib = _lrclib(server.client);

        await lrclib.fetchLyrics(_track(id: 4));
        final results = await lrclib.fetchLyricsBatch([_track(id: 4)]);

        expect(results, {4: _lyrics()});
        expect(server.requests, hasLength(1));
      });
    });
  });

  group('lrclib 429 honours retry-after', () {
    test('a 429 with Retry-After 2 waits 2 s then retries once', () {
      fakeAsync((async) {
        final delays = <Duration>[];
        var attempts = 0;
        final server = _lrclibServer(
          get: (_) => ++attempts == 1
              ? _tooManyRequests({'retry-after': '2'})
              : _json(_record()),
        );
        final lrclib = LrclibClient(
          client: server.client,
          userAgent: _userAgent,
          delay: (duration) {
            delays.add(duration);
            return Future<void>.delayed(duration);
          },
          now: () => _fixedNow,
        );
        TrackLyrics? result;

        lrclib.fetchLyrics(_track()).then((lyrics) => result = lyrics);

        async.elapse(const Duration(milliseconds: 1999));
        expect(server.requests, hasLength(1));
        expect(result, isNull);

        async.elapse(const Duration(milliseconds: 1));
        expect(delays, [const Duration(seconds: 2)]);
        expect(server.requests, hasLength(2));
        expect(server.requests.last.url, server.requests.first.url);
        expect(result, _lyrics());
      });
    });

    test('a second 429 fails with LyricsUnavailable', () async {
      final delays = <Duration>[];
      final server = _lrclibServer(
        get: (_) => _tooManyRequests({'retry-after': '2'}),
        search: (_) => _json([_record()]),
      );

      await expectLater(
        _lrclib(server.client, delays: delays).fetchLyrics(_track()),
        _throwsLyricsError<LyricsUnavailable>(_unavailableMessage),
      );

      expect(delays, [const Duration(seconds: 2)]);
      expect(server.requests.map((request) => request.url.path), [
        '/api/get',
        '/api/get',
      ]);
    });

    test('a 429 without Retry-After waits 1 s', () async {
      final delays = <Duration>[];
      var attempts = 0;
      final server = _lrclibServer(
        get: (_) => ++attempts == 1 ? _tooManyRequests() : _json(_record()),
      );

      await _lrclib(server.client, delays: delays).fetchLyrics(_track());

      expect(delays, [const Duration(seconds: 1)]);
    });

    test('a Retry-After above 10 is capped at 10 s', () async {
      for (final header in ['11', '120', '99999999999999999999999']) {
        final delays = <Duration>[];
        var attempts = 0;
        final server = _lrclibServer(
          get: (_) => ++attempts == 1
              ? _tooManyRequests({'retry-after': header})
              : _json(_record()),
        );

        await _lrclib(server.client, delays: delays).fetchLyrics(_track());

        expect(delays, [const Duration(seconds: 10)], reason: header);
      }
    });

    test('an HTTP-date Retry-After waits until that time', () async {
      for (final (offset, expected) in [
        (const Duration(seconds: 3), const Duration(seconds: 3)),
        (const Duration(minutes: 5), const Duration(seconds: 10)),
        (const Duration(seconds: -30), Duration.zero),
      ]) {
        final delays = <Duration>[];
        var attempts = 0;
        final server = _lrclibServer(
          get: (_) => ++attempts == 1
              ? _tooManyRequests({
                  'retry-after': HttpDate.format(_fixedNow.add(offset)),
                })
              : _json(_record()),
        );

        await _lrclib(server.client, delays: delays).fetchLyrics(_track());

        expect(delays, [expected], reason: '$offset');
      }
    });

    test('an unreadable Retry-After waits 1 s', () async {
      for (final header in ['soon', '-5', '2.5', '']) {
        final delays = <Duration>[];
        var attempts = 0;
        final server = _lrclibServer(
          get: (_) => ++attempts == 1
              ? _tooManyRequests({'retry-after': header})
              : _json(_record()),
        );

        await _lrclib(server.client, delays: delays).fetchLyrics(_track());

        expect(delays, [const Duration(seconds: 1)], reason: header);
      }
    });

    test('a 429 on /search is retried once too', () async {
      final delays = <Duration>[];
      var attempts = 0;
      final server = _lrclibServer(
        search: (_) => ++attempts == 1
            ? _tooManyRequests({'retry-after': '3'})
            : _json([_record(id: 5)]),
      );

      final lyrics = await _lrclib(
        server.client,
        delays: delays,
      ).fetchLyrics(_track());

      expect(lyrics.lrclibId, 5);
      expect(delays, [const Duration(seconds: 3)]);
      expect(server.requests.map((request) => request.url.path), [
        '/api/get',
        '/api/search',
        '/api/search',
      ]);
    });

    test('a retried 404 continues to search', () async {
      var attempts = 0;
      final server = _lrclibServer(
        get: (_) =>
            ++attempts == 1 ? _tooManyRequests() : http.Response('', 404),
        search: (_) => _json([_record(id: 6)]),
      );

      final lyrics = await _lrclib(server.client).fetchLyrics(_track());

      expect(lyrics.lrclibId, 6);
    });

    test('a batch leaves out a track still limited after the retry and '
        'checks it again later', () async {
      var limited = true;
      final server = _lrclibServer(
        get: (_) => limited ? _tooManyRequests() : _json(_record()),
      );
      final lrclib = _lrclib(server.client);

      expect(await lrclib.fetchLyricsBatch([_track()]), isEmpty);
      limited = false;

      expect(await lrclib.fetchLyricsBatch([_track()]), {1: _lyrics()});
    });
  });
}
