import { create } from "zustand";
import type {
  Album,
  Difficulty,
  GameMode,
  GamePhase,
  GameProgress,
  LyricsMode,
  QuizType,
  Track,
  TrackLyrics,
  TrackWithLyrics,
  Theme,
  UpdaterMachineState,
} from "../types";
import { DEFAULT_PROGRESS } from "../types";

interface GameStore {
  // Navigation
  readonly phase: GamePhase;
  readonly mode: GameMode;
  readonly difficulty: Difficulty;

  // Quiz type (sound vs lyrics)
  readonly quizType: QuizType | null;
  readonly lyricsMode: LyricsMode | null;

  // Album selection
  readonly selectedAlbumIds: readonly number[];

  // Round state
  readonly currentTrack: Track | null;
  readonly trackPool: readonly Track[];
  readonly options: readonly Track[];
  readonly streak: number;
  readonly quackCount: number;
  readonly relistenCount: number;
  readonly roundStartTime: number;

  // Lyrics pool
  readonly lyricsPool: readonly TrackWithLyrics[];
  readonly lyricsPoolIndex: number;
  readonly decoyPool: ReadonlyMap<number, TrackLyrics>;
  readonly lyricsFetchProgress: {
    readonly fetched: number;
    readonly total: number;
  } | null;
  readonly lyricsAvailableTracks: readonly Track[];

  // Session counters (not persisted, for dual_threat achievement)
  readonly sessionSoundCorrect: number;
  readonly sessionLyricsCorrect: number;

  // Albums cache (for UI)
  readonly albums: readonly Album[];

  // Persistent state
  readonly progress: GameProgress;

  // Updater FSM state (ephemeral; not persisted)
  readonly updaterState: UpdaterMachineState;

  // Pending achievement toasts
  readonly pendingToasts: readonly string[];

  // Actions
  readonly setPhase: (phase: GamePhase) => void;
  readonly setMode: (mode: GameMode) => void;
  readonly setDifficulty: (difficulty: Difficulty) => void;
  readonly setQuizType: (type: QuizType) => void;
  readonly setLyricsMode: (mode: LyricsMode) => void;
  readonly toggleAlbum: (albumId: number) => void;
  readonly clearSelectedAlbums: () => void;
  readonly setAlbums: (albums: readonly Album[]) => void;
  readonly setTrackPool: (tracks: readonly Track[]) => void;
  readonly startRound: (
    track: Track,
    pool: readonly Track[],
    options: readonly Track[],
  ) => void;
  readonly answerCorrect: (track: Track) => void;
  readonly answerIncorrect: () => void;
  readonly incrementRelisten: () => void;
  readonly resetGame: () => void;
  readonly setProgress: (progress: GameProgress) => void;
  readonly setUpdaterState: (next: UpdaterMachineState) => void;
  readonly setTheme: (theme: Theme) => void;
  readonly setVolume: (volume: number) => void;
  readonly setMediumTimer: (seconds: number) => void;
  readonly setHardTimer: (seconds: number) => void;
  readonly addToast: (achievementId: string) => void;
  readonly dismissToast: (achievementId: string) => void;
  readonly resetProgress: () => void;
  readonly setLyricsPool: (pool: readonly TrackWithLyrics[]) => void;
  readonly addToDecoyPool: (trackId: number, lyrics: TrackLyrics) => void;
  readonly nextLyricsTrack: () => TrackWithLyrics | null;
  readonly incrementLyricsStat: (mode: LyricsMode) => void;
  readonly setLyricsFetchProgress: (
    progress: { fetched: number; total: number } | null,
  ) => void;
  readonly setLyricsAvailableTracks: (tracks: readonly Track[]) => void;
}

