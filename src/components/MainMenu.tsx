import { useState, useEffect } from "react";
import { motion } from "motion/react";
import { Music, Album, Award, Settings } from "lucide-react";
import { CatIconButton } from "./CatIconButton";
import { useGameStore } from "../stores/gameStore";
import { cn } from "../lib/cn";
import { SwiftieLogo } from "./SwiftieLogo";
import { BirthdayCard } from "./BirthdayCard";
import {
  shouldAutoShowBirthdayCard,
  markBirthdayCardShown,
} from "../lib/birthday";
import type { ReactNode } from "react";

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
  const [showBirthdayCard, setShowBirthdayCard] = useState(false);
  const [catAnimDone, setCatAnimDone] = useState(false);

  useEffect(() => {
    if (shouldAutoShowBirthdayCard()) {
      const timer = setTimeout(() => {
        setShowBirthdayCard(true);
        markBirthdayCardShown();
      }, 1000);
      return () => clearTimeout(timer);
    }
  }, []);

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
      {/* Birthday Card Cat Button */}
      <div className="group fixed top-6 right-6 z-40">
        <motion.div
          initial={{ opacity: 0, scale: 0 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{
            type: "spring",
            stiffness: 300,
            damping: 30,
            delay: catAnimDone ? 0 : 0.8,
          }}
          onAnimationComplete={() => {
            if (!catAnimDone) setCatAnimDone(true);
          }}
          whileHover={{
            scale: 1.1,
            transition: { type: "spring", stiffness: 400, damping: 20 },
          }}
          whileTap={{
            scale: 0.95,
            transition: { type: "spring", stiffness: 400, damping: 20 },
          }}
          className="cursor-pointer"
        >
          <CatIconButton onClick={() => setShowBirthdayCard(true)} />
        </motion.div>
        <span className="pointer-events-none absolute -bottom-7 right-0 whitespace-nowrap rounded-md border border-border bg-card px-2 py-1 text-xs text-muted-foreground opacity-0 shadow-lg transition-opacity group-hover:opacity-100">
          Birthday Card
        </span>
      </div>

      <BirthdayCard
        isOpen={showBirthdayCard}
        onClose={() => setShowBirthdayCard(false)}
      />

      {/* Logo + Title */}
      <motion.div
        initial={{ opacity: 0, scale: 0.8 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ type: "spring", stiffness: 300, damping: 30 }}
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
