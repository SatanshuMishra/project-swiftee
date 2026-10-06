import 'package:collection/collection.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';

const Object _unchanged = Object();

typedef LyricsFetchProgress = ({int fetched, int total});

final class RoundOutcome {
  const RoundOutcome(this.track, {required this.correct});

  final Track track;
  final bool correct;

  @override
  bool operator ==(Object other) =>
      other is RoundOutcome && other.track == track && other.correct == correct;

  @override
  int get hashCode => Object.hash(track, correct);

  @override
  String toString() => 'RoundOutcome(track: $track, correct: $correct)';
}

final class GameState {
  const GameState._({
    required this.phase,
    required this.mode,
    required this.difficulty,
    required this.quizType,
    required this.lyricsMode,
    required this.selectedEraKeys,
    required this.selectedReleaseIds,
    required this.versions,
    required this.currentTrack,
    required this.trackPool,
    required this.options,
    required this.streak,
    required this.quackCount,
    required this.relistenCount,
    required this.roundStartTime,
    required this.lyricsPool,
    required this.lyricsPoolIndex,
    required this.decoyPool,
    required this.lyricsFetchProgress,
    required this.lyricsAvailableTracks,
    required this.sessionSoundCorrect,
    required this.sessionLyricsCorrect,
    required this.albums,
    required this.progress,
    required this.updaterState,
    required this.pendingToasts,
    required this.quickRoundTotal,
    required this.roundNumber,
    required this.roundResults,
  });

  static const GameState initial = GameState._(
    phase: GamePhase.menu,
    mode: GameMode.random,
    difficulty: Difficulty.easy,
    quizType: null,
    lyricsMode: null,
    selectedEraKeys: [],
    selectedReleaseIds: [],
    versions: TrackVersions.every,
    currentTrack: null,
    trackPool: [],
    options: [],
    streak: 0,
    quackCount: 0,
    relistenCount: 0,
    roundStartTime: 0,
    lyricsPool: [],
    lyricsPoolIndex: 0,
    decoyPool: {},
    lyricsFetchProgress: null,
    lyricsAvailableTracks: [],
    sessionSoundCorrect: 0,
    sessionLyricsCorrect: 0,
    albums: [],
    progress: defaultProgress,
    updaterState: UpdaterIdle(),
    pendingToasts: [],
    quickRoundTotal: null,
    roundNumber: 0,
    roundResults: [],
  );

  final GamePhase phase;
  final GameMode mode;
  final Difficulty difficulty;
  final QuizType? quizType;
  final LyricsMode? lyricsMode;
  final List<String> selectedEraKeys;
  final List<int> selectedReleaseIds;
  final TrackVersions versions;
  final Track? currentTrack;
  final List<Track> trackPool;
  final List<Track> options;
  final int streak;
  final int quackCount;
  final int relistenCount;
  final int roundStartTime;
  final List<TrackWithLyrics> lyricsPool;
  final int lyricsPoolIndex;
  final Map<int, TrackLyrics> decoyPool;
  final LyricsFetchProgress? lyricsFetchProgress;
  final List<Track> lyricsAvailableTracks;
  final int sessionSoundCorrect;
  final int sessionLyricsCorrect;
  final List<Album> albums;
  final GameProgress progress;
  final UpdaterMachineState updaterState;
  final List<String> pendingToasts;
  final int? quickRoundTotal;
  final int roundNumber;
  final List<RoundOutcome> roundResults;

  bool get isLastQuickRound {
    final total = quickRoundTotal;
    return total != null && roundNumber >= total;
  }

