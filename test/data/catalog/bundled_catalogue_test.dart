import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_store.dart';
import 'package:swiftie_quiz/domain/engine/answer_matcher.dart';
import 'package:swiftie_quiz/domain/engine/catalogue_rules.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/era.dart';

void main() {
  late List<RawRelease> releases;
  late Catalogue catalogue;

  setUpAll(() {
    releases = decodeCatalogue(File(bundledCataloguePath).readAsStringSync());
    catalogue = buildCatalogue(releases);
  });

  List<String> songsIn(String eraKey) => [
    for (final track in catalogue.tracksFor([eraKey]))
      normalizeTitle(track.title),
  ];

  test('the bundled catalogue holds every release Deezer listed', () {
    expect(releases.length, greaterThanOrEqualTo(118));
    expect(
      releases.where((release) => release.kind == ReleaseKind.album).length,
      greaterThanOrEqualTo(34),
    );
  });

  test('every era tile has music and every recording sits in exactly one', () {
    for (final era in eraGroups) {
      expect(catalogue.trackCount(era.key), isPositive, reason: era.eraName);
    }
    final total = eraGroups.fold(
      0,
      (sum, era) => sum + catalogue.trackCount(era.key),
    );
    expect(total, catalogue.recordings.length);
  });

  test('every playable recording is led by Taylor', () {
    final led = {
      for (final release in releases)
        for (final track in release.tracks)
          if (isPlayableRecording(track)) track.id,
    };
    expect(
      catalogue.allTracks.every((track) => led.contains(track.id)),
      isTrue,
    );
  });

  test('the songs that motivated the catalogue are all reachable', () {
    expect(
      songsIn('showgirl'),
      containsAll(['babylon', 'patient zero', 'cleveland', 'pink clouding']),
    );
    expect(songsIn('showgirl'), contains('the life of a showgirl'));
    expect(songsIn(singlesEra.key), contains('i knew it i knew you'));
    expect(songsIn('red'), contains('all too well'));
    final redTracks = [
      for (final track in catalogue.tracksFor(['red'])) track.title,
    ];
    expect(
      redTracks,
      contains(
        "All Too Well (10 Minute Version) (Taylor's Version) (From The Vault)",
      ),
    );
    final loveStories = [
      for (final track in catalogue.tracksFor(['fearless']))
        if (normalizeTitle(track.title) == 'love story') track.title,
    ];
    expect(loveStories, contains('Love Story'));
    expect(
      loveStories.where(
        (title) => RegExp("Taylor['’]s Version").hasMatch(title),
      ),
      isNotEmpty,
    );
  });
}
