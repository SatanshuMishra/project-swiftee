import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/http_identity.dart';
import 'package:swiftie_quiz/data/lyrics/danger_zones.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';

final String _userAgent = appUserAgent('0.3.0');

http.Response _json(Object? body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: const {'content-type': 'application/json'},
);

List<LrcLine> _makeLines(List<(double, String)> entries) => [
  for (final (timeSeconds, text) in entries)
    LrcLine(timeSeconds: timeSeconds, text: text),
];

void main() {
  group('danger zones parity', () {
    group('parseLrc', () {
      test('parses standard LRC lines with centiseconds', () {
        final result = parseLrc(
          '[00:12.34] Hello world\n[01:05.67] Second line',
        );
        expect(result, hasLength(2));
        expect(result[0].timeSeconds, closeTo(12.34, 0.05));
        expect(result[0].text, 'Hello world');
        expect(result[1].timeSeconds, closeTo(65.67, 0.05));
        expect(result[1].text, 'Second line');
      });

      test('parses lines with two-digit centiseconds', () {
        final result = parseLrc('[00:27.93] Some lyric text');
        expect(result, hasLength(1));
        expect(result[0].timeSeconds, closeTo(27.93, 0.05));
      });

      test('parses lines without centiseconds', () {
        final result = parseLrc('[02:30] No decimals here');
        expect(result, hasLength(1));
        expect(result[0].timeSeconds, 150);
      });

      test('skips empty text lines', () {
        final result = parseLrc('[00:00.00]   \n[00:05.00] Real line');
        expect(result, hasLength(1));
        expect(result[0].text, 'Real line');
      });

      test('sorts lines by time', () {
        final result = parseLrc('[01:00.00] Later\n[00:30.00] Earlier');
        expect(result[0].text, 'Earlier');
        expect(result[1].text, 'Later');
      });

      test('handles empty string', () {
        expect(parseLrc(''), isEmpty);
      });

      test('handles three-digit milliseconds', () {
        final result = parseLrc('[00:10.123] Three digit');
        expect(result[0].timeSeconds, closeTo(10.123, 0.005));
      });

      test('handles single-digit minutes', () {
        final result = parseLrc('[3:45.00] Single digit minute');
        expect(result[0].timeSeconds, closeTo(225, 0.5));
      });

      test('keeps lines with equal timestamps in source order', () {
        final result = parseLrc(
          '[00:20.00] Second\n[00:10.00] First a\n[00:10.00] First b',
        );
        expect(result.map((line) => line.text), [
          'First a',
          'First b',
          'Second',
        ]);
      });
    });

    group('estimatePreviewOffset', () {
      test('returns 30% of duration when fewer than 4 lines', () {
        final lines = _makeLines([(10, 'Line one'), (20, 'Line two')]);
        expect(estimatePreviewOffset(lines, 200), 60);
      });

      test('returns 30% when no repeated lines found', () {
        final lines = _makeLines([
          (10, 'Unique line one here'),
          (20, 'Unique line two here'),
          (30, 'Unique line three here'),
          (40, 'Unique line four here'),
        ]);
        expect(estimatePreviewOffset(lines, 200), 60);
      });

      test('finds first repeated line as chorus start', () {
        final lines = _makeLines([
          (10, 'Verse one is here now'),
          (20, 'This is the chorus line'),
          (30, 'Verse two is here now'),
          (40, 'This is the chorus line'),
        ]);
        expect(estimatePreviewOffset(lines, 200), 18);
      });

      test('clamps offset to 0 if chorus is very early', () {
        final lines = _makeLines([
          (1, 'Opening chorus repeated'),
          (5, 'Some verse lyric here'),
          (10, 'Another verse line here'),
          (15, 'Opening chorus repeated'),
        ]);
        expect(estimatePreviewOffset(lines, 200), 0);
      });

      test('skips short lines when detecting chorus', () {
        final lines = _makeLines([
          (10, 'Oh oh'),
          (20, 'A longer meaningful verse'),
          (30, 'Oh oh'),
          (40, 'Another meaningful verse'),
        ]);
        expect(estimatePreviewOffset(lines, 200), 60);
      });
    });

    group('findTitleDangerZones', () {
      test('creates danger zones for lines containing title words', () {
        final lines = _makeLines([
          (65, 'Verse words here'),
          (70, 'I am enchanted to meet you'),
          (75, 'More lyrics follow'),
        ]);
        final zones = findTitleDangerZones(lines, 'Enchanted', 'Enchanted', 60);
        expect(zones, isNotEmpty);
        expect(zones[0].start, closeTo(8.5, 0.05));
        expect(zones[0].end, closeTo(11.5, 0.05));
      });

      test('returns empty when no title words match', () {
        final lines = _makeLines([
          (65, 'Some random words'),
          (70, 'Nothing related here'),
        ]);
        final zones = findTitleDangerZones(lines, 'Enchanted', 'Enchanted', 60);
        expect(zones, isEmpty);
      });

      test('ignores lines outside the preview window', () {
        final lines = _makeLines([
          (10, 'Enchanted early on'),
          (100, 'Enchanted way late'),
        ]);
        final zones = findTitleDangerZones(lines, 'Enchanted', 'Enchanted', 60);
        expect(zones, isEmpty);
      });

      test('merges overlapping danger zones', () {
        final lines = _makeLines([
          (70, 'Anti hero in the mirror'),
          (71, "I'm the anti hero now"),
        ]);
        final zones = findTitleDangerZones(lines, 'Anti-Hero', 'Anti-Hero', 60);
        expect(zones, hasLength(1));
        expect(zones.single, const DangerZone(start: 8.5, end: 12.5));
      });

      test('clamps zones to preview boundaries (0-30)', () {
        final lines = _makeLines([(60.5, 'Enchanted right at start')]);
        final zones = findTitleDangerZones(lines, 'Enchanted', 'Enchanted', 60);
        expect(zones, hasLength(1));
        expect(zones[0].start, 0);
      });

      test('clamps zone end to the 30 s preview length', () {
        final lines = _makeLines([(89.5, 'Enchanted right at the end')]);
        final zones = findTitleDangerZones(lines, 'Enchanted', 'Enchanted', 60);
        expect(zones.single.end, 30);
      });

      test('filters stop words from title matching', () {
        final lines = _makeLines([(65, 'Look at all the stars tonight')]);
        final zones = findTitleDangerZones(
          lines,
          'All The Stars',
          'All The Stars',
          60,
        );
        expect(zones, isNotEmpty);
      });

      test('ignores every stop word when counting title words', () {
        const stopWords = [
          'the',
          'an',
          'me',
          'my',
          'you',
          'your',
          'we',
          'our',
          'it',
          'its',
          'is',
          'am',
          'are',
          'was',
          'were',
          'be',
          'been',
          'do',
          'did',
          'to',
          'of',
          'in',
          'on',
          'at',
          'for',
          'and',
          'or',
          'so',
          'no',
          'not',
          'but',
          'if',
          'up',
          'out',
          'all',
          'just',
          'like',
          'this',
          'that',
          'with',
          'from',
        ];
        for (final word in stopWords) {
          final zones = findTitleDangerZones(
            _makeLines([(65, 'Stars')]),
            '$word Stars',
            '$word Stars',
            60,
          );
          expect(zones, isNotEmpty, reason: word);
        }
      });

      test('requires 60% of meaningful title words', () {
        final zones = findTitleDangerZones(
          _makeLines([(65, 'Stars')]),
          'Bright Stars',
          'Bright Stars',
          60,
        );
        expect(zones, isEmpty);
      });

      test('uses titleShort when it has more meaningful words', () {
        final lines = _makeLines([(70, 'I keep enchanted feelings')]);
        final zones = findTitleDangerZones(
          lines,
          "Enchanted (Taylor's Version)",
          'Enchanted',
          60,
        );
        expect(zones, isNotEmpty);
      });

      test('handles multi-word title matching with 60% threshold', () {
        final lines = _makeLines([
          (70, 'We are never ever getting back together now'),
        ]);
        final zones = findTitleDangerZones(
          lines,
          'We Are Never Getting Back Together',
          'We Are Never Getting Back Together',
          60,
        );
        expect(zones, isNotEmpty);
      });

      test('keeps separate zones apart when they do not overlap', () {
        final lines = _makeLines([
          (65, 'Enchanted once'),
          (80, 'Enchanted twice'),
        ]);
        final zones = findTitleDangerZones(lines, 'Enchanted', 'Enchanted', 60);
        expect(zones, const [
          DangerZone(start: 3.5, end: 6.5),
          DangerZone(start: 18.5, end: 21.5),
        ]);
      });
    });

    group('fetchDangerZones', () {
      test('returns cached result on second call', () async {
        var calls = 0;
        final service = DangerZoneService(
          client: MockClient((request) async {
            calls++;
            return _json({
              'syncedLyrics':
                  '[00:10.00] Some lyrics here\n[00:20.00] More lyrics',
            });
          }),
          userAgent: _userAgent,
        );

        await service.fetchDangerZones(
          'Enchanted',
          'Taylor Swift',
          'Enchanted',
          300,
        );
        await service.fetchDangerZones(
          'Enchanted',
          'Taylor Swift',
          'Enchanted',
          300,
        );

        expect(calls, 1);
      });

      test('returns empty array on non-ok response', () async {
        final service = DangerZoneService(
          client: MockClient((request) async => http.Response('', 404)),
          userAgent: _userAgent,
        );

        final result = await service.fetchDangerZones(
          'Unknown Song',
          'Unknown Artist',
          'Unknown Song',
          200,
        );
        expect(result, isEmpty);
      });

      test('returns empty array when syncedLyrics is null', () async {
        final service = DangerZoneService(
          client: MockClient((request) async => _json({'syncedLyrics': null})),
          userAgent: _userAgent,
        );

        final result = await service.fetchDangerZones(
          'Some Song',
          'Some Artist',
          'Some Song',
          200,
        );
        expect(result, isEmpty);
      });

      test('returns empty array on network error', () async {
        final service = DangerZoneService(
          client: MockClient(
            (request) async => throw http.ClientException('Network error'),
          ),
          userAgent: _userAgent,
        );

        final result = await service.fetchDangerZones(
          'Test Song',
          'Test Artist',
          'Test Song',
          200,
        );
        expect(result, isEmpty);
      });

      test('returns empty array on abort (timeout)', () async {
        final service = DangerZoneService(
          client: MockClient(
            (request) async => throw http.RequestAbortedException(request.url),
          ),
          userAgent: _userAgent,
        );

        final result = await service.fetchDangerZones(
          'Slow Song',
          'Slow Artist',
          'Slow Song',
          200,
        );
        expect(result, isEmpty);
      });

      test('returns empty array on a malformed body', () async {
        final service = DangerZoneService(
          client: MockClient((request) async => http.Response('{oops', 200)),
          userAgent: _userAgent,
        );

        final result = await service.fetchDangerZones(
          'Broken Song',
          'Broken Artist',
          'Broken Song',
          200,
        );
        expect(result, isEmpty);
      });

      test('builds correct URL with query params', () async {
        final requested = <http.Request>[];
        final service = DangerZoneService(
          client: MockClient((request) async {
            requested.add(request);
            return _json({'syncedLyrics': null});
          }),
          userAgent: _userAgent,
        );

        await service.fetchDangerZones(
          'Anti-Hero',
          'Taylor Swift',
          'Anti-Hero',
          200,
        );

        final calledUrl = requested.single.url.toString();
        expect(calledUrl, contains('lrclib.net/api/get?'));
        expect(calledUrl, contains('artist_name=Taylor+Swift'));
        expect(calledUrl, contains('track_name=Anti-Hero'));
        expect(requested.single.url.scheme, 'https');
      });

      test('sends the SwiftieQuiz User-Agent', () async {
        final userAgents = <String?>[];
        final service = DangerZoneService(
          client: MockClient((request) async {
            userAgents.add(request.headers['user-agent']);
            return _json({'syncedLyrics': null});
          }),
          userAgent: _userAgent,
        );

        await service.fetchDangerZones('Test', 'Artist', 'Test', 200);

        expect(userAgents, [
          'SwiftieQuiz/0.3.0 (+https://github.com/SatanshuMishra/project-swiftee)',
        ]);
      });

      test('uses AbortController signal', () {
        fakeAsync((async) {
          final triggers = <Future<void>?>[];
          final service = DangerZoneService(
            client: MockClient.streaming((request, bodyStream) {
              triggers.add(
                request is http.Abortable ? request.abortTrigger : null,
              );
              return Completer<http.StreamedResponse>().future;
            }),
            userAgent: _userAgent,
          );
          var aborted = false;
          List<DangerZone>? result;

          service
              .fetchDangerZones('Test', 'Artist', 'Test', 200)
              .then((zones) => result = zones);
          async.flushMicrotasks();
          expect(triggers.single, isNotNull);
          triggers.single!.then((_) => aborted = true);

          async.elapse(const Duration(milliseconds: 1999));
          expect(aborted, isFalse);
          expect(result, isNull);

          async.elapse(const Duration(milliseconds: 1));
          expect(aborted, isTrue);
          expect(result, isEmpty);
        });
      });

      test('computes zones from synced lyrics', () async {
        final service = DangerZoneService(
          client: MockClient(
            (request) async => _json({
              'syncedLyrics': [
                '[00:10.00] Verse words go here',
                '[00:20.00] There is a chorus that repeats',
                '[00:25.00] I was enchanted to meet you',
                '[00:30.00] Second verse words now',
                '[00:40.00] There is a chorus that repeats',
              ].join('\n'),
            }),
          ),
          userAgent: _userAgent,
        );

        final result = await service.fetchDangerZones(
          'Enchanted',
          'Taylor Swift',
          'Enchanted',
          240,
        );

        expect(result, const [DangerZone(start: 5.5, end: 8.5)]);
      });

      test('shares a cache entry across letter case', () async {
        var calls = 0;
        final service = DangerZoneService(
          client: MockClient((request) async {
            calls++;
            return _json({'syncedLyrics': null});
          }),
          userAgent: _userAgent,
        );

        await service.fetchDangerZones('Enchanted', 'Taylor Swift', 'E', 200);
        await service.fetchDangerZones('ENCHANTED', 'taylor swift', 'E', 200);

        expect(calls, 1);
      });

      test('keeps at most 100 entries and evicts the oldest', () async {
        final requestedTitles = <String>[];
        final service = DangerZoneService(
          client: MockClient((request) async {
            requestedTitles.add(request.url.queryParameters['track_name']!);
            return _json({'syncedLyrics': null});
          }),
          userAgent: _userAgent,
        );

        for (var i = 0; i <= 100; i++) {
          await service.fetchDangerZones('Song $i', 'Artist', 'Song $i', 200);
        }
        expect(requestedTitles, hasLength(101));

        await service.fetchDangerZones('Song 1', 'Artist', 'Song 1', 200);
        expect(requestedTitles, hasLength(101));

        await service.fetchDangerZones('Song 0', 'Artist', 'Song 0', 200);
        expect(requestedTitles, hasLength(102));
        expect(requestedTitles.last, 'Song 0');
      });

      test('clearDangerZoneCache forgets cached results', () async {
        var calls = 0;
        final service = DangerZoneService(
          client: MockClient((request) async {
            calls++;
            return _json({'syncedLyrics': null});
          }),
          userAgent: _userAgent,
        );

        await service.fetchDangerZones('Test', 'Artist', 'Test', 200);
        service.clearDangerZoneCache();
        await service.fetchDangerZones('Test', 'Artist', 'Test', 200);

        expect(calls, 2);
      });
    });
  });
}
