import 'dart:math';

import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/util/shuffle.dart';

typedef TrackDraw = ({Track track, List<Track> remaining});

List<Track> createTrackPool(Iterable<Track> tracks, {Random? random}) =>
    shuffle(tracks, random: random);

TrackDraw drawNextTrack(
  List<Track> pool,
  List<Track> allTracks, {
  Random? random,
}) {
  final source = pool.isEmpty
      ? createTrackPool(allTracks, random: random)
      : pool;
  return (
    track: source.first,
    remaining: List<Track>.unmodifiable(source.skip(1)),
  );
}
