import 'package:characters/characters.dart';

const relayProtocolVersion = 1;
const relayProtocolHeader = 'x-swiftie-relay';
const relayPath = '/v1';
const checkPath = '/v1/check';
const bearerPrefix = 'Bearer ';

const maxPlayers = 8;
const maxNameLength = 20;
const maxMessageBytes = 65536;

const roomCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const roomCodeLength = 4;

const closePolicy = 1008;
const closeTooBig = 1009;

const statusChecked = 204;
const statusBadKey = 401;
const statusNeedsUpdate = 426;
const statusTooMany = 429;
const statusBusy = 503;

final _roomCode = RegExp('^[$roomCodeAlphabet]{$roomCodeLength}\$');
final _joinCode = RegExp('^[A-Z]{$roomCodeLength}\$');
final _serverKey = RegExp(r'^[A-Za-z0-9_-]{43}$');

bool isRoomCode(String code) => _roomCode.hasMatch(code);

bool isJoinCode(String code) => _joinCode.hasMatch(code);

bool isServerKey(String key) => _serverKey.hasMatch(key);

String? cleanName(String name) {
  final trimmed = name.trim();
  final length = trimmed.characters.length;
  if (length < 1 || length > maxNameLength) return null;
  if (trimmed.runes.any(_isControl)) return null;
  return trimmed;
}

bool _isControl(int rune) => rune < 0x20 || (rune >= 0x7F && rune <= 0x9F);
