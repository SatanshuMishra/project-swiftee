import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_store.dart';
import 'package:swiftie_quiz/domain/engine/catalogue_rules.dart';
import 'package:swiftie_quiz/domain/engine/game_engine.dart';
import 'package:swiftie_quiz/domain/engine/play_order.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

Track _track(int id, String title) => Track(
  id: id,
  title: title,
  titleShort: title,
  duration: 200,
  preview: '',
  artist: const Artist(id: 12246, name: 'Taylor Swift'),
  album: const Album(id: 1, title: 'Album', coverMedium: null),
);

List<int> _ids(List<Track> tracks) => [for (final track in tracks) track.id];

int _closestVersions(List<Track> order) {
  final seen = <String, int>{};
  var closest = order.length;
  for (final (index, track) in order.indexed) {
    final key = songKey(track);
    if (seen[key] case final previous?) {
      closest = min(closest, index - previous);
    }
    seen[key] = index;
  }
  return closest;
}

bool _repeatsASong(Iterable<Track> round) {
  final keys = round.map(songKey).toList();
  return keys.toSet().length < keys.length;
}

void main() {
  late Catalogue catalogue;

  setUpAll(() {
    catalogue = buildCatalogue(
      decodeCatalogue(File(bundledCataloguePath).readAsStringSync()),
    );
  });

  group('sound order', () {
    final tracks = [for (var id = 1; id <= 10; id++) _track(id, 'Song $id')];
    List<Track> heard(List<int> ids) => [for (final id in ids) tracks[id - 1]];

    test('plays every recording once', () {
      final order = soundOrder(tracks, heard: const [], random: Random(1));

      expect(_ids(order), unorderedEquals(_ids(tracks)));
    });

    test('plays what you have not heard before what you have', () {
      final order = soundOrder(tracks, heard: heard([3, 7]), random: Random(2));

      expect(_ids(order).take(8), unorderedEquals([1, 2, 4, 5, 6, 8, 9, 10]));
      expect(_ids(order).skip(8), unorderedEquals([3, 7]));
    });

    test('keeps a song heard in the last rounds out of the next ones', () {
      final last = heard([1, 2, 3, 4, 5, 6, 7, 8]);
      final order = soundOrder(tracks, heard: last, random: Random(3));

      expect(_ids(order).take(2), unorderedEquals([9, 10]));
      expect(_closestVersions([...last, ...order]), greaterThan(7));
    });

    test('counts only the latest time a recording was heard', () {
      final order = soundOrder(
        tracks.take(4),
        heard: heard([1, 2, 3, 4, 1]),
        random: Random(4),
      );

      expect(_ids(order).take(2), unorderedEquals([2, 3]));
      expect(_ids(order).skip(2), unorderedEquals([4, 1]));
    });

    test('does not replay the last pass in the same order', () {
      final orders = {
        for (var seed = 0; seed < 20; seed++)
          _ids(
            soundOrder(
              tracks,
              heard: heard([for (var id = 1; id <= 10; id++) id]),
              random: Random(seed),
            ),
          ).join(','),
      };

      expect(orders.length, greaterThan(10));
    });

    final versions = [
      for (var song = 0; song < 10; song++)
        for (var version = 0; version < 3; version++)
          _track(song * 10 + version, 'Song $song (Version $version)'),
      for (var single = 0; single < 30; single++)
        _track(1000 + single, 'Single $single'),
    ];

    test('keeps two versions of one song more than ten rounds apart', () {
      for (var seed = 0; seed < 100; seed++) {
        final order = soundOrder(
          versions,
          heard: const [],
          random: Random(seed),
        );

        expect(_closestVersions(order), greaterThan(songGapRounds));
      }
    });

    test('keeps the gap from the songs heard in the last game', () {
      final lastGame = [
        versions[0],
        for (var other = 0; other < 3; other++)
          _track(500 + other, 'Other $other'),
      ];

      for (var seed = 0; seed < 100; seed++) {
        final order = soundOrder(
          versions,
          heard: lastGame,
          random: Random(seed),
        );

        expect(
          order.take(songGapRounds - 3).map(songKey),
          isNot(contains(songKey(versions[0]))),
        );
        expect(
          order.take(songGapRounds).map((track) => track.id),
          isNot(contains(0)),
        );
      }
    });

    test('a version heard in another pick keeps its song out too', () {
      final elsewhere = _track(900, 'Song 0 (Live)');
      for (var seed = 0; seed < 100; seed++) {
        final order = soundOrder(
          versions,
          heard: [elsewhere],
          random: Random(seed),
        );

        expect(
          order.take(songGapRounds).map(songKey),
          isNot(contains(songKey(elsewhere))),
        );
      }
    });

    test('a debut song heard last game stays out of a Fearless game', () {
      final debut = catalogue.tracksFor(['ts']);
      final fearless = catalogue.tracksFor(['fearless']);
      final shared = [
        for (final track in debut)
          if (fearless.any(
            (other) => songKey(other) == songKey(track) && other.id != track.id,
          ))
            track,
      ];

      expect(shared, isNotEmpty);
      for (final song in shared) {
        for (var seed = 0; seed < 50; seed++) {
          final order = soundOrder(
            fearless,
            heard: [song],
            random: Random(seed),
          );

          expect(
            order.take(songGapRounds).map(songKey),
            isNot(contains(songKey(song))),
          );
        }
      }
    });

    test('brings a song back in a version you have not heard', () {
      for (var seed = 0; seed < 100; seed++) {
        final order = soundOrder(
          versions,
          heard: [versions[0]],
          random: Random(seed),
        );
        final next = order.firstWhere(
          (track) => songKey(track) == songKey(versions[0]),
        );

        expect(next.id, isNot(versions[0].id));
      }
    });

    test(
      'a small pick still plays and keeps a song from playing twice in a row',
      () {
        final small = [
          for (var song = 0; song < 3; song++)
            for (var version = 0; version < 3; version++)
              _track(song * 10 + version, 'Song $song (Version $version)'),
        ];

        for (var seed = 0; seed < 50; seed++) {
          final order = soundOrder(
            small,
            heard: const [],
            random: Random(seed),
          );

          expect(order, hasLength(9));
          expect(_closestVersions(order), greaterThan(1));
        }
      },
    );

    test('no pick plays two versions of one song in a ten-song game', () {
      for (final era in eraGroups) {
        final pick = catalogue.tracksFor([era.key]);
        for (var seed = 0; seed < 200; seed++) {
          final first = soundOrder(pick, heard: const [], random: Random(seed));
          final second = soundOrder(
            pick,
            heard: first.take(10).toList(),
            random: Random(seed + 1),
          );

          expect(_repeatsASong(first.take(10)), isFalse, reason: era.eraName);
          expect(
            _repeatsASong(
              [...first.take(10), ...second.take(10)].skip(5).take(10),
            ),
            isFalse,
            reason: era.eraName,
          );
        }
      }
    });

    test('any song in a pick can open a game', () {
      final evermore = catalogue.tracksFor(['evermore']);
      final openers = {
        for (var seed = 0; seed < 200; seed++)
          songKey(
            soundOrder(evermore, heard: const [], random: Random(seed)).first,
          ),
      };

      expect(
        openers,
        hasLength({for (final track in evermore) songKey(track)}.length),
      );
    });

    test('versions a small pick cannot keep apart wait for the next pass', () {
      final pick = [
        _track(1, 'Willow'),
        _track(2, 'Willow (Dancing Witch Version)'),
        _track(3, 'Willow (Lonely Witch Version)'),
        _track(4, 'Gold Rush'),
        _track(5, 'Ivy'),
      ];
      final played = <Track>[];
      var pool = <Track>[];
      for (var round = 0; round < 30; round++) {
        final draw = drawNextTrack(
          pool,
          pick,
          heard: played,
          random: Random(round),
        );
        played.add(draw.track);
        pool = draw.remaining;
      }

      expect(_closestVersions(played), greaterThan(1));
      expect(played.map((track) => track.id).toSet(), {1, 2, 3, 4, 5});
    });

    test('a recording plays twice only while the unplayed ones wait out '
        'their song', () {
      for (final key in ['evermore', 'singles', 'folklore', '1989', 'red']) {
        final pick = catalogue.tracksFor([key]);
        final songs = {for (final track in pick) songKey(track)}.length;
        final gap = min(songGapRounds, songs * 3 ~/ 4);
        for (var seed = 0; seed < 40; seed++) {
          final played = <Track>[];
          var pool = <Track>[];
          for (var round = 0; round < pick.length * 3; round++) {
            final draw = drawNextTrack(
              pool,
              pick,
              heard: played,
              random: Random(seed * 1000 + round),
            );
            final heardIds = {for (final track in played) track.id};
            if (heardIds.contains(draw.track.id)) {
              final recent = {
                for (final track in played.reversed.take(gap)) songKey(track),
              };
              for (final waiting in pick) {
                if (!heardIds.contains(waiting.id)) {
                  expect(
                    recent,
                    contains(songKey(waiting)),
                    reason: '$key round $round: ${waiting.title} skipped',
                  );
                }
              }
            }
            played.add(draw.track);
            pool = draw.remaining;
          }

          expect(_closestVersions(played), greaterThan(gap), reason: key);
          expect(
            {for (final track in played) track.id},
            {for (final track in pick) track.id},
            reason: key,
          );
        }
      }
    });
  });

  group('lyrics order', () {
    test('reads one recording of each song', () {
      final tracks = [
        _track(1, 'Red'),
        _track(2, "Red (Taylor's Version)"),
        _track(3, 'Starlight'),
        _track(4, "Starlight (Taylor's Version)"),
        _track(5, 'Holy Ground'),
      ];

      final order = lyricsOrder(tracks, read: const [], random: Random(5));

      expect(
        order.map(songKey),
        unorderedEquals(['red', 'starlight', 'holy ground']),
      );
    });

    test('reads the studio words rather than a live or demo take', () {
      final tracks = [
        _track(1, 'Fearless (Live from Clear Channel Stripped 2008)'),
        _track(2, 'Fearless'),
        _track(3, 'Fearless - Demo'),
        _track(4, "Fearless (Taylor's Version)"),
        _track(5, 'Everything Has Changed (feat. Ed Sheeran)'),
        _track(6, 'Everything Has Changed (Live)'),
      ];

      final picked = <int>{
        for (var seed = 0; seed < 40; seed++)
          ...lyricsOrder(
            tracks,
            read: const [],
            random: Random(seed),
          ).map((track) => track.id),
      };

      expect(picked, {2, 4, 5});
    });

    test('a song you have read waits until the others have been read', () {
      final tracks = [
        _track(1, 'Red'),
        _track(2, "Red (Taylor's Version)"),
        _track(3, 'Starlight'),
        _track(4, 'Holy Ground'),
      ];

      final order = lyricsOrder(tracks, read: const ['red'], random: Random(6));

      expect(order.map(songKey).last, 'red');
    });

    test('a song repeats only after every song in the pick was read', () {
      final folklore = catalogue.tracksFor(['folklore']);
      final songs = lyricsOrder(
        folklore,
        read: const [],
        random: Random(7),
      ).map(songKey).toList();

      expect(songs.toSet().length, songs.length);
      expect(songs.length, lessThan(folklore.length));
    });

    test('the next pass keeps the songs read last at a distance', () {
      final folklore = catalogue.tracksFor(['folklore']);
      for (var seed = 0; seed < 50; seed++) {
        final first = lyricsOrder(
          folklore,
          read: const [],
          random: Random(seed),
        );
        final second = lyricsReplay(
          first,
          track: (track) => track,
          read: first.map(songKey).toList(),
          random: Random(seed + 1),
        );

        expect(second.map(songKey).toSet(), first.map(songKey).toSet());
        expect(
          _closestVersions([...first, ...second]),
          greaterThan(first.length ~/ 2),
        );
      }
    });
  });
}
