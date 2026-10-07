import 'package:swiftie_quiz/domain/engine/play_order.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/util/song_title.dart';

List<Track> keepVersions(List<Track> tracks, TrackVersions versions) =>
    switch (versions) {
      TrackVersions.every => tracks,
      TrackVersions.taylorsVersion => _replacedByTaylorsVersion(tracks),
      TrackVersions.noLive => List.unmodifiable([
        for (final track in tracks)
          if (takeOf(track.title) != Take.live) track,
      ]),
    };

List<Track> _replacedByTaylorsVersion(List<Track> tracks) {
  final rerecorded = {
    for (final track in tracks)
      if (isTaylorsVersion(track.title)) songKey(track),
  };
  return List.unmodifiable([
    for (final track in tracks)
      if (isTaylorsVersion(track.title) || !rerecorded.contains(songKey(track)))
        track,
  ]);
}
