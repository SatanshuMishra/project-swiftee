import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

sealed class PreviewError implements Exception {
  const PreviewError();

  String get message;

  @override
  String toString() => message;
}

final class PreviewForbidden extends PreviewError {
  const PreviewForbidden();

  @override
  String get message => 'Preview download failed: HTTP 403';

  @override
  bool operator ==(Object other) => other is PreviewForbidden;

  @override
  int get hashCode => (PreviewForbidden).hashCode;
}

final class PreviewDownloadFailed extends PreviewError {
  const PreviewDownloadFailed(this.status);

  final int status;

  @override
  String get message => 'Preview download failed: HTTP $status';

  @override
  bool operator ==(Object other) =>
      other is PreviewDownloadFailed && other.status == status;

  @override
  int get hashCode => Object.hash(PreviewDownloadFailed, status);
}

final class PreviewMissing extends PreviewError {
  const PreviewMissing();

  @override
  String get message => 'This song has no preview right now';

  @override
  bool operator ==(Object other) => other is PreviewMissing;

  @override
  int get hashCode => (PreviewMissing).hashCode;
}

final class PreviewUnreachable extends PreviewError {
  const PreviewUnreachable(this.detail);

  final String detail;

  @override
  String get message => 'Preview download failed: $detail';

  @override
  bool operator ==(Object other) =>
      other is PreviewUnreachable && other.detail == detail;

  @override
  int get hashCode => Object.hash(PreviewUnreachable, detail);
}

final class PreviewDownloader {
  PreviewDownloader(this._client, this._userAgent);

  static const Duration requestTimeout = Duration(seconds: 10);
  static const int maxRedirects = 5;
  static const Set<int> _redirectStatuses = {301, 302, 303, 307, 308};
  static const String _signedPreviewHost = 'cdnt-preview.dzcdn.net';
  static final RegExp _shardedPreviewHost = RegExp(
    r'^cdns-preview-[a-z0-9]+\.dzcdn\.net$',
  );

  final http.Client _client;
  final String _userAgent;

  Future<Uint8List> download(Uri previewUrl) async {
    final abort = Completer<void>();
    try {
      return await _fetch(previewUrl, abort.future, maxRedirects).timeout(
        requestTimeout,
        onTimeout: () {
          abort.complete();
          throw const PreviewUnreachable('request timed out');
        },
      );
    } on PreviewError {
      rethrow;
    } on http.ClientException catch (error) {
      throw PreviewUnreachable(error.message);
    } on Exception catch (error) {
      throw PreviewUnreachable('$error');
    }
  }

  static bool isTrustedPreviewUrl(Uri url) =>
      url.isScheme('https') &&
      url.port == 443 &&
      url.userInfo.isEmpty &&
      (url.host == _signedPreviewHost ||
          _shardedPreviewHost.hasMatch(url.host));

  Future<Uint8List> _fetch(
    Uri url,
    Future<void> abortTrigger,
    int redirectsLeft,
  ) async {
    if (!isTrustedPreviewUrl(url)) {
      throw const PreviewUnreachable('untrusted preview link');
    }
    final request =
        http.AbortableRequest('GET', url, abortTrigger: abortTrigger)
          ..followRedirects = false
          ..headers['User-Agent'] = _userAgent;
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    return switch ((response.statusCode, response.headers['location'])) {
      (403, _) => throw const PreviewForbidden(),
      (final status, _) when status >= 200 && status < 300 =>
        response.bodyBytes,
      (final status, final String location)
          when _redirectStatuses.contains(status) && redirectsLeft > 0 =>
        await _fetch(url.resolve(location), abortTrigger, redirectsLeft - 1),
      (final status, _) => throw PreviewDownloadFailed(status),
    };
  }
}
