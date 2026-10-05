import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:swiftie_quiz/data/lyrics/lyrics_error.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

const String _lrclibHost = 'lrclib.net';
const String _exactMatchPath = '/api/get';
const String _searchPath = '/api/search';
const Duration _requestTimeout = Duration(seconds: 10);
const int _batchSize = 5;
const int _tooManyRequests = 429;
const Duration _defaultRetryAfter = Duration(seconds: 1);
const int _maxRetryAfterSeconds = 10;

final RegExp _trailingParenthetical = RegExp(r'\s*\([^)]*\)\s*$');
final RegExp _delaySeconds = RegExp(r'^\d+$');

typedef _LrclibRecord = ({
  int id,
  String trackName,
  String albumName,
  double duration,
  bool instrumental,
  String? plainLyrics,
});

typedef _BatchOutcome = ({int trackId, TrackLyrics? lyrics, bool cacheable});

String normaliseTitle(String title) {
  final stripped = title.replaceFirst(_trailingParenthetical, '');
  return stripped == title ? title.trim() : normaliseTitle(stripped);
}

List<String> processPlainLyrics(String raw) => List.unmodifiable(
  raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !_isSectionHeader(line)),
);

bool _isSectionHeader(String line) =>
    line.startsWith('[') && line.endsWith(']');

class LrclibClient {
  LrclibClient({
    required this._client,
    required this._userAgent,
    this._delay = Future<void>.delayed,
    this._now = DateTime.now,
  });

  final http.Client _client;
  final String _userAgent;
  final Future<void> Function(Duration) _delay;
  final DateTime Function() _now;
  Map<int, TrackLyrics?> _cache = const {};

  Future<TrackLyrics> fetchLyrics(Track track) async {
    if (_cache.containsKey(track.id)) {
      return _cache[track.id] ?? (throw const LyricsNotFound());
    }
    try {
      final lyrics = await _lookUp(track);
      _remember({track.id: lyrics});
      return lyrics;
    } on LyricsNotFound {
      _remember({track.id: null});
      rethrow;
    }
  }

  Future<Map<int, TrackLyrics?>> fetchLyricsBatch(List<Track> tracks) async {
    final pending = [
      for (final track in tracks)
        if (!_cache.containsKey(track.id)) track,
    ];
    var results = <int, TrackLyrics?>{
      for (final track in tracks)
        if (_cache.containsKey(track.id)) track.id: _cache[track.id],
    };
    for (final chunk in pending.slices(_batchSize)) {
      final outcomes = await Future.wait(chunk.map(_batchOutcome));
      _remember({
        for (final outcome in outcomes)
          if (outcome.cacheable) outcome.trackId: outcome.lyrics,
      });
      results = {
        ...results,
        for (final outcome in outcomes) outcome.trackId: outcome.lyrics,
      };
    }
    return Map.unmodifiable(results);
  }

  Future<_BatchOutcome> _batchOutcome(Track track) async {
    try {
      return (trackId: track.id, lyrics: await _lookUp(track), cacheable: true);
    } on LyricsNotFound {
      return (trackId: track.id, lyrics: null, cacheable: true);
    } on LyricsError {
      return (trackId: track.id, lyrics: null, cacheable: false);
    }
  }

  void _remember(Map<int, TrackLyrics?> entries) {
    _cache = Map.unmodifiable({..._cache, ...entries});
  }

  Future<TrackLyrics> _lookUp(Track track) async =>
      await _exactMatch(track) ??
      await _closestSearchMatch(track) ??
      (throw const LyricsNotFound());

  Future<TrackLyrics?> _exactMatch(Track track) async {
    final response = await _get(
      Uri.https(_lrclibHost, _exactMatchPath, {
        'track_name': track.title,
        'artist_name': track.artist.name,
        'album_name': track.album.title,
        'duration': '${track.duration}',
      }),
    );
    if (_isServerError(response.statusCode)) {
      throw const LyricsUnavailable();
    }
    if (!_isSuccess(response.statusCode)) {
      return null;
    }
    final record = _recordFrom(_decodeJson(response));
    return record == null || record.instrumental ? null : _lyricsFrom(record);
  }

