import { useEffect, useMemo, useRef } from "react";
import { Play, Pause } from "lucide-react";
import { useAudio } from "../hooks/useAudio";
import type { TrackInfo } from "../hooks/useAudio";
import type { Track } from "../types";

interface AudioPlayerProps {
  readonly previewUrl: string;
  readonly active: boolean;
  readonly track?: Track;
  readonly onLoaded?: () => void;
}

function buildTrackInfo(track: Track): TrackInfo {
  return {
    title: track.title,
    titleShort: track.titleShort,
    artistName: track.artist.name,
    songDurationSeconds: track.duration,
  };
}

export function AudioPlayer({
  previewUrl,
  active,
  track,
  onLoaded,
}: AudioPlayerProps) {
  const {
    playing,
    loading,
    progress,
    relistenStage,
    play,
    relisten,
    stop,
    reset,
  } = useAudio();

  const trackInfo = useMemo(
    () => (track ? buildTrackInfo(track) : undefined),
    [track],
  );

  // Store callbacks in refs to keep them out of effect deps
  const playRef = useRef(play);
  playRef.current = play;
  const stopRef = useRef(stop);
  stopRef.current = stop;
  const resetRef = useRef(reset);
  resetRef.current = reset;
  const onLoadedRef = useRef(onLoaded);
  onLoadedRef.current = onLoaded;
  const trackInfoRef = useRef(trackInfo);
  trackInfoRef.current = trackInfo;

  // Auto-play when previewUrl changes and active is true
  useEffect(() => {
    if (previewUrl && active) {
      playRef
        .current(previewUrl, trackInfoRef.current)
        .then(() => onLoadedRef.current?.());
    }
    return () => {
      stopRef.current();
    };
  }, [previewUrl, active]);

  // Stop audio when active becomes false
  useEffect(() => {
    if (!active) {
      resetRef.current();
    }
  }, [active]);

  const handlePlay = async () => {
    await play(previewUrl, trackInfo);
    onLoaded?.();
  };

  const relistenLabel = () => {
    if (relistenStage === 0) return "Re-listen";
    if (relistenStage === 1) return "Re-listen";
    if (relistenStage === 2) return "Need more?";
    return "Play full clip";
  };

  return (
    <div className="flex flex-col items-center gap-6 rounded-2xl border border-border bg-card p-8">
      {/* Heading */}
      <div className="text-center">
        <h3 className="text-3xl font-bold tracking-tight">Name That Song!</h3>
        <p className="mt-1 text-sm text-muted-foreground">
          Listen carefully and guess the track
        </p>
      </div>

      {/* Large circular play/pause button */}
      {loading ? (
        <div className="flex h-20 w-20 items-center justify-center rounded-full bg-muted">
          <span className="text-sm text-muted-foreground">...</span>
        </div>
      ) : playing ? (
        <button
          onClick={stop}
          className="flex h-20 w-20 items-center justify-center rounded-full bg-gradient-to-br from-purple-500 to-pink-500 shadow-lg transition-transform hover:scale-110"
        >
          <Pause className="h-8 w-8 text-white" />
        </button>
      ) : progress > 0 ? (
        <button
          onClick={relisten}
          className="flex h-20 w-20 items-center justify-center rounded-full border-2 border-purple-500/50 bg-card shadow-lg transition-transform hover:scale-110"
        >
          <Play className="h-8 w-8 text-purple-400" />
        </button>
      ) : (
        <button
          onClick={handlePlay}
          className="flex h-20 w-20 items-center justify-center rounded-full bg-gradient-to-br from-purple-500 to-pink-500 shadow-lg transition-transform hover:scale-110"
        >
          <Play className="ml-1 h-8 w-8 text-white" />
        </button>
      )}

      {/* Progress bar */}
      <div className="w-full">
        <div className="h-2 w-full overflow-hidden rounded-full bg-muted">
          <div
            className="h-full rounded-full bg-gradient-to-r from-purple-500 to-pink-500 transition-all"
            style={{ width: `${progress * 100}%` }}
          />
        </div>
      </div>

      {/* Relisten button (when paused after first listen) */}
      {!loading && !playing && progress > 0 && (
        <button
          onClick={relisten}
          className="rounded-xl border border-border bg-card px-6 py-2 text-sm font-medium text-muted-foreground transition-colors hover:border-primary/50 hover:text-foreground"
        >
          {relistenLabel()}
        </button>
      )}
    </div>
  );
}
