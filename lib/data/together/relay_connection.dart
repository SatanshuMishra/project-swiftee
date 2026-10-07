import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:swiftie_quiz/domain/together/server_link.dart';
import 'package:together_protocol/together_protocol.dart';

enum RelayFailure { badLink, needsUpdate, busy, unreachable }

final class RelayRefused implements Exception {
  const RelayRefused(this.failure);

  final RelayFailure failure;

  @override
  String toString() => 'RelayRefused(${failure.name})';
}

abstract interface class RelayConnection {
  Stream<RelayMessage> get messages;

  void send(ClientMessage message);

  Future<void> close();
}

abstract interface class RelayConnector {
  Future<void> check(ServerLink link);

  Future<RelayConnection> connect(ServerLink link);
}

final class HttpRelayConnector implements RelayConnector {
  const HttpRelayConnector({
    required this._client,
    required this._openSocket,
    this._timeout = const Duration(seconds: 8),
  });

  final http.Client _client;
  final Future<WebSocket> Function(Uri uri, Map<String, Object> headers)
  _openSocket;
  final Duration _timeout;

  @override
  Future<void> check(ServerLink link) async {
    final failure = _failureFor(await _checkStatus(link));
    if (failure != null) {
      throw RelayRefused(failure);
    }
  }

  @override
  Future<RelayConnection> connect(ServerLink link) async {
    await check(link);
    final opening = _openSocket(link.relayUri, _relayHeaders(link));
    try {
      return _SocketConnection(await opening.timeout(_timeout));
    } on TimeoutException {
      unawaited(
        opening.then<void>((socket) => socket.close(), onError: (Object _) {}),
      );
      throw const RelayRefused(RelayFailure.unreachable);
    } on Exception {
      throw const RelayRefused(RelayFailure.unreachable);
    }
  }

  Future<int?> _checkStatus(ServerLink link) async {
    final abort = Completer<void>();
    final request =
        http.AbortableRequest('GET', link.checkUri, abortTrigger: abort.future)
          ..followRedirects = false
          ..headers.addAll(_relayHeaders(link));
    try {
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(_timeout);
      return response.statusCode;
    } on TimeoutException {
      abort.complete();
      return null;
    } on Exception {
      return null;
    }
  }
}

Map<String, String> _relayHeaders(ServerLink link) => Map.unmodifiable({
  HttpHeaders.authorizationHeader: '$bearerPrefix${link.key}',
  relayProtocolHeader: '$relayProtocolVersion',
});

RelayFailure? _failureFor(int? status) => switch (status) {
  statusChecked => null,
  statusBadKey => RelayFailure.badLink,
  statusNeedsUpdate => RelayFailure.needsUpdate,
  statusTooMany || statusBusy => RelayFailure.busy,
  _ => RelayFailure.unreachable,
};

final class _SocketConnection implements RelayConnection {
  _SocketConnection(this._socket);

  final WebSocket _socket;
  late final StreamController<RelayMessage> _messages =
      StreamController.broadcast(onListen: _listen);
  StreamSubscription<Object?>? _frames;

  @override
  Stream<RelayMessage> get messages => _messages.stream;

  @override
  void send(ClientMessage message) {
    if (!_messages.isClosed) {
      _socket.add(message.encode());
    }
  }

  @override
  Future<void> close() => _end();

  void _listen() {
    _frames ??= _socket.listen(
      _receive,
      onError: (Object _) => unawaited(_end()),
      onDone: () => unawaited(_end()),
      cancelOnError: true,
    );
  }

  void _receive(Object? frame) {
    if (_messages.isClosed) {
      return;
    }
    final message = frame is String ? _decoded(frame) : null;
    if (message == null) {
      unawaited(_end(closePolicy));
    } else {
      _messages.add(message);
    }
  }

  Future<void> _end([int? code]) async {
    if (_messages.isClosed) {
      return;
    }
    final closing = _messages.close();
    await _socket.close(code);
    await closing;
  }
}

RelayMessage? _decoded(String frame) {
  try {
    return RelayMessage.decode(frame);
  } on ProtocolError {
    return null;
  }
}
