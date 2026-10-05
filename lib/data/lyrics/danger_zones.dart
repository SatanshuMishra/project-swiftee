import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:swiftie_quiz/domain/models/lyrics.dart';

const String _lrclibHost = 'lrclib.net';
const String _exactMatchPath = '/api/get';
const Duration _fetchTimeout = Duration(seconds: 2);
const double _dangerZonePaddingSeconds = 1.5;
const double _previewLengthSeconds = 30;
const int _maxCacheSize = 100;
const Set<String> _stopWords = {
  'the',
  'a',
  'an',
  'i',
  'me',
  'my',
  'you',
  'your',
  'we',
  'our',
  'it',
  'its',
  'is',
  'am',
  'are',
  'was',
  'were',
  'be',
  'been',
  'do',
  'did',
  'to',
  'of',
  'in',
  'on',
  'at',
  'for',
  'and',
  'or',
  'so',
  'no',
  'not',
  'but',
  'if',
  'up',
  'out',
  'all',
  'just',
  'like',
  'this',
  'that',
  'with',
  'from',
};

final RegExp _lrcLine = RegExp(
  r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\][ \t]*(.*)',
);
final RegExp _parenthetical = RegExp(r'\s*\([^)]*\)\s*');
final RegExp _punctuation = RegExp(r'''['.,?!:;"]''');
final RegExp _whitespace = RegExp(r'\s+');

List<LrcLine> parseLrc(String raw) => List.unmodifiable(
  [
    for (final match in _lrcLine.allMatches(raw))
      if (match.group(4)!.trim() case final text when text.isNotEmpty)
        LrcLine(timeSeconds: _timestampSeconds(match), text: text),
  ].sortedBy<num>((line) => line.timeSeconds),
);

double _timestampSeconds(RegExpMatch match) {
  final minutes = int.parse(match.group(1)!);
  final seconds = int.parse(match.group(2)!);
  final fraction = match.group(3);
  final milliseconds = fraction == null
      ? 0
      : int.parse(fraction.padRight(3, '0'));
  return minutes * 60 + seconds + milliseconds / 1000;
}

double estimatePreviewOffset(List<LrcLine> lines, num songDurationSeconds) {
  if (lines.length < 4) {
    return songDurationSeconds.toDouble() * 0.3;
  }
  final normalized = [for (final line in lines) line.text.toLowerCase().trim()];
  for (var i = 0; i < normalized.length; i++) {
    if (normalized[i].length < 10) {
      continue;
    }
    final firstOccurrence = normalized.indexOf(normalized[i]);
    if (firstOccurrence < i) {
      return math.max(0.0, lines[firstOccurrence].timeSeconds - 2);
    }
  }
  return songDurationSeconds.toDouble() * 0.3;
}

String _normalizeTitle(String title) => title
    .toLowerCase()
    .replaceAll(_parenthetical, ' ')
    .replaceAll('-', ' ')
    .replaceAll(_punctuation, '')
    .replaceAll(_whitespace, ' ')
    .trim();

List<String> _extractTitleWords(String title) => List.unmodifiable(
  _normalizeTitle(title)
      .split(_whitespace)
      .where((word) => word.length > 1 && !_stopWords.contains(word)),
);

bool _lineContainsTitle(String lineText, List<String> titleWords) {
  if (titleWords.isEmpty) {
    return false;
  }
  final normalizedLine = _normalizeTitle(lineText);
  final matchCount = titleWords.where(normalizedLine.contains).length;
  final threshold = math.max(1, (titleWords.length * 0.6).ceil());
  return matchCount >= threshold;
}

List<DangerZone> _mergeZones(List<DangerZone> zones) {
  if (zones.isEmpty) {
    return const [];
  }
  final sorted = zones.sortedBy<num>((zone) => zone.start);
  return List.unmodifiable(
    sorted.skip(1).fold<List<DangerZone>>([sorted.first], (merged, current) {
      final previous = merged.last;
      return current.start <= previous.end
          ? [
              ...merged.take(merged.length - 1),
              DangerZone(
                start: previous.start,
                end: math.max(previous.end, current.end),
              ),
            ]
          : [...merged, current];
    }),
  );
}

List<DangerZone> findTitleDangerZones(
  List<LrcLine> lines,
  String title,
  String titleShort,
  double previewOffset,
) {
  final titleWords = _extractTitleWords(title);
  final shortWords = _extractTitleWords(titleShort);
  final words = shortWords.length >= titleWords.length
      ? shortWords
      : titleWords;
  final previewEnd = previewOffset + _previewLengthSeconds;
  return _mergeZones([
    for (final line in lines)
      if (line.timeSeconds >= previewOffset &&
          line.timeSeconds <= previewEnd &&
          _lineContainsTitle(line.text, words))
        _zoneAround(line.timeSeconds - previewOffset),
  ]);
}

DangerZone _zoneAround(double relativeTime) => DangerZone(
  start: math.max(0.0, relativeTime - _dangerZonePaddingSeconds),
  end: math.min(
    _previewLengthSeconds,
    relativeTime + _dangerZonePaddingSeconds,
  ),
);

String _buildCacheKey(String artist, String title) =>
    '${artist.toLowerCase()}::${title.toLowerCase()}';

class DangerZoneService {
  DangerZoneService({required this._client, required this._userAgent});

  final http.Client _client;
  final String _userAgent;
  Map<String, List<DangerZone>> _cache = const {};

  Future<List<DangerZone>> fetchDangerZones(
    String trackTitle,
    String artistName,
    String titleShort,
    num songDurationSeconds,
  ) async {
    final key = _buildCacheKey(artistName, trackTitle);
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }
    final zones = await _lookUp(
      trackTitle,
      artistName,
      titleShort,
      songDurationSeconds,
    );
    _remember(key, zones);
    return zones;
  }

  void clearDangerZoneCache() {
    _cache = const {};
  }

  Future<List<DangerZone>> _lookUp(
    String trackTitle,
    String artistName,
    String titleShort,
    num songDurationSeconds,
  ) async {
    try {
      final response = await _get(
        Uri.https(_lrclibHost, _exactMatchPath, {
          'artist_name': artistName,
          'track_name': trackTitle,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final syncedLyrics = switch (jsonDecode(
        utf8.decode(response.bodyBytes),
      )) {
        {'syncedLyrics': final String synced} when synced.isNotEmpty => synced,
        _ => null,
      };
      if (syncedLyrics == null) {
        return const [];
      }
      final lines = parseLrc(syncedLyrics);
      return findTitleDangerZones(
        lines,
        trackTitle,
        titleShort,
        estimatePreviewOffset(lines, songDurationSeconds),
      );
    } on Exception {
      return const [];
    }
  }

  Future<http.Response> _get(Uri uri) async {
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
          .timeout(_fetchTimeout);
    } on TimeoutException {
      abort.complete();
      rethrow;
    }
  }

  void _remember(String key, List<DangerZone> zones) {
    final kept = _cache.length >= _maxCacheSize
        ? Map.fromEntries(_cache.entries.skip(1))
        : _cache;
    _cache = Map.unmodifiable({
      ...kept,
      key: List<DangerZone>.unmodifiable(zones),
    });
  }
}
