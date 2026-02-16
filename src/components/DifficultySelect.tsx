import type { Difficulty } from "../types";
import { useGameStore } from "../stores/gameStore";

const DIFFICULTIES: readonly {
  readonly id: Difficulty;
  readonly label: string;
  readonly description: string;
}[] = [
  {
    id: "easy",
    label: "Easy",
    description: "Multiple choice with album hint. No time limit.",
  },
  {
    id: "medium",
    label: "Medium",
    description: "Multiple choice. 20-second timer.",
  },
  {
    id: "hard",
    label: "Hard",
    description: "Type your answer. 15-second timer.",
  },
];

export function DifficultySelect() {
  const setDifficulty = useGameStore((s) => s.setDifficulty);
  const setPhase = useGameStore((s) => s.setPhase);

  const handleSelect = (difficulty: Difficulty) => {
    setDifficulty(difficulty);
    setPhase("playing");
  };

  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-8">
      <button
        onClick={() => setPhase("menu")}
        className="absolute left-8 top-8 text-sm"
        style={{ color: "var(--color-text-secondary)" }}
      >
        ← Back
      </button>

      <h2
        className="text-3xl font-bold"
        style={{ color: "var(--color-text-primary)" }}
      >
        Choose Difficulty
      </h2>

      <div className="flex gap-6">
        {DIFFICULTIES.map((diff) => (
          <button
            key={diff.id}
            onClick={() => handleSelect(diff.id)}
            className="flex w-56 flex-col items-center gap-3 rounded-xl p-6 transition-all hover:scale-105"
            style={{
              backgroundColor: "var(--color-surface)",
              border: "1px solid var(--color-border)",
            }}
          >
            <span
              className="text-2xl font-bold"
              style={{ color: "var(--color-accent)" }}
            >
              {diff.label}
            </span>
            <span
              className="text-center text-sm"
              style={{ color: "var(--color-text-secondary)" }}
            >
              {diff.description}
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}
