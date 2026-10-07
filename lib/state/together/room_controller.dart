import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/data/together/game_wire.dart';
import 'package:swiftie_quiz/data/together/relay_connection.dart';
import 'package:swiftie_quiz/domain/engine/misu_lines.dart';
import 'package:swiftie_quiz/domain/together/game_messages.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/domain/together/server_link.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/together/room_state.dart';
import 'package:together_protocol/together_protocol.dart';

typedef RoomMessage = ({String from, GameMessage message});

final roomControllerProvider = NotifierProvider<RoomController, RoomState>(
  RoomController.new,
);

class RoomController extends Notifier<RoomState> {
  late StreamController<RoomMessage> _messages;
  late StreamController<RelayMessage> _presence;
  RelayConnection? _connection;
  StreamSubscription<RelayMessage>? _subscription;
  int _attempt = 0;

  @override
  RoomState build() {
    final messages = StreamController<RoomMessage>.broadcast();
    final presence = StreamController<RelayMessage>.broadcast();
    _messages = messages;
    _presence = presence;
    ref.onDispose(() {
      _attempt += 1;
      unawaited(_disconnect());
      unawaited(messages.close());
      unawaited(presence.close());
    });
    return RoomState.initial;
  }

  Stream<RoomMessage> get messages => _messages.stream;

  Stream<RelayMessage> get presence => _presence.stream;

  Future<void> open(ServerLink link) async {
    if (_active) {
      return;
    }
    final connection = await _connect(link);
    connection?.send(OpenRoom(name: _playerName(), game: gameProtocolVersion));
  }

  Future<void> join(ServerLink link, String code) async {
    if (_active) {
      return;
    }
    final joinCode = code.toUpperCase();
    if (!isJoinCode(joinCode)) {
      state = state.copyWith(failure: RoomFailure.badCode);
      return;
    }
    final connection = await _connect(link);
    connection?.send(
      JoinRoom(code: joinCode, name: _playerName(), game: gameProtocolVersion),
    );
  }

  void setSettings(RoomSettings settings, String scopeLabel) {
    state = state.copyWith(settings: settings, scopeLabel: scopeLabel);
    if (_openHost) {
      sendToAll(SettingsChanged(settings: settings, scopeLabel: scopeLabel));
    }
  }

  void sendToAll(GameMessage message) => _sendBody(message, to: null);

  void sendTo(String playerId, GameMessage message) =>
      _sendBody(message, to: playerId);

  void sendToHost(GameMessage message) => _sendBody(message, to: null);

  void lock() {
    if (_openHost) {
      _connection?.send(const LockRoom());
    }
  }

  void unlock() {
    if (_openHost) {
      _connection?.send(const UnlockRoom());
    }
  }

  Future<void> leave() async {
    _attempt += 1;
    state = state.role == RoomRole.guest
        ? RoomState.initial
        : RoomState.initial.copyWith(
            settings: state.settings,
            scopeLabel: state.scopeLabel,
          );
    await _disconnect();
  }

  void clearFailure() => state = state.copyWith(failure: null, closedBy: null);

  bool get _active =>
      state.status == RoomStatus.connecting || state.status == RoomStatus.open;

  bool get _openHost =>
      state.role == RoomRole.host && state.status == RoomStatus.open;

  String _playerName() => displayName(
    ref.read(editionProvider),
    ref.read(gameControllerProvider).progress.settings.nickname,
  );

  Future<RelayConnection?> _connect(ServerLink link) async {
    _attempt += 1;
    final attempt = _attempt;
    final connector = ref.read(relayConnectorProvider);
    unawaited(_disconnect());
    state = RoomState.initial.copyWith(
      status: RoomStatus.connecting,
      settings: state.settings,
      scopeLabel: state.scopeLabel,
    );
    try {
      final connection = await connector.connect(link);
      if (attempt != _attempt) {
        unawaited(connection.close());
        return null;
      }
      _connection = connection;
      _subscription = connection.messages.listen(
        _receive,
        onDone: _connectionEnded,
      );
      return connection;
    } on RelayRefused catch (refused) {
      _connectFailed(attempt, _refusalFailure(refused.failure));
      return null;
    } on Object {
      _connectFailed(attempt, RoomFailure.unreachable);
      return null;
    }
  }

