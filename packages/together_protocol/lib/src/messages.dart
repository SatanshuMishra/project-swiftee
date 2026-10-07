import 'dart:convert';

import 'limits.dart';

final class ProtocolError implements Exception {
  const ProtocolError(this.message);

  final String message;

  @override
  String toString() => 'ProtocolError: $message';
}

final class Player {
  const Player({required this.id, required this.name, required this.avatar});

  factory Player.fromJson(Object? json) {
    final fields = _object(json);
    return Player(
      id: _id(fields, 'id'),
      name: _name(fields),
      avatar: _id(fields, 'avatar'),
    );
  }

  final String id;
  final String name;
  final String avatar;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'avatar': avatar};

  @override
  bool operator ==(Object other) =>
      other is Player &&
      other.id == id &&
      other.name == name &&
      other.avatar == avatar;

  @override
  int get hashCode => Object.hash(id, name, avatar);
}

enum RelayErrorReason {
  notFound('not-found'),
  full('full'),
  inGame('in-game'),
  gameMismatch('game-mismatch'),
  notHost('not-host'),
  badRequest('bad-request'),
  alreadyInRoom('already-in-room');

  const RelayErrorReason(this.wireName);

  final String wireName;
}

sealed class ClientMessage {
  const ClientMessage();

  static ClientMessage decode(String text) {
    final fields = _decode(text);
    return switch (_string(fields, 't')) {
      'open' => OpenRoom(name: _name(fields), game: _game(fields)),
      'join' => JoinRoom(
        code: _joinCode(fields, 'code'),
        name: _name(fields),
        game: _game(fields),
      ),
      'send' => SendBody(body: _body(fields), to: _optionalId(fields, 'to')),
      'lock' => const LockRoom(),
      'unlock' => const UnlockRoom(),
      _ => throw const ProtocolError('Unknown message type'),
    };
  }

  Map<String, Object?> toJson();

  String encode() => jsonEncode(toJson());
}

final class OpenRoom extends ClientMessage {
  const OpenRoom({required this.name, required this.game});

  final String name;
  final int game;

  @override
  Map<String, Object?> toJson() => {'t': 'open', 'name': name, 'game': game};

  @override
  bool operator ==(Object other) =>
      other is OpenRoom && other.name == name && other.game == game;

  @override
  int get hashCode => Object.hash(OpenRoom, name, game);
}

final class JoinRoom extends ClientMessage {
  const JoinRoom({required this.code, required this.name, required this.game});

  final String code;
  final String name;
  final int game;

  @override
  Map<String, Object?> toJson() => {
    't': 'join',
    'code': code,
    'name': name,
    'game': game,
  };

  @override
  bool operator ==(Object other) =>
      other is JoinRoom &&
      other.code == code &&
      other.name == name &&
      other.game == game;

  @override
  int get hashCode => Object.hash(JoinRoom, code, name, game);
}

final class SendBody extends ClientMessage {
  SendBody({required Map<String, Object?> body, this.to})
    : body = _frozenObject(body);

  final Map<String, Object?> body;
  final String? to;

  @override
  Map<String, Object?> toJson() => {'t': 'send', 'to': to, 'body': body};

  @override
  bool operator ==(Object other) =>
      other is SendBody && other.to == to && _sameJson(other.body, body);

  @override
  int get hashCode => Object.hash(SendBody, to, _jsonHash(body));
}

final class LockRoom extends ClientMessage {
  const LockRoom();

  @override
  Map<String, Object?> toJson() => {'t': 'lock'};

  @override
  bool operator ==(Object other) => other is LockRoom;

  @override
  int get hashCode => (LockRoom).hashCode;
}

final class UnlockRoom extends ClientMessage {
  const UnlockRoom();

  @override
  Map<String, Object?> toJson() => {'t': 'unlock'};

  @override
  bool operator ==(Object other) => other is UnlockRoom;

  @override
  int get hashCode => (UnlockRoom).hashCode;
}

