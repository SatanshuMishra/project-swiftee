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

    test('fetches only releases it has not seen and keeps them', () async {
      final requested = <String>[];
      final client = DeezerClient(
        client: MockClient((request) async {
          requested.add(request.url.path);
          final body = switch (request.url.path) {
            '/artist/12246/albums' => {
              'data': [
                {
                  'id': 1103662682,
                  'title': 'The Life of a Showgirl: The Encore',
                  'record_type': 'album',
                  'release_date': '2026-09-25',
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
            },
            '/album/1103662682/tracks' => {
              'data': [deezerTrack(72, 'Babylon', isrc: 'SG02')],
            },
            _ => {
              'error': {'message': 'unexpected ${request.url}'},
            },
          };
          return http.Response(jsonEncode(body), 200);
        }),
        userAgent: 'test',
      );

      final added = await store().addNewReleases(client, {130721292});

      expect(added.map((release) => release.id), [1103662682]);
      expect(added.single.tracks.single.title, 'Babylon');
      expect(requested, ['/artist/12246/albums', '/album/1103662682/tracks']);
      final reloaded = await store().load();
      expect(reloaded.map((release) => release.id), [130721292, 1103662682]);
    });
  });
}