export const useGameStore = create<GameStore>((set, get) => ({
  // Initial state
  phase: "menu",
  mode: "random",
  difficulty: "easy",
  quizType: null,
  lyricsMode: null,
  selectedAlbumIds: [],
  currentTrack: null,
  trackPool: [],
  options: [],
  streak: 0,
  quackCount: 0,
  relistenCount: 0,
  roundStartTime: 0,
  lyricsPool: [],
  lyricsPoolIndex: 0,
  decoyPool: new Map(),
  lyricsFetchProgress: null,
  lyricsAvailableTracks: [],
  sessionSoundCorrect: 0,
  sessionLyricsCorrect: 0,
  albums: [],
  progress: DEFAULT_PROGRESS,
  updaterState: { kind: "idle" },
  pendingToasts: [],

  // Actions -- all return new state (immutable)
  setPhase: (phase) => set({ phase }),
  setMode: (mode) => set({ mode }),
  setDifficulty: (difficulty) => set({ difficulty }),
  setQuizType: (type) => set({ quizType: type }),
  setLyricsMode: (mode) => set({ lyricsMode: mode }),

  toggleAlbum: (albumId) =>
    set((state) => {
      const exists = state.selectedAlbumIds.includes(albumId);
      return {
        selectedAlbumIds: exists
          ? state.selectedAlbumIds.filter((id) => id !== albumId)
          : [...state.selectedAlbumIds, albumId],
      };
    }),

  clearSelectedAlbums: () => set({ selectedAlbumIds: [] }),
  setAlbums: (albums) => set({ albums }),
  setTrackPool: (tracks) => set({ trackPool: tracks }),

  startRound: (track, pool, options) =>
    set({
      currentTrack: track,
      trackPool: pool,
      options,
      relistenCount: 0,
      roundStartTime: Date.now(),
    }),

  answerCorrect: (track) =>
    set((state) => {
      const albumId = String(track.album.id);
      const trackId = String(track.id);
      const existingAlbums = state.progress.stats.albumsPlayed;
      const existingTracks =
        state.progress.stats.tracksGuessedPerAlbum[albumId] ?? [];

      const isLyrics = state.quizType === "lyrics";

      return {
        streak: state.streak + 1,
        quackCount: 0,
        sessionSoundCorrect: isLyrics
          ? state.sessionSoundCorrect
          : state.sessionSoundCorrect + 1,
        sessionLyricsCorrect: isLyrics
          ? state.sessionLyricsCorrect + 1
          : state.sessionLyricsCorrect,
        progress: {
          ...state.progress,
          stats: {
            ...state.progress.stats,
            totalCorrect: state.progress.stats.totalCorrect + 1,
            albumsPlayed: existingAlbums.includes(albumId)
              ? existingAlbums
              : [...existingAlbums, albumId],
            tracksGuessedPerAlbum: {
              ...state.progress.stats.tracksGuessedPerAlbum,
              [albumId]: existingTracks.includes(trackId)
                ? existingTracks
                : [...existingTracks, trackId],
            },
            totalLyricsCorrect: isLyrics
              ? state.progress.stats.totalLyricsCorrect + 1
              : state.progress.stats.totalLyricsCorrect,
            nameThaSongCorrect: state.progress.stats.nameThaSongCorrect,
            lyricsOrLieCorrect: state.progress.stats.lyricsOrLieCorrect,
          },
        },
      };
    }),

  answerIncorrect: () =>
    set((state) => ({
      streak: 0,
      quackCount: state.quackCount + 1,
    })),

  incrementRelisten: () =>
    set((state) => ({ relistenCount: state.relistenCount + 1 })),

  resetGame: () =>
    set((state) => ({
      phase: "menu",
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
      decoyPool: new Map(),
      lyricsFetchProgress: null,
      lyricsAvailableTracks: [],
      // Preserve session counters across resets
      sessionSoundCorrect: state.sessionSoundCorrect,
      sessionLyricsCorrect: state.sessionLyricsCorrect,
    })),

  setProgress: (progress) => set({ progress }),

  setUpdaterState: (next) => set({ updaterState: next }),

  setTheme: (theme) =>
    set((state) => ({
      progress: {
        ...state.progress,
        settings: { ...state.progress.settings, theme },
      },
    })),

  setVolume: (volume) =>
    set((state) => ({
      progress: {
        ...state.progress,
        settings: { ...state.progress.settings, volume },
      },
    })),

  setMediumTimer: (seconds) =>
    set((state) => ({
      progress: {
        ...state.progress,
        settings: { ...state.progress.settings, mediumTimer: seconds },
      },
    })),

  setHardTimer: (seconds) =>
    set((state) => ({
      progress: {
        ...state.progress,
        settings: { ...state.progress.settings, hardTimer: seconds },
      },
    })),

  addToast: (achievementId) =>
    set((state) => ({
      pendingToasts: [...state.pendingToasts, achievementId],
    })),

  dismissToast: (achievementId) =>
    set((state) => ({
      pendingToasts: state.pendingToasts.filter((id) => id !== achievementId),
    })),

  resetProgress: () => set({ progress: DEFAULT_PROGRESS }),

  setLyricsPool: (pool) => set({ lyricsPool: pool, lyricsPoolIndex: 0 }),

  addToDecoyPool: (trackId, lyrics) =>
    set((state) => {
      const newPool = new Map(state.decoyPool);
      newPool.set(trackId, lyrics);
      return { decoyPool: newPool };
    }),

  nextLyricsTrack: () => {
    const state = get();
    if (state.lyricsPool.length === 0) return null;

    const index = state.lyricsPoolIndex;
    if (index >= state.lyricsPool.length) {
      // Reshuffle: we'll set index back to 1 and return item 0
      // The caller should handle reshuffling externally
      set({ lyricsPoolIndex: 1 });
      return state.lyricsPool[0];
    }

    set({ lyricsPoolIndex: index + 1 });
    return state.lyricsPool[index];
  },

  incrementLyricsStat: (mode) =>
    set((state) => {
      const stats = { ...state.progress.stats };
      switch (mode) {
        case "name-that-song":
          return {
            progress: {
              ...state.progress,
              stats: {
                ...stats,
                nameThaSongCorrect: stats.nameThaSongCorrect + 1,
              },
            },
          };
        case "lyrics-or-lie":
          return {
            progress: {
              ...state.progress,
              stats: {
                ...stats,
                lyricsOrLieCorrect: stats.lyricsOrLieCorrect + 1,
              },
            },
          };
      }
    }),

  setLyricsFetchProgress: (progress) => set({ lyricsFetchProgress: progress }),

  setLyricsAvailableTracks: (tracks) => set({ lyricsAvailableTracks: tracks }),
}));
