import { motion } from "motion/react";
import { Volume2, BookOpen, ArrowLeft } from "lucide-react";
import { useGameStore } from "../stores/gameStore";
import { cn } from "../lib/cn";
import type { ReactNode } from "react";

interface TypeCardProps {
  readonly onClick: () => void;
  readonly icon: ReactNode;
  readonly label: string;
  readonly description: string;
  readonly gradientFrom: string;
  readonly gradientTo: string;
  readonly delay: number;
}

function TypeCard({
  onClick,
  icon,
  label,
  description,
  gradientFrom,
  gradientTo,
  delay,
}: TypeCardProps) {
  return (
    <motion.button
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay, type: "spring", stiffness: 300, damping: 30 }}
      whileHover={{ scale: 1.02 }}
      whileTap={{ scale: 0.98 }}
      onClick={onClick}
      className={cn(
        "group relative flex flex-col items-start gap-4 overflow-hidden rounded-2xl",
        "bg-card border border-border p-8 text-left",
        "transition-[color,background-color,border-color,box-shadow] duration-300",
        "hover:border-primary/50 hover:shadow-xl",
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
      </div>
    </motion.button>
  );
}

export function QuizTypeSelect() {
  const setPhase = useGameStore((s) => s.setPhase);
  const setQuizType = useGameStore((s) => s.setQuizType);
  const mode = useGameStore((s) => s.mode);

  const handleSound = () => {
    setQuizType("sound");
    setPhase("difficulty-select");
  };

  const handleLyrics = () => {
    setQuizType("lyrics");
    setPhase("lyrics-mode-select");
  };

  const handleBack = () => {
    setPhase(mode === "album" ? "album-select" : "menu");
  };

  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-8 bg-gradient-to-br from-background to-muted/20 px-6">
      <motion.button
        initial={{ opacity: 0, x: -10 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ type: "spring", stiffness: 300, damping: 30 }}
        onClick={handleBack}
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
          How do you want to play?
        </h2>
        <p className="mt-2 text-muted-foreground">
          Choose your quiz style
        </p>
      </motion.div>

      <div className="grid w-full max-w-2xl grid-cols-1 gap-6 md:grid-cols-2">
        <TypeCard
          onClick={handleSound}
          icon={<Volume2 className="h-6 w-6 text-white" />}
          label="Sound"
          description="Hear a clip, guess the song"
          gradientFrom="#8b5cf6"
          gradientTo="#6366f1"
          delay={0.1}
        />
        <TypeCard
          onClick={handleLyrics}
          icon={<BookOpen className="h-6 w-6 text-white" />}
          label="Lyrics"
          description="Read lyrics, test your knowledge"
          gradientFrom="#ec4899"
          gradientTo="#f43f5e"
          delay={0.2}
        />
      </div>
    </div>
  );
}
