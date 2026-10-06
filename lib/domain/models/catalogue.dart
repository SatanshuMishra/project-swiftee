import 'package:collection/collection.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

enum ReleaseKind {
  album,
  ep,
  single;

  static ReleaseKind fromWire(String value) => switch (value) {
    'album' || 'compile' => ReleaseKind.album,
    'ep' => ReleaseKind.ep,
    _ => ReleaseKind.single,
  };
}

final class RawTrack {
  const RawTrack({
    required this.id,
    required this.title,
    required this.titleShort,
    required this.titleVersion,
    required this.duration,
    required this.artistId,
    required this.isrc,
    required this.hasPreview,
  });

  final int id;
  final String title;
  final String titleShort;
  final String titleVersion;
  final int duration;
  final int artistId;
  final String isrc;
  final bool hasPreview;

  @override
  bool operator ==(Object other) =>
      other is RawTrack &&
      other.id == id &&
      other.title == title &&
      other.titleShort == titleShort &&
      other.titleVersion == titleVersion &&
      other.duration == duration &&
      other.artistId == artistId &&
      other.isrc == isrc &&
      other.hasPreview == hasPreview;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    titleShort,
    titleVersion,
    duration,
    artistId,
    isrc,
    hasPreview,
  );

  @override
  String toString() => 'RawTrack(id: $id, title: $title, isrc: $isrc)';
}

final class RawRelease {
  const RawRelease({
    required this.id,
    required this.title,
    required this.kind,
    required this.releaseDate,
    required this.coverMedium,
    required this._tracks,
  });

  final int id;
  final String title;
  final ReleaseKind kind;
  final String releaseDate;
  final String? coverMedium;
  final List<RawTrack> _tracks;

  List<RawTrack> get tracks => UnmodifiableListView(_tracks);

  Album get album => Album(id: id, title: title, coverMedium: coverMedium);

  RawRelease copyWith({List<RawTrack>? tracks}) => RawRelease(
    id: id,
    title: title,
    kind: kind,
    releaseDate: releaseDate,
    coverMedium: coverMedium,
    tracks: tracks == null ? _tracks : List.unmodifiable(tracks),
  );

  @override
  bool operator ==(Object other) =>
      other is RawRelease &&
      other.id == id &&
      other.title == title &&
      other.kind == kind &&
      other.releaseDate == releaseDate &&
      other.coverMedium == coverMedium &&
      const ListEquality<RawTrack>().equals(other._tracks, _tracks);

  @override
  int get hashCode => Object.hash(
    id,
    title,
    kind,
    releaseDate,
    coverMedium,
    const ListEquality<RawTrack>().hash(_tracks),
  );

  @override
  String toString() =>
      'RawRelease(id: $id, title: $title, kind: $kind, '
      'releaseDate: $releaseDate, tracks: ${_tracks.length})';
}

final class CatalogueRecording {
  const CatalogueRecording({
    required this.track,
    required this.isrc,
    required this.eraKey,
  });

  final Track track;
  final String isrc;
  final String eraKey;

  @override
  bool operator ==(Object other) =>
      other is CatalogueRecording &&
      other.track == track &&
      other.isrc == isrc &&
      other.eraKey == eraKey;

  @override
  int get hashCode => Object.hash(track, isrc, eraKey);

  @override
  String toString() =>
      'CatalogueRecording(track: ${track.title}, isrc: $isrc, era: $eraKey)';
}

final class Catalogue {
  Catalogue({
    required List<RawRelease> sources,
    required Map<int, String> releaseEras,
    required List<CatalogueRecording> recordings,
  }) : sources = List.unmodifiable(sources),
       _releaseEras = Map.unmodifiable(releaseEras),
       recordings = List.unmodifiable(recordings);

  static final Catalogue empty = Catalogue(
    sources: const [],
    releaseEras: const {},
    recordings: const [],
  );

  final List<RawRelease> sources;
  final Map<int, String> _releaseEras;
  final List<CatalogueRecording> recordings;

  late final List<Album> albums = List.unmodifiable([
    for (final release in sources) release.album,
  ]);

  late final List<Track> allTracks = List.unmodifiable([
    for (final recording in recordings) recording.track,
  ]);

  late final Map<int, int> homeTotals = Map.unmodifiable(
    recordings.groupFoldBy<int, int>(
      (recording) => recording.track.album.id,
      (count, _) => (count ?? 0) + 1,
    ),
  );

  bool get isEmpty => recordings.isEmpty;

  Set<int> get releaseIds => {for (final release in sources) release.id};

  List<Track> tracksFor(Iterable<String> eraKeys) {
    final keys = eraKeys.toSet();
    return List.unmodifiable([
      for (final recording in recordings)
        if (keys.contains(recording.eraKey)) recording.track,
    ]);
  }

  int trackCount(String eraKey) =>
      recordings.where((recording) => recording.eraKey == eraKey).length;

  Era? eraOf(int releaseId) => switch (_releaseEras[releaseId]) {
    final key? => eraByKey(key),
    null => eraForAlbumId(releaseId),
  };

  String? coverFor(String eraKey) {
    final era = eraByKey(eraKey);
    final anchor = sources.firstWhereOrNull(
      (release) => era != null && release.id == era.deezerAlbumId,
    );
    if (anchor?.coverMedium case final cover?) {
      return cover;
    }
    final inEra = sources
        .where(
          (release) =>
              _releaseEras[release.id] == eraKey &&
              release.coverMedium != null &&
              homeTotals.containsKey(release.id),
        )
        .sortedBy((release) => release.releaseDate);
    return inEra.lastOrNull?.coverMedium;
  }
}
