import { useCallback } from "react";
import { useGameStore } from "../stores/gameStore";
import { ACHIEVEMENT_DEFS } from "../engine/achievements";
import type { Difficulty, GameProgress, QuizType, LyricsMode } from "../types";

interface CheckContext {
  readonly correct: boolean;
  readonly streak: number;
  readonly quackCount: number;
  readonly difficulty: Difficulty;
  readonly timeElapsed: number;
  readonly usedFullClip: boolean;
  readonly progress: GameProgress;
  readonly totalTracksOnAlbum?: number;
  readonly quizType?: QuizType;
  readonly lyricsMode?: LyricsMode;
  readonly sessionSoundCorrect?: number;
  readonly sessionLyricsCorrect?: number;
}

export function useAchievements() {
  const progress = useGameStore((s) => s.progress);
  const setProgress = useGameStore((s) => s.setProgress);
  const addToast = useGameStore((s) => s.addToast);

  const checkAndUnlock = useCallback(
    (context: CheckContext) => {
      const newAchievements = { ...context.progress.achievements };
      const newlyUnlocked: string[] = [];

      for (const def of ACHIEVEMENT_DEFS) {
        if (newAchievements[def.id]?.unlocked) continue;

        const shouldUnlock = evaluateCondition(def.id, context);
        if (shouldUnlock) {
          newAchievements[def.id] = {
            unlocked: true,
            unlockedAt: new Date().toISOString(),
          };
          newlyUnlocked.push(def.id);
        }
      }

      if (newlyUnlocked.length > 0) {
        const updatedProgress: GameProgress = {
          ...context.progress,
          achievements: newAchievements,
        };
        setProgress(updatedProgress);
        for (const id of newlyUnlocked) {
          addToast(id);
        }
      }
    },
    [setProgress, addToast],
  );

  return { checkAndUnlock, progress };
}

function evaluateCondition(id: string, ctx: CheckContext): boolean {
  if (!ctx.correct && id !== "quack_collector") return false;

  switch (id) {
    case "first_meow":
      return ctx.progress.stats.totalCorrect >= 1;

    case "getting_warmed_up":
      return ctx.progress.stats.totalCorrect >= 10;

    case "purrfect_streak":
      return ctx.streak >= 10;

    case "album_explorer":
      return ctx.progress.stats.albumsPlayed.length >= 5;

    case "album_completionist": {
      const tracksPerAlbum = ctx.progress.stats.tracksGuessedPerAlbum;
      if (ctx.totalTracksOnAlbum) {
        for (const albumTracks of Object.values(tracksPerAlbum)) {
          if (albumTracks.length >= ctx.totalTracksOnAlbum) return true;
        }
      }
      return false;
    }

    case "hard_mode_hero":
      return ctx.difficulty === "hard" && ctx.progress.stats.totalCorrect >= 5;

    case "speed_demon":
      return ctx.timeElapsed <= 3000;

    case "persistent_listener":
      return ctx.usedFullClip;

    case "quack_collector":
      return !ctx.correct && ctx.quackCount >= 5;

    case "all_ears":
      return ctx.progress.stats.totalCorrect >= 50;

    // Lyrics achievements
    case "lyric_lover":
      return ctx.progress.stats.totalLyricsCorrect >= 1;

    case "poet_laureate":
      return ctx.progress.stats.nameThaSongCorrect >= 20;

    case "lie_detector":
      return ctx.progress.stats.lyricsOrLieCorrect >= 15;

    case "dual_threat":
      return (
        (ctx.sessionSoundCorrect ?? 0) >= 1 &&
        (ctx.sessionLyricsCorrect ?? 0) >= 1
      );

    case "lyric_streak":
      return ctx.quizType === "lyrics" && ctx.streak >= 10;

    default:
      return false;
  }
}
