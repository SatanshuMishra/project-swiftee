import { create } from "zustand";
import type {
  Album,
  Difficulty,
  GameMode,
  GamePhase,
  GameProgress,
  Track,
  Theme,
} from "../types";
import { DEFAULT_PROGRESS } from "../types";

interface GameStore {
  // Navigation
  readonly phase: GamePhase;
  readonly mode: GameMode;
  readonly difficulty: Difficulty;

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

  // Albums cache (for UI)
  readonly albums: readonly Album[];

  // Persistent state
  readonly progress: GameProgress;

  // Pending achievement toasts
  readonly pendingToasts: readonly string[];

  // Actions
  readonly setPhase: (phase: GamePhase) => void;
  readonly setMode: (mode: GameMode) => void;
  readonly setDifficulty: (difficulty: Difficulty) => void;
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
  readonly setTheme: (theme: Theme) => void;
  readonly setVolume: (volume: number) => void;
  readonly addToast: (achievementId: string) => void;
  readonly dismissToast: (achievementId: string) => void;
  readonly resetProgress: () => void;
}

export const useGameStore = create<GameStore>((set) => ({
  // Initial state
  phase: "menu",
  mode: "random",
  difficulty: "easy",
  selectedAlbumIds: [],
  currentTrack: null,
  trackPool: [],
  options: [],
  streak: 0,
  quackCount: 0,
  relistenCount: 0,
  roundStartTime: 0,
  albums: [],
  progress: DEFAULT_PROGRESS,
  pendingToasts: [],

  // Actions -- all return new state (immutable)
  setPhase: (phase) => set({ phase }),
  setMode: (mode) => set({ mode }),
  setDifficulty: (difficulty) => set({ difficulty }),

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

      return {
        streak: state.streak + 1,
        quackCount: 0,
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
    set({
      phase: "menu",
      currentTrack: null,
      trackPool: [],
      options: [],
      streak: 0,
      quackCount: 0,
      relistenCount: 0,
      selectedAlbumIds: [],
    }),

  setProgress: (progress) => set({ progress }),

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

  addToast: (achievementId) =>
    set((state) => ({
      pendingToasts: [...state.pendingToasts, achievementId],
    })),

  dismissToast: (achievementId) =>
    set((state) => ({
      pendingToasts: state.pendingToasts.filter((id) => id !== achievementId),
    })),

  resetProgress: () => set({ progress: DEFAULT_PROGRESS }),
}));
