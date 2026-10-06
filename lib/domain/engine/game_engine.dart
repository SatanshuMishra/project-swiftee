import 'dart:math';

import 'package:swiftie_quiz/domain/engine/play_order.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

typedef TrackDraw = ({Track track, List<Track> remaining});

List<Track> createTrackPool(
  Iterable<Track> tracks, {
  List<Track> heard = const [],
  Random? random,
}) => soundOrder(tracks, heard: heard, random: random);

TrackDraw drawNextTrack(
  List<Track> pool,
  List<Track> allTracks, {
  List<Track> heard = const [],
  Random? random,
}) {
  final source = pool.isEmpty
      ? createTrackPool(allTracks, heard: heard, random: random)
      : pool;
  return (
    track: source.first,
    remaining: List<Track>.unmodifiable(source.skip(1)),
  );
}
