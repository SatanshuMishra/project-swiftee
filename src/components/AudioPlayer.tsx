import { useEffect, useMemo, useRef } from "react";
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
    <div
      className="flex flex-col items-center gap-3 rounded-xl p-4"
      style={{
        backgroundColor: "var(--color-surface)",
        border: "1px solid var(--color-border)",
      }}
    >
      {/* Progress bar */}
      <div
        className="h-2 w-full overflow-hidden rounded-full"
        style={{ backgroundColor: "var(--color-border)" }}
      >
        <div
          className="h-full rounded-full transition-all"
          style={{
            width: `${progress * 100}%`,
            backgroundColor: "var(--color-accent)",
          }}
        />
      </div>

      <div className="flex gap-3">
        {loading ? (
          <span
            className="px-6 py-2 text-sm"
            style={{ color: "var(--color-text-secondary)" }}
          >
            Loading...
          </span>
        ) : playing ? (
          <button
            onClick={stop}
            className="rounded-lg px-6 py-2 font-medium"
            style={{
              backgroundColor: "var(--color-surface)",
              border: "1px solid var(--color-border)",
              color: "var(--color-text-primary)",
            }}
          >
            Pause
          </button>
        ) : progress > 0 ? (
          <button
            onClick={relisten}
            className="rounded-lg px-6 py-2 font-medium"
            style={{
              backgroundColor: "var(--color-surface)",
              border: "1px solid var(--color-accent)",
              color: "var(--color-accent)",
            }}
          >
            {relistenLabel()}
          </button>
        ) : (
          <button
            onClick={handlePlay}
            className="rounded-lg px-6 py-2 font-medium text-white"
            style={{ backgroundColor: "var(--color-accent)" }}
          >
            Play
          </button>
        )}
      </div>
    </div>
  );
}
