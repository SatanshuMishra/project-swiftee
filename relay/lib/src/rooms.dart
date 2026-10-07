import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:together_protocol/together_protocol.dart';

import 'relay_limits.dart';

const _idAlphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
const _avatarAlphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
const _idLength = 12;
const _avatarLength = 16;

final class Rooms {
  Rooms({required this._limits, required this._random, required this._report});

  final RelayLimits _limits;
  final Random _random;
  final void Function(String event) _report;
  final _clock = Stopwatch()..start();

  var _rooms = const <String, _Room>{};
  var _seats = const <WebSocket, String>{};
  var _live = const <WebSocket>{};

  int get count => _rooms.length;

  Future<void> accept(WebSocket socket) {
    final ended = Completer<void>();
    var recent = const <Duration>[];
    final handshake = Timer(_limits.handshakeTimeout, () {
      if (!_seats.containsKey(socket)) _shut(socket, closePolicy, 'handshake');
    });
    _live = Set.unmodifiable({..._live, socket});
    socket.done.ignore();
    socket.listen(
      (Object? frame) {
        if (!_live.contains(socket)) return;
        final now = _clock.elapsed;
        recent = List.unmodifiable([
          for (final at in recent)
            if (now - at < _limits.messageWindow) at,
          now,
        ]);
        _receive(socket, frame, recent.length);
      },
      onError: (Object _) => _report('socket error'),
      onDone: () {
        handshake.cancel();
        _live = Set.unmodifiable(_live.where((other) => other != socket));
        _leave(socket);
        ended.complete();
      },
    );
    return ended.future;
  }

  void closeAll() {
    for (final socket in _live) {
      _shut(socket, WebSocketStatus.goingAway);
    }
  }

  void _receive(WebSocket socket, Object? frame, int inWindow) {
    if (_tooBig(frame)) {
      _shut(socket, closeTooBig, 'too-big');
    } else if (inWindow > _limits.burstMessages) {
      _shut(socket, closePolicy, 'flood');
    } else {
      _handle(socket, _decode(frame));
    }
  }

  bool _tooBig(Object? frame) => switch (frame) {
    final String text =>
      text.length > _limits.maxMessageBytes ||
          _utf8Length(text) > _limits.maxMessageBytes,
    final List<int> bytes => bytes.length > _limits.maxMessageBytes,
    _ => false,
  };

  void _handle(WebSocket socket, ClientMessage? message) {
    switch (message) {
      case null:
        _send(socket, const RelayError(RelayErrorReason.badRequest));
        _report('bad request');
      case OpenRoom(:final name, :final game):
        _open(socket, name, game);
      case JoinRoom(:final code, :final name, :final game):
        _join(socket, code, name, game);
      case SendBody(:final body, :final to):
        _forward(socket, body, to);
      case LockRoom():
        _lock(socket, locked: true);
      case UnlockRoom():
        _lock(socket, locked: false);
    }
  }

  void _open(WebSocket socket, String name, int game) {
    if (_seats.containsKey(socket)) {
      _send(socket, const RelayError(RelayErrorReason.alreadyInRoom));
    } else if (_rooms.length >= _limits.maxRooms) {
      _shut(socket, closePolicy, 'room-limit');
    } else {
      final code = _fresh(roomCodeAlphabet, roomCodeLength, _rooms.containsKey);
      final host = _Member(_newPlayer(name, const []), socket);
      _rooms = _with(
        _rooms,
        code,
        _Room(code: code, game: game, members: [host]),
      );
      _seats = _with(_seats, socket, code);
      _send(socket, RoomOpened(code: code, you: host.player));
      _report('room opened');
    }
  }

  void _join(WebSocket socket, String code, String name, int game) {
    switch (_rooms[code]) {
      case _ when _seats.containsKey(socket):
        _send(socket, const RelayError(RelayErrorReason.alreadyInRoom));
      case null:
        _refuse(socket, RelayErrorReason.notFound);
      case _Room(locked: true):
        _refuse(socket, RelayErrorReason.inGame);
      case _Room(:final members) when members.length >= maxPlayers:
        _refuse(socket, RelayErrorReason.full);
      case final _Room room when room.game != game:
        _refuse(socket, RelayErrorReason.gameMismatch);
      case final _Room room:
        _admit(socket, room, name);
    }
  }

  void _admit(WebSocket socket, _Room room, String name) {
    final guest = _Member(_newPlayer(name, room.members), socket);
    final joined = room.copyWith(members: [...room.members, guest]);
    _rooms = _with(_rooms, room.code, joined);
    _seats = _with(_seats, socket, room.code);
    _send(
      socket,
      RoomJoined(
        code: room.code,
        you: guest.player,
        hostId: room.host.player.id,
        players: joined.players,
      ),
    );
    _broadcast(room.members, PeerJoined(guest.player));
    _report('player joined');
  }

  void _refuse(WebSocket socket, RelayErrorReason reason) {
    _send(socket, RelayError(reason));
    _report('join refused reason=${reason.wireName}');
  }

