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
        className="rounded-lg px-8 py-3 font-medium text-white"
        style={{ backgroundColor: "var(--color-accent)" }}
      >
        Next
      </button>
    </div>
  );
}
