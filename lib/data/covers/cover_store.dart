import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

const String bundledCoversFolder = 'assets/covers';
const String savedCoversFolderName = 'covers';

final RegExp _deezerCover = RegExp(r'/images/cover/([0-9a-f]{32})/');
final RegExp _bundledCover = RegExp(
  '^${RegExp.escape(bundledCoversFolder)}/([0-9a-f]{32})\\.jpg\$',
);

String? coverKey(String url) => _deezerCover.firstMatch(url)?.group(1);

String bundledCoverAsset(String key) => '$bundledCoversFolder/$key.jpg';

String deezerCoverUrl(String key, int size) =>
    'https://cdn-images.dzcdn.net/images/cover/$key/'
    '${size}x$size-000000-80-0-0.jpg';

Set<String> bundledCoverKeys(Iterable<String> assets) => {
  for (final asset in assets) ?_bundledCover.firstMatch(asset)?.group(1),
};

final class CoverUnavailable implements Exception {
  const CoverUnavailable(this.url, this.reason);

  final String url;
  final String reason;

  @override
  String toString() => 'CoverUnavailable($url: $reason)';
}

final class CoverStore {
  CoverStore({
    required this._client,
    required this._bundledKeys,
    required this._loadAsset,
    required this.folder,
    required this.save,
    this.timeout = const Duration(seconds: 10),
    this.retryAfter = const Duration(seconds: 1),
  });

  static const int attempts = 2;

  final http.Client _client;
  final Future<Set<String>> Function() _bundledKeys;
  final Future<Uint8List> Function(String asset) _loadAsset;
  final Directory folder;
  final bool save;
  final Duration timeout;
  final Duration retryAfter;

  late final Future<Set<String>> _bundled = _bundledKeys();

  Future<Uint8List> load(String url) async {
    final key = coverKey(url);
    if (key != null && (await _bundled).contains(key)) {
      return _loadAsset(bundledCoverAsset(key));
    }
    final kept = key != null && save
        ? File(p.join(folder.path, '$key.jpg'))
        : null;
    if (kept != null && await kept.exists()) {
      return kept.readAsBytes();
    }
    final bytes = await _download(Uri.parse(url));
    if (kept != null) {
      await _keep(kept, bytes);
    }
    return bytes;
  }

  Future<void> forget() async {
    if (await folder.exists()) {
      await folder.delete(recursive: true);
    }
  }

  Future<Uint8List> _download(Uri uri, [int attempt = 1]) async {
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } on Object catch (error) {
      return _retryOr(uri, attempt, CoverUnavailable('$uri', '$error'));
    }
    final status = response.statusCode;
    if (status == HttpStatus.ok && _isImage(response.bodyBytes)) {
      return response.bodyBytes;
    }
    final failure = CoverUnavailable(
      '$uri',
      status == HttpStatus.ok ? 'not an image' : 'HTTP $status',
    );
    return _transient(status) ? _retryOr(uri, attempt, failure) : throw failure;
  }

  Future<Uint8List> _retryOr(
    Uri uri,
    int attempt,
    CoverUnavailable failure,
  ) async {
    if (attempt >= attempts) {
      throw failure;
    }
    await Future<void>.delayed(retryAfter);
    return _download(uri, attempt + 1);
  }

  Future<void> _keep(File file, Uint8List bytes) async {
    final temp = File('${file.path}.tmp');
    try {
      await file.parent.create(recursive: true);
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
    } on FileSystemException catch (error, stackTrace) {
      developer.log(
        'A cover could not be kept',
        name: 'swiftie_quiz.covers',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static bool _transient(int status) =>
      status == HttpStatus.requestTimeout ||
      status == HttpStatus.tooManyRequests ||
      status >= HttpStatus.internalServerError;

  static bool _isImage(Uint8List bytes) => switch (bytes) {
    [0xFF, 0xD8, 0xFF, ...] => true,
    [0x89, 0x50, 0x4E, 0x47, ...] => true,
    [0x52, 0x49, 0x46, 0x46, _, _, _, _, 0x57, 0x45, 0x42, 0x50, ...] => true,
    _ => false,
  };
}