  void _forward(WebSocket socket, Map<String, Object?> body, String? to) {
    final room = _roomOf(socket);
    if (room == null) {
      _send(socket, const RelayError(RelayErrorReason.notFound));
      return;
    }
    final text = Relayed(
      from: room.memberAt(socket).player.id,
      body: body,
    ).encode();
    final recipients = room.isHost(socket)
        ? room.guests.where((guest) => to == null || guest.player.id == to)
        : [room.host];
    for (final member in recipients) {
      _sendText(member.socket, text);
    }
  }

  void _lock(WebSocket socket, {required bool locked}) {
    switch (_roomOf(socket)) {
      case null:
        _send(socket, const RelayError(RelayErrorReason.notFound));
      case final _Room room when !room.isHost(socket):
        _send(socket, const RelayError(RelayErrorReason.notHost));
      case final _Room room:
        _rooms = _with(_rooms, room.code, room.copyWith(locked: locked));
        _report(locked ? 'room locked' : 'room unlocked');
    }
  }

  void _leave(WebSocket socket) {
    final room = _roomOf(socket);
    _seats = _without(_seats, socket);
    if (room == null) return;
    if (room.isHost(socket)) {
      _close(room);
    } else {
      final leaver = room.memberAt(socket);
      final rest = room.copyWith(
        members: [
          for (final member in room.members)
            if (member != leaver) member,
        ],
      );
      _rooms = _with(_rooms, room.code, rest);
      _broadcast(rest.members, PeerLeft(leaver.player.id));
      _report('player left');
    }
  }

  void _close(_Room room) {
    _rooms = _without(_rooms, room.code);
    for (final guest in room.guests) {
      _seats = _without(_seats, guest.socket);
      _send(guest.socket, const RoomClosed());
      _shut(guest.socket, WebSocketStatus.normalClosure);
    }
    _report('room closed');
  }

  _Room? _roomOf(WebSocket socket) => switch (_seats[socket]) {
    final String code => _rooms[code],
    null => null,
  };

  void _send(WebSocket socket, RelayMessage message) =>
      _sendText(socket, message.encode());

  void _broadcast(Iterable<_Member> members, RelayMessage message) {
    final text = message.encode();
    for (final member in members) {
      _sendText(member.socket, text);
    }
  }

  void _sendText(WebSocket socket, String text) {
    if (_live.contains(socket)) socket.add(text);
  }

  void _shut(WebSocket socket, int code, [String? reason]) {
    if (!_live.contains(socket)) return;
    _live = Set.unmodifiable(_live.where((other) => other != socket));
    socket.close(code).ignore();
    if (reason != null) _report('socket shut reason=$reason');
  }

  Player _newPlayer(String name, List<_Member> members) => Player(
    id: _fresh(
      _idAlphabet,
      _idLength,
      (id) => members.any((member) => member.player.id == id),
    ),
    name: name,
    avatar: _draw(_avatarAlphabet, _avatarLength),
  );

  String _fresh(String alphabet, int length, bool Function(String) taken) {
    final candidate = _draw(alphabet, length);
    return taken(candidate) ? _fresh(alphabet, length, taken) : candidate;
  }

  String _draw(String alphabet, int length) => String.fromCharCodes([
    for (var i = 0; i < length; i++)
      alphabet.codeUnitAt(_random.nextInt(alphabet.length)),
  ]);
}

final class _Room {
  _Room({
    required this.code,
    required this.game,
    required List<_Member> members,
    this.locked = false,
  }) : members = List.unmodifiable(members);

  final String code;
  final int game;
  final List<_Member> members;
  final bool locked;

  _Member get host => members.first;

  Iterable<_Member> get guests => members.skip(1);

  List<Player> get players => [for (final member in members) member.player];

  bool isHost(WebSocket socket) => host.socket == socket;

  _Member memberAt(WebSocket socket) =>
      members.firstWhere((member) => member.socket == socket);

  _Room copyWith({List<_Member>? members, bool? locked}) => _Room(
    code: code,
    game: game,
    members: members ?? this.members,
    locked: locked ?? this.locked,
  );
}

final class _Member {
  const _Member(this.player, this.socket);

  final Player player;
  final WebSocket socket;
}

ClientMessage? _decode(Object? frame) {
  if (frame is! String) return null;
  try {
    return switch (ClientMessage.decode(frame)) {
      SendBody(:final body) when !_finite(body) => null,
      final message => message,
    };
  } on ProtocolError {
    return null;
  }
}

bool _finite(Object? value) => switch (value) {
  final double number => number.isFinite,
  final Map<String, Object?> object => object.values.every(_finite),
  final List<Object?> list => list.every(_finite),
  _ => true,
};

int _utf8Length(String text) =>
    text.codeUnits.fold(0, (length, unit) => length + _utf8Width(unit));

int _utf8Width(int unit) => switch (unit) {
  < 0x80 => 1,
  < 0x800 => 2,
  >= 0xD800 && < 0xE000 => 2,
  _ => 3,
};

Map<K, V> _with<K, V>(Map<K, V> map, K key, V value) =>
    Map.unmodifiable({...map, key: value});

Map<K, V> _without<K, V>(Map<K, V> map, K key) => Map.unmodifiable({
  for (final MapEntry(key: other, :value) in map.entries)
    if (other != key) other: value,
});
