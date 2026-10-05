import 'package:swiftie_quiz/domain/models/track.dart';

const Object _unchanged = Object();

final class RoundResult {
  const RoundResult({
    required this.correct,
    required this.correctTrack,
    required this.answeredTrackId,
    required this.answeredText,
    required this.timeElapsed,
    required this.usedFullClip,
  });

  final bool correct;
  final Track correctTrack;
  final int? answeredTrackId;
  final String? answeredText;
  final int timeElapsed;
  final bool usedFullClip;

  RoundResult copyWith({
    bool? correct,
    Track? correctTrack,
    Object? answeredTrackId = _unchanged,
    Object? answeredText = _unchanged,
    int? timeElapsed,
    bool? usedFullClip,
  }) => RoundResult(
    correct: correct ?? this.correct,
    correctTrack: correctTrack ?? this.correctTrack,
    answeredTrackId: identical(answeredTrackId, _unchanged)
        ? this.answeredTrackId
        : answeredTrackId as int?,
    answeredText: identical(answeredText, _unchanged)
        ? this.answeredText
        : answeredText as String?,
    timeElapsed: timeElapsed ?? this.timeElapsed,
    usedFullClip: usedFullClip ?? this.usedFullClip,
  );

  @override
  bool operator ==(Object other) =>
      other is RoundResult &&
      other.correct == correct &&
      other.correctTrack == correctTrack &&
      other.answeredTrackId == answeredTrackId &&
      other.answeredText == answeredText &&
      other.timeElapsed == timeElapsed &&
      other.usedFullClip == usedFullClip;

  @override
  int get hashCode => Object.hash(
    correct,
    correctTrack,
    answeredTrackId,
    answeredText,
    timeElapsed,
    usedFullClip,
  );

  @override
  String toString() =>
      'RoundResult(correct: $correct, correctTrack: $correctTrack, '
      'answeredTrackId: $answeredTrackId, answeredText: $answeredText, '
      'timeElapsed: $timeElapsed, usedFullClip: $usedFullClip)';
}
