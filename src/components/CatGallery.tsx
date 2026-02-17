import { motion } from "motion/react";
import { ArrowLeft, Lock } from "lucide-react";
import { useGameStore } from "../stores/gameStore";
import { ACHIEVEMENT_DEFS } from "../engine/achievements";
import { cn } from "../lib/cn";

const GRADIENT_COLORS = [
  { from: "#8b5cf6", to: "#6366f1" },
  { from: "#ec4899", to: "#f43f5e" },
  { from: "#f97316", to: "#eab308" },
  { from: "#06b6d4", to: "#3b82f6" },
  { from: "#22c55e", to: "#16a34a" },
] as const;

export function CatGallery() {
  const setPhase = useGameStore((s) => s.setPhase);
  const achievements = useGameStore((s) => s.progress.achievements);

  const unlockedCount = ACHIEVEMENT_DEFS.filter(
    (d) => achievements[d.id]?.unlocked,
  ).length;
  const totalCount = ACHIEVEMENT_DEFS.length;
  const progressPct = totalCount > 0 ? (unlockedCount / totalCount) * 100 : 0;

  return (
    <div className="flex min-h-screen flex-col items-center gap-8 bg-gradient-to-br from-background to-muted/20 p-8">
      {/* Header */}
      <div className="flex w-full max-w-5xl items-center justify-between">
        <motion.button
          initial={{ opacity: 0, x: -10 }}
          animate={{ opacity: 1, x: 0 }}
          onClick={() => setPhase("menu")}
          className="flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" />
          Back
        </motion.button>
        <div />
      </div>

      {/* Title + progress */}
      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        className="flex w-full max-w-5xl flex-col items-center gap-4"
      >
        <div className="text-center">
          <h2 className="text-4xl font-bold tracking-tight">Cat Gallery</h2>
          <p className="mt-2 text-muted-foreground">
            {unlockedCount} of {totalCount} achievements unlocked
          </p>
        </div>
        {/* Overall progress bar */}
        <div className="h-2 w-full max-w-xs overflow-hidden rounded-full bg-muted">
          <div
            className="h-full rounded-full bg-gradient-to-r from-purple-500 to-pink-500 transition-all"
            style={{ width: `${progressPct}%` }}
          />
        </div>
      </motion.div>

      {/* Achievement cards */}
      <div className="grid w-full max-w-5xl grid-cols-2 gap-6 sm:grid-cols-3 md:grid-cols-5">
        {ACHIEVEMENT_DEFS.map((def, index) => {
          const state = achievements[def.id];
          const unlocked = state?.unlocked ?? false;
          const gradient = GRADIENT_COLORS[index % GRADIENT_COLORS.length];

          return (
            <motion.div
              key={def.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{
                delay: Math.min(index * 0.05, 0.5),
                type: "spring",
                stiffness: 300,
                damping: 25,
              }}
              className={cn(
                "relative flex flex-col items-center gap-2 overflow-hidden rounded-xl border p-6",
                unlocked
                  ? "bg-card border-border hover:shadow-lg hover:scale-105 transition-all"
                  : "bg-muted/50 border-border/50",
              )}
            >
              {/* Gradient top bar for unlocked */}
              {unlocked && (
                <div
                  className="absolute left-0 right-0 top-0 h-1"
                  style={{
                    background: `linear-gradient(90deg, ${gradient.from}, ${gradient.to})`,
                  }}
                />
              )}

              <div className="flex h-16 w-16 items-center justify-center rounded-lg text-3xl">
                {unlocked ? (
                  "🐱"
                ) : (
                  <Lock className="h-6 w-6 text-muted-foreground" />
                )}
              </div>

              <span className="text-center text-sm font-medium text-foreground">
                {unlocked ? def.name : "???"}
              </span>

              <span className="text-center text-xs text-muted-foreground">
                {unlocked ? def.description : "Keep playing to unlock."}
              </span>

              {unlocked && state?.unlockedAt && (
                <span className="text-xs text-muted-foreground">
                  {new Date(state.unlockedAt).toLocaleDateString()}
                </span>
              )}
            </motion.div>
          );
        })}
      </div>
    </div>
  );
}
