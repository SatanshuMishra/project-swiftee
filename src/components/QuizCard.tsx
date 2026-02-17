import { useState, useRef, useEffect } from "react";
import { motion } from "motion/react";
import { cn } from "../lib/cn";
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
        <p className="text-sm text-muted-foreground">Album: {albumHint}</p>
      )}

      {/* Multiple choice (Easy/Medium) — vertical stack */}
      {difficulty !== "hard" && (
        <div className="w-full max-w-lg space-y-3">
          {options.map((track, index) => (
            <motion.button
              key={track.id}
              initial={{ opacity: 0, x: -10 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: index * 0.05 }}
              onClick={() => onAnswer(track.id)}
              disabled={disabled}
              className={cn(
                "w-full rounded-xl border-2 p-4 text-left font-medium transition-all",
                "border-border bg-background",
                "hover:border-primary/50 hover:bg-card",
                disabled && "opacity-50 cursor-not-allowed",
              )}
            >
              {track.titleShort || track.title}
            </motion.button>
          ))}
        </div>
      )}

      {/* Text input (Hard) */}
      {difficulty === "hard" && (
        <form
          onSubmit={handleSubmit}
          className="flex w-full max-w-lg flex-col items-center gap-3"
        >
          <input
            ref={inputRef}
            type="text"
            value={textInput}
            onChange={(e) => setTextInput(e.target.value)}
            disabled={disabled}
            placeholder="Type your answer..."
            className={cn(
              "w-full rounded-xl border bg-muted/30 px-4 py-3 text-center text-lg text-foreground outline-none",
              "border-border transition-all",
              "focus:border-primary/50 focus:ring-2 focus:ring-primary/20",
            )}
          />
          <button
            type="submit"
            disabled={disabled || !textInput.trim()}
            className={cn(
              "rounded-xl bg-primary px-8 py-3 font-medium text-primary-foreground transition-opacity",
              (disabled || !textInput.trim()) && "opacity-50 cursor-not-allowed",
            )}
          >
            Submit
          </button>
        </form>
      )}
    </div>
  );
}
