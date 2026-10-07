import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/play_order.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/domain/together/server_link.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/play_history_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

final gameControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);

const int quickRoundLength = 10;

const int nicknameMaxLength = 20;

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

  void toggleEra(String eraKey) {
    final selected = state.selectedEraKeys;
    state = state.copyWith(
      selectedEraKeys: selected.contains(eraKey)
          ? [
              for (final key in selected)
                if (key != eraKey) key,
            ]
          : [...selected, eraKey],
    );
  }

  void toggleRelease(int releaseId) {
    final selected = state.selectedReleaseIds;
    state = state.copyWith(
      selectedReleaseIds: selected.contains(releaseId)
          ? [
              for (final id in selected)
                if (id != releaseId) id,
            ]
          : [...selected, releaseId],
    );
  }

  void clearSelection() =>
      state = state.copyWith(selectedEraKeys: [], selectedReleaseIds: []);

  void setVersions(VersionChoice versions) =>
      state = state.copyWith(versions: versions);

  void beginSetup(GameMode mode) => state = state.copyWith(
    mode: mode,
    quickRoundTotal: null,
    roundNumber: 0,
    roundResults: [],
    phase: GamePhase.setup,
  );

  void startQuickRound() => state = state.copyWith(
    mode: GameMode.tonight,
    quizType: QuizType.sound,
    lyricsMode: null,
    difficulty: Difficulty.medium,
    quickRoundTotal: quickRoundLength,
    roundNumber: 0,
    roundResults: [],
    streak: 0,
    quackCount: 0,
    phase: GamePhase.playing,
  );

  void finishQuickRound() =>
      state = state.copyWith(phase: GamePhase.roundSummary);

  void setAlbums(List<Album> albums) => state = state.copyWith(albums: albums);

  void setTrackPool(List<Track> tracks) =>
      state = state.copyWith(trackPool: tracks);

  void startRound(
    Track track,
    List<Track> pool,
    List<Track> options, {
    bool redraw = false,
  }) => state = state.copyWith(
    currentTrack: track,
    trackPool: pool,
    options: options,
    relistenCount: 0,
    roundStartTime: ref.read(clockProvider)().millisecondsSinceEpoch,
    roundNumber: redraw && state.roundNumber > state.roundResults.length
        ? state.roundNumber
        : state.roundNumber + 1,
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
      roundResults: [...state.roundResults, RoundOutcome(track, correct: true)],
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

  void answerIncorrect([Track? track]) => state = state.copyWith(
    streak: 0,
    quackCount: state.quackCount + 1,
    roundResults: track == null
        ? null
        : [...state.roundResults, RoundOutcome(track, correct: false)],
  );

  void incrementRelisten() =>
      state = state.copyWith(relistenCount: state.relistenCount + 1);

  void resetRelisten() => state = state.copyWith(relistenCount: 0);

  void resetGame() => state = state.copyWith(
    phase: GamePhase.menu,
    currentTrack: null,
    trackPool: [],
    options: [],
    streak: 0,
    quackCount: 0,
    relistenCount: 0,
    selectedEraKeys: [],
    selectedReleaseIds: [],
    quizType: null,
    lyricsMode: null,
    lyricsPool: [],
    lyricsPoolIndex: 0,
    decoyPool: {},
    lyricsFetchProgress: null,
    lyricsAvailableTracks: [],
    quickRoundTotal: null,
    roundNumber: 0,
    roundResults: [],
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

  void setMisuVisits(MisuVisits visits) =>
      _updateSettings((settings) => settings.copyWith(misuVisits: visits));

  void setNickname(String value) {
    final nickname = value
        .trim()
        .characters
        .take(nicknameMaxLength)
        .toString()
        .trimRight();
    if (nickname.isEmpty) {
      return;
    }
    _updateSettings((settings) => settings.copyWith(nickname: nickname));
  }

  void setTogetherLink(String text) => _updateSettings(
    (settings) => settings.copyWith(togetherLink: ServerLink.parse(text)?.text),
  );

  void addToast(String achievementId) => state = state.copyWith(
    pendingToasts: [...state.pendingToasts, achievementId],
  );

  void dismissToast(String achievementId) => state = state.copyWith(
    pendingToasts: [
      for (final id in state.pendingToasts)
        if (id != achievementId) id,
    ],
  );

  void resetProgress() => state = state.copyWith(
    progress: state.progress.copyWith(
      achievements: defaultProgress.achievements,
      stats: defaultProgress.stats,
    ),
  );

  void setLyricsPool(List<TrackWithLyrics> pool) =>
      state = state.copyWith(lyricsPool: pool, lyricsPoolIndex: 0);

  void appendLyricsPool(List<TrackWithLyrics> fresh) {
    final pool = state.lyricsPool;
    final ids = {for (final entry in pool) entry.track.id};
    final songs = {for (final entry in pool) songKey(entry.track)};
    final added = [
      for (final entry in fresh)
        if (ids.add(entry.track.id) && songs.add(songKey(entry.track))) entry,
    ];
    if (added.isNotEmpty) {
      state = state.copyWith(lyricsPool: [...pool, ...added]);
    }
  }

  void addToDecoyPool(int trackId, TrackLyrics lyrics) =>
      state = state.copyWith(decoyPool: {...state.decoyPool, trackId: lyrics});

  TrackWithLyrics? nextLyricsTrack() {
    final pool = state.lyricsPool;
    if (pool.isEmpty) {
      return null;
    }
    final index = state.lyricsPoolIndex;
    final roundNumber = state.roundNumber + 1;
    if (index >= pool.length) {
      final replay = lyricsReplay(
        pool,
        track: (entry) => entry.track,
        read: ref.read(playHistoryProvider).read,
        random: ref.read(randomProvider),
      );
      state = state.copyWith(
        lyricsPool: replay,
        lyricsPoolIndex: 1,
        roundNumber: roundNumber,
      );
      return replay.first;
    }
    state = state.copyWith(
      lyricsPoolIndex: index + 1,
      roundNumber: roundNumber,
    );
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
