import 'package:collection/collection.dart';

const Object _unchanged = Object();

final class Artist {
  const Artist({required this.id, required this.name});

  final int id;
  final String name;

  Artist copyWith({int? id, String? name}) =>
      Artist(id: id ?? this.id, name: name ?? this.name);

  @override
  bool operator ==(Object other) =>
      other is Artist && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Artist(id: $id, name: $name)';
}

final class Album {
  const Album({
    required this.id,
    required this.title,
    required this.coverMedium,
  });

  final int id;
  final String title;
  final String? coverMedium;

  Album copyWith({int? id, String? title, Object? coverMedium = _unchanged}) =>
      Album(
        id: id ?? this.id,
        title: title ?? this.title,
        coverMedium: identical(coverMedium, _unchanged)
            ? this.coverMedium
            : coverMedium as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is Album &&
      other.id == id &&
      other.title == title &&
      other.coverMedium == coverMedium;

  @override
  int get hashCode => Object.hash(id, title, coverMedium);

  @override
  String toString() =>
      'Album(id: $id, title: $title, coverMedium: $coverMedium)';
}

final class Track {
  const Track({
    required this.id,
    required this.title,
    required this.titleShort,
    required this.duration,
    required this.preview,
    required this.artist,
    required this.album,
    this.trackPosition,
    this.eraKey,
  });

  final int id;
  final String title;
  final String titleShort;
  final int duration;
  final String preview;
  final Artist artist;
  final Album album;
  final int? trackPosition;
  final String? eraKey;

  Track copyWith({
    int? id,
    String? title,
    String? titleShort,
    int? duration,
    String? preview,
    Artist? artist,
    Album? album,
    Object? trackPosition = _unchanged,
    Object? eraKey = _unchanged,
  }) => Track(
    id: id ?? this.id,
    title: title ?? this.title,
    titleShort: titleShort ?? this.titleShort,
    duration: duration ?? this.duration,
    preview: preview ?? this.preview,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    trackPosition: identical(trackPosition, _unchanged)
        ? this.trackPosition
        : trackPosition as int?,
    eraKey: identical(eraKey, _unchanged) ? this.eraKey : eraKey as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is Track &&
      other.id == id &&
      other.title == title &&
      other.titleShort == titleShort &&
      other.duration == duration &&
      other.preview == preview &&
      other.artist == artist &&
      other.album == album &&
      other.trackPosition == trackPosition &&
      other.eraKey == eraKey;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    titleShort,
    duration,
    preview,
    artist,
    album,
    trackPosition,
    eraKey,
  );

  @override
  String toString() =>
      'Track(id: $id, title: $title, titleShort: $titleShort, '
      'duration: $duration, preview: $preview, artist: $artist, '
      'album: $album, trackPosition: $trackPosition, eraKey: $eraKey)';
}

final class AlbumTracks {
  const AlbumTracks({required this._tracks, required this.totalTracks});

  final List<Track> _tracks;
  final int totalTracks;

  List<Track> get tracks => UnmodifiableListView(_tracks);

  AlbumTracks copyWith({List<Track>? tracks, int? totalTracks}) => AlbumTracks(
    tracks: tracks == null ? _tracks : List.unmodifiable(tracks),
    totalTracks: totalTracks ?? this.totalTracks,
  );

  @override
  bool operator ==(Object other) =>
      other is AlbumTracks &&
      const ListEquality<Track>().equals(other._tracks, _tracks) &&
      other.totalTracks == totalTracks;

  @override
  int get hashCode =>
      Object.hash(const ListEquality<Track>().hash(_tracks), totalTracks);

  @override
  String toString() =>
      'AlbumTracks(tracks: $_tracks, totalTracks: $totalTracks)';
}
