import 'dart:math';

import 'package:collection/collection.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/domain/together/scoring.dart';

const Object _unchanged = Object();

final class FastestAnswer {
  const FastestAnswer({required this.seconds, required this.song});

  final double seconds;
  final String song;

  @override
  bool operator ==(Object other) =>
      other is FastestAnswer && other.seconds == seconds && other.song == song;

  @override
  int get hashCode => Object.hash(seconds, song);

  @override
  String toString() => 'FastestAnswer(seconds: $seconds, song: $song)';
}

final class PlayerScore {
  const PlayerScore({
    required this.id,
    required this.score,
    required this.streak,
    required this.best,
    required this.wins,
    required this.fastest,
    required this.left,
  });

  const PlayerScore.start(this.id)
    : score = 0,
      streak = 0,
      best = 0,
      wins = 0,
      fastest = null,
      left = false;

  final String id;
  final int score;
  final int streak;
  final int best;
  final int wins;
  final FastestAnswer? fastest;
  final bool left;

  PlayerScore copyWith({
    String? id,
    int? score,
    int? streak,
    int? best,
    int? wins,
    Object? fastest = _unchanged,
    bool? left,
  }) => PlayerScore(
    id: id ?? this.id,
    score: score ?? this.score,
    streak: streak ?? this.streak,
    best: best ?? this.best,
    wins: wins ?? this.wins,
    fastest: identical(fastest, _unchanged)
        ? this.fastest
        : fastest as FastestAnswer?,
    left: left ?? this.left,
  );

  @override
  bool operator ==(Object other) =>
      other is PlayerScore &&
      other.id == id &&
      other.score == score &&
      other.streak == streak &&
      other.best == best &&
      other.wins == wins &&
      other.fastest == fastest &&
      other.left == left;

  @override
  int get hashCode => Object.hash(id, score, streak, best, wins, fastest, left);

  @override
  String toString() =>
      'PlayerScore(id: $id, score: $score, streak: $streak, best: $best, '
      'wins: $wins, fastest: $fastest, left: $left)';
}

final class RoundResult {
  const RoundResult({
    required this.playerId,
    required this.pickTrackId,
    required this.pickReal,
    required this.right,
    required this.at,
    required this.gain,
  });

  final String playerId;
  final int? pickTrackId;
  final bool? pickReal;
  final bool right;
  final double? at;
  final int gain;

  @override
  bool operator ==(Object other) =>
      other is RoundResult &&
      other.playerId == playerId &&
      other.pickTrackId == pickTrackId &&
      other.pickReal == pickReal &&
      other.right == right &&
      other.at == at &&
      other.gain == gain;

  @override
  int get hashCode =>
      Object.hash(playerId, pickTrackId, pickReal, right, at, gain);

  @override
  String toString() =>
      'RoundResult(playerId: $playerId, pickTrackId: $pickTrackId, '
      'pickReal: $pickReal, right: $right, at: $at, gain: $gain)';
}

List<PlayerScore> applyRound(
  List<PlayerScore> before,
  List<RoundResult> results,
  String song,
) {
  final byPlayer = {for (final result in results) result.playerId: result};
  return List.unmodifiable([
    for (final player in before) _scored(player, byPlayer[player.id], song),
  ]);
}

PlayerScore _scored(PlayerScore player, RoundResult? result, String song) {
  if (player.left) return player;
  if (result == null || result.gain <= 0) return player.copyWith(streak: 0);
  final streak = player.streak + 1;
  final at = result.at;
  final fastest = player.fastest;
  final faster = at != null && (fastest == null || at < fastest.seconds);
  return player.copyWith(
    score: player.score + result.gain,
    streak: streak,
    best: max(player.best, streak),
    wins: player.wins + 1,
    fastest: faster ? FastestAnswer(seconds: at, song: song) : fastest,
  );
}

List<PlayerScore> ranked(
  List<PlayerScore> players, {
  required String viewerId,
  required List<String> joinOrder,
}) {
  int place(int index) {
    final joined = joinOrder.indexOf(players[index].id);
    return joined < 0 ? joinOrder.length + index : joined;
  }

  final order = List.generate(players.length, (index) => index).sorted((a, b) {
    final byScore = players[b].score.compareTo(players[a].score);
    if (byScore != 0) return byScore;
    final aViewer = players[a].id == viewerId;
    final bViewer = players[b].id == viewerId;
    if (aViewer != bViewer) return aViewer ? -1 : 1;
    return place(a).compareTo(place(b));
  });
  return List.unmodifiable([for (final index in order) players[index]]);
}

({String id, FastestAnswer fastest})? fastestHighlight(
  List<PlayerScore> players,
) => players.fold<({String id, FastestAnswer fastest})?>(
  null,
  (top, player) => switch (player.fastest) {
    final fastest? when top == null || fastest.seconds < top.fastest.seconds =>
      (id: player.id, fastest: fastest),
    _ => top,
  },
);

({String id, int best})? streakHighlight(List<PlayerScore> players) {
  final longest = players.fold<PlayerScore?>(
    null,
    (top, player) => top == null || player.best > top.best ? player : top,
  );
  return longest == null || longest.best == 0
      ? null
      : (id: longest.id, best: longest.best);
}

String winnerTitle({
  required bool viewerWon,
  required String viewerName,
  required String winnerName,
}) => viewerWon ? 'You take it, $viewerName.' : '$winnerName takes it.';

String winnerSubline(int score, int rounds) =>
    '$score points over $rounds rounds.';

bool closeFinish({
  required TogetherMode mode,
  required List<double> rightTimes,
  required int round,
  required int lastRemarkRound,
}) {
  if (mode != TogetherMode.classic || rightTimes.length < 2) return false;
  if (round - lastRemarkRound < closeFinishEvery) return false;
  final times = rightTimes.sorted((a, b) => a.compareTo(b));
  return times[1] - times[0] < closeFinishGap;
}

String statusLine({
  required TogetherMode mode,
  required bool revealed,
  required AnswerStatus? status,
  required bool wonQuickDraw,
  required RoundResult? result,
  required bool left,
}) {
  if (left) return 'Left';
  if (!revealed) {
    return switch (status) {
      AnswerStatus.out => 'Sitting out',
      AnswerStatus.answered when wonQuickDraw => 'Got it first',
      AnswerStatus.answered => 'Answered',
      null => 'Listening…',
    };
  }
  if (mode == TogetherMode.quickDraw) {
    if (wonQuickDraw) return 'Got it first';
    return status == AnswerStatus.out ? 'Wrong guess' : '—';
  }
  return switch (result) {
    RoundResult(right: true, :final at) =>
      'Right · ${(at ?? 0).toStringAsFixed(1)} s',
    _ when status != null => 'Wrong',
    _ => 'No answer',
  };
}
