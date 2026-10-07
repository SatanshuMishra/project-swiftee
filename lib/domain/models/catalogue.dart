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

final class CatalogueRelease {
  CatalogueRelease({
    required this.id,
    required this.title,
    required this.kind,
    required this.releaseDate,
    required this.coverMedium,
    required this.eraKey,
    required List<Track> tracks,
  }) : tracks = List.unmodifiable(tracks);

  final int id;
  final String title;
  final ReleaseKind kind;
  final String releaseDate;
  final String? coverMedium;
  final String eraKey;
  final List<Track> tracks;

  String get year =>
      releaseDate.length >= 4 ? releaseDate.substring(0, 4) : releaseDate;

  @override
  bool operator ==(Object other) =>
      other is CatalogueRelease &&
      other.id == id &&
      other.title == title &&
      other.kind == kind &&
      other.releaseDate == releaseDate &&
      other.coverMedium == coverMedium &&
      other.eraKey == eraKey &&
      const ListEquality<Track>().equals(other.tracks, tracks);

  @override
  int get hashCode => Object.hash(
    id,
    title,
    kind,
    releaseDate,
    coverMedium,
    eraKey,
    const ListEquality<Track>().hash(tracks),
  );

  @override
  String toString() =>
      'CatalogueRelease(id: $id, title: $title, kind: $kind, '
      'era: $eraKey, tracks: ${tracks.length})';
}

final class Catalogue {
  Catalogue({
    required List<RawRelease> sources,
    required Map<int, String> releaseEras,
    required List<CatalogueRecording> recordings,
    List<Era> derivedEras = const [],
  }) : sources = List.unmodifiable(sources),
       _releaseEras = Map.unmodifiable(releaseEras),
       recordings = List.unmodifiable(recordings),
       derivedEras = List.unmodifiable(derivedEras);

  static final Catalogue empty = Catalogue(
    sources: const [],
    releaseEras: const {},
    recordings: const [],
  );

  final List<RawRelease> sources;
  final Map<int, String> _releaseEras;
  final List<CatalogueRecording> recordings;
  final List<Era> derivedEras;

  late final List<Era> albumEras = List.unmodifiable([
    ...curatedEras,
    ...derivedEras,
  ]);

  late final List<Era> eras = List.unmodifiable([...albumEras, singlesEra]);

  Era? eraByKey(String key) => eras.firstWhereOrNull((era) => era.key == key);

  Era? eraOfTrack(Track track) => switch (track.eraKey) {
    final key? => eraByKey(key),
    null => eraOf(track.album.id),
  };

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

  late final List<CatalogueRelease> releases = _releases();

  bool get isEmpty => recordings.isEmpty;

  Set<int> get releaseIds => {for (final release in sources) release.id};

  List<Track> tracksFor(
    Iterable<String> eraKeys, {
    Iterable<int> releaseIds = const [],
  }) {
    final keys = eraKeys.toSet();
    final picked = releaseIds.toSet();
    final inReleases = {
      for (final release in releases)
        if (picked.contains(release.id))
          for (final track in release.tracks) track.id,
    };
    return List.unmodifiable([
      for (final recording in recordings)
        if (keys.contains(recording.eraKey) ||
            inReleases.contains(recording.track.id))
          recording.track,
    ]);
  }

  List<CatalogueRelease> _releases() {
    final byKey = {
      for (final recording in recordings) recording.isrc: recording.track,
    };
    return List.unmodifiable([
      for (final release in sources)
        if (_releaseTracks(release, byKey) case final tracks
            when tracks.isNotEmpty)
          CatalogueRelease(
            id: release.id,
            title: release.title,
            kind: release.kind,
            releaseDate: release.releaseDate,
            coverMedium: release.coverMedium,
            eraKey: _releaseEras[release.id] ?? singlesEra.key,
            tracks: tracks,
          ),
    ]);
  }

  static List<Track> _releaseTracks(
    RawRelease release,
    Map<String, Track> byKey,
  ) {
    final seen = <int>{};
    return [
      for (final track in release.tracks)
        if (byKey[track.isrc.isEmpty ? 'deezer:${track.id}' : track.isrc]
            case final recording? when seen.add(recording.id))
          recording,
    ];
  }

  int trackCount(String eraKey) =>
      recordings.where((recording) => recording.eraKey == eraKey).length;

  Era? eraOf(int releaseId) => switch (_releaseEras[releaseId]) {
    final key? => eraByKey(key),
    null => albumEras.firstWhereOrNull((era) => era.deezerAlbumId == releaseId),
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

  @override
  bool operator ==(Object other) =>
      other is Catalogue &&
      const ListEquality<RawRelease>().equals(other.sources, sources) &&
      const MapEquality<int, String>().equals(
        other._releaseEras,
        _releaseEras,
      ) &&
      const ListEquality<CatalogueRecording>().equals(
        other.recordings,
        recordings,
      ) &&
      const ListEquality<Era>().equals(other.derivedEras, derivedEras);

  @override
  int get hashCode => Object.hash(
    const ListEquality<RawRelease>().hash(sources),
    const MapEquality<int, String>().hash(_releaseEras),
    const ListEquality<CatalogueRecording>().hash(recordings),
    const ListEquality<Era>().hash(derivedEras),
  );

  @override
  String toString() =>
      'Catalogue(releases: ${sources.length}, '
      'recordings: ${recordings.length})';
}
