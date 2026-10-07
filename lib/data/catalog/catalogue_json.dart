import 'dart:convert';

import 'package:swiftie_quiz/data/catalog/catalog_error.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';

const int catalogueFormat = 1;

RawRelease parseReleaseSummary(Object? json) => switch (json) {
  {
        'id': final int id,
        'title': final String title,
        'record_type': final String kind,
        'release_date': final String date,
      } &&
      final Map<String, Object?> fields =>
    RawRelease(
      id: id,
      title: title,
      kind: ReleaseKind.fromWire(kind),
      releaseDate: date,
      coverMedium: fields['cover_medium'] as String?,
      tracks: const [],
    ),
  _ => throw const ParseError('expected a release'),
};

RawTrack parseRawTrack(Object? json) => switch (json) {
  {
        'id': final int id,
        'title': final String title,
        'duration': final int duration,
        'artist': {'id': final int artistId},
      } &&
      final Map<String, Object?> fields =>
    RawTrack(
      id: id,
      title: title,
      titleShort: fields['title_short'] as String? ?? title,
      titleVersion: fields['title_version'] as String? ?? '',
      duration: duration,
      artistId: artistId,
      isrc: fields['isrc'] as String? ?? '',
      hasPreview: (fields['preview'] as String? ?? '').isNotEmpty,
    ),
  _ => throw const ParseError('expected a track'),
};

typedef CatalogueEntry = ({RawRelease release, DateTime fetchedAt});

String encodeCatalogue(
  Iterable<RawRelease> releases, {
  required String fetchedAt,
}) => jsonEncode({
  'format': catalogueFormat,
  'fetchedAt': fetchedAt,
  'releases': [for (final release in releases) _encodeRelease(release)],
});

String encodeCatalogueEntries(
  Iterable<CatalogueEntry> entries, {
  required DateTime fetchedAt,
}) => jsonEncode({
  'format': catalogueFormat,
  'fetchedAt': fetchedAt.toUtc().toIso8601String(),
  'releases': [
    for (final entry in entries)
      {
        ..._encodeRelease(entry.release),
        'fetched': entry.fetchedAt.toUtc().toIso8601String(),
      },
  ],
});

List<CatalogueEntry> decodeCatalogueEntries(
  String text, {
  DateTime? unstamped,
}) {
  final json = _decodeJson(text);
  return switch (json) {
    {
      'format': catalogueFormat,
      'fetchedAt': final String fetchedAt,
      'releases': final List<Object?> releases,
    } =>
      List.unmodifiable([
        for (final release in releases)
          (
            release: _decodeRelease(release),
            fetchedAt:
                _fetchedAt(release) ?? unstamped ?? _parseTime(fetchedAt),
          ),
      ]),
    _ => throw const ParseError('unsupported catalogue'),
  };
}

DateTime? _fetchedAt(Object? release) => switch (release) {
  {'fetched': final String fetched} => _parseTime(fetched),
  _ => null,
};

DateTime _parseTime(String value) =>
    DateTime.tryParse(value)?.toUtc() ??
    (throw const ParseError('invalid catalogue time'));

Object? _decodeJson(String text) {
  try {
    return jsonDecode(text);
  } on FormatException catch (error) {
    throw ParseError(error.message);
  }
}

List<RawRelease> decodeCatalogue(String text) {
  final json = _decodeJson(text);
  return switch (json) {
    {'format': catalogueFormat, 'releases': final List<Object?> releases} =>
      List.unmodifiable(releases.map(_decodeRelease)),
    _ => throw const ParseError('unsupported catalogue'),
  };
}

Map<String, Object?> _encodeRelease(RawRelease release) => {
  'id': release.id,
  'title': release.title,
  'kind': release.kind.name,
  'date': release.releaseDate,
  'cover': release.coverMedium,
  'tracks': [
    for (final track in release.tracks)
      {
        'id': track.id,
        'title': track.title,
        if (track.titleShort != track.title) 'short': track.titleShort,
        if (track.titleVersion.isNotEmpty) 'version': track.titleVersion,
        'duration': track.duration,
        'artist': track.artistId,
        'isrc': track.isrc,
        'preview': track.hasPreview,
      },
  ],
};

RawRelease _decodeRelease(Object? json) => switch (json) {
  {
        'id': final int id,
        'title': final String title,
        'kind': final String kind,
        'date': final String date,
        'tracks': final List<Object?> tracks,
      } &&
      final Map<String, Object?> fields =>
    RawRelease(
      id: id,
      title: title,
      kind: ReleaseKind.values.byName(kind),
      releaseDate: date,
      coverMedium: fields['cover'] as String?,
      tracks: List.unmodifiable(tracks.map(_decodeTrack)),
    ),
  _ => throw const ParseError('invalid catalogue release'),
};

RawTrack _decodeTrack(Object? json) => switch (json) {
  {
        'id': final int id,
        'title': final String title,
        'duration': final int duration,
        'artist': final int artistId,
        'isrc': final String isrc,
        'preview': final bool preview,
      } &&
      final Map<String, Object?> fields =>
    RawTrack(
      id: id,
      title: title,
      titleShort: fields['short'] as String? ?? title,
      titleVersion: fields['version'] as String? ?? '',
      duration: duration,
      artistId: artistId,
      isrc: isrc,
      hasPreview: preview,
    ),
  _ => throw const ParseError('invalid catalogue track'),
};
