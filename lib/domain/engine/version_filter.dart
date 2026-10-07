import 'package:swiftie_quiz/domain/engine/play_order.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/util/song_title.dart';

typedef VersionMix = ({bool rerecorded, bool liveTakes, bool otherTakes});

typedef _Labelled = ({Track track, Take take, bool taylors, bool rerecorded});

final class VersionIndex {
  VersionIndex(List<Track> tracks) : _entries = _label(tracks);

  final List<_Labelled> _entries;

  late final VersionMix mix = (
    rerecorded: _entries.any((entry) => entry.rerecorded),
    liveTakes: _entries.any((entry) => entry.take == Take.live),
    otherTakes: _entries.any((entry) => entry.take == Take.alternate),
  );

  bool offers(VersionOption option) => switch (option) {
    VersionOption.taylorsVersions || VersionOption.originals => mix.rerecorded,
    VersionOption.liveTakes => mix.liveTakes,
    VersionOption.otherTakes => mix.otherTakes,
  };

  List<Track> keep(VersionChoice choice) => List.unmodifiable([
    for (final entry in _entries)
      if (_keeps(choice, entry)) entry.track,
  ]);

  int count(VersionChoice choice) =>
      _entries.where((entry) => _keeps(choice, entry)).length;

  bool canToggle(VersionChoice choice, VersionOption option) {
    final next = choice.toggled(option);
    return (next.taylorsVersions || next.originals) &&
        _entries.any((entry) => _keeps(next, entry));
  }

  static bool _keeps(VersionChoice choice, _Labelled entry) =>
      switch (entry.take) {
        Take.studio => true,
        Take.live => choice.liveTakes,
        Take.alternate => choice.otherTakes,
      } &&
      (!entry.rerecorded ||
          (entry.taylors ? choice.taylorsVersions : choice.originals));

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

VersionMix versionMixOf(Iterable<Track> tracks) =>
    VersionIndex(tracks.toList(growable: false)).mix;

bool canToggle(
  List<Track> tracks,
  VersionChoice choice,
  VersionOption option,
) => VersionIndex(tracks).canToggle(choice, option);
