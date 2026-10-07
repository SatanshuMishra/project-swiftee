import 'package:together_protocol/together_protocol.dart';

const Set<String> _loopbackHosts = {'localhost', '127.0.0.1', '::1'};

final class ServerLink {
  const ServerLink._({
    required this.host,
    required this.relayUri,
    required this.checkUri,
    required this.key,
  });

  static ServerLink? parse(String input) {
    final trimmed = input.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        trimmed.contains('@') ||
        uri.host.isEmpty ||
        uri.host.contains('%') ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        !isServerKey(uri.fragment)) {
      return null;
    }
    final secure = switch (uri.scheme) {
      'https' => true,
      'http' when _loopbackHosts.contains(uri.host) => false,
      _ => null,
    };
    if (secure == null) {
      return null;
    }
    final port = uri.hasPort ? uri.port : null;
    final hostName = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    return ServerLink._(
      host: port == null ? hostName : '$hostName:$port',
      relayUri: Uri(
        scheme: secure ? 'wss' : 'ws',
        host: uri.host,
        port: port,
        path: relayPath,
      ),
      checkUri: Uri(
        scheme: secure ? 'https' : 'http',
        host: uri.host,
        port: port,
        path: checkPath,
      ),
      key: uri.fragment,
    );
  }

  final String host;
  final Uri relayUri;
  final Uri checkUri;
  final String key;

  String get text => '${checkUri.scheme}://$host/#$key';

  @override
  bool operator ==(Object other) => other is ServerLink && other.text == text;

  @override
  int get hashCode => text.hashCode;
}
