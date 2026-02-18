import { motion } from "motion/react";
import { Check, X } from "lucide-react";
import { LyricSnippetCard } from "./LyricSnippetCard";
import { cn } from "../lib/cn";

interface LyricsOrLieCardProps {
  readonly songTitle: string;
  readonly albumCover: string | null;
  readonly showAlbumCover: boolean;
  readonly lyricLine: string;
  readonly onAnswer: (isReal: boolean) => void;
  readonly disabled: boolean;
}

export function LyricsOrLieCard({
  songTitle,
  albumCover,
  showAlbumCover,
  lyricLine,
  onAnswer,
  disabled,
}: LyricsOrLieCardProps) {
  return (
    <div className="flex w-full flex-col items-center gap-6">
      {/* Song title + optional album cover */}
      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ type: "spring", stiffness: 300, damping: 30 }}
        className="flex items-center gap-4"
      >
        {showAlbumCover && albumCover && (
          <img
            src={albumCover}
            alt="Album cover"
            className="h-16 w-16 rounded-lg object-cover"
          />
        )}
        <h3 className="text-2xl font-bold text-foreground">{songTitle}</h3>
      </motion.div>

      {/* Lyric line */}
      <LyricSnippetCard lines={[lyricLine]} />

      {/* Question */}
      <p className="text-sm text-muted-foreground">
        Is this lyric really from this song?
      </p>

      {/* Real / Fake buttons */}
      <div className="flex w-full max-w-sm gap-4">
        <motion.button
          whileHover={disabled ? undefined : { scale: 1.03 }}
          whileTap={disabled ? undefined : { scale: 0.97 }}
          onClick={() => onAnswer(true)}
          disabled={disabled}
          className={cn(
            "flex flex-1 items-center justify-center gap-2 rounded-xl border-2 p-4 font-medium transition-all",
            "border-green-500/30 bg-green-500/5 text-green-400",
            "hover:border-green-500/60 hover:bg-green-500/10",
            disabled && "opacity-50 cursor-not-allowed",
          )}
        >
          <Check className="h-5 w-5" />
          Real
        </motion.button>
        <motion.button
          whileHover={disabled ? undefined : { scale: 1.03 }}
          whileTap={disabled ? undefined : { scale: 0.97 }}
          onClick={() => onAnswer(false)}
          disabled={disabled}
          className={cn(
            "flex flex-1 items-center justify-center gap-2 rounded-xl border-2 p-4 font-medium transition-all",
            "border-border bg-background text-foreground",
            "hover:border-primary/50 hover:bg-card",
            disabled && "opacity-50 cursor-not-allowed",
          )}
        >
          <X className="h-5 w-5" />
          Fake
        </motion.button>
      </div>
    </div>
  );
}
