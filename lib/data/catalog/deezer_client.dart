import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:swiftie_quiz/data/catalog/catalog_error.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/data/catalog/deezer_json.dart';
import 'package:swiftie_quiz/data/catalog/rate_limiter.dart';
import 'package:swiftie_quiz/data/catalog/response_cache.dart';
import 'package:swiftie_quiz/data/catalog/track_filter.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

final class DeezerClient {
  DeezerClient({
    required this._client,
    required this._userAgent,
    DateTime Function() now = DateTime.now,
  }) : _now = now,
       _rateLimiter = RateLimiter(now: now),
       _cache = ResponseCache(now: now);

  static const String baseUrl = 'https://api.deezer.com';
  static const String _apiHost = 'api.deezer.com';
  static const int artistId = 12246;
  static const Duration requestTimeout = Duration(seconds: 10);
  static const Duration previewExpiryMargin = Duration(seconds: 60);
  static const Duration unsignedPreviewLifetime = Duration(minutes: 10);

  static const String _albumsKey = 'albums';
  static const String _topTracksKey = 'top_tracks';
  static final RegExp _hdneaExpiry = RegExp(r'(?:^|~)exp=(\d{1,12})(?:~|$)');

  final http.Client _client;
  final String _userAgent;
  final DateTime Function() _now;
  final RateLimiter _rateLimiter;
  final ResponseCache _cache;

  Future<List<Album>> fetchAlbums() async {
    if (_cache.get<List<Album>>(_albumsKey) case final cached?) {
      return cached;
    }
    final albums = List<Album>.unmodifiable(
      await _pagesFrom(
        _endpoint('/artist/$artistId/albums?limit=100'),
        const {},
        parseAlbum,
      ),
    );
    _cache.put(_albumsKey, albums);
    return albums;
  }

  Future<AlbumTracks> fetchAlbumTracks(int albumId) async {
    if (albumId <= 0) {
      throw const ApiError('Invalid album ID');
    }
    final key = 'album_tracks:$albumId';
    if (_cache.get<AlbumTracks>(key) case final cached?) {
      return cached;
    }
    final detail = parseAlbumDetail(
      await _getJson(_endpoint('/album/$albumId')),
    );
    final tracks = List<Track>.unmodifiable([
      for (final (index, candidate) in detail.tracks.indexed)
        if (isPlayableSong(candidate))
          candidate.track.copyWith(
            album: detail.album,
            trackPosition: index + 1,
          ),
    ]);
    final albumTracks = AlbumTracks(tracks: tracks, totalTracks: tracks.length);
    _cache.put(key, albumTracks, expiresAt: _previewsExpireAt(tracks));
    return albumTracks;
  }

  Future<List<Track>> fetchTopTracks() async {
    if (_cache.get<List<Track>>(_topTracksKey) case final cached?) {
      return cached;
    }
    final page = parseDeezerPage(
      await _getJson(_endpoint('/artist/$artistId/top?limit=100')),
      parseDeezerTrack,
    );
    final tracks = List<Track>.unmodifiable(_playableSongs(page.data));
    _cache.put(_topTracksKey, tracks, expiresAt: _previewsExpireAt(tracks));
    return tracks;
  }

  Future<List<RawRelease>> fetchReleaseSummaries() async => List.unmodifiable(
    await _pagesFrom(
      _endpoint('/artist/$artistId/albums?limit=100'),
      const {},
      parseReleaseSummary,
    ),
  );

  Future<List<RawTrack>> fetchReleaseTracks(int releaseId) async {
    if (releaseId <= 0) {
      throw const ApiError('Invalid album ID');
    }
    return List.unmodifiable(
      await _pagesFrom(
        _endpoint('/album/$releaseId/tracks?limit=100'),
        const {},
        parseRawTrack,
      ),
    );
  }

  Future<Track> refreshTrack(int trackId) async =>
      parseDeezerTrack(await _getJson(_endpoint('/track/$trackId'))).track;

  Future<List<T>> _pagesFrom<T>(
    Uri page,
    Set<Uri> requested,
    T Function(Object? item) parseItem,
  ) async {
    final body = parseDeezerPage(await _getJson(page), parseItem);
    final seen = {...requested, page};
    final next = _followableNext(body.next, seen);
    return next == null
        ? body.data
        : [...body.data, ...await _pagesFrom(next, seen, parseItem)];
  }

  Iterable<Track> _playableSongs(Iterable<DeezerTrack> candidates) => [
    for (final candidate in candidates)
      if (isPlayableSong(candidate)) candidate.track,
  ];

  DateTime _previewsExpireAt(Iterable<Track> tracks) {
    final unsignedExpiry = _now().add(unsignedPreviewLifetime);
    return tracks
            .map(
              (track) => _signedPreviewExpiry(track.preview) ?? unsignedExpiry,
            )
            .minOrNull ??
        unsignedExpiry;
  }

  Future<Object?> _getJson(Uri url) async {
    _rateLimiter.acquire();
    final response = await _get(url);
    final body = _decodeBody(response);
    if (_deezerFailure(body) case final failure?) {
      throw failure;
    }
    if (!_succeeded(response)) {
      throw NetworkError('HTTP ${response.statusCode}');
    }
    return body;
  }

  Future<http.Response> _get(Uri url) async {
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      'GET',
      url,
      abortTrigger: abort.future,
    )..headers['User-Agent'] = _userAgent;
    try {
      return await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            requestTimeout,
            onTimeout: () {
              abort.complete();
              throw const NetworkError('request timed out');
            },
          );
    } on CatalogError {
      rethrow;
    } on http.ClientException catch (error) {
      throw NetworkError(error.message);
    } on Exception catch (error) {
      throw NetworkError('$error');
    }
  }

  static Uri _endpoint(String pathAndQuery) =>
      Uri.parse('$baseUrl$pathAndQuery');

  static Uri? _followableNext(String? next, Set<Uri> requested) =>
      switch (next == null ? null : Uri.tryParse(next)) {
        final Uri uri
            when uri.isScheme('https') &&
                uri.host == _apiHost &&
                uri.port == 443 &&
                uri.userInfo.isEmpty &&
                !requested.contains(uri) =>
          uri,
        _ => null,
      };

  static DateTime? _signedPreviewExpiry(String preview) {
    final token = Uri.tryParse(preview)?.queryParameters['hdnea'];
    final exp = token == null ? null : _hdneaExpiry.firstMatch(token)?[1];
    return exp == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            int.parse(exp) * 1000,
            isUtc: true,
          ).subtract(previewExpiryMargin);
  }

  static Object? _decodeBody(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw _succeeded(response)
          ? ParseError(error.message)
          : NetworkError('HTTP ${response.statusCode}');
    }
  }

  static CatalogError? _deezerFailure(Object? body) => switch (body) {
    {'error': {'code': 4}} => const RateLimited(),
    {'error': {'message': final String message}} => ApiError(message),
    {'error': final Object? error} => ApiError(jsonEncode(error)),
    _ => null,
  };

  static bool _succeeded(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;
}
