import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/achievements.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

typedef AchievementContext = ({
  bool correct,
  int streak,
  int quackCount,
  Difficulty difficulty,
  Duration timeElapsed,
  bool usedFullClip,
  GameProgress progress,
  Map<int, int> albumTrackTotals,
  int erasPlayed,
  QuizType? quizType,
  LyricsMode? lyricsMode,
  int sessionSoundCorrect,
  int sessionLyricsCorrect,
  Track? track,
});

const Duration _speedDemonLimit = Duration(seconds: 3);

bool achievementConditionMet(String id, AchievementContext context) {
  if (!context.correct && id != 'quack_collector') {
    return false;
  }
  final stats = context.progress.stats;
  return switch (id) {
    'first_meow' => stats.totalCorrect >= 1,
    'getting_warmed_up' => stats.totalCorrect >= 10,
    'purrfect_streak' => context.streak >= 10,
    'album_explorer' => context.erasPlayed >= 5,
    'album_completionist' => _hasCompletedAlbum(
      stats,
      context.albumTrackTotals,
    ),
    'hard_mode_hero' =>
      context.difficulty == Difficulty.hard && stats.totalCorrect >= 5,
    'speed_demon' => context.timeElapsed <= _speedDemonLimit,
    'persistent_listener' => context.usedFullClip,
    'quack_collector' => !context.correct && context.quackCount >= 5,
    'all_ears' => stats.totalCorrect >= 50,
    'lyric_lover' => stats.totalLyricsCorrect >= 1,
    'poet_laureate' => stats.nameThaSongCorrect >= 20,
    'lie_detector' => stats.lyricsOrLieCorrect >= 15,
    'dual_threat' =>
      context.sessionSoundCorrect >= 1 && context.sessionLyricsCorrect >= 1,
    'lyric_streak' =>
      context.quizType == QuizType.lyrics && context.streak >= 10,
    _ => false,
  };
}

int erasPlayed(Iterable<String> albumIds, Catalogue catalogue) => {
  for (final id in albumIds)
    switch (int.tryParse(id)) {
      final albumId? => catalogue.eraOf(albumId)?.key ?? 'album:$id',
      null => 'album:$id',
    },
}.length;

Map<int, int> eraAlbumTotals(Catalogue catalogue) {
  final totals = catalogue.homeTotals;
  return Map.unmodifiable({
    for (final era in catalogue.albumEras)
      era.deezerAlbumId: ?totals[era.deezerAlbumId],
  });
}

bool _hasCompletedAlbum(GameStats stats, Map<int, int> albumTrackTotals) =>
    albumTrackTotals.entries.any(
      (album) =>
          album.value > 0 &&
          (stats.tracksGuessedPerAlbum['${album.key}']?.length ?? 0) >=
              album.value,
    );

String _isoTimestamp(DateTime moment) => DateTime.fromMillisecondsSinceEpoch(
  moment.millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();

final achievementsControllerProvider = Provider<AchievementsController>(
  AchievementsController.new,
);

class AchievementsController {
  AchievementsController(this._ref);

  final Ref _ref;

  List<String> checkAfterAnswer({
    required bool correct,
    required Duration timeElapsed,
    required bool usedFullClip,
    Track? track,
  }) {
    final game = _ref.read(gameControllerProvider);
    final catalogue = _ref.read(catalogControllerProvider).catalogue;
    return checkAndUnlock((
      correct: correct,
      streak: game.streak,
      quackCount: game.quackCount,
      difficulty: game.difficulty,
      timeElapsed: timeElapsed,
      usedFullClip: usedFullClip,
      progress: game.progress,
      albumTrackTotals: eraAlbumTotals(catalogue),
      erasPlayed: erasPlayed(game.progress.stats.albumsPlayed, catalogue),
      quizType: game.quizType,
      lyricsMode: game.lyricsMode,
      sessionSoundCorrect: game.sessionSoundCorrect,
      sessionLyricsCorrect: game.sessionLyricsCorrect,
      track: track,
    ));
  }

  List<String> checkAndUnlock(AchievementContext context) {
    final progress = _ref.read(gameControllerProvider).progress;
    final newlyUnlocked = List<String>.unmodifiable([
      for (final def in achievementDefs)
        if (!(progress.achievements[def.id]?.unlocked ?? false) &&
            achievementConditionMet(def.id, context))
          def.id,
    ]);
    if (newlyUnlocked.isEmpty) {
      return newlyUnlocked;
    }
    final track = context.track;
    final unlocked = AchievementState(
      unlocked: true,
      unlockedAt: _isoTimestamp(_ref.read(clockProvider)()),
      song: track?.title,
      albumId: track == null ? null : '${track.album.id}',
      trackId: track == null ? null : '${track.id}',
    );
    final game = _ref.read(gameControllerProvider.notifier)
      ..setProgress(
        progress.copyWith(
          achievements: {
            ...progress.achievements,
            for (final id in newlyUnlocked) id: unlocked,
          },
        ),
      );
    for (final id in newlyUnlocked) {
      game.addToast(id);
    }
    return newlyUnlocked;
  }
}