  Future<TrackLyrics?> _closestSearchMatch(Track track) async {
    final response = await _get(
      Uri.https(_lrclibHost, _searchPath, {
        'track_name': normaliseTitle(track.title),
        'artist_name': track.artist.name,
      }),
    );
    if (!_isSuccess(response.statusCode)) {
      return null;
    }
    final candidates = (_recordsFrom(_decodeJson(response)) ?? const [])
        .where(
          (record) =>
              !record.instrumental &&
              (record.plainLyrics?.trim().isNotEmpty ?? false),
        )
        .toList();
    if (candidates.isEmpty) {
      return null;
    }
    final closest = candidates.reduce(
      (best, candidate) =>
          _durationGap(candidate, track.duration) <
              _durationGap(best, track.duration)
          ? candidate
          : best,
    );
    return _lyricsFrom(closest);
  }

  Future<http.Response> _get(Uri uri) async {
    final response = await _send(uri);
    if (response.statusCode != _tooManyRequests) {
      return response;
    }
    await _delay(_retryAfter(response.headers['retry-after']));
    final retried = await _send(uri);
    if (retried.statusCode == _tooManyRequests) {
      throw const LyricsUnavailable();
    }
    return retried;
  }

  Future<http.Response> _send(Uri uri) async {
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      'GET',
      uri,
      abortTrigger: abort.future,
    )..headers['User-Agent'] = _userAgent;
    try {
      return await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(_requestTimeout);
    } on TimeoutException {
      abort.complete();
      throw const LyricsUnavailable();
    } on Exception {
      throw const LyricsUnavailable();
    }
  }

  Duration _retryAfter(String? header) {
    final value = header?.trim() ?? '';
    if (_delaySeconds.hasMatch(value)) {
      final seconds = int.tryParse(value) ?? _maxRetryAfterSeconds;
      return Duration(seconds: math.min(seconds, _maxRetryAfterSeconds));
    }
    final untilDate = _untilHttpDate(value);
    if (untilDate == null) {
      return _defaultRetryAfter;
    }
    const ceiling = Duration(seconds: _maxRetryAfterSeconds);
    return untilDate.isNegative
        ? Duration.zero
        : (untilDate > ceiling ? ceiling : untilDate);
  }

  Duration? _untilHttpDate(String value) {
    try {
      return HttpDate.parse(value).difference(_now());
    } on HttpException {
      return null;
    }
  }
}

bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

bool _isServerError(int statusCode) => statusCode >= 500 && statusCode < 600;

int _durationGap(_LrclibRecord record, int targetSeconds) =>
    (record.duration.round() - targetSeconds).abs();

TrackLyrics? _lyricsFrom(_LrclibRecord record) {
  final plain = record.plainLyrics;
  if (plain == null) {
    return null;
  }
  final lines = processPlainLyrics(plain);
  return lines.isEmpty
      ? null
      : TrackLyrics(
          lrclibId: record.id,
          lines: lines,
          lineCount: lines.length,
          sourceTrack: record.trackName,
          sourceAlbum: record.albumName,
        );
}

Object? _decodeJson(http.Response response) {
  try {
    return jsonDecode(utf8.decode(response.bodyBytes));
  } on FormatException {
    return null;
  }
}

List<_LrclibRecord>? _recordsFrom(Object? json) {
  if (json is! List<Object?>) {
    return null;
  }
  final records = json.map(_recordFrom).toList();
  return records.contains(null) ? null : records.nonNulls.toList();
}

_LrclibRecord? _recordFrom(Object? json) {
  if (json is! Map<String, Object?>) {
    return null;
  }
  final plainLyrics = json['plainLyrics'];
  return switch (json) {
    {
      'id': final int id,
      'trackName': final String trackName,
      'artistName': String _,
      'albumName': final String albumName,
      'duration': final num duration,
      'instrumental': final bool instrumental,
    }
        when id >= 0 && duration.isFinite && (plainLyrics is String?) =>
      (
        id: id,
        trackName: trackName,
        albumName: albumName,
        duration: duration.toDouble(),
        instrumental: instrumental,
        plainLyrics: plainLyrics,
      ),
    _ => null,
  };
}
