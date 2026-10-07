import 'package:swiftie_quiz/domain/engine/play_order.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/util/song_title.dart';

typedef VersionMix = ({bool rerecorded, bool liveTakes, bool otherTakes});

Set<String> _rerecordedSongs(Iterable<Track> tracks) {
  final taylors = <String>{};
  final originals = <String>{};
  for (final track in tracks) {
    (isTaylorsVersion(track.title) ? taylors : originals).add(songKey(track));
  }
  return taylors.intersection(originals);
}

VersionMix versionMixOf(Iterable<Track> tracks) => (
  rerecorded: _rerecordedSongs(tracks).isNotEmpty,
  liveTakes: tracks.any((track) => takeOf(track.title) == Take.live),
  otherTakes: tracks.any((track) => takeOf(track.title) == Take.alternate),
);

List<Track> keepVersions(List<Track> tracks, VersionChoice choice) {
  final rerecorded = _rerecordedSongs(tracks);
  return List.unmodifiable([
    for (final track in tracks)
      if (_keepsTake(choice, takeOf(track.title)) &&
          (!rerecorded.contains(songKey(track)) ||
              (isTaylorsVersion(track.title)
                  ? choice.taylorsVersions
                  : choice.originals)))
        track,
  ]);
}

bool _keepsTake(VersionChoice choice, Take take) => switch (take) {
  Take.studio => true,
  Take.live => choice.liveTakes,
  Take.alternate => choice.otherTakes,
};

bool canToggle(List<Track> tracks, VersionChoice choice, VersionOption option) {
  final next = choice.toggled(option);
  return (next.taylorsVersions || next.originals) &&
      keepVersions(tracks, next).isNotEmpty;
}
