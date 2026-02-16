import type { Track } from "../types";

/**
 * Fisher-Yates shuffle (returns new array).
 */
function shuffle<T>(arr: readonly T[]): T[] {
  const result = [...arr];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

/**
 * Create a shuffled track pool from an array of tracks.
 * Filters out tracks without preview URLs.
 */
export function createTrackPool(tracks: readonly Track[]): Track[] {
  const playable = tracks.filter((t) => t.preview && t.preview.length > 0);
  return shuffle(playable);
}

/**
 * Draw the next track from the pool.
 * Returns the drawn track and the remaining pool.
 * If pool is empty, reshuffles the original tracks.
 */
export function drawNextTrack(
  pool: readonly Track[],
  allTracks: readonly Track[],
): { readonly track: Track; readonly remaining: readonly Track[] } {
  if (pool.length === 0) {
    const reshuffled = createTrackPool(allTracks);
    return { track: reshuffled[0], remaining: reshuffled.slice(1) };
  }
  return { track: pool[0], remaining: pool.slice(1) };
}
