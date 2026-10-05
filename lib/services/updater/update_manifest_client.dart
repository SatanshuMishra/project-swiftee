import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/services/updater/update_config.dart';

final class AvailableUpdate {
  const AvailableUpdate({
    required this.manifest,
    required this.url,
    required this.signature,
  });

  final UpdateManifest manifest;
  final Uri url;
  final String signature;

  AvailableUpdate copyWith({
    UpdateManifest? manifest,
    Uri? url,
    String? signature,
  }) => AvailableUpdate(
    manifest: manifest ?? this.manifest,
    url: url ?? this.url,
    signature: signature ?? this.signature,
  );

  @override
  bool operator ==(Object other) =>
      other is AvailableUpdate &&
      other.manifest == manifest &&
      other.url == url &&
      other.signature == signature;

  @override
  int get hashCode => Object.hash(manifest, url, signature);

  @override
  String toString() =>
      'AvailableUpdate(manifest: $manifest, url: $url, signature: $signature)';
}

final class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UpdateManifestClient {
  const UpdateManifestClient({
    required this._client,
    required this._userAgent,
    required this._platform,
    this._endpoint = updateEndpoint,
    this._timeout = updateCheckTimeout,
  });

  final http.Client _client;
  final String _userAgent;
  final UpdatePlatform _platform;
  final String _endpoint;
  final Duration _timeout;

  Future<AvailableUpdate?> check(String runningVersion) async {
    final current = _parseVersion(runningVersion, 'running version');
    final response = await _fetch();
    if (response.statusCode == 204) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const UpdateCheckException(
        'Could not fetch a valid release JSON from the remote',
      );
    }
    final release = _parseRelease(response.bodyBytes);
    return release.version > current ? release.update : null;
  }

  Future<http.Response> _fetch() async {
    try {
      return await _client
          .get(
            Uri.parse(_endpoint),
            headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw UpdateCheckException(
        'The update check timed out after ${_timeout.inSeconds} seconds',
      );
    } on http.ClientException catch (error) {
      throw UpdateCheckException(error.message);
    }
  }

  _RemoteRelease _parseRelease(List<int> body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(body));
    } on FormatException catch (error) {
      throw UpdateCheckException('Invalid update manifest: ${error.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw const UpdateCheckException(
        'Invalid update manifest: expected a JSON object',
      );
    }
    final versionText = _requiredString(decoded, 'version');
    final version = _parseVersion(
      versionText.replaceFirst(RegExp('^v+'), ''),
      'version',
    );
    final notes = _optionalString(decoded, 'notes') ?? '';
    final pubDate = _optionalString(decoded, 'pub_date');
    if (pubDate != null && DateTime.tryParse(pubDate) == null) {
      throw UpdateCheckException(
        'invalid value for `pub_date`: $pubDate is not a date',
      );
    }
    final platform = _platformEntry(decoded);
    return _RemoteRelease(
      version: version,
      update: AvailableUpdate(
        manifest: UpdateManifest(
          version: version.toString(),
          notes: notes,
          pubDate: pubDate ?? '',
        ),
        url: _downloadUrl(_requiredString(platform, 'url')),
        signature: _requiredString(platform, 'signature'),
      ),
    );
  }

  Map<String, Object?> _platformEntry(Map<String, Object?> release) {
    final platforms = release['platforms'];
    if (platforms is! Map<String, Object?>) {
      throw const UpdateCheckException(
        'Invalid update manifest: `platforms` is missing',
      );
    }
    final entry = platforms[_platform.manifestKey];
    if (entry is! Map<String, Object?>) {
      throw UpdateCheckException(
        'the platform `${_platform.manifestKey}` was not found in the '
        'response `platforms` object',
      );
    }
    return entry;
  }

  static Uri _downloadUrl(String text) {
    final url = Uri.tryParse(text);
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      throw UpdateCheckException(
        'Invalid update manifest: $text is not an https URL',
      );
    }
    return url;
  }

  static Version _parseVersion(String text, String field) {
    try {
      return Version.parse(text);
    } on FormatException {
      throw UpdateCheckException(
        'Invalid $field: $text is not a semantic version',
      );
    }
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw UpdateCheckException('Invalid update manifest: `$key` is missing');
    }
    return value;
  }

  static String? _optionalString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value != null && value is! String) {
      throw UpdateCheckException(
        'Invalid update manifest: `$key` is not a string',
      );
    }
    return value as String?;
  }
}

final class _RemoteRelease {
  const _RemoteRelease({required this.version, required this.update});

  final Version version;
  final AvailableUpdate update;
}
