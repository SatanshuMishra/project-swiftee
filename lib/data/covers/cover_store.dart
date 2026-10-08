import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

const String bundledCoversFolder = 'assets/covers';
const String savedCoversFolderName = 'covers';

final RegExp _deezerCover = RegExp(
  r'^https://(?:cdn-images|e-cdns-images)\.dzcdn\.net/images/cover/'
  r'([0-9a-f]{32})/',
);
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
    required this._folder,
    required this._save,
    this.timeout = const Duration(seconds: 10),
    this.retryAfter = const Duration(seconds: 1),
  });

  static const int attempts = 2;

  final http.Client _client;
  final Future<Set<String>> Function() _bundledKeys;
  final Future<Uint8List> Function(String asset) _loadAsset;
  final Directory Function() _folder;
  final bool Function() _save;
  final Duration timeout;
  final Duration retryAfter;

  late final Future<Set<String>> _bundled = _bundledKeys();
  int _forgotten = 0;
  int _written = 0;
  Set<Future<void>> _writes = const {};

  Future<Uint8List> load(String url) async {
    final key = coverKey(url);
    if (key != null && (await _bundled).contains(key)) {
      return _loadAsset(bundledCoverAsset(key));
    }
    final kept = key == null ? null : _keptFile(key);
    if (kept != null) {
      if (await _readKept(kept) case final bytes?) {
        return bytes;
      }
    }
    final forgotten = _forgotten;
    final bytes = await _download(Uri.parse(url));
    if (kept != null) {
      await _track(_keep(kept, bytes, forgotten));
    }
    return bytes;
  }

  Future<void> forget() async {
    _forgotten += 1;
    await Future.wait(_writes);
    final folder = _folderOrNull();
    try {
      if (folder != null && await folder.exists()) {
        await folder.delete(recursive: true);
      }
    } on FileSystemException catch (error, stackTrace) {
      _log('Kept covers could not be removed', error, stackTrace);
    }
  }

  File? _keptFile(String key) => switch (_save() ? _folderOrNull() : null) {
    final folder? => File(p.join(folder.path, '$key.jpg')),
    null => null,
  };

  Directory? _folderOrNull() {
    try {
      return _folder();
    } on Object catch (error, stackTrace) {
      _log('The covers folder could not be found', error, stackTrace);
      return null;
    }
  }

  Future<Uint8List?> _readKept(File file) async {
    try {
      if (!await file.exists()) {
        return null;
      }
      final bytes = await file.readAsBytes();
      if (_isImage(bytes)) {
        return bytes;
      }
      await file.delete();
    } on FileSystemException catch (error, stackTrace) {
      _log('A kept cover could not be read', error, stackTrace);
    }
    return null;
  }

  Future<void> _track(Future<void> write) async {
    _writes = {..._writes, write};
    try {
      await write;
    } finally {
      _writes = {
        for (final pending in _writes)
          if (!identical(pending, write)) pending,
      };
    }
  }

  Future<void> _keep(File file, Uint8List bytes, int forgotten) async {
    if (forgotten != _forgotten || !_save()) {
      return;
    }
    _written += 1;
    final temp = File('${file.path}.$_written.tmp');
    try {
      await file.parent.create(recursive: true);
      await temp.writeAsBytes(bytes, flush: true);
      if (forgotten == _forgotten && _save()) {
        await temp.rename(file.path);
      } else {
        await temp.delete();
      }
    } on FileSystemException catch (error, stackTrace) {
      _log('A cover could not be kept', error, stackTrace);
      await temp.delete().then<void>((_) {}, onError: (Object _) {});
    }
  }

  Future<Uint8List> _download(Uri uri, [int attempt = 1]) async {
    final http.Response response;
    try {
      response = await _send(uri);
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

  Future<http.Response> _send(Uri uri) async {
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      'GET',
      uri,
      abortTrigger: abort.future,
    );
    try {
      return await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on TimeoutException {
      abort.complete();
      rethrow;
    }
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

  static void _log(String message, Object error, StackTrace stackTrace) =>
      developer.log(
        message,
        name: 'swiftie_quiz.covers',
        error: error,
        stackTrace: stackTrace,
      );

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
