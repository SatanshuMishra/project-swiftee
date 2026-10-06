import 'dart:math';

import 'package:collection/collection.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

final class PlayHistory {
  const PlayHistory._({
    required this._heard,
    required this._read,
    required this._lines,
  });

  static const PlayHistory empty = PlayHistory._(
    heard: [],
    read: [],
    lines: [],
  );
  static const int limit = 2000;

  final List<Track> _heard;
  final List<String> _read;
  final List<String> _lines;

  List<Track> get heard => UnmodifiableListView(_heard);
  List<String> get read => UnmodifiableListView(_read);
  List<String> get lines => UnmodifiableListView(_lines);

  PlayHistory hear(Track track) => PlayHistory._(
    heard: _appended(_heard, [track]),
    read: _read,
    lines: _lines,
  );

  PlayHistory readLyrics(String song, Iterable<String> shown) => PlayHistory._(
    heard: _heard,
    read: _appended(_read, [song]),
    lines: _appended(_lines, shown),
  );

  static List<T> _appended<T>(List<T> list, Iterable<T> more) {
    final all = [...list, ...more];
    return List.unmodifiable(all.sublist(max(0, all.length - limit)));
  }

  @override
  bool operator ==(Object other) =>
      other is PlayHistory &&
      const ListEquality<Track>().equals(other._heard, _heard) &&
      const ListEquality<String>().equals(other._read, _read) &&
      const ListEquality<String>().equals(other._lines, _lines);

  @override
  int get hashCode => Object.hash(
    const ListEquality<Track>().hash(_heard),
    const ListEquality<String>().hash(_read),
    const ListEquality<String>().hash(_lines),
  );

  @override
  String toString() =>
      'PlayHistory(heard: ${_heard.length}, read: ${_read.length}, '
      'lines: ${_lines.length})';
}
