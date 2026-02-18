import { useEffect, useState } from "react";
import { motion } from "motion/react";
import { ArrowLeft } from "lucide-react";
import { invoke } from "@tauri-apps/api/core";
import { useGameStore } from "../stores/gameStore";
import { useLyrics } from "../hooks/useLyrics";
import { CatLoader } from "./CatLoader";
import type { Track, AlbumTracksResponse } from "../types";

const MIN_POOL_SIZE = 5;
const LYRICS_FETCH_TIMEOUT_MS = 30_000;
const MESSAGE_INTERVAL_MS = 3_000;

const LOADING_MESSAGES: readonly string[] = [
  "Fetching lyrics...",
  "Digging through the vault...",
  "Long story short, almost ready...",
  "Shaking it off...",
  "Gathering all the easter eggs...",
  "In your wildest dreams...",
  "This is me trying...",
  "Almost out of the woods...",
  "It's a love story, just wait...",
  "Finding the bridge...",
];

export function LyricsLoadingScreen() {
  const mode = useGameStore((s) => s.mode);
  const selectedAlbumIds = useGameStore((s) => s.selectedAlbumIds);
  const setPhase = useGameStore((s) => s.setPhase);
  const resetGame = useGameStore((s) => s.resetGame);
  const setLyricsAvailableTracks = useGameStore(
    (s) => s.setLyricsAvailableTracks,
  );

  const { preFetchInitial } = useLyrics();
  const [error, setError] = useState<string | null>(null);
  const [messageIndex, setMessageIndex] = useState(0);

  // Rotate loading messages
  useEffect(() => {
    const id = setInterval(() => {
      setMessageIndex((prev) => (prev + 1) % LOADING_MESSAGES.length);
    }, MESSAGE_INTERVAL_MS);
    return () => clearInterval(id);
  }, []);

  useEffect(() => {
    const abort = new AbortController();

    const run = async () => {
      try {
        let tracks: Track[];
        if (mode === "random") {
          tracks = await invoke<Track[]>("fetch_top_tracks");
        } else {
          const albumResults = await Promise.allSettled(
            selectedAlbumIds.map((albumId) =>
              invoke<AlbumTracksResponse>("fetch_album_tracks", { albumId }),
            ),
          );
          const allTracks: Track[] = [];
          for (const result of albumResults) {
            if (result.status === "fulfilled") {
              allTracks.push(...result.value.tracks);
            }
          }
          if (allTracks.length === 0) {
            setError(
              "Could not load tracks for the selected albums. Please try again.",
            );
            return;
          }
          tracks = allTracks;
        }

        if (abort.signal.aborted) return;

        // Store full track list for background fetching during gameplay
        setLyricsAvailableTracks(tracks);

        const pool = await Promise.race([
          preFetchInitial(tracks),
          new Promise<never>((_, reject) => {
            const timer = setTimeout(
              () =>
                reject(
                  new Error("Lyrics loading timed out. Please try again."),
                ),
              LYRICS_FETCH_TIMEOUT_MS,
            );
            abort.signal.addEventListener("abort", () => clearTimeout(timer));
          }),
        ]);

        if (abort.signal.aborted) return;

        if (pool.length < MIN_POOL_SIZE) {
          setError(
            "Not enough songs with lyrics available. Try a different mode or add more albums.",
          );
          return;
        }

        setPhase("playing");
      } catch (err) {
        if (abort.signal.aborted) return;
        setError(
          err instanceof Error
            ? err.message
            : "Failed to load lyrics. Please try again.",
        );
      }
    };

    run();

    return () => {
      abort.abort();
    };
  }, [mode, selectedAlbumIds, preFetchInitial, setPhase, setLyricsAvailableTracks]);

  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-6 bg-gradient-to-br from-background to-muted/20 px-6">
      {error ? (
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          className="flex flex-col items-center gap-4"
        >
          <p className="text-center text-lg text-red-400">{error}</p>
          <button
            onClick={() => setPhase("lyrics-mode-select")}
            className="flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to Mode Select
          </button>
        </motion.div>
      ) : (
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ type: "spring", stiffness: 300, damping: 30 }}
          className="flex flex-col items-center gap-4"
        >
          <CatLoader label={LOADING_MESSAGES[messageIndex]} />

          <button
            onClick={resetGame}
            className="mt-4 flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to Menu
          </button>
        </motion.div>
      )}
    </div>
  );
}
