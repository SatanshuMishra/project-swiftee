// Models mirroring Rust backend (camelCase from serde)
export interface Track {
  readonly id: number;
  readonly title: string;
  readonly titleShort: string;
  readonly duration: number;
  readonly preview: string;
  readonly artist: Artist;
  readonly album: Album;
}

export interface Artist {
  readonly id: number;
  readonly name: string;
}

export interface Album {
  readonly id: number;
  readonly title: string;
  readonly coverMedium: string | null;
}

// Response from fetch_album_tracks command
export interface AlbumTracksResponse {
  readonly tracks: readonly Track[];
  readonly totalTracks: number;
}

// Game types
export type GamePhase =
  | "menu"
  | "album-select"
  | "quiz-type-select"
  | "lyrics-mode-select"
  | "difficulty-select"
  | "lyrics-loading"
  | "playing"
  | "cat-gallery"
  | "settings";

export type GameMode = "random" | "album";

export type QuizType = "sound" | "lyrics";

export type LyricsMode = "name-that-song" | "lyrics-or-lie";

export type Difficulty = "easy" | "medium" | "hard";

export type Theme = "dark" | "light" | "system";

// Achievement types
export interface AchievementDef {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly catFile: string;
}

export interface AchievementState {
  readonly unlocked: boolean;
  readonly unlockedAt: string | null;
}

// Lyrics types (from LRCLIB via Rust backend)
export interface TrackLyrics {
  readonly lrclibId: number;
  readonly lines: readonly string[];
  readonly lineCount: number;
  readonly sourceTrack: string;
  readonly sourceAlbum: string;
}

export interface TrackWithLyrics {
  readonly track: Track;
  readonly lyrics: TrackLyrics;
}

export interface LyricSnippet {
  readonly lines: readonly string[];
  readonly sourceLineIndices: readonly number[];
}

export interface DecoyResult {
  readonly lines: readonly string[];
  readonly isReal: boolean;
  readonly sourceSong?: string;
}

// Persistence types (matches save.json schema)
export interface GameProgress {
  readonly version: number;
  readonly achievements: Record<string, AchievementState>;
  readonly stats: GameStats;
  readonly settings: GameSettings;
  readonly updater: UpdaterState;
}

export interface GameStats {
  readonly totalCorrect: number;
  readonly albumsPlayed: readonly string[];
  readonly tracksGuessedPerAlbum: Record<string, readonly string[]>;
  readonly totalLyricsCorrect: number;
  readonly nameThaSongCorrect: number;
  readonly lyricsOrLieCorrect: number;
}

export interface GameSettings {
  readonly theme: Theme;
  readonly volume: number;
  readonly mediumTimer: number;
  readonly hardTimer: number;
}

export interface UpdaterState {
  readonly autoCheckEnabled: boolean;
  readonly lastCheckedAt: string | null;
  readonly skippedVersions: readonly string[];
  readonly remindLaterUntil: string | null;
}

// Round state
export interface RoundResult {
  readonly correct: boolean;
  readonly correctTrack: Track;
  readonly answeredTrackId: number | null;
  readonly answeredText: string | null;
  readonly timeElapsed: number;
  readonly usedFullClip: boolean;
}

// Updater types (client-only — UpdaterMachineState is ephemeral session state)
export interface UpdateManifest {
  readonly version: string;
  readonly notes: string;
  readonly pubDate: string;
}

export type UpdaterMachineState =
  | { readonly kind: "idle" }
  | { readonly kind: "checking" }
  | { readonly kind: "up-to-date" }
  | { readonly kind: "available"; readonly manifest: UpdateManifest }
  | { readonly kind: "downloading"; readonly manifest: UpdateManifest; readonly progress: number }
  | { readonly kind: "ready"; readonly manifest: UpdateManifest }
  | { readonly kind: "installing" }
  | {
      readonly kind: "error";
      readonly subtype: "check" | "download" | "signature" | "install";
      readonly message: string;
    };

// Mirrors src-tauri/src/storage/load.rs LoadResult (serde tag = "kind", camelCase)
export type LoadResult =
  | { readonly kind: "fresh" }
  | { readonly kind: "loaded"; readonly progress: GameProgress }
  | { readonly kind: "migrated"; readonly progress: GameProgress; readonly fromVersion: number };

export const DEFAULT_PROGRESS: GameProgress = {
  version: 3,
  achievements: {},
  stats: {
    totalCorrect: 0,
    albumsPlayed: [],
    tracksGuessedPerAlbum: {},
    totalLyricsCorrect: 0,
    nameThaSongCorrect: 0,
    lyricsOrLieCorrect: 0,
  },
  settings: {
    theme: "dark",
    volume: 0.8,
    mediumTimer: 30,
    hardTimer: 20,
  },
  updater: {
    autoCheckEnabled: true,
    lastCheckedAt: null,
    skippedVersions: [],
    remindLaterUntil: null,
  },
};
