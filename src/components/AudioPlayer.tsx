import { useEffect, useRef } from "react";
import { useAudio } from "../hooks/useAudio";

interface AudioPlayerProps {
  readonly previewUrl: string;
  readonly onLoaded?: () => void;
}

export function AudioPlayer({ previewUrl, onLoaded }: AudioPlayerProps) {
  const { playing, loading, progress, relistenStage, play, relisten, stop } =
    useAudio();
  const prevUrlRef = useRef<string | null>(null);

  // Auto-play when previewUrl changes (new round)
  useEffect(() => {
    if (previewUrl && previewUrl !== prevUrlRef.current) {
      prevUrlRef.current = previewUrl;
      play(previewUrl).then(() => onLoaded?.());
    }
  }, [previewUrl, play, onLoaded]);

  const handlePlay = async () => {
    await play(previewUrl);
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
        {!playing && !loading && progress === 0 && (
          <button
            onClick={handlePlay}
            className="rounded-lg px-6 py-2 font-medium text-white"
            style={{ backgroundColor: "var(--color-accent)" }}
          >
            ▶ Play
          </button>
        )}

        {playing && (
          <button
            onClick={stop}
            className="rounded-lg px-6 py-2 font-medium"
            style={{
              backgroundColor: "var(--color-surface)",
              border: "1px solid var(--color-border)",
              color: "var(--color-text-primary)",
            }}
          >
            ⏸ Pause
          </button>
        )}

        {loading && (
          <span
            className="px-6 py-2 text-sm"
            style={{ color: "var(--color-text-secondary)" }}
          >
            Loading...
          </span>
        )}

        {!playing && !loading && progress > 0 && (
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
        )}
      </div>
    </div>
  );
}
