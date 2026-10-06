import 'dart:collection';
import 'dart:math';

import 'package:swiftie_quiz/domain/engine/answer_matcher.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/util/shuffle.dart';
import 'package:swiftie_quiz/domain/util/song_title.dart';

const int songGapRounds = 10;

String songKey(Track track) => normalizeTitle(track.title);

List<Track> soundOrder(
  Iterable<Track> tracks, {
  required List<Track> heard,
  Random? random,
}) => playOrder(
  tracks,
  key: (track) => track.id,
  song: songKey,
  played: [for (final track in heard) track.id],
  recent: [
    for (final track in heard.skip(max(0, heard.length - songGapRounds)))
      songKey(track),
  ],
  songGap: (songs) => min(songGapRounds, songs * 3 ~/ 4),
  deferCrowded: true,
  random: random,
);

List<Track> lyricsOrder(
  Iterable<Track> tracks, {
  required List<String> read,
  Random? random,
}) {
  final generator = random ?? Random();
  return lyricsReplay(
    lyricsSources(tracks, random: generator),
    track: (track) => track,
    read: read,
    random: generator,
  );
}

List<T> lyricsReplay<T>(
  Iterable<T> entries, {
  required Track Function(T entry) track,
  required List<String> read,
  Random? random,
}) => playOrder(
  entries,
  key: (entry) => songKey(track(entry)),
  song: (entry) => songKey(track(entry)),
  played: read,
  recent: read,
  songGap: (songs) => songs ~/ 2,
  deferCrowded: false,
  random: random,
);

List<Track> lyricsSources(Iterable<Track> tracks, {Random? random}) {
  final generator = random ?? Random();
  final versions = <String, List<Track>>{};
  for (final track in tracks) {
    (versions[songKey(track)] ??= []).add(track);
  }
  return UnmodifiableListView([
    for (final takes in versions.values)
      _pick(switch (takes
          .where((track) => isStudioVersion(track.title))
          .toList()) {
        [] => takes,
        final studio => studio,
      }, generator),
  ]);
}

List<T> playOrder<T>(
  Iterable<T> items, {
  required Object Function(T item) key,
  required String Function(T item) song,
  required List<Object> played,
  required List<String> recent,
  required int Function(int songs) songGap,
  required bool deferCrowded,
  Random? random,
}) {
  final all = items.toList(growable: false);
  final songIds = <String, int>{};
  final songOf = [
    for (final item in all)
      songIds.putIfAbsent(song(item), () => songIds.length),
  ];
  final slotOf = <Object, int>{
    for (final (index, item) in all.indexed) key(item): index,
  };
  final rank = List<int>.filled(all.length, 0);
  for (final (position, index) in shuffle([
    for (var index = 0; index < all.length; index++) index,
  ], random: random ?? Random()).indexed) {
    rank[index] = position;
  }
  final plays = List<int>.filled(all.length, 0);
  for (final entry in played) {
    if (slotOf[entry] case final index?) {
      plays[index]++;
    }
  }
  final lastAt = List<int?>.filled(songIds.length, null);
  var clock = played.length;
  for (final (offset, entry) in recent.indexed) {
    if (songIds[entry] case final id?) {
      lastAt[id] = clock - recent.length + offset;
    }
  }
  final gap = songGap(songIds.length);
  bool crowded(int index) {
    final at = lastAt[songOf[index]];
    return at != null && clock - at <= gap;
  }

  int compare(int a, int b) {
    final byRoom = (crowded(a) ? 1 : 0) - (crowded(b) ? 1 : 0);
    if (byRoom != 0) {
      return byRoom;
    }
    final byPlays = plays[a] - plays[b];
    return byPlays != 0 ? byPlays : rank[a] - rank[b];
  }

  final waiting = [for (var index = 0; index < all.length; index++) index];
  final placed = <int>[];
  while (waiting.isNotEmpty) {
    var best = 0;
    for (var position = 1; position < waiting.length; position++) {
      if (compare(waiting[position], waiting[best]) < 0) {
        best = position;
      }
    }
    final next = waiting[best];
    if (deferCrowded && placed.isNotEmpty && crowded(next)) {
      break;
    }
    waiting[best] = waiting.last;
    waiting.removeLast();
    placed.add(next);
    plays[next]++;
    lastAt[songOf[next]] = clock++;
  }
  return UnmodifiableListView([for (final index in placed) all[index]]);
}

T _pick<T>(List<T> items, Random random) => items[random.nextInt(items.length)];
