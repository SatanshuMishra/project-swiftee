import { useEffect, useMemo, useRef } from "react";
import { Play, Pause } from "lucide-react";
import { CatLoader } from "./CatLoader";
import { useAudio } from "../hooks/useAudio";
import { FIRST_ESCALATION_RELISTEN } from "../engine/relistenSchedule";
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

function formatTime(seconds: number): string {
  return `${Math.floor(seconds)}s`;
}

export function AudioPlayer({
  previewUrl,
  active,
  track,
  onLoaded,
}: AudioPlayerProps) {
  const {
    playing,
    paused,
    loading,
    progress,
    clipDuration,
    relistenStage,
    play,
    relisten,
    pause,
    resume,
    reset,
  } = useAudio();

  const trackInfo = useMemo(
    () => (track ? buildTrackInfo(track) : undefined),
    [track],
  );

  // Store callbacks in refs to keep them out of effect deps
  const playRef = useRef(play);
  playRef.current = play;
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
        .then(() => onLoadedRef.current?.())
        .catch(() => onLoadedRef.current?.());
    }
    return () => {
      resetRef.current();
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

  const clipExtended = relistenStage >= FIRST_ESCALATION_RELISTEN;
  const elapsed = clipDuration > 0 ? progress * clipDuration : 0;

  // Determine which action the circular button triggers
  const handleButtonClick = () => {
    if (playing) {
      pause();
    } else if (paused) {
      resume();
    } else if (progress > 0) {
      relisten();
    } else {
      void handlePlay();
    }
  };

  // Button visual style: gradient for play/pause, border for resume/relisten
  const isGradientButton = playing || (!paused && progress === 0);

  return (
    <>
      <div className="flex flex-col items-center gap-6 rounded-2xl border border-border bg-card p-8">
        {/* Heading */}
        <div className="text-center">
          <h3 className="text-3xl font-bold tracking-tight">
            Name That Song!
          </h3>
          <p className="mt-1 text-sm text-muted-foreground">
            Listen carefully and guess the track
          </p>
        </div>

        {/* Large circular play/pause button */}
        {loading ? (
          <div className="flex h-20 w-20 items-center justify-center overflow-hidden">
            <CatLoader size="sm" />
          </div>
        ) : (
          <button
            onClick={handleButtonClick}
            className={`flex h-20 w-20 items-center justify-center rounded-full shadow-lg transition-transform hover:scale-110 ${
              isGradientButton
                ? "bg-gradient-to-br from-purple-500 to-pink-500"
                : "border-2 border-purple-500/50 bg-card"
            }`}
          >
            {playing ? (
              <Pause
                className={`h-8 w-8 ${isGradientButton ? "text-white" : "text-purple-400"}`}
              />
            ) : (
              <Play
                className={`h-8 w-8 ${isGradientButton ? "ml-1 text-white" : "text-purple-400"}`}
              />
            )}
          </button>
        )}

        {/* Progress bar + duration */}
        <div className="flex w-full items-center gap-3">
          <div className="h-2 flex-1 overflow-hidden rounded-full bg-muted">
            <div
              className="h-full rounded-full bg-gradient-to-r from-purple-500 to-pink-500 transition-all"
              style={{ width: `${progress * 100}%` }}
            />
          </div>
          {clipDuration > 0 && (
            <span className="text-xs tabular-nums text-muted-foreground">
              {formatTime(elapsed)} / {formatTime(clipDuration)}
            </span>
          )}
        </div>
      </div>

      {/* Clip extended note — outside card, centered */}
      {clipExtended && (
        <p className="mt-2 text-center text-xs text-muted-foreground/70">
          Clip extended to help with your guess
        </p>
      )}
    </>
  );
}
