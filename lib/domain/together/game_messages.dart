import 'package:collection/collection.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/domain/together/scoring.dart';
import 'package:swiftie_quiz/domain/together/standings.dart';

const int gameProtocolVersion = 1;

sealed class GameMessage {
  const GameMessage();
}

final class SettingsChanged extends GameMessage {
  const SettingsChanged({required this.settings, required this.scopeLabel});

  final RoomSettings settings;
  final String scopeLabel;

  @override
  bool operator ==(Object other) =>
      other is SettingsChanged &&
      other.settings == settings &&
      other.scopeLabel == scopeLabel;

  @override
  int get hashCode => Object.hash(settings, scopeLabel);

  @override
  String toString() =>
      'SettingsChanged(settings: $settings, scopeLabel: $scopeLabel)';
}

final class GameStarting extends GameMessage {
  const GameStarting();

  @override
  bool operator ==(Object other) => other is GameStarting;

  @override
  int get hashCode => (GameStarting).hashCode;

  @override
  String toString() => 'GameStarting()';
}

final class RoundStart extends GameMessage {
  RoundStart({
    required this.number,
    required this.total,
    required this.track,
    List<Track> options = const [],
    this.clipStart = 0,
    List<String> lines = const [],
  }) : options = List.unmodifiable(options),
       lines = List.unmodifiable(lines);

  final int number;
  final int total;
  final Track track;
  final List<Track> options;
  final double clipStart;
  final List<String> lines;

  @override
  bool operator ==(Object other) =>
      other is RoundStart &&
      other.number == number &&
      other.total == total &&
      other.track == track &&
      const ListEquality<Track>().equals(other.options, options) &&
      other.clipStart == clipStart &&
      const ListEquality<String>().equals(other.lines, lines);

  @override
  int get hashCode => Object.hash(
    number,
    total,
    track,
    const ListEquality<Track>().hash(options),
    clipStart,
    const ListEquality<String>().hash(lines),
  );

  @override
  String toString() =>
      'RoundStart(number: $number, total: $total, track: ${track.id}, '
      'options: ${options.length}, clipStart: $clipStart, '
      'lines: ${lines.length})';
}

final class AnswerSent extends GameMessage {
  const AnswerSent({
    required this.number,
    required this.trackId,
    required this.real,
    required this.at,
  });

  final int number;
  final int? trackId;
  final bool? real;
  final double at;

  @override
  bool operator ==(Object other) =>
      other is AnswerSent &&
      other.number == number &&
      other.trackId == trackId &&
      other.real == real &&
      other.at == at;

  @override
  int get hashCode => Object.hash(number, trackId, real, at);

  @override
  String toString() =>
      'AnswerSent(number: $number, trackId: $trackId, real: $real, at: $at)';
}

final class StatusChanged extends GameMessage {
  const StatusChanged({
    required this.number,
    required this.playerId,
    required this.status,
  });

  final int number;
  final String playerId;
  final AnswerStatus status;

  @override
  bool operator ==(Object other) =>
      other is StatusChanged &&
      other.number == number &&
      other.playerId == playerId &&
      other.status == status;

  @override
  int get hashCode => Object.hash(number, playerId, status);

  @override
  String toString() =>
      'StatusChanged(number: $number, playerId: $playerId, status: $status)';
}

final class RoundRevealed extends GameMessage {
  RoundRevealed({
    required this.number,
    required this.answerTrackId,
    required this.isReal,
    required this.sourceSong,
    required this.winnerId,
    required List<RoundResult> results,
    required List<PlayerScore> standings,
  }) : results = List.unmodifiable(results),
       standings = List.unmodifiable(standings);

  final int number;
  final int? answerTrackId;
  final bool? isReal;
  final String? sourceSong;
  final String? winnerId;
  final List<RoundResult> results;
  final List<PlayerScore> standings;

  @override
  bool operator ==(Object other) =>
      other is RoundRevealed &&
      other.number == number &&
      other.answerTrackId == answerTrackId &&
      other.isReal == isReal &&
      other.sourceSong == sourceSong &&
      other.winnerId == winnerId &&
      const ListEquality<RoundResult>().equals(other.results, results) &&
      const ListEquality<PlayerScore>().equals(other.standings, standings);

  @override
  int get hashCode => Object.hash(
    number,
    answerTrackId,
    isReal,
    sourceSong,
    winnerId,
    const ListEquality<RoundResult>().hash(results),
    const ListEquality<PlayerScore>().hash(standings),
  );

  @override
  String toString() =>
      'RoundRevealed(number: $number, answerTrackId: $answerTrackId, '
      'isReal: $isReal, sourceSong: $sourceSong, winnerId: $winnerId, '
      'results: $results, standings: $standings)';
}

final class GameEnded extends GameMessage {
  GameEnded({required List<PlayerScore> standings})
    : standings = List.unmodifiable(standings);

  final List<PlayerScore> standings;

  @override
  bool operator ==(Object other) =>
      other is GameEnded &&
      const ListEquality<PlayerScore>().equals(other.standings, standings);

  @override
  int get hashCode => const ListEquality<PlayerScore>().hash(standings);

  @override
  String toString() => 'GameEnded(standings: $standings)';
}

final class BackToLobby extends GameMessage {
  const BackToLobby();

  @override
  bool operator ==(Object other) => other is BackToLobby;

  @override
  int get hashCode => (BackToLobby).hashCode;

  @override
  String toString() => 'BackToLobby()';
}
