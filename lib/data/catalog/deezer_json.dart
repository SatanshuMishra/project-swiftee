import 'package:swiftie_quiz/data/catalog/catalog_error.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

typedef DeezerTrack = ({Track track, String titleVersion});

typedef DeezerPage<T> = ({List<T> data, String? next});

const Album _absentAlbum = Album(id: 0, title: '', coverMedium: null);

Artist parseArtist(Object? json) {
  final fields = _object(json, 'artist');
  return Artist(
    id: _requiredCount(fields, 'id'),
    name: _requiredString(fields, 'name'),
  );
}

Album parseAlbum(Object? json) {
  final fields = _object(json, 'album');
  return Album(
    id: _defaultedCount(fields, 'id'),
    title: _defaultedString(fields, 'title'),
    coverMedium: _optionalString(fields, 'cover_medium'),
  );
}

DeezerTrack parseDeezerTrack(Object? json) {
  final fields = _object(json, 'track');
  return (
    track: Track(
      id: _requiredCount(fields, 'id'),
      title: _requiredString(fields, 'title'),
      titleShort: _defaultedString(fields, 'title_short'),
      duration: _requiredCount(fields, 'duration'),
      preview: _optionalString(fields, 'preview') ?? '',
      artist: parseArtist(_required(fields, 'artist')),
      album: fields.containsKey('album')
          ? parseAlbum(fields['album'])
          : _absentAlbum,
    ),
    titleVersion: _optionalString(fields, 'title_version') ?? '',
  );
}

DeezerPage<T> parseDeezerPage<T>(
  Object? json,
  T Function(Object? item) parseItem,
) {
  final fields = _object(json, 'response');
  return (
    data: _list(fields, 'data', parseItem),
    next: _optionalString(fields, 'next'),
  );
}

Map<String, Object?> _object(Object? json, String name) => switch (json) {
  final Map<String, Object?> fields => fields,
  _ => throw ParseError('expected $name to be an object'),
};

Object? _required(Map<String, Object?> fields, String key) =>
    fields.containsKey(key)
    ? fields[key]
    : throw ParseError('missing field `$key`');

int _requiredCount(Map<String, Object?> fields, String key) =>
    _count(_required(fields, key), key);

int _defaultedCount(Map<String, Object?> fields, String key) =>
    fields.containsKey(key) ? _count(fields[key], key) : 0;

int _count(Object? value, String key) => switch (value) {
  final int count when count >= 0 => count,
  _ => throw ParseError('invalid value for field `$key`'),
};

String _requiredString(Map<String, Object?> fields, String key) =>
    _string(_required(fields, key), key);

String _defaultedString(Map<String, Object?> fields, String key) =>
    fields.containsKey(key) ? _string(fields[key], key) : '';

String? _optionalString(Map<String, Object?> fields, String key) =>
    fields[key] == null ? null : _string(fields[key], key);

String _string(Object? value, String key) => switch (value) {
  final String text => text,
  _ => throw ParseError('invalid value for field `$key`'),
};

List<T> _list<T>(
  Map<String, Object?> fields,
  String key,
  T Function(Object? item) parseItem,
) => switch (_required(fields, key)) {
  final List<Object?> items => List.unmodifiable(items.map(parseItem)),
  _ => throw ParseError('invalid value for field `$key`'),
};