  GameState copyWith({
    GamePhase? phase,
    GameMode? mode,
    Difficulty? difficulty,
    Object? quizType = _unchanged,
    Object? lyricsMode = _unchanged,
    List<String>? selectedEraKeys,
    List<int>? selectedReleaseIds,
    TrackVersions? versions,
    Object? currentTrack = _unchanged,
    List<Track>? trackPool,
    List<Track>? options,
    int? streak,
    int? quackCount,
    int? relistenCount,
    int? roundStartTime,
    List<TrackWithLyrics>? lyricsPool,
    int? lyricsPoolIndex,
    Map<int, TrackLyrics>? decoyPool,
    Object? lyricsFetchProgress = _unchanged,
    List<Track>? lyricsAvailableTracks,
    int? sessionSoundCorrect,
    int? sessionLyricsCorrect,
    List<Album>? albums,
    GameProgress? progress,
    UpdaterMachineState? updaterState,
    List<String>? pendingToasts,
    Object? quickRoundTotal = _unchanged,
    int? roundNumber,
    List<RoundOutcome>? roundResults,
  }) => GameState._(
    phase: phase ?? this.phase,
    mode: mode ?? this.mode,
    difficulty: difficulty ?? this.difficulty,
    quizType: identical(quizType, _unchanged)
        ? this.quizType
        : quizType as QuizType?,
    lyricsMode: identical(lyricsMode, _unchanged)
        ? this.lyricsMode
        : lyricsMode as LyricsMode?,
    selectedEraKeys: selectedEraKeys == null
        ? this.selectedEraKeys
        : List.unmodifiable(selectedEraKeys),
    selectedReleaseIds: selectedReleaseIds == null
        ? this.selectedReleaseIds
        : List.unmodifiable(selectedReleaseIds),
    versions: versions ?? this.versions,
    currentTrack: identical(currentTrack, _unchanged)
        ? this.currentTrack
        : currentTrack as Track?,
    trackPool: trackPool == null
        ? this.trackPool
        : List.unmodifiable(trackPool),
    options: options == null ? this.options : List.unmodifiable(options),
    streak: streak ?? this.streak,
    quackCount: quackCount ?? this.quackCount,
    relistenCount: relistenCount ?? this.relistenCount,
    roundStartTime: roundStartTime ?? this.roundStartTime,
    lyricsPool: lyricsPool == null
        ? this.lyricsPool
        : List.unmodifiable(lyricsPool),
    lyricsPoolIndex: lyricsPoolIndex ?? this.lyricsPoolIndex,
    decoyPool: decoyPool == null ? this.decoyPool : Map.unmodifiable(decoyPool),
    lyricsFetchProgress: identical(lyricsFetchProgress, _unchanged)
        ? this.lyricsFetchProgress
        : lyricsFetchProgress as LyricsFetchProgress?,
    lyricsAvailableTracks: lyricsAvailableTracks == null
        ? this.lyricsAvailableTracks
        : List.unmodifiable(lyricsAvailableTracks),
    sessionSoundCorrect: sessionSoundCorrect ?? this.sessionSoundCorrect,
    sessionLyricsCorrect: sessionLyricsCorrect ?? this.sessionLyricsCorrect,
    albums: albums == null ? this.albums : List.unmodifiable(albums),
    progress: progress ?? this.progress,
    updaterState: updaterState ?? this.updaterState,
    pendingToasts: pendingToasts == null
        ? this.pendingToasts
        : List.unmodifiable(pendingToasts),
    quickRoundTotal: identical(quickRoundTotal, _unchanged)
        ? this.quickRoundTotal
        : quickRoundTotal as int?,
    roundNumber: roundNumber ?? this.roundNumber,
    roundResults: roundResults == null
        ? this.roundResults
        : List.unmodifiable(roundResults),
  );

