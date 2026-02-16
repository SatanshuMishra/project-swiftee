import { useState, useRef, useEffect } from "react";
import type { Difficulty, Track } from "../types";

interface QuizCardProps {
  readonly difficulty: Difficulty;
  readonly options: readonly Track[];
  readonly albumHint: string | undefined;
  readonly onAnswer: (answer: number | string) => void;
  readonly disabled: boolean;
}

export function QuizCard({
  difficulty,
  options,
  albumHint,
  onAnswer,
  disabled,
}: QuizCardProps) {
  const [textInput, setTextInput] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (difficulty === "hard" && inputRef.current) {
      inputRef.current.focus();
    }
  }, [difficulty]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (textInput.trim()) {
      onAnswer(textInput.trim());
    }
  };

  return (
    <div className="flex w-full flex-col items-center gap-4">
      {/* Album hint for easy mode */}
      {difficulty === "easy" && albumHint && (
        <p className="text-sm" style={{ color: "var(--color-text-secondary)" }}>
          Album: {albumHint}
        </p>
      )}

      {/* Multiple choice (Easy/Medium) */}
      {difficulty !== "hard" && (
        <div className="grid w-full max-w-lg grid-cols-2 gap-3">
          {options.map((track) => (
            <button
              key={track.id}
              onClick={() => onAnswer(track.id)}
              disabled={disabled}
              className="rounded-lg px-4 py-3 text-center font-medium transition-all"
              style={{
                backgroundColor: "var(--color-surface)",
                border: "1px solid var(--color-border)",
                color: "var(--color-text-primary)",
                opacity: disabled ? 0.5 : 1,
              }}
            >
              {track.titleShort || track.title}
            </button>
          ))}
        </div>
      )}

      {/* Text input (Hard) */}
      {difficulty === "hard" && (
        <form onSubmit={handleSubmit} className="flex w-full max-w-lg gap-2">
          <input
            ref={inputRef}
            type="text"
            value={textInput}
            onChange={(e) => setTextInput(e.target.value)}
            disabled={disabled}
            placeholder="Type your answer..."
            className="flex-1 rounded-lg px-4 py-3 outline-none"
            style={{
              backgroundColor: "var(--color-surface)",
              border: "1px solid var(--color-border)",
              color: "var(--color-text-primary)",
            }}
          />
          <button
            type="submit"
            disabled={disabled || !textInput.trim()}
            className="rounded-lg px-6 py-3 font-medium text-white"
            style={{
              backgroundColor: "var(--color-accent)",
              opacity: disabled || !textInput.trim() ? 0.5 : 1,
            }}
          >
            Submit
          </button>
        </form>
      )}
    </div>
  );
}