  void _connectFailed(int attempt, RoomFailure failure) {
    if (attempt == _attempt) {
      state = state.copyWith(status: RoomStatus.idle, failure: failure);
    }
  }

  Future<void> _disconnect() async {
    final connection = _connection;
    final subscription = _subscription;
    _connection = null;
    _subscription = null;
    await subscription?.cancel();
    await connection?.close();
  }

  void _sendBody(GameMessage message, {required String? to}) {
    if (state.status == RoomStatus.open) {
      _connection?.send(SendBody(body: encodeGameMessage(message), to: to));
    }
  }

  void _receive(RelayMessage message) {
    switch (message) {
      case RoomOpened(:final code, :final you)
          when state.status == RoomStatus.connecting:
        state = state.copyWith(
          role: RoomRole.host,
          status: RoomStatus.open,
          code: code,
          you: you,
          hostId: you.id,
          players: [you],
        );
      case RoomJoined(:final code, :final you, :final hostId, :final players)
          when state.status == RoomStatus.connecting:
        state = state.copyWith(
          role: RoomRole.guest,
          status: RoomStatus.open,
          code: code,
          you: you,
          hostId: hostId,
          players: players,
        );
      case PeerJoined(:final player):
        state = state.copyWith(players: [...state.players, player]);
        if (_openHost) {
          sendTo(
            player.id,
            SettingsChanged(
              settings: state.settings,
              scopeLabel: state.scopeLabel,
            ),
          );
        }
        _presence.add(message);
      case PeerLeft(:final id):
        state = state.copyWith(
          players: [
            for (final player in state.players)
              if (player.id != id) player,
          ],
        );
        _presence.add(message);
      case Relayed(:final from, :final body):
        _relayed(from, body);
      case RoomClosed():
        state = state.copyWith(
          status: RoomStatus.closed,
          failure: RoomFailure.hostClosed,
          closedBy: state.hostName,
        );
        unawaited(_disconnect());
      case RelayError(:final reason) when state.status == RoomStatus.connecting:
        state = state.copyWith(
          status: RoomStatus.idle,
          failure: _joinFailure(reason),
        );
        unawaited(_disconnect());
      case RoomOpened() || RoomJoined() || RelayError():
        break;
    }
  }

  void _relayed(String from, Map<String, Object?> body) {
    final message = _decoded(body);
    if (message == null) {
      return;
    }
    if (message case SettingsChanged(:final settings, :final scopeLabel)
        when state.role == RoomRole.guest && from == state.hostId) {
      state = state.copyWith(settings: settings, scopeLabel: scopeLabel);
    }
    _messages.add((from: from, message: message));
  }

  void _connectionEnded() {
    _connection = null;
    _subscription = null;
    state = switch (state.status) {
      RoomStatus.open => state.copyWith(
        status: RoomStatus.closed,
        failure: RoomFailure.connectionLost,
      ),
      RoomStatus.connecting => state.copyWith(
        status: RoomStatus.idle,
        failure: RoomFailure.unreachable,
      ),
      RoomStatus.idle || RoomStatus.closed => state,
    };
  }
}

GameMessage? _decoded(Map<String, Object?> body) {
  try {
    return decodeGameMessage(body);
  } on FormatException {
    return null;
  }
}

RoomFailure _refusalFailure(RelayFailure failure) => switch (failure) {
  RelayFailure.badLink => RoomFailure.badLink,
  RelayFailure.needsUpdate => RoomFailure.needsUpdate,
  RelayFailure.busy => RoomFailure.busy,
  RelayFailure.unreachable => RoomFailure.unreachable,
};

RoomFailure _joinFailure(RelayErrorReason reason) => switch (reason) {
  RelayErrorReason.notFound => RoomFailure.notFound,
  RelayErrorReason.full => RoomFailure.full,
  RelayErrorReason.inGame => RoomFailure.inGame,
  RelayErrorReason.gameMismatch => RoomFailure.gameMismatch,
  RelayErrorReason.notHost ||
  RelayErrorReason.badRequest ||
  RelayErrorReason.alreadyInRoom => RoomFailure.unreachable,
};
