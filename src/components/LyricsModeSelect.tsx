import { motion } from "motion/react";
import { BookOpen, Eye, ArrowLeft } from "lucide-react";
import { useGameStore } from "../stores/gameStore";
import { cn } from "../lib/cn";
import type { ReactNode } from "react";
import type { LyricsMode } from "../types";

interface ModeCardProps {
  readonly onClick: () => void;
  readonly icon: ReactNode;
  readonly label: string;
  readonly description: string;
  readonly gradientFrom: string;
  readonly gradientTo: string;
  readonly delay: number;
  readonly disabled?: boolean;
  readonly disabledReason?: string;
}

function ModeCard({
  onClick,
  icon,
  label,
  description,
  gradientFrom,
  gradientTo,
  delay,
  disabled = false,
  disabledReason,
}: ModeCardProps) {
  return (
    <motion.button
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay, type: "spring", stiffness: 300, damping: 30 }}
      whileHover={disabled ? undefined : { scale: 1.02 }}
      whileTap={disabled ? undefined : { scale: 0.98 }}
      onClick={disabled ? undefined : onClick}
      disabled={disabled}
      className={cn(
        "group relative flex flex-col items-start gap-4 overflow-hidden rounded-2xl",
        "bg-card border border-border p-8 text-left",
        "transition-[color,background-color,border-color,box-shadow] duration-300",
        disabled
          ? "opacity-50 cursor-not-allowed"
          : "hover:border-primary/50 hover:shadow-xl cursor-pointer",
      )}
    >
      <div
        className="pointer-events-none absolute inset-0 opacity-0 transition-opacity group-hover:opacity-10"
        style={{
          background: `linear-gradient(135deg, ${gradientFrom}, ${gradientTo})`,
        }}
      />
      <div
        className="inline-flex rounded-xl p-3"
        style={{
          background: `linear-gradient(135deg, ${gradientFrom}, ${gradientTo})`,
        }}
      >
        {icon}
      </div>
      <div>
        <h3 className="text-lg font-semibold text-foreground">{label}</h3>
        <p className="mt-1 text-sm text-muted-foreground">{description}</p>
        {disabled && disabledReason && (
          <p className="mt-2 text-xs text-yellow-500">{disabledReason}</p>
        )}
      </div>
    </motion.button>
  );
}

export function LyricsModeSelect() {
  const setPhase = useGameStore((s) => s.setPhase);
  const setLyricsMode = useGameStore((s) => s.setLyricsMode);
  const handleMode = (lyricsMode: LyricsMode) => {
    setLyricsMode(lyricsMode);
    setPhase("difficulty-select");
  };

  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-8 bg-gradient-to-br from-background to-muted/20 px-6">
      <motion.button
        initial={{ opacity: 0, x: -10 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ type: "spring", stiffness: 300, damping: 30 }}
        onClick={() => setPhase("quiz-type-select")}
        className="absolute left-8 top-8 flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
      >
        <ArrowLeft className="h-4 w-4" />
        Back
      </motion.button>

      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ type: "spring", stiffness: 300, damping: 30 }}
        className="text-center"
      >
        <h2 className="text-4xl font-bold tracking-tight">
          Choose your challenge
        </h2>
        <p className="mt-2 text-muted-foreground">Pick a lyrics game mode</p>
      </motion.div>

      <div className="grid w-full max-w-3xl grid-cols-1 gap-6 md:grid-cols-2">
        <ModeCard
          onClick={() => handleMode("name-that-song")}
          icon={<BookOpen className="h-6 w-6 text-white" />}
          label="Name That Song"
          description="Read lyrics, guess the title"
          gradientFrom="#8b5cf6"
          gradientTo="#6366f1"
          delay={0.1}
        />
        <ModeCard
          onClick={() => handleMode("lyrics-or-lie")}
          icon={<Eye className="h-6 w-6 text-white" />}
          label="Lyrics or Lie"
          description="See a lyric, decide if it's real or fake"
          gradientFrom="#f97316"
          gradientTo="#eab308"
          delay={0.2}
        />
      </div>
    </div>
  );
}
