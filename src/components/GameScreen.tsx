import { useCallback, useEffect, useRef, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { motion, AnimatePresence } from "motion/react";
import { ArrowLeft } from "lucide-react";
import { StreakBadge } from "./StreakBadge";
import { useGameStore } from "../stores/gameStore";
import { useAchievements } from "../hooks/useAchievements";
import { createTrackPool, drawNextTrack } from "../engine/gameEngine";
import { generateOptions } from "../engine/optionGenerator";
import { checkAnswer } from "../engine/answerMatcher";
import { playQuacks, loadQuackBuffer } from "../engine/quackManager";
import { AudioPlayer } from "./AudioPlayer";
import { QuizCard } from "./QuizCard";
import { Timer } from "./Timer";
import { ResultFeedback } from "./ResultFeedback";
import type { Track, AlbumTracksResponse } from "../types";

type RoundState = "loading" | "playing" | "answered";

function SwiftieLogoSmall() {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 64 64"
      width={40}
      height={40}
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

export function GameScreen() {
  const mode = useGameStore((s) => s.mode);
  const difficulty = useGameStore((s) => s.difficulty);
  const selectedAlbumIds = useGameStore((s) => s.selectedAlbumIds);
  const currentTrack = useGameStore((s) => s.currentTrack);
  const trackPool = useGameStore((s) => s.trackPool);
  const options = useGameStore((s) => s.options);
  const streak = useGameStore((s) => s.streak);
  const quackCount = useGameStore((s) => s.quackCount);
  const relistenCount = useGameStore((s) => s.relistenCount);
  const progress = useGameStore((s) => s.progress);
  const startRound = useGameStore((s) => s.startRound);
  const answerCorrect = useGameStore((s) => s.answerCorrect);
  const answerIncorrect = useGameStore((s) => s.answerIncorrect);
  const resetGame = useGameStore((s) => s.resetGame);
  const setTrackPool = useGameStore((s) => s.setTrackPool);

  const { checkAndUnlock } = useAchievements();

  const [roundState, setRoundState] = useState<RoundState>("loading");
  const [lastResult, setLastResult] = useState<boolean | null>(null);
  const [timerActive, setTimerActive] = useState(false);
  const allTracksRef = useRef<readonly Track[]>([]);
  const roundStartTimeRef = useRef(0);
  const quackContextRef = useRef<AudioContext | null>(null);
  const quackBufferRef = useRef<AudioBuffer | null>(null);

  // Load tracks on mount
  useEffect(() => {
    const loadTracks = async () => {
      try {
        let tracks: Track[];
        if (mode === "random") {
          tracks = await invoke<Track[]>("fetch_top_tracks");
        } else {
          const allTracks: Track[] = [];
          for (const albumId of selectedAlbumIds) {
            const response = await invoke<AlbumTracksResponse>(
              "fetch_album_tracks",
              { albumId },
            );
            allTracks.push(...response.tracks);
          }
          tracks = allTracks;
        }
        allTracksRef.current = tracks;
        const pool = createTrackPool(tracks);
        setTrackPool(pool);
        beginRound(pool, tracks);
      } catch (err) {
        console.error("Failed to load tracks:", err);
      }
    };
    loadTracks();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const beginRound = useCallback(
    (pool: readonly Track[], allTracks: readonly Track[]) => {
      const { track, remaining } = drawNextTrack(pool, allTracks);
      const opts = generateOptions(track, allTracks);
      startRound(track, remaining, opts);
      setRoundState("playing");
      setLastResult(null);
      setTimerActive(true);
      roundStartTimeRef.current = Date.now();
    },
    [startRound],
  );

  const handleAnswer = useCallback(
    (answer: number | string) => {
      if (!currentTrack || roundState !== "playing") return;

      setTimerActive(false);
      const correct = checkAnswer(answer, currentTrack, difficulty);
      setLastResult(correct);
      setRoundState("answered");

      const timeElapsed = Date.now() - roundStartTimeRef.current;
      const usedFullClip = relistenCount >= 3;

      if (correct) {
        answerCorrect(currentTrack);
        // Check achievements with updated state
        const updatedProgress = {
          ...progress,
          stats: {
            ...progress.stats,
            totalCorrect: progress.stats.totalCorrect + 1,
          },
        };
        checkAndUnlock({
          correct: true,
          streak: streak + 1,
          quackCount: 0,
          difficulty,
          timeElapsed,
          usedFullClip,
          progress: updatedProgress,
        });
      } else {
        answerIncorrect();
        // Play escalating quacks on wrong answer
        const newQuackCount = quackCount + 1;
        void (async () => {
          try {
            if (!quackContextRef.current) {
              quackContextRef.current = new AudioContext();
            }
            const ctx = quackContextRef.current;
            if (!quackBufferRef.current) {
              quackBufferRef.current = await loadQuackBuffer(ctx);
            }
            await playQuacks(
              newQuackCount,
              ctx,
              quackBufferRef.current,
              progress.settings.volume,
            );
          } catch {
            // Quack playback is non-critical
          }
        })();
        checkAndUnlock({
          correct: false,
          streak: 0,
          quackCount: newQuackCount,
          difficulty,
          timeElapsed,
          usedFullClip,
          progress,
        });
      }
    },
    [
      currentTrack,
      roundState,
      difficulty,
      relistenCount,
      streak,
      quackCount,
      progress,
      answerCorrect,
      answerIncorrect,
      checkAndUnlock,
    ],
  );

  const handleTimerExpire = useCallback(() => {
    if (roundState === "playing") {
      handleAnswer(-1); // Timeout treated as incorrect
    }
  }, [roundState, handleAnswer]);

  const handleNext = useCallback(() => {
    beginRound(trackPool, allTracksRef.current);
  }, [trackPool, beginRound]);

  const timerDuration =
    difficulty === "medium" ? 20 : difficulty === "hard" ? 15 : 0;

  if (roundState === "loading" || !currentTrack) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-background to-muted/20">
        <p className="text-muted-foreground">Loading tracks...</p>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen flex-col items-center gap-6 bg-gradient-to-br from-background to-muted/20 p-8">
      {/* Header */}
      <div className="flex w-full max-w-lg items-center justify-between">
        <button
          onClick={resetGame}
          className="flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" />
          Exit
        </button>

        <SwiftieLogoSmall />

        <StreakBadge streak={streak} />
      </div>

      {/* Audio Player */}
      <div className="w-full max-w-lg">
        <AudioPlayer
          previewUrl={currentTrack.preview}
          active={roundState === "playing"}
          track={currentTrack}
        />
      </div>

      {/* Timer */}
      {timerDuration > 0 && roundState === "playing" && (
        <div className="w-full max-w-lg">
          <Timer
            duration={timerDuration}
            onExpire={handleTimerExpire}
            active={timerActive}
          />
        </div>
      )}

      {/* Quiz or Result */}
      <AnimatePresence mode="wait">
        {roundState === "playing" && (
          <motion.div
            key="quiz"
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            className="w-full max-w-lg"
          >
            <QuizCard
              difficulty={difficulty}
              options={options}
              albumHint={
                difficulty === "easy" ? currentTrack.album.title : undefined
              }
              onAnswer={handleAnswer}
              disabled={false}
            />
          </motion.div>
        )}

        {roundState === "answered" && lastResult !== null && (
          <motion.div
            key="result"
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.95 }}
          >
            <ResultFeedback
              correct={lastResult}
              correctTrack={currentTrack}
              onNext={handleNext}
            />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
