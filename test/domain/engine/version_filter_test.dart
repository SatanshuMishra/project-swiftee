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
      final kept = keepVersions(everything, all.copyWith(originals: false));

      expect(everything.length - kept.length, 98);
      expect(
        {for (final track in kept) songKey(track)},
        {for (final track in everything) songKey(track)},
      );
    });

    test("originals alone drop the re-recordings but keep vault songs, "
        'which have no original', () {
      final kept = titles(
        keepVersions(catalogue.allTracks, all.copyWith(taylorsVersions: false)),
      );

      expect(kept, contains('Red'));
      expect(kept, isNot(contains("Red (Taylor's Version)")));
      expect(
        kept,
        contains("Mr. Perfectly Fine (Taylor’s Version) (From The Vault)"),
      );
      expect(
        {
          for (final track in keepVersions(
            catalogue.allTracks,
            all.copyWith(taylorsVersions: false),
          ))
            songKey(track),
        },
        {for (final track in catalogue.allTracks) songKey(track)},
      );
    });

    test('turning off live or other takes drops exactly those takes', () {
      final everything = catalogue.allTracks;

      expect(
        everything.length -
            keepVersions(everything, all.copyWith(liveTakes: false)).length,
        53,
      );
      expect(
        everything.length -
            keepVersions(everything, all.copyWith(otherTakes: false)).length,
        28,
      );
      expect(
        keepVersions(
          everything,
          all.copyWith(liveTakes: false, otherTakes: false),
        ).where((track) => takeOf(track.title) != Take.studio),
        isEmpty,
      );
    });

    test('a recording plays only when both of its labels are selected', () {
      final speakNowAndRed = catalogue.tracksFor(['speaknow', 'red']);
      const acousticTv = "State Of Grace (Acoustic Version) (Taylor's Version)";
      const originalLive = 'Haunted (Live/2011)';

      expect(
        titles(keepVersions(speakNowAndRed, all)),
        containsAll([acousticTv, originalLive]),
      );
      final tvAndOther = titles(
        keepVersions(
          speakNowAndRed,
          all.copyWith(originals: false, liveTakes: false),
        ),
      );
      expect(tvAndOther, contains(acousticTv));
      expect(tvAndOther, isNot(contains(originalLive)));
      final originalsAndLive = titles(
        keepVersions(
          speakNowAndRed,
          all.copyWith(taylorsVersions: false, otherTakes: false),
        ),
      );
      expect(originalsAndLive, contains(originalLive));
      expect(originalsAndLive, isNot(contains(acousticTv)));
    });

    test('a pick reports which choices matter to it', () {
      expect(versionMixOf(catalogue.tracksFor(['red'])), (
        rerecorded: true,
        liveTakes: true,
        otherTakes: true,
      ));
      expect(versionMixOf(catalogue.tracksFor(['rep'])), (
        rerecorded: false,
        liveTakes: false,
        otherTakes: false,
      ));
      final redTv = catalogue.releases.firstWhere(
        (release) => release.title == "Red (Taylor's Version)",
      );
      expect(versionMixOf(redTv.tracks).rerecorded, isFalse);
    });

    test('the last recording kind and a choice that leaves nothing cannot '
        'be turned off', () {
      final red = catalogue.tracksFor(['red']);
      final tvOnly = all.copyWith(originals: false);
      final liveOnly = [
        for (final track in catalogue.tracksFor(['speaknow']))
          if (takeOf(track.title) == Take.live) track,
      ];

      expect(canToggle(red, all, VersionOption.originals), isTrue);
      expect(canToggle(red, tvOnly, VersionOption.taylorsVersions), isFalse);
      expect(canToggle(red, tvOnly, VersionOption.originals), isTrue);
      expect(canToggle(liveOnly, all, VersionOption.liveTakes), isFalse);
      expect(canToggle(liveOnly, all, VersionOption.otherTakes), isTrue);
    });
  });
}
