import 'package:collection/collection.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/domain/together/scoring.dart';
import 'package:swiftie_quiz/domain/together/standings.dart';
import 'package:together_protocol/together_protocol.dart';

const Object _unchanged = Object();

enum TogetherStage {
  idle,
  starting,
  countdown,
  loading,
  round,
  reveal,
  ended,
  lost,
}

final class TogetherGameState {
  const TogetherGameState._({
    required this.stage,
    required this.number,
    required this.total,
    required this.mode,
    required this.difficulty,
    required this.track,
    required this.options,
    required this.lines,
    required this.count,
    required this.myTrackPick,
    required this.myRealPick,
    required this.myStatus,
    required this.statuses,
    required this.results,
    required this.answerTrackId,
    required this.isReal,
    required this.sourceSong,
    required this.winnerId,
    required this.standings,
    required this.revealLeft,
    required this.departed,
    required this.roster,
    required this.startFailed,
  });

  static const TogetherGameState initial = TogetherGameState._(
    stage: TogetherStage.idle,
    number: 0,
    total: 0,
    mode: TogetherMode.classic,
    difficulty: Difficulty.medium,
    track: null,
    options: [],
    lines: [],
    count: 0,
    myTrackPick: null,
    myRealPick: null,
    myStatus: null,
    statuses: {},
    results: {},
    answerTrackId: null,
    isReal: null,
    sourceSong: null,
    winnerId: null,
    standings: [],
    revealLeft: 0,
    departed: {},
    roster: [],
    startFailed: false,
  );

  final TogetherStage stage;
  final int number;
  final int total;
  final TogetherMode mode;
  final Difficulty difficulty;
  final Track? track;
  final List<Track> options;
  final List<String> lines;
  final int count;
  final int? myTrackPick;
  final bool? myRealPick;
  final AnswerStatus? myStatus;
  final Map<String, AnswerStatus> statuses;
  final Map<String, RoundResult> results;
  final int? answerTrackId;
  final bool? isReal;
  final String? sourceSong;
  final String? winnerId;
  final List<PlayerScore> standings;
  final int revealLeft;
  final Set<String> departed;
  final List<Player> roster;
  final bool startFailed;

  TogetherGameState copyWith({
    TogetherStage? stage,
    int? number,
    int? total,
    TogetherMode? mode,
    Difficulty? difficulty,
    Object? track = _unchanged,
    List<Track>? options,
    List<String>? lines,
    int? count,
    Object? myTrackPick = _unchanged,
    Object? myRealPick = _unchanged,
    Object? myStatus = _unchanged,
    Map<String, AnswerStatus>? statuses,
    Map<String, RoundResult>? results,
    Object? answerTrackId = _unchanged,
    Object? isReal = _unchanged,
    Object? sourceSong = _unchanged,
    Object? winnerId = _unchanged,
    List<PlayerScore>? standings,
    int? revealLeft,
    Set<String>? departed,
    List<Player>? roster,
    bool? startFailed,
  }) => TogetherGameState._(
    stage: stage ?? this.stage,
    number: number ?? this.number,
    total: total ?? this.total,
    mode: mode ?? this.mode,
    difficulty: difficulty ?? this.difficulty,
    track: identical(track, _unchanged) ? this.track : track as Track?,
    options: options == null ? this.options : List.unmodifiable(options),
    lines: lines == null ? this.lines : List.unmodifiable(lines),
    count: count ?? this.count,
    myTrackPick: identical(myTrackPick, _unchanged)
        ? this.myTrackPick
        : myTrackPick as int?,
    myRealPick: identical(myRealPick, _unchanged)
        ? this.myRealPick
        : myRealPick as bool?,
    myStatus: identical(myStatus, _unchanged)
        ? this.myStatus
        : myStatus as AnswerStatus?,
    statuses: statuses == null ? this.statuses : Map.unmodifiable(statuses),
    results: results == null ? this.results : Map.unmodifiable(results),
    answerTrackId: identical(answerTrackId, _unchanged)
        ? this.answerTrackId
        : answerTrackId as int?,
    isReal: identical(isReal, _unchanged) ? this.isReal : isReal as bool?,
    sourceSong: identical(sourceSong, _unchanged)
        ? this.sourceSong
        : sourceSong as String?,
    winnerId: identical(winnerId, _unchanged)
        ? this.winnerId
        : winnerId as String?,
    standings: standings == null
        ? this.standings
        : List.unmodifiable(standings),
    revealLeft: revealLeft ?? this.revealLeft,
    departed: departed == null ? this.departed : Set.unmodifiable(departed),
    roster: roster == null ? this.roster : List.unmodifiable(roster),
    startFailed: startFailed ?? this.startFailed,
  );

  @override
  bool operator ==(Object other) =>
      other is TogetherGameState &&
      other.stage == stage &&
      other.number == number &&
      other.total == total &&
      other.mode == mode &&
      other.difficulty == difficulty &&
      other.track == track &&
      const ListEquality<Track>().equals(other.options, options) &&
      const ListEquality<String>().equals(other.lines, lines) &&
      other.count == count &&
      other.myTrackPick == myTrackPick &&
      other.myRealPick == myRealPick &&
      other.myStatus == myStatus &&
      const MapEquality<String, AnswerStatus>().equals(
        other.statuses,
        statuses,
      ) &&
      const MapEquality<String, RoundResult>().equals(other.results, results) &&
      other.answerTrackId == answerTrackId &&
      other.isReal == isReal &&
      other.sourceSong == sourceSong &&
      other.winnerId == winnerId &&
      const ListEquality<PlayerScore>().equals(other.standings, standings) &&
      other.revealLeft == revealLeft &&
      const SetEquality<String>().equals(other.departed, departed) &&
      const ListEquality<Player>().equals(other.roster, roster) &&
      other.startFailed == startFailed;

  @override
  int get hashCode => Object.hashAll([
    stage,
    number,
    total,
    mode,
    difficulty,
    track,
    const ListEquality<Track>().hash(options),
    const ListEquality<String>().hash(lines),
    count,
    myTrackPick,
    myRealPick,
    myStatus,
    const MapEquality<String, AnswerStatus>().hash(statuses),
    const MapEquality<String, RoundResult>().hash(results),
    answerTrackId,
    isReal,
    sourceSong,
    winnerId,
    const ListEquality<PlayerScore>().hash(standings),
    revealLeft,
    const SetEquality<String>().hash(departed),
    const ListEquality<Player>().hash(roster),
    startFailed,
  ]);

  @override
  String toString() =>
      'TogetherGameState(stage: $stage, number: $number, total: $total, '
      'mode: $mode, difficulty: $difficulty, track: ${track?.id}, '
      'options: ${options.length}, lines: ${lines.length}, count: $count, '
      'myTrackPick: $myTrackPick, myRealPick: $myRealPick, '
      'myStatus: $myStatus, statuses: $statuses, results: $results, '
      'answerTrackId: $answerTrackId, isReal: $isReal, '
      'sourceSong: $sourceSong, winnerId: $winnerId, '
      'standings: $standings, revealLeft: $revealLeft, '
      'departed: $departed, '
      'roster: ${[for (final player in roster) player.name]}, '
      'startFailed: $startFailed)';
}