sealed class RelayMessage {
  const RelayMessage();

  static RelayMessage decode(String text) {
    final fields = _decode(text);
    return switch (_string(fields, 't')) {
      'opened' => RoomOpened(
        code: _joinCode(fields, 'code'),
        you: Player.fromJson(fields['you']),
      ),
      'joined' => RoomJoined(
        code: _joinCode(fields, 'code'),
        you: Player.fromJson(fields['you']),
        hostId: _id(fields, 'host'),
        players: _players(fields),
      ),
      'peer-joined' => PeerJoined(Player.fromJson(fields['player'])),
      'peer-left' => PeerLeft(_id(fields, 'id')),
      'msg' => Relayed(from: _id(fields, 'from'), body: _body(fields)),
      'closed' => const RoomClosed(),
      'error' => RelayError(_reason(fields)),
      _ => throw const ProtocolError('Unknown message type'),
    };
  }

  Map<String, Object?> toJson();

  String encode() => jsonEncode(toJson());
}

final class RoomOpened extends RelayMessage {
  const RoomOpened({required this.code, required this.you});

  final String code;
  final Player you;

  @override
  Map<String, Object?> toJson() => {
    't': 'opened',
    'code': code,
    'you': you.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is RoomOpened && other.code == code && other.you == you;

  @override
  int get hashCode => Object.hash(RoomOpened, code, you);
}

final class RoomJoined extends RelayMessage {
  RoomJoined({
    required this.code,
    required this.you,
    required this.hostId,
    required List<Player> players,
  }) : players = List.unmodifiable(players);

  final String code;
  final Player you;
  final String hostId;
  final List<Player> players;

