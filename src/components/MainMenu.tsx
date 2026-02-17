import { motion } from "motion/react";
import { Music, Album, Award, Settings } from "lucide-react";
import { useGameStore } from "../stores/gameStore";
import { cn } from "../lib/cn";
import type { ReactNode } from "react";

function SwiftieLogo() {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 64 64"
      width={80}
      height={80}
      aria-hidden="true"
    >
      <circle cx="32" cy="32" r="32" fill="#E97F6A" />
      <g fill="#ffffff" transform="translate(18, 12)">
        <rect x="20" y="0" width="4" height="28" rx="2" />
        <circle cx="8" cy="34" r="8" />
        <rect x="20" y="0" width="10" height="4" rx="2" />
      </g>
    </svg>
  );
}

interface MenuCardProps {
  readonly onClick: () => void;
  readonly icon: ReactNode;
  readonly label: string;
  readonly description: string;
  readonly gradientFrom: string;
  readonly gradientTo: string;
  readonly delay: number;
}

function MenuCard({
  onClick,
  icon,
  label,
  description,
  gradientFrom,
  gradientTo,
  delay,
}: MenuCardProps) {
  return (
    <motion.button
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay, type: "spring", stiffness: 300, damping: 25 }}
      onClick={onClick}
      className={cn(
        "group relative flex flex-col items-start gap-4 overflow-hidden rounded-2xl",
        "bg-card border border-border p-8 text-left",
        "transition-all duration-300",
        "hover:border-primary/50 hover:shadow-xl hover:scale-[1.02]",
      )}
    >
      {/* Hover gradient overlay */}
      <div
        className="pointer-events-none absolute inset-0 opacity-0 transition-opacity group-hover:opacity-10"
        style={{
          background: `linear-gradient(135deg, ${gradientFrom}, ${gradientTo})`,
        }}
      />

      {/* Icon badge */}
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

export function MainMenu() {
  const setPhase = useGameStore((s) => s.setPhase);
  const setMode = useGameStore((s) => s.setMode);

  const handleRandom = () => {
    setMode("random");
    setPhase("difficulty-select");
  };

  const handlePickAlbums = () => {
    setMode("album");
    setPhase("album-select");
  };

  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-8 bg-gradient-to-br from-background to-muted/20 px-6">
      {/* Logo + Title */}
      <motion.div
        initial={{ opacity: 0, scale: 0.8 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ type: "spring", stiffness: 300, damping: 20 }}
        className="flex flex-col items-center gap-4"
      >
        <SwiftieLogo />
        <div className="text-center">
          <h1 className="text-5xl font-extrabold tracking-tight">
            Swiftie Quiz
          </h1>
          <p className="mt-2 text-muted-foreground">
            How well do you know Taylor&apos;s music?
          </p>
        </div>
      </motion.div>

      {/* 2x2 Menu Grid */}
      <div className="grid w-full max-w-2xl grid-cols-1 gap-6 md:grid-cols-2">
        <MenuCard
          onClick={handleRandom}
          icon={<Music className="h-6 w-6 text-white" />}
          label="Random Mode"
          description="All songs, shuffled randomly"
          gradientFrom="#8b5cf6"
          gradientTo="#6366f1"
          delay={0.1}
        />
        <MenuCard
          onClick={handlePickAlbums}
          icon={<Album className="h-6 w-6 text-white" />}
          label="Pick Albums"
          description="Choose your favorite albums"
          gradientFrom="#ec4899"
          gradientTo="#f43f5e"
          delay={0.2}
        />
        <MenuCard
          onClick={() => setPhase("cat-gallery")}
          icon={<Award className="h-6 w-6 text-white" />}
          label="Cat Gallery"
          description="View your achievements"
          gradientFrom="#f97316"
          gradientTo="#eab308"
          delay={0.3}
        />
        <MenuCard
          onClick={() => setPhase("settings")}
          icon={<Settings className="h-6 w-6 text-white" />}
          label="Settings"
          description="Theme, volume & more"
          gradientFrom="#06b6d4"
          gradientTo="#3b82f6"
          delay={0.4}
        />
      </div>
    </div>
  );
}
