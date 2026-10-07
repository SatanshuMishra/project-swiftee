import 'dart:async';

import 'package:swiftie_quiz/data/together/game_wire.dart';
import 'package:swiftie_quiz/data/together/relay_connection.dart';
import 'package:swiftie_quiz/domain/together/game_messages.dart';
import 'package:swiftie_quiz/domain/together/server_link.dart';
import 'package:together_protocol/together_protocol.dart';

typedef SentBody = ({String? to, GameMessage message});

final class FakeRelay implements RelayConnector {
  FakeRelay({this.refusal});

  final RelayFailure? refusal;
  List<ClientMessage> _sent = const [];
  int _connections = 0;
  _FakeConnection? _connection;

  List<ClientMessage> get sent => _sent;

  int get connections => _connections;

  bool get connected => _connection?.isOpen ?? false;

  List<SentBody> get bodies => [
    for (final message in _sent)
      if (message is SendBody)
        (to: message.to, message: decodeGameMessage(message.body)),
  ];

  @override
  Future<void> check(ServerLink link) async {
    final failure = refusal;
    if (failure != null) {
      throw RelayRefused(failure);
    }
  }

  @override
  Future<RelayConnection> connect(ServerLink link) async {
    await check(link);
    _connections += 1;
    final connection = _FakeConnection(_record);
    _connection = connection;
    return connection;
  }

  void push(RelayMessage message) => _current.push(message);

  void pushGame(String from, GameMessage message) =>
      push(Relayed(from: from, body: encodeGameMessage(message)));

  Future<void> end() => _current.close();

  _FakeConnection get _current =>
      _connection ?? (throw StateError('nothing has connected to the relay'));

  void _record(ClientMessage message) => _sent = [..._sent, message];
}

final class _FakeConnection implements RelayConnection {
  _FakeConnection(this._record);

  final void Function(ClientMessage message) _record;
  final StreamController<RelayMessage> _messages = StreamController.broadcast();

  bool get isOpen => !_messages.isClosed;

  @override
  Stream<RelayMessage> get messages => _messages.stream;

  @override
  void send(ClientMessage message) {
    if (isOpen) {
      _record(message);
    }
  }

  void push(RelayMessage message) {
    if (isOpen) {
      _messages.add(message);
    }
  }

  @override
  Future<void> close() async {
    if (isOpen) {
      await _messages.close();
    }
  }
}
