import 'package:collection/collection.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';

enum TogetherMode {
  classic(
    'classic',
    'Classic',
    'Everyone hears the same clip and answers. Faster right answers score more.',
  ),
  quickDraw(
    'quick-draw',
    'Quick draw',
    'First right answer takes the round. Guess wrong and you sit out until the next song.',
  ),
  lyricsOrLie(
    'lyrics-or-lie',
    'Lyrics or Lie',
    'Everyone sees the same line and votes Real or Fake. Every right call scores.',
  );

  const TogetherMode(this.wireName, this.title, this.description);

  final String wireName;
  final String title;
  final String description;

  static TogetherMode? fromWireName(String wireName) =>
      values.firstWhereOrNull((value) => value.wireName == wireName);
}

const List<int> roundChoices = [5, 10, 15];

const int countdownFrom = 3;
const Duration countdownStep = Duration(milliseconds: 800);
const int revealSeconds = 6;
const Duration allAnsweredDelay = Duration(milliseconds: 600);
const Duration quickDrawWindow = Duration(milliseconds: 500);
const Duration timeUpGrace = Duration(seconds: 1);
const double closeFinishGap = 0.5;
const int closeFinishEvery = 3;

int roundSeconds(Difficulty difficulty) => switch (difficulty) {
  Difficulty.easy => 30,
  Difficulty.medium => 20,
  Difficulty.hard => 12,
};

String difficultyNote(Difficulty difficulty) => switch (difficulty) {
  Difficulty.easy => 'Album cover shown · 30 seconds a round',
  Difficulty.medium => 'No hints · 20 seconds a round',
  Difficulty.hard => 'No hints · 12 seconds a round',
};

final class RoomScope {
  const RoomScope.everything() : eraKeys = const [], releaseIds = const [];

  RoomScope.picked({
    required List<String> eraKeys,
    required List<int> releaseIds,
  }) : eraKeys = List.unmodifiable(eraKeys),
       releaseIds = List.unmodifiable(releaseIds);

  final List<String> eraKeys;
  final List<int> releaseIds;

  bool get everything => eraKeys.isEmpty && releaseIds.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is RoomScope &&
      const ListEquality<String>().equals(other.eraKeys, eraKeys) &&
      const ListEquality<int>().equals(other.releaseIds, releaseIds);

  @override
  int get hashCode => Object.hash(
    const ListEquality<String>().hash(eraKeys),
    const ListEquality<int>().hash(releaseIds),
  );

  @override
  String toString() => everything
      ? 'RoomScope.everything()'
      : 'RoomScope.picked(eraKeys: $eraKeys, releaseIds: $releaseIds)';
}

final class RoomSettings {
  const RoomSettings({
    this.mode = TogetherMode.classic,
    this.rounds = 10,
    this.difficulty = Difficulty.medium,
    this.scope = const RoomScope.everything(),
  });

  final TogetherMode mode;
  final int rounds;
  final Difficulty difficulty;
  final RoomScope scope;

  RoomSettings copyWith({
    TogetherMode? mode,
    int? rounds,
    Difficulty? difficulty,
    RoomScope? scope,
  }) => RoomSettings(
    mode: mode ?? this.mode,
    rounds: rounds ?? this.rounds,
    difficulty: difficulty ?? this.difficulty,
    scope: scope ?? this.scope,
  );

  @override
  bool operator ==(Object other) =>
      other is RoomSettings &&
      other.mode == mode &&
      other.rounds == rounds &&
      other.difficulty == difficulty &&
      other.scope == scope;

  @override
  int get hashCode => Object.hash(mode, rounds, difficulty, scope);

  @override
  String toString() =>
      'RoomSettings(mode: $mode, rounds: $rounds, '
      'difficulty: $difficulty, scope: $scope)';
}
