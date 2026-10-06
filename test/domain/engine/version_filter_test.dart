import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_store.dart';
import 'package:swiftie_quiz/domain/engine/catalogue_rules.dart';
import 'package:swiftie_quiz/domain/engine/play_order.dart';
import 'package:swiftie_quiz/domain/engine/version_filter.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/util/song_title.dart';

void main() {
  late Catalogue catalogue;

  setUpAll(() {
    catalogue = buildCatalogue(
      decodeCatalogue(File(bundledCataloguePath).readAsStringSync()),
    );
  });

  group('which versions', () {
    test('every version keeps the pick as it is', () {
      final pick = catalogue.tracksFor(['red']);

      expect(keepVersions(pick, TrackVersions.every), same(pick));
    });

    test("taylor's version drops the originals she re-recorded", () {
      final all = catalogue.allTracks;
      final kept = keepVersions(all, TrackVersions.taylorsVersion);
      final rerecorded = {
        for (final track in all)
          if (isTaylorsVersion(track.title)) songKey(track),
      };

      expect(all.length - kept.length, 98);
      for (final track in kept) {
        expect(
          isTaylorsVersion(track.title) || !rerecorded.contains(songKey(track)),
          isTrue,
          reason: track.title,
        );
      }
      expect(
        {for (final track in kept) songKey(track)},
        {for (final track in all) songKey(track)},
      );
    });

    test("taylor's version keeps originals a pick has no re-recording of", () {
      final red = catalogue.releases.firstWhere(
        (release) => release.title == 'Red',
      );

      expect(
        keepVersions(red.tracks, TrackVersions.taylorsVersion),
        red.tracks,
      );
    });

    test('no live takes drops live and Long Pond recordings', () {
      final all = catalogue.allTracks;
      final kept = keepVersions(all, TrackVersions.noLive);

      expect(all.length - kept.length, 53);
      expect(kept.where((track) => isLiveTake(track.title)), isEmpty);
      expect(
        kept.map((track) => track.title),
        containsAll(['Long Live', "Long Live (Taylor's Version)"]),
      );
    });
  });
}
