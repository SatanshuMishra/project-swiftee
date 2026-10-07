import 'package:collection/collection.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:together_protocol/together_protocol.dart';

const Object _unchanged = Object();

enum RoomRole { host, guest }

enum RoomStatus { idle, connecting, open, closed }

enum RoomFailure {
  badLink,
  needsUpdate,
  busy,
  unreachable,
  badCode,
  notFound,
  full,
  inGame,
  gameMismatch,
  hostClosed,
  connectionLost,
}

final class RoomState {
  const RoomState._({
    required this.role,
    required this.status,
    required this.code,
    required this.you,
    required this.hostId,
    required this.players,
    required this.settings,
    required this.scopeLabel,
    required this.failure,
    required this.closedBy,
  });

  static const RoomState initial = RoomState._(
    role: null,
    status: RoomStatus.idle,
    code: null,
    you: null,
    hostId: null,
    players: [],
    settings: RoomSettings(),
    scopeLabel: 'Shuffle everything',
    failure: null,
    closedBy: null,
  );

  final RoomRole? role;
  final RoomStatus status;
  final String? code;
  final Player? you;
  final String? hostId;
  final List<Player> players;
  final RoomSettings settings;
  final String scopeLabel;
  final RoomFailure? failure;
  final String? closedBy;

  String? get hostName =>
      players.firstWhereOrNull((player) => player.id == hostId)?.name;

  RoomState copyWith({
    Object? role = _unchanged,
    RoomStatus? status,
    Object? code = _unchanged,
    Object? you = _unchanged,
    Object? hostId = _unchanged,
    List<Player>? players,
    RoomSettings? settings,
    String? scopeLabel,
    Object? failure = _unchanged,
    Object? closedBy = _unchanged,
  }) => RoomState._(
    role: identical(role, _unchanged) ? this.role : role as RoomRole?,
    status: status ?? this.status,
    code: identical(code, _unchanged) ? this.code : code as String?,
    you: identical(you, _unchanged) ? this.you : you as Player?,
    hostId: identical(hostId, _unchanged) ? this.hostId : hostId as String?,
    players: players == null ? this.players : List.unmodifiable(players),
    settings: settings ?? this.settings,
    scopeLabel: scopeLabel ?? this.scopeLabel,
    failure: identical(failure, _unchanged)
        ? this.failure
        : failure as RoomFailure?,
    closedBy: identical(closedBy, _unchanged)
        ? this.closedBy
        : closedBy as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is RoomState &&
      other.role == role &&
      other.status == status &&
      other.code == code &&
      other.you == you &&
      other.hostId == hostId &&
      const ListEquality<Player>().equals(other.players, players) &&
      other.settings == settings &&
      other.scopeLabel == scopeLabel &&
      other.failure == failure &&
      other.closedBy == closedBy;

  @override
  int get hashCode => Object.hash(
    role,
    status,
    code,
    you,
    hostId,
    const ListEquality<Player>().hash(players),
    settings,
    scopeLabel,
    failure,
    closedBy,
  );

  @override
  String toString() =>
      'RoomState(role: $role, status: $status, code: $code, '
      'you: ${you?.name}, hostId: $hostId, '
      'players: ${[for (final player in players) player.name]}, '
      'settings: $settings, scopeLabel: $scopeLabel, failure: $failure, '
      'closedBy: $closedBy)';
}