  @override
  Map<String, Object?> toJson() => {
    't': 'joined',
    'code': code,
    'you': you.toJson(),
    'host': hostId,
    'players': [for (final player in players) player.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is RoomJoined &&
      other.code == code &&
      other.you == you &&
      other.hostId == hostId &&
      _sameList(other.players, players);

  @override
  int get hashCode =>
      Object.hash(RoomJoined, code, you, hostId, Object.hashAll(players));
}

final class PeerJoined extends RelayMessage {
  const PeerJoined(this.player);

  final Player player;

  @override
  Map<String, Object?> toJson() => {
    't': 'peer-joined',
    'player': player.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is PeerJoined && other.player == player;

  @override
  int get hashCode => Object.hash(PeerJoined, player);
}

final class PeerLeft extends RelayMessage {
  const PeerLeft(this.id);

  final String id;

  @override
  Map<String, Object?> toJson() => {'t': 'peer-left', 'id': id};

  @override
  bool operator ==(Object other) => other is PeerLeft && other.id == id;

  @override
  int get hashCode => Object.hash(PeerLeft, id);
}

final class Relayed extends RelayMessage {
  Relayed({required this.from, required Map<String, Object?> body})
    : body = _frozenObject(body);

  final String from;
  final Map<String, Object?> body;

  @override
  Map<String, Object?> toJson() => {'t': 'msg', 'from': from, 'body': body};

  @override
  bool operator ==(Object other) =>
      other is Relayed && other.from == from && _sameJson(other.body, body);

  @override
  int get hashCode => Object.hash(Relayed, from, _jsonHash(body));
}

final class RoomClosed extends RelayMessage {
  const RoomClosed();

  @override
  Map<String, Object?> toJson() => {'t': 'closed'};

  @override
  bool operator ==(Object other) => other is RoomClosed;

  @override
  int get hashCode => (RoomClosed).hashCode;
}

final class RelayError extends RelayMessage {
  const RelayError(this.reason);

  final RelayErrorReason reason;

  @override
  Map<String, Object?> toJson() => {'t': 'error', 'reason': reason.wireName};

  @override
  bool operator ==(Object other) =>
      other is RelayError && other.reason == reason;

  @override
  int get hashCode => Object.hash(RelayError, reason);
}

final _playerToken = RegExp(r'^[A-Za-z0-9]{1,32}$');

const _maxBodyDepth = 32;

Map<String, Object?> _decode(String text) {
  final Object? value;
  try {
    value = jsonDecode(text);
  } on FormatException {
    throw const ProtocolError('Message is not JSON');
  }
  return _object(value);
}

Map<String, Object?> _object(Object? value) => switch (value) {
  final Map<String, Object?> fields => fields,
  _ => throw const ProtocolError('Expected a JSON object'),
};

String _string(Map<String, Object?> fields, String key) =>
    switch (fields[key]) {
      final String value => value,
      _ => throw ProtocolError('"$key" must be a string'),
    };

String _name(Map<String, Object?> fields) =>
    cleanName(_string(fields, 'name')) ??
    (throw const ProtocolError('"name" is not a valid name'));

String _id(Map<String, Object?> fields, String key) => switch (fields[key]) {
  final String value when _playerToken.hasMatch(value) => value,
  _ => throw ProtocolError('"$key" must be 1 to 32 letters or digits'),
};

String? _optionalId(Map<String, Object?> fields, String key) =>
    fields[key] == null ? null : _id(fields, key);

String _joinCode(Map<String, Object?> fields, String key) =>
    switch (fields[key]) {
      final String value when isJoinCode(value) => value,
      _ => throw ProtocolError('"$key" must be $roomCodeLength letters A-Z'),
    };

int _game(Map<String, Object?> fields) => switch (fields['game']) {
  final int game when game >= 1 => game,
  _ => throw const ProtocolError('"game" must be a whole number from 1'),
};

Map<String, Object?> _body(Map<String, Object?> fields) =>
    switch (fields['body']) {
      final Map<String, Object?> body => body,
      _ => throw const ProtocolError('"body" must be a JSON object'),
    };

List<Player> _players(Map<String, Object?> fields) =>
    switch (fields['players']) {
      final List<Object?> players => [
        for (final player in players) Player.fromJson(player),
      ],
      _ => throw const ProtocolError('"players" must be a list'),
    };

RelayErrorReason _reason(Map<String, Object?> fields) {
  final wireName = _string(fields, 'reason');
  return RelayErrorReason.values
          .where((reason) => reason.wireName == wireName)
          .firstOrNull ??
      (throw const ProtocolError('Unknown error reason'));
}

Map<String, Object?> _frozenObject(
  Map<String, Object?> object, [
  int depth = 1,
]) => Map<String, Object?>.unmodifiable({
  for (final MapEntry(:key, :value) in object.entries)
    key: _frozen(value, depth + 1),
});

Object? _frozen(Object? value, int depth) => switch (value) {
  Map<String, Object?>() || List<Object?>() when depth > _maxBodyDepth =>
    throw const ProtocolError('"body" is nested too deeply'),
  final Map<String, Object?> object => _frozenObject(object, depth),
  final List<Object?> list => List<Object?>.unmodifiable(
    list.map((item) => _frozen(item, depth + 1)),
  ),
  _ => value,
};

bool _sameJson(Object? a, Object? b) => switch ((a, b)) {
  (final Map<Object?, Object?> x, final Map<Object?, Object?> y) =>
    x.length == y.length &&
        x.entries.every(
          (entry) =>
              y.containsKey(entry.key) && _sameJson(entry.value, y[entry.key]),
        ),
  (final List<Object?> x, final List<Object?> y) => _sameList(x, y),
  _ => a == b,
};

bool _sameList(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_sameJson(a[i], b[i])) return false;
  }
  return true;
}

int _jsonHash(Object? value) => switch (value) {
  final Map<Object?, Object?> object => Object.hashAllUnordered(
    object.entries.map(
      (entry) => Object.hash(entry.key, _jsonHash(entry.value)),
    ),
  ),
  final List<Object?> list => Object.hashAll(list.map(_jsonHash)),
  _ => value.hashCode,
};
