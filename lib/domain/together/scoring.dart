import 'package:collection/collection.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';

int roundGain(
  TogetherMode mode, {
  required bool right,
  required double at,
  required Difficulty difficulty,
  required bool won,
}) {
  final limit = roundSeconds(difficulty);
  return switch (mode) {
    TogetherMode.classic when right =>
      100 + (100 * (limit - at).clamp(0, limit) / limit).round(),
    TogetherMode.quickDraw => won ? 100 : 0,
    TogetherMode.lyricsOrLie when right => 100,
    _ => 0,
  };
}

final class TimedAnswer {
  const TimedAnswer({
    required this.playerId,
    required this.right,
    required this.at,
    required this.receivedAt,
  });

  final String playerId;
  final bool right;
  final double at;
  final Duration receivedAt;

  @override
  bool operator ==(Object other) =>
      other is TimedAnswer &&
      other.playerId == playerId &&
      other.right == right &&
      other.at == at &&
      other.receivedAt == receivedAt;

  @override
  int get hashCode => Object.hash(playerId, right, at, receivedAt);

  @override
  String toString() =>
      'TimedAnswer(playerId: $playerId, right: $right, at: $at, '
      'receivedAt: $receivedAt)';
}

String? quickDrawWinner(List<TimedAnswer> answers) {
  final right = answers.where((answer) => answer.right).toList();
  if (right.isEmpty) return null;
  final first = right.map((answer) => answer.receivedAt).min;
  return right
      .where((answer) => answer.receivedAt - first <= quickDrawWindow)
      .sorted(_quickDrawOrder)
      .first
      .playerId;
}

int _quickDrawOrder(TimedAnswer a, TimedAnswer b) {
  final bySelfTime = a.at.compareTo(b.at);
  return bySelfTime != 0 ? bySelfTime : a.receivedAt.compareTo(b.receivedAt);
}

enum AnswerStatus { answered, out }

AnswerStatus answerStatus(TogetherMode mode, {required bool right}) =>
    mode == TogetherMode.quickDraw && !right
    ? AnswerStatus.out
    : AnswerStatus.answered;

bool everyoneDone(
  Iterable<String> activeIds,
  Map<String, AnswerStatus> statuses,
) => activeIds.every(statuses.containsKey);
