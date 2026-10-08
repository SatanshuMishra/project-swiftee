import 'package:swiftie_quiz/domain/engine/play_order.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/util/song_title.dart';

typedef _Labelled = ({Track track, Take take, bool taylors, bool rerecorded});

final class VersionIndex {
  VersionIndex(List<Track> tracks) : _entries = _label(tracks);

  final List<_Labelled> _entries;

  late final bool hasRerecorded = _entries.any((entry) => entry.rerecorded);

  List<Track> keep(VersionChoice choice) => List.unmodifiable([
    for (final entry in _entries)
      if (_keeps(choice, entry)) entry.track,
  ]);

  int count(VersionChoice choice) =>
      _entries.where((entry) => _keeps(choice, entry)).length;

  int countOf(Take take, VersionChoice choice) => _entries
      .where((entry) => entry.take == take && _plays(choice.rerecorded, entry))
      .length;

  bool canToggle(VersionChoice choice, Take take) =>
      countOf(take, choice) > 0 && count(choice.toggled(take)) > 0;

  bool canChoose(VersionChoice choice, Rerecorded rerecorded) =>
      count(choice.copyWith(rerecorded: rerecorded)) > 0;

  VersionChoice usable(VersionChoice choice) =>
      count(choice) > 0 ? choice : VersionChoice.all;

  VersionChoice fitted(VersionChoice choice) {
    final usable = this.usable(choice);
    final both = usable.copyWith(rerecorded: Rerecorded.both);
    final recording = count(usable) == count(both) ? both : usable;
    bool held(Take take) => countOf(take, recording) > 0;
    return recording.copyWith(
      studio: recording.studio || !held(Take.studio),
      live: recording.live || !held(Take.live),
      alternate: recording.alternate || !held(Take.alternate),
    );
  }

  static bool _keeps(VersionChoice choice, _Labelled entry) =>
      choice.plays(entry.take) && _plays(choice.rerecorded, entry);

  static bool _plays(Rerecorded rerecorded, _Labelled entry) =>
      !entry.rerecorded ||
      switch (rerecorded) {
        Rerecorded.taylorsVersion => entry.taylors,
        Rerecorded.original => !entry.taylors,
        Rerecorded.both => true,
      };

  static List<_Labelled> _label(List<Track> tracks) {
    final taylors = <String>{};
    final originals = <String>{};
    for (final track in tracks) {
      if (!isFromTheVault(track.title)) {
        (isTaylorsVersion(track.title) ? taylors : originals).add(
          songKey(track),
        );
      }
    }
    final both = taylors.intersection(originals);
    return List.unmodifiable([
      for (final track in tracks)
        (
          track: track,
          take: takeOf(track.title),
          taylors: isTaylorsVersion(track.title),
          rerecorded:
              !isFromTheVault(track.title) && both.contains(songKey(track)),
        ),
    ]);
  }
}

List<Track> keepVersions(List<Track> tracks, VersionChoice choice) =>
    VersionIndex(tracks).keep(choice);
