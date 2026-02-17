import { motion } from "motion/react";
import { Zap, Flame, Skull, ArrowLeft } from "lucide-react";
import type { Difficulty } from "../types";
import { useGameStore } from "../stores/gameStore";
import { cn } from "../lib/cn";
import type { ReactNode } from "react";

interface DifficultyDef {
  readonly id: Difficulty;
  readonly label: string;
  readonly description: string;
  readonly icon: ReactNode;
  readonly gradientFrom: string;
  readonly gradientTo: string;
  readonly features: readonly string[];
}

const DIFFICULTIES: readonly DifficultyDef[] = [
  {
    id: "easy",
    label: "Easy",
    description: "Perfect for new Swifties",
    icon: <Zap className="h-6 w-6 text-white" />,
    gradientFrom: "#22c55e",
    gradientTo: "#16a34a",
    features: ["Multiple choice", "Album hint shown", "No time limit"],
  },
  {
    id: "medium",
    label: "Medium",
    description: "For dedicated fans",
    icon: <Flame className="h-6 w-6 text-white" />,
    gradientFrom: "#f97316",
    gradientTo: "#ea580c",
    features: ["Multiple choice", "No album hint", "20-second timer"],
  },
  {
    id: "hard",
    label: "Hard",
    description: "True Swiftie challenge",
    icon: <Skull className="h-6 w-6 text-white" />,
    gradientFrom: "#ef4444",
    gradientTo: "#dc2626",
    features: ["Type your answer", "No hints", "15-second timer"],
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
    <div className="flex min-h-screen flex-col items-center justify-center gap-8 bg-gradient-to-br from-background to-muted/20 px-6">
      {/* Back button */}
      <motion.button
        initial={{ opacity: 0, x: -10 }}
        animate={{ opacity: 1, x: 0 }}
        onClick={() => setPhase("menu")}
        className="absolute left-8 top-8 flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
      >
        <ArrowLeft className="h-4 w-4" />
        Back
      </motion.button>

      {/* Title */}
      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        className="text-center"
      >
        <h2 className="text-4xl font-bold tracking-tight">
          Choose Difficulty
        </h2>
        <p className="mt-2 text-muted-foreground">
          Select your challenge level
        </p>
      </motion.div>

      {/* 3-column grid */}
      <div className="grid w-full max-w-4xl grid-cols-1 gap-6 md:grid-cols-3">
        {DIFFICULTIES.map((diff, index) => (
          <motion.button
            key={diff.id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{
              delay: 0.1 + index * 0.1,
              type: "spring",
              stiffness: 300,
              damping: 25,
            }}
            onClick={() => handleSelect(diff.id)}
            className={cn(
              "group relative flex flex-col items-center gap-4 overflow-hidden rounded-2xl",
              "bg-card border border-border p-8",
              "transition-all duration-300",
              "hover:border-primary/50 hover:shadow-xl hover:scale-[1.05]",
            )}
          >
            {/* Hover gradient overlay */}
            <div
              className="pointer-events-none absolute inset-0 opacity-0 transition-opacity group-hover:opacity-10"
              style={{
                background: `linear-gradient(135deg, ${diff.gradientFrom}, ${diff.gradientTo})`,
              }}
            />

            {/* Gradient icon badge */}
            <div
              className="inline-flex rounded-xl p-3"
              style={{
                background: `linear-gradient(135deg, ${diff.gradientFrom}, ${diff.gradientTo})`,
              }}
            >
              {diff.icon}
            </div>

            <div className="text-center">
              <h3 className="text-2xl font-bold text-foreground">
                {diff.label}
              </h3>
              <p className="mt-1 text-sm text-muted-foreground">
                {diff.description}
              </p>
            </div>

            {/* Feature list */}
            <ul className="mt-2 space-y-1 text-left text-sm text-muted-foreground">
              {diff.features.map((feat) => (
                <li key={feat} className="flex items-center gap-2">
                  <span
                    className="inline-block h-1.5 w-1.5 rounded-full"
                    style={{ backgroundColor: diff.gradientFrom }}
                  />
                  {feat}
                </li>
              ))}
            </ul>
          </motion.button>
        ))}
      </div>
    </div>
  );
}
