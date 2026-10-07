import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:together_protocol/together_protocol.dart';

import 'relay_limits.dart';
import 'rooms.dart';

const _welcome =
    'Project Swiftie relay. Copy the whole link into Project Swiftie → '
    'Settings → Play together.';
const _cloudflareAddressHeader = 'cf-connecting-ip';

final class RelayServer {
  RelayServer._({
    required this._server,
    required String key,
    required this._limits,
    required this._trustCloudflareAddress,
    required Random random,
    required this._log,
  }) : _authorization = utf8.encode('$bearerPrefix$key') {
    _rooms = Rooms(limits: _limits, random: random, report: _report);
  }

  static Future<RelayServer> start({
    required String key,
    InternetAddress? address,
    int port = 8080,
    RelayLimits limits = const RelayLimits(),
    bool trustCloudflareAddress = false,
    Random? random,
    void Function(String line)? log,
  }) async {
    if (!isServerKey(key)) {
      throw ArgumentError('must be 43 base64url characters', 'key');
    }
    final server = await HttpServer.bind(
      address ?? InternetAddress.anyIPv4,
      port,
    );
    final relay = RelayServer._(
      server: server,
      key: key,
      limits: limits,
      trustCloudflareAddress: trustCloudflareAddress,
      random: random ?? Random.secure(),
      log: log ?? (_) {},
    );
    server.listen(
      (request) => unawaited(relay._serve(request)),
      onError: (Object _) => relay._report('listener error'),
    );
    relay._report('relay started');
    return relay;
  }

  final HttpServer _server;
  final List<int> _authorization;
  final RelayLimits _limits;
  final bool _trustCloudflareAddress;
  final void Function(String line) _log;
  final _clock = Stopwatch()..start();
  late final Rooms _rooms;

  var _sockets = 0;
  var _socketsByAddress = const <String, int>{};
  var _failures = const <String, List<Duration>>{};
  var _sessions = const <Future<void>>{};
  var _stopping = false;
  Future<void>? _stopped;

  int get port => _server.port;

  Future<void> close() => _stopped ??= _stop();

  Future<void> _stop() async {
    _stopping = true;
    await _server.close(force: true);
    _rooms.closeAll();
    await Future.wait(_sessions);
    _report('relay stopped');
  }

  Future<void> _serve(HttpRequest request) async {
    if (request.method != 'GET') {
      _answer(
        request,
        HttpStatus.methodNotAllowed,
        headers: const {'allow': 'GET'},
      );
      return;
    }
    switch (request.uri.path) {
      case '/':
        _answer(request, HttpStatus.ok, text: _welcome);
      case '/healthz':
        _answer(request, HttpStatus.ok, text: 'ok');
      case checkPath || relayPath:
        await _gate(request);
      default:
        _answer(request, HttpStatus.notFound);
    }
  }

  Future<void> _gate(HttpRequest request) async {
    final address = _addressOf(request);
    if (_recentFailures(address).length >= _limits.authFailures) {
      _refuse(request, statusTooMany);
    } else if (!_holdsKey(request)) {
      _recordFailure(address);
      _refuse(
        request,
        statusBadKey,
        headers: const {'www-authenticate': 'Bearer'},
      );
    } else if (_single(request.headers, relayProtocolHeader) !=
        '$relayProtocolVersion') {
      _refuse(request, statusNeedsUpdate);
    } else if (request.uri.path == checkPath) {
      _answer(request, statusChecked);
    } else if (_sockets >= _limits.maxSockets ||
        (_socketsByAddress[address] ?? 0) >= _limits.maxSocketsPerAddress) {
      _refuse(request, statusBusy);
    } else if (!WebSocketTransformer.isUpgradeRequest(request)) {
      _answer(request, HttpStatus.badRequest);
    } else {
      await _connect(request, address);
    }
  }

  Future<void> _connect(HttpRequest request, String address) async {
    _hold(address, 1);
    final WebSocket socket;
    try {
      socket = await WebSocketTransformer.upgrade(
        request,
        compression: CompressionOptions.compressionOff,
      );
    } on Exception {
      _hold(address, -1);
      return;
    }
    if (_stopping) {
      socket.close(WebSocketStatus.goingAway).ignore();
      _hold(address, -1);
      return;
    }
    socket.pingInterval = _limits.pingInterval;
    _report('socket opened');
    final session = _rooms.accept(socket);
    _sessions = Set.unmodifiable({..._sessions, session});
    await session;
    _sessions = Set.unmodifiable(_sessions.where((other) => other != session));
    _hold(address, -1);
    _report('socket closed');
  }

  String _addressOf(HttpRequest request) {
    final forwarded = _trustCloudflareAddress
        ? _single(request.headers, _cloudflareAddressHeader)?.trim()
        : null;
    return forwarded != null && forwarded.isNotEmpty
        ? forwarded
        : request.connectionInfo?.remoteAddress.address ?? '';
  }

  bool _holdsKey(HttpRequest request) {
    final given = utf8.encode(
      _single(request.headers, HttpHeaders.authorizationHeader) ?? '',
    );
    var difference = _authorization.length ^ given.length;
    for (var i = 0; i < _authorization.length; i++) {
      difference |= _authorization[i] ^ (i < given.length ? given[i] : 0);
    }
    return difference == 0;
  }

  List<Duration> _recentFailures(String address) {
    final now = _clock.elapsed;
    return [
      for (final at in _failures[address] ?? const <Duration>[])
        if (now - at < _limits.authWindow) at,
    ];
  }

  void _recordFailure(String address) {
    final now = _clock.elapsed;
    _failures = Map.unmodifiable({
      for (final MapEntry(key: other, :value) in _failures.entries)
        if (other != address && now - value.last < _limits.authWindow)
          other: value,
      address: List<Duration>.unmodifiable([..._recentFailures(address), now]),
    });
  }

  void _hold(String address, int change) {
    final held = (_socketsByAddress[address] ?? 0) + change;
    _sockets += change;
    _socketsByAddress = Map.unmodifiable({
      for (final MapEntry(key: other, :value) in _socketsByAddress.entries)
        if (other != address) other: value,
      if (held > 0) address: held,
    });
  }

  void _refuse(
    HttpRequest request,
    int status, {
    Map<String, String> headers = const {},
  }) {
    _answer(request, status, headers: headers);
    _report('request refused status=$status');
  }

  void _report(String event) =>
      _log('$event rooms=${_rooms.count} sockets=$_sockets');
}

String? _single(HttpHeaders headers, String name) => switch (headers[name]) {
  [final value] => value,
  _ => null,
};

void _answer(
  HttpRequest request,
  int status, {
  String? text,
  Map<String, String> headers = const {},
}) {
  final response = request.response..statusCode = status;
  if (_asksToUpgrade(request)) response.persistentConnection = false;
  for (final MapEntry(:key, :value) in headers.entries) {
    response.headers.set(key, value);
  }
  if (text != null) {
    response.headers.contentType = ContentType.text;
    response.write(text);
  }
  response.close().ignore();
}

bool _asksToUpgrade(HttpRequest request) =>
    request.headers[HttpHeaders.connectionHeader]?.any(
      (token) => token.toLowerCase() == 'upgrade',
    ) ??
    false;
