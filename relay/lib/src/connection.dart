import 'dart:async';
import 'dart:io';

import 'metered_socket.dart';
import 'relay_limits.dart';

typedef _Outgoing = ({String text, int bytes});

final class Connection {
  Connection._(this.address, this.socket, this._transport, this._limits) {
    _drained = socket
        .addStream(_outbox.stream.map(_deliver))
        .then<void>((_) {}, onError: (Object _) {});
    _transport.done
        .then<void>((_) => _settle(), onError: (Object _) => _settle())
        .ignore();
  }

  factory Connection.serve(
    Socket upgraded, {
    required String address,
    required RelayLimits limits,
    required void Function(Connection connection, Breach breach) breached,
  }) {
    late final Connection connection;
    final transport = MeteredSocket(
      upgraded,
      maxMessageBytes: limits.maxMessageBytes,
      bytesPerSecond: limits.inboundBytesPerSecond,
      breached: (breach) => breached(connection, breach),
    );
    final socket = WebSocket.fromUpgradedSocket(
      transport,
      serverSide: true,
      compression: CompressionOptions.compressionOff,
      maxPayloadLength: limits.maxMessageBytes,
    )..pingInterval = limits.pingInterval;
    connection = Connection._(address, socket, transport, limits);
    return connection;
  }

  final String address;
  final WebSocket socket;
  final MeteredSocket _transport;
  final RelayLimits _limits;
  final _outbox = StreamController<_Outgoing>(sync: true);
  late final Future<void> _drained;
  var _queuedBytes = 0;
  var _settled = false;
  Timer? _deadline;

  bool send(String text, int bytes) {
    if (_outbox.isClosed) return true;
    _queuedBytes += bytes;
    _outbox.add((text: text, bytes: bytes));
    return _queuedBytes <= _limits.maxQueuedBytes;
  }

  void close(int code) {
    _stopSending();
    _drained.then((_) => socket.close(code)).ignore();
    _expire();
  }

  void ended() {
    _stopSending();
    _expire();
  }

  void destroy() {
    _deadline?.cancel();
    _transport.destroy();
  }

  void _stopSending() {
    if (!_outbox.isClosed) _outbox.close().ignore();
  }

  void _expire() {
    if (!_settled) _deadline ??= Timer(_limits.closeGrace, destroy);
  }

  void _settle() {
    _settled = true;
    _deadline?.cancel();
  }

  String _deliver(_Outgoing outgoing) {
    _queuedBytes -= outgoing.bytes;
    return outgoing.text;
  }
}
