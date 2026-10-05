import 'package:collection/collection.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

const Object _unchanged = Object();

final class TrackLyrics {
  const TrackLyrics({
    required this.lrclibId,
    required this._lines,
    required this.lineCount,
    required this.sourceTrack,
    required this.sourceAlbum,
  });

  final int lrclibId;
  final List<String> _lines;
  final int lineCount;
  final String sourceTrack;
  final String sourceAlbum;

  List<String> get lines => UnmodifiableListView(_lines);

  TrackLyrics copyWith({
    int? lrclibId,
    List<String>? lines,
    int? lineCount,
    String? sourceTrack,
    String? sourceAlbum,
  }) => TrackLyrics(
    lrclibId: lrclibId ?? this.lrclibId,
    lines: lines == null ? _lines : List.unmodifiable(lines),
    lineCount: lineCount ?? this.lineCount,
    sourceTrack: sourceTrack ?? this.sourceTrack,
    sourceAlbum: sourceAlbum ?? this.sourceAlbum,
  );

  @override
  bool operator ==(Object other) =>
      other is TrackLyrics &&
      other.lrclibId == lrclibId &&
      const ListEquality<String>().equals(other._lines, _lines) &&
      other.lineCount == lineCount &&
      other.sourceTrack == sourceTrack &&
      other.sourceAlbum == sourceAlbum;

  @override
  int get hashCode => Object.hash(
    lrclibId,
    const ListEquality<String>().hash(_lines),
    lineCount,
    sourceTrack,
    sourceAlbum,
  );

  @override
  String toString() =>
      'TrackLyrics(lrclibId: $lrclibId, lines: $_lines, '
      'lineCount: $lineCount, sourceTrack: $sourceTrack, '
      'sourceAlbum: $sourceAlbum)';
}

final class TrackWithLyrics {
  const TrackWithLyrics({required this.track, required this.lyrics});

  final Track track;
  final TrackLyrics lyrics;

  TrackWithLyrics copyWith({Track? track, TrackLyrics? lyrics}) =>
      TrackWithLyrics(
        track: track ?? this.track,
        lyrics: lyrics ?? this.lyrics,
      );

  @override
  bool operator ==(Object other) =>
      other is TrackWithLyrics &&
      other.track == track &&
      other.lyrics == lyrics;

  @override
  int get hashCode => Object.hash(track, lyrics);

  @override
  String toString() => 'TrackWithLyrics(track: $track, lyrics: $lyrics)';
}

final class LyricSnippet {
  const LyricSnippet({required this._lines, required this._sourceLineIndices});

  final List<String> _lines;
  final List<int> _sourceLineIndices;

  List<String> get lines => UnmodifiableListView(_lines);

  List<int> get sourceLineIndices => UnmodifiableListView(_sourceLineIndices);

  LyricSnippet copyWith({List<String>? lines, List<int>? sourceLineIndices}) =>
      LyricSnippet(
        lines: lines == null ? _lines : List.unmodifiable(lines),
        sourceLineIndices: sourceLineIndices == null
            ? _sourceLineIndices
            : List.unmodifiable(sourceLineIndices),
      );

  @override
  bool operator ==(Object other) =>
      other is LyricSnippet &&
      const ListEquality<String>().equals(other._lines, _lines) &&
      const ListEquality<int>().equals(
        other._sourceLineIndices,
        _sourceLineIndices,
      );

  @override
  int get hashCode => Object.hash(
    const ListEquality<String>().hash(_lines),
    const ListEquality<int>().hash(_sourceLineIndices),
  );

  @override
  String toString() =>
      'LyricSnippet(lines: $_lines, sourceLineIndices: $_sourceLineIndices)';
}

final class DecoyResult {
  const DecoyResult({
    required this._lines,
    required this.isReal,
    required this.sourceSong,
  });

  final List<String> _lines;
  final bool isReal;
  final String? sourceSong;

  List<String> get lines => UnmodifiableListView(_lines);

  DecoyResult copyWith({
    List<String>? lines,
    bool? isReal,
    Object? sourceSong = _unchanged,
  }) => DecoyResult(
    lines: lines == null ? _lines : List.unmodifiable(lines),
    isReal: isReal ?? this.isReal,
    sourceSong: identical(sourceSong, _unchanged)
        ? this.sourceSong
        : sourceSong as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is DecoyResult &&
      const ListEquality<String>().equals(other._lines, _lines) &&
      other.isReal == isReal &&
      other.sourceSong == sourceSong;

  @override
  int get hashCode => Object.hash(
    const ListEquality<String>().hash(_lines),
    isReal,
    sourceSong,
  );

  @override
  String toString() =>
      'DecoyResult(lines: $_lines, isReal: $isReal, sourceSong: $sourceSong)';
}

final class LrcLine {
  const LrcLine({required this.timeSeconds, required this.text});

  final double timeSeconds;
  final String text;

  LrcLine copyWith({double? timeSeconds, String? text}) => LrcLine(
    timeSeconds: timeSeconds ?? this.timeSeconds,
    text: text ?? this.text,
  );

  @override
  bool operator ==(Object other) =>
      other is LrcLine &&
      other.timeSeconds == timeSeconds &&
      other.text == text;

  @override
  int get hashCode => Object.hash(timeSeconds, text);

  @override
  String toString() => 'LrcLine(timeSeconds: $timeSeconds, text: $text)';
}

final class DangerZone {
  const DangerZone({required this.start, required this.end});

  final double start;
  final double end;

  DangerZone copyWith({double? start, double? end}) =>
      DangerZone(start: start ?? this.start, end: end ?? this.end);

  @override
  bool operator ==(Object other) =>
      other is DangerZone && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DangerZone(start: $start, end: $end)';
}
