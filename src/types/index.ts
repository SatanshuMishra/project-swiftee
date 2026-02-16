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
  | "difficulty-select"
  | "playing"
  | "cat-gallery"
  | "settings";

export type GameMode = "random" | "album";

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

// Persistence types (matches save.json schema)
export interface GameProgress {
  readonly version: number;
  readonly achievements: Record<string, AchievementState>;
  readonly stats: GameStats;
  readonly settings: GameSettings;
}

export interface GameStats {
  readonly totalCorrect: number;
  readonly albumsPlayed: readonly string[];
  readonly tracksGuessedPerAlbum: Record<string, readonly string[]>;
}

export interface GameSettings {
  readonly theme: Theme;
  readonly volume: number;
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

export const DEFAULT_PROGRESS: GameProgress = {
  version: 1,
  achievements: {},
  stats: {
    totalCorrect: 0,
    albumsPlayed: [],
    tracksGuessedPerAlbum: {},
  },
  settings: {
    theme: "dark",
    volume: 0.8,
  },
};
