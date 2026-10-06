import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_store.dart';
import 'package:swiftie_quiz/domain/engine/catalogue_rules.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/era.dart';

void main() {
  late Catalogue catalogue;

  setUpAll(() {
    catalogue = buildCatalogue(
      decodeCatalogue(File(bundledCataloguePath).readAsStringSync()),
    );
  });

  CatalogueRelease release(String title) =>
      catalogue.releases.firstWhere((release) => release.title == title);

  group('catalogue releases', () {
    test('lists every release with something to play, under its era', () {
      final eraKeys = {for (final era in eraGroups) era.key};

      expect(catalogue.releases, hasLength(97));
      for (final release in catalogue.releases) {
        expect(release.tracks, isNotEmpty, reason: release.title);
        expect(eraKeys, contains(release.eraKey), reason: release.title);
        expect(release.year, matches(RegExp(r'^\d{4}$')));
      }
    });

    test('a release holds the recordings on it, wherever they belong', () {
      final playlist = release(
        'reputation Stadium Tour Surprise Song Playlist',
      );
      final ids = {for (final track in catalogue.allTracks) track.id};

      expect(playlist.eraKey, 'rep');
      expect(playlist.tracks, hasLength(42));
      expect(
        playlist.tracks.where((track) => track.eraKey != 'rep'),
        hasLength(41),
      );
      expect(playlist.tracks.every((track) => ids.contains(track.id)), isTrue);
    });

    test('picking a release adds its recordings to the picked eras', () {
      final folklore = release('folklore');
      final red = catalogue.tracksFor(['red']);

      final picked = catalogue.tracksFor(['red'], releaseIds: [folklore.id]);

      expect(picked, hasLength(red.length + folklore.tracks.length));
      expect(picked.toSet(), {...red, ...folklore.tracks});
    });

    test('a recording on a picked release and a picked era counts once', () {
      final lover = release('Lover');

      final picked = catalogue.tracksFor(['lover'], releaseIds: [lover.id]);

      expect(picked, catalogue.tracksFor(['lover']));
    });

    test('a release alone plays only its own recordings', () {
      final playlist = release(
        'reputation Stadium Tour Surprise Song Playlist',
      );

      final picked = catalogue.tracksFor(const [], releaseIds: [playlist.id]);

      expect(picked.toSet(), playlist.tracks.toSet());
      expect(picked.length, playlist.tracks.length);
    });
  });
}
