import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:together_protocol/together_protocol.dart';

import 'connection.dart';
import 'metered_socket.dart';
import 'relay_limits.dart';
import 'strikes.dart';

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
  late final _refusals = Strikes(
    threshold: _limits.joinRefusalsPerAddress + 1,
    window: _limits.joinRefusalWindow,
    capacity: _limits.maxTrackedAddresses,
  );

  var _rooms = const <String, _Room>{};
  var _seats = const <Connection, String>{};
  var _live = const <Connection>{};
  var _refused = const <Connection, int>{};
  Timer? _idleSweep;

  int get count => _rooms.length;

  Future<void> accept(Socket upgraded, String address) {
    final connection = Connection.serve(
      upgraded,
      address: address,
      limits: _limits,
      breached: _breached,
    );
    final ended = Completer<void>();
    var recent = const <Duration>[];
    final handshake = Timer(_limits.handshakeTimeout, () {
      if (!_seats.containsKey(connection)) {
        _shut(connection, closePolicy, 'handshake');
      }
    });
    _live = Set.unmodifiable({..._live, connection});
    connection.socket.done.ignore();
    connection.socket.listen(
      (Object? frame) {
        if (!_live.contains(connection)) return;
        final now = _clock.elapsed;
        recent = List.unmodifiable([
          for (final at in recent)
            if (now - at < _limits.messageWindow) at,
          now,
        ]);
        _receive(connection, frame, recent.length);
      },
      onError: (Object _) => _report('socket error'),
      onDone: () {
        handshake.cancel();
        _live = Set.unmodifiable(_live.where((other) => other != connection));
        _leave(connection);
        connection.ended();
        ended.complete();
      },
    );
    return ended.future;
  }

  void closeAll() {
    _idleSweep?.cancel();
    for (final connection in _live) {
      _shut(connection, WebSocketStatus.goingAway);
    }
  }

  void _receive(Connection connection, Object? frame, int inWindow) {
    if (inWindow > _limits.burstMessages) {
      _shut(connection, closePolicy, 'flood');
    } else {
      _handle(connection, _decode(frame));
    }
  }

  void _breached(Connection connection, Breach breach) {
    if (breach.destroys) {
      _live = Set.unmodifiable(_live.where((other) => other != connection));
      _report('socket dropped reason=${breach.reason}');
    } else {
      _shut(connection, closeTooBig, breach.reason);
    }
  }

  void _handle(Connection connection, ClientMessage? message) {
    switch (message) {
      case null:
        _send(connection, const RelayError(RelayErrorReason.badRequest));
        _report('bad request');
      case OpenRoom(:final name, :final game):
        _open(connection, name, game);
      case JoinRoom(:final code, :final name, :final game):
        _join(connection, code, name, game);
      case SendBody(:final body, :final to):
        _forward(connection, body, to);
      case LockRoom():
        _lock(connection, locked: true);
      case UnlockRoom():
        _lock(connection, locked: false);
    }
  }

  void _open(Connection connection, String name, int game) {
    if (_seats.containsKey(connection)) {
      _send(connection, const RelayError(RelayErrorReason.alreadyInRoom));
    } else if (_rooms.length >= _limits.maxRooms) {
      _shut(connection, closePolicy, 'room-limit');
    } else if (_hostedFrom(connection.address) >= _limits.maxRoomsPerAddress) {
      _shut(connection, closePolicy, 'address-room-limit');
    } else {
      final code = _fresh(roomCodeAlphabet, roomCodeLength, _rooms.containsKey);
      final host = _Member(_newPlayer(name, const []), connection);
      _rooms = _with(
        _rooms,
        code,
        _Room(code: code, game: game, members: [host], active: _clock.elapsed),
      );
      _seats = _with(_seats, connection, code);
      _send(connection, RoomOpened(code: code, you: host.player));
      _report('room opened');
      _armIdleSweep();
    }
  }

  int _hostedFrom(String address) => _rooms.values
      .where((room) => room.host.connection.address == address)
      .length;

  void _join(Connection connection, String code, String name, int game) {
    if (_seats.containsKey(connection)) {
      _send(connection, const RelayError(RelayErrorReason.alreadyInRoom));
    } else if (_refusals.reached(connection.address)) {
      _turnAway(connection, RelayErrorReason.notFound, 'throttled');
    } else {
      switch (_rooms[code]) {
        case null:
          _refuse(connection, RelayErrorReason.notFound);
        case _Room(locked: true):
          _refuse(connection, RelayErrorReason.inGame);
        case _Room(:final members) when members.length >= maxPlayers:
          _refuse(connection, RelayErrorReason.full);
        case final _Room room when room.game != game:
          _refuse(connection, RelayErrorReason.gameMismatch);
        case final _Room room:
          _admit(connection, room, name);
      }
    }
  }

  void _admit(Connection connection, _Room room, String name) {
    final guest = _Member(_newPlayer(name, room.members), connection);
    final joined = room.copyWith(members: [...room.members, guest]);
    _rooms = _with(_rooms, room.code, joined);
    _seats = _with(_seats, connection, room.code);
    _send(
      connection,
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

  void _refuse(Connection connection, RelayErrorReason reason) {
    _refusals.record(connection.address);
    _turnAway(connection, reason, reason.wireName);
  }

  void _turnAway(
    Connection connection,
    RelayErrorReason reason,
    String logged,
  ) {
    _send(connection, RelayError(reason));
    _report('join refused reason=$logged');
    final refused = (_refused[connection] ?? 0) + 1;
    _refused = _with(_refused, connection, refused);
    if (refused >= _limits.joinRefusalsPerSocket) {
      _shut(connection, closePolicy, 'join-refusals');
    }
  }

  void _forward(Connection connection, Map<String, Object?> body, String? to) {
    final room = _roomOf(connection);
    if (room == null) {
      _send(connection, const RelayError(RelayErrorReason.notFound));
      return;
    }
    final text = Relayed(
      from: room.memberAt(connection).player.id,
      body: body,
    ).encode();
    final bytes = _utf8Length(text);
    if (bytes > _limits.maxMessageBytes) {
      _send(connection, const RelayError(RelayErrorReason.badRequest));
      _report('bad request reason=too-big');
      return;
    }
    final fromHost = room.isHost(connection);
    final recipients = fromHost
        ? room.guests
              .where((guest) => to == null || guest.player.id == to)
              .toList()
        : [room.host];
    if (fromHost && recipients.isNotEmpty) {
      _rooms = _with(_rooms, room.code, room.copyWith(active: _clock.elapsed));
    }
    for (final member in recipients) {
      _sendText(member.connection, text, bytes);
    }
  }

  void _lock(Connection connection, {required bool locked}) {
    switch (_roomOf(connection)) {
      case null:
        _send(connection, const RelayError(RelayErrorReason.notFound));
      case final _Room room when !room.isHost(connection):
        _send(connection, const RelayError(RelayErrorReason.notHost));
      case final _Room room:
        _rooms = _with(_rooms, room.code, room.copyWith(locked: locked));
        _report(locked ? 'room locked' : 'room unlocked');
    }
  }

  void _leave(Connection connection) {
    final room = _roomOf(connection);
    _seats = _without(_seats, connection);
    _refused = _without(_refused, connection);
    if (room == null) return;
    if (room.isHost(connection)) {
      _close(room, room.guests);
    } else {
      final leaver = room.memberAt(connection);
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

  void _close(_Room room, Iterable<_Member> members, [String? reason]) {
    _rooms = _without(_rooms, room.code);
    for (final member in members) {
      _seats = _without(_seats, member.connection);
      _send(member.connection, const RoomClosed());
      _shut(member.connection, WebSocketStatus.normalClosure);
    }
    _report(reason == null ? 'room closed' : 'room closed reason=$reason');
  }

  void _armIdleSweep() {
    if (_rooms.isEmpty || (_idleSweep?.isActive ?? false)) return;
    final quietest = _rooms.values
        .map((room) => room.active)
        .reduce((a, b) => a < b ? a : b);
    _idleSweep = Timer(
      quietest + _limits.roomIdleTimeout - _clock.elapsed,
      _closeIdleRooms,
    );
  }

  void _closeIdleRooms() {
    final now = _clock.elapsed;
    for (final room in _rooms.values) {
      if (now - room.active >= _limits.roomIdleTimeout) {
        _close(room, room.members, 'idle');
      }
    }
    _armIdleSweep();
  }

  _Room? _roomOf(Connection connection) => switch (_seats[connection]) {
    final String code => _rooms[code],
    null => null,
  };

  void _send(Connection connection, RelayMessage message) {
    final text = message.encode();
    _sendText(connection, text, _utf8Length(text));
  }

  void _broadcast(Iterable<_Member> members, RelayMessage message) {
    final text = message.encode();
    final bytes = _utf8Length(text);
    for (final member in members) {
      _sendText(member.connection, text, bytes);
    }
  }

  void _sendText(Connection connection, String text, int bytes) {
    if (_live.contains(connection) && !connection.send(text, bytes)) {
      _shut(connection, closePolicy, 'backlog');
    }
  }

  void _shut(Connection connection, int code, [String? reason]) {
    if (!_live.contains(connection)) return;
    _live = Set.unmodifiable(_live.where((other) => other != connection));
    connection.close(code);
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
    required this.active,
    this.locked = false,
  }) : members = List.unmodifiable(members);

  final String code;
  final int game;
  final List<_Member> members;
  final Duration active;
  final bool locked;

  _Member get host => members.first;

  Iterable<_Member> get guests => members.skip(1);

  List<Player> get players => [for (final member in members) member.player];

  bool isHost(Connection connection) => host.connection == connection;

  _Member memberAt(Connection connection) =>
      members.firstWhere((member) => member.connection == connection);

  _Room copyWith({List<_Member>? members, Duration? active, bool? locked}) =>
      _Room(
        code: code,
        game: game,
        members: members ?? this.members,
        active: active ?? this.active,
        locked: locked ?? this.locked,
      );
}

final class _Member {
  const _Member(this.player, this.connection);

  final Player player;
  final Connection connection;
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
