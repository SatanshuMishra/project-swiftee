import { useCallback } from "react";
import { invoke } from "@tauri-apps/api/core";
import { useGameStore } from "../stores/gameStore";
import type { Track, TrackLyrics, TrackWithLyrics } from "../types";
import { shuffle } from "../lib/shuffle";

interface LyricsBatchRequest {
  readonly trackId: number;
  readonly trackTitle: string;
  readonly artistName: string;
  readonly albumName: string | null;
  readonly durationSecs: number | null;
}

const MIN_POOL_SIZE = 5;
const INITIAL_BATCH_SIZE = 8;
const ROLLING_BATCH_SIZE = 5;

export function useLyrics() {
  const setLyricsPool = useGameStore((s) => s.setLyricsPool);
  const addToDecoyPool = useGameStore((s) => s.addToDecoyPool);
  const setLyricsFetchProgress = useGameStore((s) => s.setLyricsFetchProgress);

  /**
   * Pre-fetch initial batch of lyrics for game start.
   * Returns the filtered pool of tracks with confirmed lyrics.
   */
  const preFetchInitial = useCallback(
    async (
      tracks: readonly Track[],
      onProgress?: (fetched: number, total: number) => void,
    ): Promise<readonly TrackWithLyrics[]> => {
      const batch = tracks.slice(0, INITIAL_BATCH_SIZE);
      const total = batch.length;
      setLyricsFetchProgress({ fetched: 0, total });

      const requests: LyricsBatchRequest[] = batch.map((t) => ({
        trackId: t.id,
        trackTitle: t.title,
        artistName: t.artist.name,
        albumName: t.album.title ?? null,
        durationSecs: t.duration ?? null,
      }));

      const results = await invoke<Record<string, TrackLyrics | null>>(
        "fetch_lyrics_batch",
        { tracks: requests },
      );

      const pool: TrackWithLyrics[] = [];
      for (const track of batch) {
        const lyrics = results[String(track.id)];
        if (lyrics) {
          pool.push({ track, lyrics });
          addToDecoyPool(track.id, lyrics);
        }
      }

      const fetched = Object.keys(results).length;
      setLyricsFetchProgress({ fetched, total });
      onProgress?.(fetched, total);

      if (pool.length < MIN_POOL_SIZE) {
        setLyricsFetchProgress(null);
        return pool;
      }

      const shuffledPool = shuffle(pool);
      setLyricsPool(shuffledPool);
      setLyricsFetchProgress(null);

      return shuffledPool;
    },
    [setLyricsPool, addToDecoyPool, setLyricsFetchProgress],
  );

  /**
   * Pre-fetch more lyrics in the background during gameplay.
   * Fetches the next batch of unfetched tracks.
   */
  const preFetchMore = useCallback(
    async (
      tracks: readonly Track[],
      existingIds: ReadonlySet<number>,
    ): Promise<readonly TrackWithLyrics[]> => {
      const unfetched = tracks.filter((t) => !existingIds.has(t.id));
      if (unfetched.length === 0) return [];

      const batch = unfetched.slice(0, ROLLING_BATCH_SIZE);
      const requests: LyricsBatchRequest[] = batch.map((t) => ({
        trackId: t.id,
        trackTitle: t.title,
        artistName: t.artist.name,
        albumName: t.album.title ?? null,
        durationSecs: t.duration ?? null,
      }));

      try {
        const results = await invoke<Record<string, TrackLyrics | null>>(
          "fetch_lyrics_batch",
          { tracks: requests },
        );

        const newTracks: TrackWithLyrics[] = [];
        for (const track of batch) {
          const lyrics = results[String(track.id)];
          if (lyrics) {
            newTracks.push({ track, lyrics });
            addToDecoyPool(track.id, lyrics);
          }
        }

        return newTracks;
      } catch {
        // Rolling pre-fetch failures are non-critical
        return [];
      }
    },
    [addToDecoyPool],
  );

  return { preFetchInitial, preFetchMore };
}
