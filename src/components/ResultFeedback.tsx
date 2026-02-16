import { useEffect, useState } from "react";
import type { Track } from "../types";

const POSITIVE_MESSAGES = [
  "Nice one!",
  "You got it!",
  "Nailed it!",
  "Perfect!",
  "Spot on!",
  "Impressive!",
  "Well done!",
  "Crushed it!",
  "Too easy!",
  "Swiftie certified!",
] as const;

const NEXT_DELAY_MS = 2000;

function randomPositiveMessage(): string {
  return POSITIVE_MESSAGES[Math.floor(Math.random() * POSITIVE_MESSAGES.length)];
}

interface ResultFeedbackProps {
  readonly correct: boolean;
  readonly correctTrack: Track;
  readonly onNext: () => void;
}

export function ResultFeedback({
  correct,
  correctTrack,
  onNext,
}: ResultFeedbackProps) {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const timer = setTimeout(() => setReady(true), NEXT_DELAY_MS);
    return () => clearTimeout(timer);
  }, []);

  return (
    <div className="flex flex-col items-center gap-4">
      <div
        className="rounded-xl px-8 py-4 text-center"
        style={{
          backgroundColor: correct
            ? "var(--color-correct)"
            : "var(--color-incorrect)",
          color: "#ffffff",
        }}
      >
        {correct ? (
          <p className="text-lg font-bold">{randomPositiveMessage()}</p>
        ) : (
          <div>
            <p className="text-lg font-bold">
              It was &ldquo;{correctTrack.titleShort || correctTrack.title}&rdquo;
            </p>
            <p className="text-sm opacity-80">
              by {correctTrack.artist.name}
            </p>
          </div>
        )}
      </div>

      <button
        onClick={onNext}
        disabled={!ready}
        className="rounded-lg px-8 py-3 font-medium text-white transition-opacity"
        style={{
          backgroundColor: "var(--color-accent)",
          opacity: ready ? 1 : 0.5,
          cursor: ready ? "pointer" : "not-allowed",
        }}
      >
        {ready ? "Next" : "Next..."}
      </button>
    </div>
  );
}
