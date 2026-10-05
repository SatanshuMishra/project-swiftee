import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';
import 'package:swiftie_quiz/services/updater/minisign.dart' as minisign;
import 'package:swiftie_quiz/services/updater/update_config.dart';
import 'package:swiftie_quiz/services/updater/update_manifest_client.dart';

sealed class DownloadEvent {
  const DownloadEvent();
}

final class DownloadStarted extends DownloadEvent {
  const DownloadStarted({required this.contentLength});

  final int? contentLength;

  @override
  bool operator ==(Object other) =>
      other is DownloadStarted && other.contentLength == contentLength;

  @override
  int get hashCode => Object.hash(DownloadStarted, contentLength);

  @override
  String toString() => 'DownloadStarted(contentLength: $contentLength)';
}

final class DownloadProgress extends DownloadEvent {
  const DownloadProgress({required this.chunkLength});

  final int chunkLength;

  @override
  bool operator ==(Object other) =>
      other is DownloadProgress && other.chunkLength == chunkLength;

  @override
  int get hashCode => Object.hash(DownloadProgress, chunkLength);

  @override
  String toString() => 'DownloadProgress(chunkLength: $chunkLength)';
}

final class DownloadFinished extends DownloadEvent {
  const DownloadFinished();

  @override
  bool operator ==(Object other) => other is DownloadFinished;

  @override
  int get hashCode => (DownloadFinished).hashCode;

  @override
  String toString() => 'DownloadFinished()';
}

final class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class UpdateSignatureException implements Exception {
  const UpdateSignatureException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UpdateDownloader {
  const UpdateDownloader({
    required this._client,
    required this._userAgent,
    this._publicKey = updaterPublicKey,
  });

  final http.Client _client;
  final String _userAgent;
  final String _publicKey;

  Future<Uint8List> download(
    AvailableUpdate update, {
    required void Function(DownloadEvent event) onEvent,
  }) async {
    final bytes = await _receive(update.url, onEvent);
    onEvent(const DownloadFinished());
    await _verify(bytes, update);
    return bytes;
  }

  Future<Uint8List> _receive(
    Uri url,
    void Function(DownloadEvent event) onEvent,
  ) async {
    try {
      final request = http.Request('GET', url);
      request.headers.addAll({
        'User-Agent': _userAgent,
        'Accept': 'application/octet-stream',
      });
      final response = await _client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final reason = response.reasonPhrase;
        throw UpdateDownloadException(
          'Download request failed with status: ${response.statusCode}'
          '${reason == null || reason.isEmpty ? '' : ' $reason'}',
        );
      }
      onEvent(DownloadStarted(contentLength: response.contentLength));
      final received = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        onEvent(DownloadProgress(chunkLength: chunk.length));
        received.add(chunk);
      }
      return received.takeBytes();
    } on http.ClientException catch (error) {
      throw UpdateDownloadException(error.message);
    }
  }

  Future<void> _verify(Uint8List bytes, AvailableUpdate update) async {
    final String trustedComment;
    try {
      trustedComment = await minisign.verify(
        bytes,
        update.signature,
        _publicKey,
      );
    } on minisign.MinisignException catch (error) {
      throw UpdateSignatureException(error.message);
    }
    final signedVersion = _signedVersion(trustedComment);
    final announcedVersion = update.manifest.version;
    if (signedVersion != null &&
        !_sameVersion(signedVersion, announcedVersion)) {
      throw UpdateSignatureException(
        'The update was signed for version $signedVersion but the update '
        'endpoint announced version $announcedVersion. The endpoint response '
        'may have been tampered with to force installing a different release.',
      );
    }
  }

  static String? _signedVersion(String trustedComment) {
    const prefix = 'version:';
    for (final field in trustedComment.split('\t')) {
      if (field.startsWith(prefix)) {
        return field.substring(prefix.length);
      }
    }
    return null;
  }

  static bool _sameVersion(String signed, String announced) {
    try {
      return Version.parse(_withoutLeadingV(signed)) ==
          Version.parse(_withoutLeadingV(announced));
    } on FormatException {
      return signed == announced;
    }
  }

  static String _withoutLeadingV(String version) =>
      version.replaceFirst(RegExp('^v+'), '');
}
