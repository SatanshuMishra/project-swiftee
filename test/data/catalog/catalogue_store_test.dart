import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_store.dart';
import 'package:swiftie_quiz/data/catalog/deezer_client.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';

import '../../fixtures/catalogue_fixture.dart';

Map<String, Object?> deezerTrack(int id, String title, {String isrc = 'X'}) => {
  'id': id,
  'title': title,
  'title_short': title,
  'title_version': '',
  'duration': 210,
  'isrc': isrc,
  'preview': 'https://cdnt-preview.dzcdn.net/$id.mp3',
  'artist': {'id': taylor, 'name': 'Taylor Swift'},
};

void main() {
  late Directory folder;
  final bundled = [fixtureReleases.first];

  setUp(() => folder = Directory.systemTemp.createTempSync('catalogue'));
  tearDown(() => folder.deleteSync(recursive: true));

  CatalogueStore store() => CatalogueStore(
    loadBundled: () async =>
        encodeCatalogue(bundled, fetchedAt: '2026-10-06T00:00:00Z'),
    updatesFile: File('${folder.path}/$catalogueUpdatesFileName'),
    now: () => DateTime.utc(2026, 10, 6),
  );

  group('catalogue json', () {
    test('a catalogue survives encoding and decoding', () {
      final text = encodeCatalogue(
        fixtureReleases,
        fetchedAt: '2026-10-06T00:00:00Z',
      );
      expect(decodeCatalogue(text), fixtureReleases);
    });

    test('Deezer release and track items become raw releases and tracks', () {
      final release = parseReleaseSummary({
        'id': 1103662682,
        'title': 'The Life of a Showgirl: The Encore',
        'record_type': 'album',
        'release_date': '2026-09-25',
        'cover_medium': 'https://cover.test/encore.jpg',
      });
      expect(release.kind, ReleaseKind.album);
      expect(release.tracks, isEmpty);
      final track = parseRawTrack(deezerTrack(72, 'Babylon', isrc: 'SG02'));
      expect(track.isrc, 'SG02');
      expect(track.artistId, taylor);
      expect(track.hasPreview, isTrue);
    });
  });

  group('catalogue store', () {
    test('loads the bundled catalogue when nothing new was found', () async {
      expect(await store().load(), bundled);
    });

    test(
      'a release the app now bundles replaces the copy kept on disk',
      () async {
        final updates = File('${folder.path}/$catalogueUpdatesFileName');
        final stale = fixtureReleases.first.copyWith(
          tracks: [
            rawTrack(1, 'State Of Grace', isrc: 'RED01', preview: false),
          ],
        );
        final newer = rawRelease(1103662682, 'The Encore', '2026-09-25', [
          rawTrack(72, 'Babylon', isrc: 'SG02'),
        ]);
        updates.writeAsStringSync(
          encodeCatalogue([stale, newer], fetchedAt: '2026-10-01T00:00:00Z'),
        );

        final loaded = await store().load();

        expect(loaded, [...bundled, newer]);
        expect(decodeCatalogue(updates.readAsStringSync()), [newer]);
      },
    );

    DeezerClient deezer(
      List<Map<String, Object?>> summaries,
      Map<int, List<Map<String, Object?>>> tracks, {
      Set<int> failing = const {},
      List<String>? requested,
    }) => DeezerClient(
      client: MockClient((request) async {
        requested?.add(request.url.path);
        final path = request.url.path;
        final albumId = int.tryParse(
          RegExp(r'^/album/(\d+)/tracks$').firstMatch(path)?[1] ?? '',
        );
        final body = switch (path) {
          '/artist/12246/albums' => {'data': summaries},
          _ when failing.contains(albumId) => {
            'error': {'message': 'unavailable'},
          },
          _ when tracks.containsKey(albumId) => {'data': tracks[albumId]},
          _ => {
            'error': {'message': 'unexpected ${request.url}'},
          },
        };
        return http.Response(jsonEncode(body), 200);
      }),
      userAgent: 'test',
    );

    Map<String, Object?> summary(int id, String title, String date) => {
      'id': id,
      'title': title,
      'record_type': 'album',
      'release_date': date,
      'cover_medium': null,
    };

    final known = {for (final release in bundled) release.id: release};

    test('fetches every release it has not seen, however many, and keeps '
        'them', () async {
      final requested = <String>[];
      final client = deezer(
        [
          for (var id = 1; id <= 12; id++)
            summary(5000 + id, 'Single $id', '2020-01-$id'.padLeft(10, '0')),
          summary(130721292, 'Red', '2012-10-22'),
        ],
        {
          for (var id = 1; id <= 12; id++)
            5000 + id: [deezerTrack(6000 + id, 'Song $id', isrc: 'S$id')],
        },
        requested: requested,
      );

      final changed = await store().refreshReleases(client, known);

      expect(changed, hasLength(12));
      expect(requested, isNot(contains('/album/130721292/tracks')));
      final reloaded = await store().load();
      expect(reloaded.first.id, 130721292);
      expect(reloaded.skip(1).map((release) => release.id), [
        for (var id = 1; id <= 12; id++) 5000 + id,
      ]);
    });

    test('fetches a release from the last 90 days again and keeps tracks '
        'Deezer added to it, but leaves older releases alone', () async {
      final recent = rawRelease(1103662682, 'The Encore', '2026-09-25', [
        rawTrack(72, 'Babylon', isrc: 'SG02'),
      ]);
      final client = deezer(
        [
          summary(1103662682, 'The Encore', '2026-09-25'),
          summary(130721292, 'Red', '2012-10-22'),
        ],
        {
          1103662682: [
            deezerTrack(72, 'Babylon', isrc: 'SG02'),
            deezerTrack(73, 'Bonus Song', isrc: 'SG03'),
          ],
        },
      );

      final changed = await store().refreshReleases(client, {
        ...known,
        recent.id: recent,
      });

      expect(changed.single.tracks.map((track) => track.title), [
        'Babylon',
        'Bonus Song',
      ]);
    });

    test('an unchanged recent release is not written again', () async {
      final encore = summary(1103662682, 'The Encore', '2026-09-25');
      final babylon = deezerTrack(72, 'Babylon', isrc: 'SG02');
      final client = deezer(
        [encore],
        {
          1103662682: [babylon],
        },
      );

      final changed = await store().refreshReleases(client, {
        ...known,
        1103662682: parseReleaseSummary(encore)
            .copyWith(tracks: [parseRawTrack(babylon)]),
      });

      expect(changed, isEmpty);
      expect(
        File('${folder.path}/$catalogueUpdatesFileName').existsSync(),
        isFalse,
      );
    });

    test('a release that fails to load keeps the ones fetched before it, '
        'and the next check picks it up', () async {
      final client = deezer(
        [
          summary(5001, 'First', '2020-01-01'),
          summary(5002, 'Broken', '2020-01-02'),
          summary(5003, 'Third', '2020-01-03'),
        ],
        {
          5001: [deezerTrack(6001, 'One', isrc: 'S1')],
          5003: [deezerTrack(6003, 'Three', isrc: 'S3')],
        },
        failing: {5002},
      );

      final changed = await store().refreshReleases(client, known);

      expect(changed.map((release) => release.id), [5001]);
      final reloaded = await store().load();
      expect(reloaded.map((release) => release.id), [130721292, 5001]);
    });

    test('a bundled release fetched again since the bundle was built uses '
        'the newer copy', () async {
      final updates = File('${folder.path}/$catalogueUpdatesFileName');
      final grown = fixtureReleases.first.copyWith(
        tracks: [
          ...fixtureReleases.first.tracks,
          rawTrack(9, 'A Song Deezer Added', isrc: 'RED09'),
        ],
      );
      updates.writeAsStringSync(
        encodeCatalogueEntries([
          (release: grown, fetchedAt: DateTime.utc(2026, 10, 7)),
        ], fetchedAt: DateTime.utc(2026, 10, 7)),
      );

      final loaded = await store().load();

      expect(loaded, [grown]);
      expect(decodeCatalogue(updates.readAsStringSync()), [grown]);
    });

    test('an updates file from v0.4 without per-release times uses its '
        'file time', () {
      final text = encodeCatalogue(bundled, fetchedAt: '2026-10-01T00:00:00Z');

      expect(
        decodeCatalogueEntries(text).single.fetchedAt,
        DateTime.utc(2026, 10, 1),
      );
    });
  });

  test('a check fetches at most 25 releases, unknown ones before recent '
      'ones it has seen', () async {
    final requested = <String>[];
    final summaries = [
      for (var id = 1; id <= 30; id++)
        {
          'id': 7000 + id,
          'title': 'New $id',
          'record_type': 'single',
          'release_date': '2020-01-01',
          'cover_medium': null,
        },
      {
        'id': 1103662682,
        'title': 'The Encore',
        'record_type': 'album',
        'release_date': '2026-09-25',
        'cover_medium': null,
      },
    ];
    final client = DeezerClient(
      client: MockClient((request) async {
        requested.add(request.url.path);
        final id = RegExp(r'^/album/(\d+)/tracks$')
            .firstMatch(request.url.path)?[1];
        return http.Response(
          jsonEncode(
            request.url.path == '/artist/12246/albums'
                ? {'data': summaries}
                : {
                    'data': [deezerTrack(int.parse(id!), 'Song $id')],
                  },
          ),
          200,
        );
      }),
      userAgent: 'test',
    );
    final store = CatalogueStore(
      loadBundled: () async =>
          encodeCatalogue(bundled, fetchedAt: '2026-10-06T00:00:00Z'),
      updatesFile: File('${folder.path}/$catalogueUpdatesFileName'),
      now: () => DateTime.utc(2026, 10, 6),
    );

    final changed = await store.refreshReleases(client, {
      for (final release in bundled) release.id: release,
      1103662682: rawRelease(1103662682, 'The Encore', '2026-09-25', const []),
    });

    expect(changed, hasLength(CatalogueStore.releasesPerCheck));
    expect(changed.map((release) => release.id), [
      for (var id = 1; id <= 25; id++) 7000 + id,
    ]);
    expect(requested, isNot(contains('/album/1103662682/tracks')));
  });

  test(
    'a v0.4 updates file never overrides a release the app now bundles',
    () async {
      final updates = File('${folder.path}/$catalogueUpdatesFileName');
      final stale = fixtureReleases.first.copyWith(
        tracks: [rawTrack(1, 'State Of Grace', isrc: 'RED01', preview: false)],
      );
      updates.writeAsStringSync(
        encodeCatalogue([stale], fetchedAt: '2026-10-10T00:00:00Z'),
      );
      final store = CatalogueStore(
        loadBundled: () async =>
            encodeCatalogue(bundled, fetchedAt: '2026-10-07T00:00:00Z'),
        updatesFile: updates,
        now: () => DateTime.utc(2026, 10, 11),
      );

      expect(await store.load(), bundled);
    },
  );
}
