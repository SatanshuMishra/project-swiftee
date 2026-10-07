import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:swiftie_quiz/data/catalog/catalog_error.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/data/catalog/deezer_json.dart';
import 'package:swiftie_quiz/data/catalog/rate_limiter.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

final class _Transient implements Exception {
  const _Transient(this.error);

  final NetworkError error;
}

final class DeezerClient {
  DeezerClient({
    required this._client,
    required this._userAgent,
    DateTime Function() now = DateTime.now,
    this._delay = Future<void>.delayed,
  }) : _rateLimiter = RateLimiter(now: now);

  static const String baseUrl = 'https://api.deezer.com';
  static const String _apiHost = 'api.deezer.com';
  static const int artistId = 12246;
  static const Duration requestTimeout = Duration(seconds: 10);
  static const Duration retryDelay = Duration(milliseconds: 500);

  final http.Client _client;
  final String _userAgent;
  final RateLimiter _rateLimiter;
  final Future<void> Function(Duration) _delay;

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

  Future<http.Response> _get(Uri url) {
    final abort = Completer<void>();
    return _attempts(url, abort.future).timeout(
      requestTimeout,
      onTimeout: () {
        abort.complete();
        throw const NetworkError('request timed out');
      },
    );
  }

  Future<http.Response> _attempts(Uri url, Future<void> abortTrigger) async {
    if (await _firstAttempt(url, abortTrigger) case final answered?) {
      return answered;
    }
    await _delay(retryDelay);
    try {
      return await _send(url, abortTrigger);
    } on _Transient catch (transient) {
      throw transient.error;
    }
  }

  Future<http.Response?> _firstAttempt(
    Uri url,
    Future<void> abortTrigger,
  ) async {
    try {
      final response = await _send(url, abortTrigger);
      return response.statusCode >= 500 ? null : response;
    } on _Transient {
      return null;
    }
  }

  Future<http.Response> _send(Uri url, Future<void> abortTrigger) async {
    final request = http.AbortableRequest(
      'GET',
      url,
      abortTrigger: abortTrigger,
    )..headers['User-Agent'] = _userAgent;
    try {
      return await _client.send(request).then(http.Response.fromStream);
    } on http.ClientException catch (error) {
      throw _Transient(NetworkError(error.message));
    } on Exception catch (error) {
      throw _Transient(NetworkError('$error'));
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