  @override
  bool operator ==(Object other) =>
      other is GameState &&
      other.phase == phase &&
      other.mode == mode &&
      other.difficulty == difficulty &&
      other.quizType == quizType &&
      other.lyricsMode == lyricsMode &&
      const ListEquality<String>().equals(
        other.selectedEraKeys,
        selectedEraKeys,
      ) &&
      const ListEquality<int>().equals(
        other.selectedReleaseIds,
        selectedReleaseIds,
      ) &&
      other.versions == versions &&
      other.currentTrack == currentTrack &&
      const ListEquality<Track>().equals(other.trackPool, trackPool) &&
      const ListEquality<Track>().equals(other.options, options) &&
      other.streak == streak &&
      other.quackCount == quackCount &&
      other.relistenCount == relistenCount &&
      other.roundStartTime == roundStartTime &&
      const ListEquality<TrackWithLyrics>().equals(
        other.lyricsPool,
        lyricsPool,
      ) &&
      other.lyricsPoolIndex == lyricsPoolIndex &&
      const MapEquality<int, TrackLyrics>().equals(
        other.decoyPool,
        decoyPool,
      ) &&
      other.lyricsFetchProgress == lyricsFetchProgress &&
      const ListEquality<Track>().equals(
        other.lyricsAvailableTracks,
        lyricsAvailableTracks,
      ) &&
      other.sessionSoundCorrect == sessionSoundCorrect &&
      other.sessionLyricsCorrect == sessionLyricsCorrect &&
      const ListEquality<Album>().equals(other.albums, albums) &&
      other.progress == progress &&
      other.updaterState == updaterState &&
      const ListEquality<String>().equals(other.pendingToasts, pendingToasts) &&
      other.quickRoundTotal == quickRoundTotal &&
      other.roundNumber == roundNumber &&
      const ListEquality<RoundOutcome>().equals(
        other.roundResults,
        roundResults,
      );

  @override
  int get hashCode => Object.hashAll([
    phase,
    mode,
    difficulty,
    quizType,
    lyricsMode,
    const ListEquality<String>().hash(selectedEraKeys),
    const ListEquality<int>().hash(selectedReleaseIds),
    versions,
    currentTrack,
    const ListEquality<Track>().hash(trackPool),
    const ListEquality<Track>().hash(options),
    streak,
    quackCount,
    relistenCount,
    roundStartTime,
    const ListEquality<TrackWithLyrics>().hash(lyricsPool),
    lyricsPoolIndex,
    const MapEquality<int, TrackLyrics>().hash(decoyPool),
    lyricsFetchProgress,
    const ListEquality<Track>().hash(lyricsAvailableTracks),
    sessionSoundCorrect,
    sessionLyricsCorrect,
    const ListEquality<Album>().hash(albums),
    progress,
    updaterState,
    const ListEquality<String>().hash(pendingToasts),
    quickRoundTotal,
    roundNumber,
    const ListEquality<RoundOutcome>().hash(roundResults),
  ]);

  @override
  String toString() =>
      'GameState(phase: $phase, mode: $mode, difficulty: $difficulty, '
      'quizType: $quizType, lyricsMode: $lyricsMode, '
      'selectedEraKeys: $selectedEraKeys, '
      'selectedReleaseIds: $selectedReleaseIds, versions: $versions, '
      'currentTrack: $currentTrack, '
      'trackPool: ${trackPool.length} tracks, '
      'options: ${options.length} tracks, streak: $streak, '
      'quackCount: $quackCount, relistenCount: $relistenCount, '
      'roundStartTime: $roundStartTime, '
      'lyricsPool: ${lyricsPool.length} tracks, '
      'lyricsPoolIndex: $lyricsPoolIndex, '
      'decoyPool: ${decoyPool.length} entries, '
      'lyricsFetchProgress: $lyricsFetchProgress, '
      'lyricsAvailableTracks: ${lyricsAvailableTracks.length} tracks, '
      'sessionSoundCorrect: $sessionSoundCorrect, '
      'sessionLyricsCorrect: $sessionLyricsCorrect, '
      'albums: ${albums.length} albums, progress: $progress, '
      'updaterState: $updaterState, pendingToasts: $pendingToasts, '
      'quickRoundTotal: $quickRoundTotal, roundNumber: $roundNumber, '
      'roundResults: ${roundResults.length} outcomes)';
}
