import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/providers.dart';

final gameControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);

class GameController extends Notifier<GameState> {
  @override
  GameState build() => GameState.initial;

  void setPhase(GamePhase phase) => state = state.copyWith(phase: phase);

  void setMode(GameMode mode) => state = state.copyWith(mode: mode);

  void setDifficulty(Difficulty difficulty) =>
      state = state.copyWith(difficulty: difficulty);

  void setQuizType(QuizType type) => state = state.copyWith(quizType: type);

  void setLyricsMode(LyricsMode mode) =>
      state = state.copyWith(lyricsMode: mode);

  void toggleAlbum(int albumId) {
    final selected = state.selectedAlbumIds;
    state = state.copyWith(
      selectedAlbumIds: selected.contains(albumId)
          ? [
              for (final id in selected)
                if (id != albumId) id,
            ]
          : [...selected, albumId],
    );
  }

  void clearSelectedAlbums() => state = state.copyWith(selectedAlbumIds: []);

  void setAlbums(List<Album> albums) => state = state.copyWith(albums: albums);

  void setTrackPool(List<Track> tracks) =>
      state = state.copyWith(trackPool: tracks);

  void startRound(Track track, List<Track> pool, List<Track> options) =>
      state = state.copyWith(
        currentTrack: track,
        trackPool: pool,
        options: options,
        relistenCount: 0,
        roundStartTime: ref.read(clockProvider)().millisecondsSinceEpoch,
      );

  void answerCorrect(Track track) {
    final albumId = '${track.album.id}';
    final trackId = '${track.id}';
    final stats = state.progress.stats;
    final existingAlbums = stats.albumsPlayed;
    final existingTracks = stats.tracksGuessedPerAlbum[albumId] ?? const [];
    final isLyrics = state.quizType == QuizType.lyrics;

    state = state.copyWith(
      streak: state.streak + 1,
      quackCount: 0,
      sessionSoundCorrect: isLyrics
          ? state.sessionSoundCorrect
          : state.sessionSoundCorrect + 1,
      sessionLyricsCorrect: isLyrics
          ? state.sessionLyricsCorrect + 1
          : state.sessionLyricsCorrect,
      progress: state.progress.copyWith(
        stats: stats.copyWith(
          totalCorrect: stats.totalCorrect + 1,
          albumsPlayed: existingAlbums.contains(albumId)
              ? existingAlbums
              : [...existingAlbums, albumId],
          tracksGuessedPerAlbum: {
            ...stats.tracksGuessedPerAlbum,
            albumId: existingTracks.contains(trackId)
                ? existingTracks
                : [...existingTracks, trackId],
          },
          totalLyricsCorrect: isLyrics
              ? stats.totalLyricsCorrect + 1
              : stats.totalLyricsCorrect,
        ),
      ),
    );
  }

  void answerIncorrect() =>
      state = state.copyWith(streak: 0, quackCount: state.quackCount + 1);

  void incrementRelisten() =>
      state = state.copyWith(relistenCount: state.relistenCount + 1);

  void resetGame() => state = state.copyWith(
    phase: GamePhase.menu,
    currentTrack: null,
    trackPool: [],
    options: [],
    streak: 0,
    quackCount: 0,
    relistenCount: 0,
    selectedAlbumIds: [],
    quizType: null,
    lyricsMode: null,
    lyricsPool: [],
    lyricsPoolIndex: 0,
    decoyPool: {},
    lyricsFetchProgress: null,
    lyricsAvailableTracks: [],
  );

  void setProgress(GameProgress progress) =>
      state = state.copyWith(progress: progress);

  void setUpdaterState(UpdaterMachineState next) =>
      state = state.copyWith(updaterState: next);

  void setTheme(ThemeSetting theme) =>
      _updateSettings((settings) => settings.copyWith(theme: theme));

  void setVolume(double volume) =>
      _updateSettings((settings) => settings.copyWith(volume: volume));

  void setMediumTimer(int seconds) =>
      _updateSettings((settings) => settings.copyWith(mediumTimer: seconds));

  void setHardTimer(int seconds) =>
      _updateSettings((settings) => settings.copyWith(hardTimer: seconds));

  void addToast(String achievementId) => state = state.copyWith(
    pendingToasts: [...state.pendingToasts, achievementId],
  );

  void dismissToast(String achievementId) => state = state.copyWith(
    pendingToasts: [
      for (final id in state.pendingToasts)
        if (id != achievementId) id,
    ],
  );

  void resetProgress() => state = state.copyWith(progress: defaultProgress);

  void setLyricsPool(List<TrackWithLyrics> pool) =>
      state = state.copyWith(lyricsPool: pool, lyricsPoolIndex: 0);

  void addToDecoyPool(int trackId, TrackLyrics lyrics) =>
      state = state.copyWith(decoyPool: {...state.decoyPool, trackId: lyrics});

  TrackWithLyrics? nextLyricsTrack() {
    final pool = state.lyricsPool;
    if (pool.isEmpty) {
      return null;
    }
    final index = state.lyricsPoolIndex;
    if (index >= pool.length) {
      state = state.copyWith(lyricsPoolIndex: 1);
      return pool.first;
    }
    state = state.copyWith(lyricsPoolIndex: index + 1);
    return pool[index];
  }

  void incrementLyricsStat(LyricsMode mode) {
    final stats = state.progress.stats;
    state = state.copyWith(
      progress: state.progress.copyWith(
        stats: switch (mode) {
          LyricsMode.nameThatSong => stats.copyWith(
            nameThaSongCorrect: stats.nameThaSongCorrect + 1,
          ),
          LyricsMode.lyricsOrLie => stats.copyWith(
            lyricsOrLieCorrect: stats.lyricsOrLieCorrect + 1,
          ),
        },
      ),
    );
  }

  void setLyricsFetchProgress(LyricsFetchProgress? progress) =>
      state = state.copyWith(lyricsFetchProgress: progress);

  void setLyricsAvailableTracks(List<Track> tracks) =>
      state = state.copyWith(lyricsAvailableTracks: tracks);

  void _updateSettings(GameSettings Function(GameSettings settings) change) =>
      state = state.copyWith(
        progress: state.progress.copyWith(
          settings: change(state.progress.settings),
        ),
      );
}
