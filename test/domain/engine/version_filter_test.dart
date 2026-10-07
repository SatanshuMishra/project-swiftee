import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_store.dart';
import 'package:swiftie_quiz/domain/engine/catalogue_rules.dart';
import 'package:swiftie_quiz/domain/engine/play_order.dart';
import 'package:swiftie_quiz/domain/engine/version_filter.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/util/song_title.dart';

void main() {
  late Catalogue catalogue;

  setUpAll(() {
    catalogue = buildCatalogue(
      decodeCatalogue(File(bundledCataloguePath).readAsStringSync()),
    );
  });

  group('which versions', () {
    const all = VersionChoice.all;
    List<String> titles(List<Track> tracks) => [
      for (final track in tracks) track.title,
    ];

    test('everything selected keeps the pick as it is', () {
      final pick = catalogue.tracksFor(['red']);

      expect(keepVersions(pick, all), pick);
    });

    test("taylor's version alone drops the originals she re-recorded and "
        'keeps every song', () {
      final everything = catalogue.allTracks;
      final kept = keepVersions(
        everything,
        all.copyWith(rerecorded: Rerecorded.taylorsVersion),
      );

      expect(everything.length - kept.length, 98);
      expect(
        {for (final track in kept) songKey(track)},
        {for (final track in everything) songKey(track)},
      );
    });

    test('originals alone drop the re-recordings but keep vault songs, '
        'which have no original', () {
      final originals = all.copyWith(rerecorded: Rerecorded.original);
      final kept = titles(keepVersions(catalogue.allTracks, originals));

      expect(kept, contains('Red'));
      expect(kept, isNot(contains("Red (Taylor's Version)")));
      expect(
        kept,
        contains("Mr. Perfectly Fine (Taylor’s Version) (From The Vault)"),
      );
      expect(
        {
          for (final track in keepVersions(catalogue.allTracks, originals))
            songKey(track),
        },
        {for (final track in catalogue.allTracks) songKey(track)},
      );
    });

    test('every vault song plays whichever recordings are chosen, even '
        'one that shares a title with a re-recorded song', () {
      final red = catalogue.tracksFor(['red']);
      final vault = [
        for (final track in red)
          if (isFromTheVault(track.title)) track.title,
      ];
      expect(
        vault,
        contains(
          "All Too Well (10 Minute Version) (Taylor's Version) (From The Vault)",
        ),
      );
      for (final rerecorded in Rerecorded.values) {
        expect(
          titles(keepVersions(red, all.copyWith(rerecorded: rerecorded))),
          containsAll(vault),
        );
      }
    });

    test('each kind of take counts its recordings in the pick', () {
      final everything = VersionIndex(catalogue.allTracks);
      final poetsAndShowgirl = VersionIndex(
        catalogue.tracksFor(['ttpd', 'showgirl']),
      );

      expect(
        [for (final take in Take.values) everything.countOf(take, all)],
        [339, 53, 28],
      );
      expect(
        [for (final take in Take.values) poetsAndShowgirl.countOf(take, all)],
        [47, 0, 8],
      );
      expect(
        everything.countOf(
          Take.studio,
          all.copyWith(rerecorded: Rerecorded.taylorsVersion),
        ),
        lessThan(339),
      );
    });

    test('turning off a kind of take drops exactly those takes', () {
      final everything = catalogue.allTracks;

      expect(
        everything.length -
            keepVersions(everything, all.copyWith(live: false)).length,
        53,
      );
      expect(
        everything.length -
            keepVersions(everything, all.copyWith(alternate: false)).length,
        28,
      );
      expect(
        keepVersions(
          everything,
          all.copyWith(studio: false),
        ).where((track) => takeOf(track.title) == Take.studio),
        isEmpty,
      );
      expect(
        keepVersions(
          everything,
          all.copyWith(live: false, alternate: false),
        ).where((track) => takeOf(track.title) != Take.studio),
        isEmpty,
      );
    });

    test('a recording plays only when its take and its recording are both '
        'chosen', () {
      final speakNowAndRed = catalogue.tracksFor(['speaknow', 'red']);
      const acousticTv = "State Of Grace (Acoustic Version) (Taylor's Version)";
      const originalLive = 'Haunted (Live/2011)';

      expect(
        titles(keepVersions(speakNowAndRed, all)),
        containsAll([acousticTv, originalLive]),
      );
      final tvAndAcoustic = titles(
        keepVersions(
          speakNowAndRed,
          all.copyWith(rerecorded: Rerecorded.taylorsVersion, live: false),
        ),
      );
      expect(tvAndAcoustic, contains(acousticTv));
      expect(tvAndAcoustic, isNot(contains(originalLive)));
      final originalsAndLive = titles(
        keepVersions(
          speakNowAndRed,
          all.copyWith(rerecorded: Rerecorded.original, alternate: false),
        ),
      );
      expect(originalsAndLive, contains(originalLive));
      expect(originalsAndLive, isNot(contains(acousticTv)));
    });

    test('only a pick holding both recordings of a song asks about '
        're-recordings', () {
      expect(VersionIndex(catalogue.tracksFor(['red'])).hasRerecorded, isTrue);
      expect(VersionIndex(catalogue.tracksFor(['rep'])).hasRerecorded, isFalse);
      final redTv = catalogue.releases.firstWhere(
        (release) => release.title == "Red (Taylor's Version)",
      );
      expect(VersionIndex(redTv.tracks).hasRerecorded, isFalse);
    });

    test('a choice that would leave nothing to play cannot be made', () {
      final red = VersionIndex(catalogue.tracksFor(['red']));
      final rep = VersionIndex(catalogue.tracksFor(['rep']));
      final mine = VersionIndex([
        for (final track in catalogue.tracksFor(['speaknow']))
          if (track.title.startsWith('Mine')) track,
      ]);
      final liveOnly = all.copyWith(studio: false, alternate: false);

      expect(red.canToggle(all, Take.live), isTrue);
      expect(rep.canToggle(all, Take.studio), isFalse);
      expect(rep.canToggle(all, Take.live), isFalse);
      expect(rep.canToggle(all, Take.alternate), isFalse);
      expect(mine.canToggle(liveOnly, Take.live), isFalse);
      expect(mine.canToggle(liveOnly, Take.studio), isTrue);
      expect(mine.canChoose(liveOnly, Rerecorded.original), isTrue);
      expect(mine.canChoose(liveOnly, Rerecorded.taylorsVersion), isFalse);
    });

    test('a remembered choice that leaves nothing for a new pick falls back '
        'to every version', () {
      final liveRelease = catalogue.releases.firstWhere(
        (release) => release.title == 'Speak Now World Tour Live',
      );
      final noLive = all.copyWith(live: false);

      expect(VersionIndex(liveRelease.tracks).usable(noLive), all);
      expect(VersionIndex(catalogue.tracksFor(['red'])).usable(noLive), noLive);
    });
  });
}
