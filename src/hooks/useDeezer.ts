import { useState, useCallback } from "react";
import { invoke } from "@tauri-apps/api/core";
import type { Album, Track, AlbumTracksResponse } from "../types";

interface UseDeezerResult<T> {
  readonly data: T | null;
  readonly loading: boolean;
  readonly error: string | null;
  readonly fetch: () => Promise<T | null>;
}

function useDeezerCommand<T>(
  command: string,
  args?: Record<string, unknown>,
): UseDeezerResult<T> {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const result = await invoke<T>(command, args);
      setData(result);
      return result;
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setError(message);
      return null;
    } finally {
      setLoading(false);
    }
  }, [command, args]);

  return { data, loading, error, fetch: fetchData };
}

export function useFetchAlbums(): UseDeezerResult<Album[]> {
  return useDeezerCommand<Album[]>("fetch_albums");
}

export function useFetchAlbumTracks(
  albumId: number,
): UseDeezerResult<AlbumTracksResponse> {
  return useDeezerCommand<AlbumTracksResponse>("fetch_album_tracks", {
    albumId,
  });
}

export function useFetchTopTracks(): UseDeezerResult<Track[]> {
  return useDeezerCommand<Track[]>("fetch_top_tracks");
}
