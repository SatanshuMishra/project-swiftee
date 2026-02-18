import { useCallback, useRef, useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { ArrowLeft } from "lucide-react";
import { StreakBadge } from "./StreakBadge";
import { useGameStore } from "../stores/gameStore";
import { useAchievements } from "../hooks/useAchievements";
import { useLyrics } from "../hooks/useLyrics";
import { checkAnswer } from "../engine/answerMatcher";
import {
  extractSnippet,
  sanitiseSnippet,
  selectDecoyOrReal,
} from "../engine/lyricProcessor";
import { generateOptions } from "../engine/optionGenerator";
import { playQuacks, loadQuackBuffer } from "../engine/quackManager";
import { QuizCard } from "./QuizCard";
import { Timer } from "./Timer";
import { ResultFeedback } from "./ResultFeedback";
import { LyricSnippetCard } from "./LyricSnippetCard";
import { LyricsOrLieCard } from "./LyricsOrLieCard";
import type { Track, TrackWithLyrics, DecoyResult } from "../types";
import { shuffle } from "../lib/shuffle";

type RoundState = "playing" | "answered";

interface LyricsRoundData {
  readonly trackWithLyrics: TrackWithLyrics;
  readonly snippetLines: readonly string[];
  readonly decoyResult?: DecoyResult;
}

function getTimerDuration(
  lyricsMode: string | null,
  difficulty: string,
): number {
  if (lyricsMode === "name-that-song") {
    if (difficulty === "medium") return 20;
    if (difficulty === "hard") return 15;
    return 0;
  }
  if (lyricsMode === "lyrics-or-lie") {
    if (difficulty === "medium") return 15;
    if (difficulty === "hard") return 10;
    return 0;
  }
  return 0;
}

function getLineCount(lyricsMode: string | null, difficulty: string): number {
  if (lyricsMode === "name-that-song") {
    if (difficulty === "easy") return 4;
    if (difficulty === "medium") return 3;
    return 2;
  }
  return 1;
}

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

export function LyricsGameScreen() {
  const lyricsMode = useGameStore((s) => s.lyricsMode);
  const difficulty = useGameStore((s) => s.difficulty);
  const lyricsPool = useGameStore((s) => s.lyricsPool);
  const lyricsAvailableTracks = useGameStore((s) => s.lyricsAvailableTracks);
  const decoyPool = useGameStore((s) => s.decoyPool);
  const streak = useGameStore((s) => s.streak);
  const quackCount = useGameStore((s) => s.quackCount);
  const progress = useGameStore((s) => s.progress);
  const answerCorrect = useGameStore((s) => s.answerCorrect);
  const answerIncorrect = useGameStore((s) => s.answerIncorrect);
  const incrementLyricsStat = useGameStore((s) => s.incrementLyricsStat);
  const nextLyricsTrack = useGameStore((s) => s.nextLyricsTrack);
  const setLyricsPool = useGameStore((s) => s.setLyricsPool);
  const resetGame = useGameStore((s) => s.resetGame);

  const { checkAndUnlock } = useAchievements();
  const { preFetchMore } = useLyrics();

  const [roundState, setRoundState] = useState<RoundState>("playing");
  const [roundData, setRoundData] = useState<LyricsRoundData | null>(null);
  const [lastResult, setLastResult] = useState<boolean | null>(null);
  const [timerActive, setTimerActive] = useState(false);
  const [options, setOptions] = useState<readonly Track[]>([]);
  const roundStartTimeRef = useRef(0);
  const quackContextRef = useRef<AudioContext | null>(null);
  const quackBufferRef = useRef<AudioBuffer | null>(null);
  const poolIndexRef = useRef(0);
  const allTracksRef = useRef<readonly Track[]>([]);
  const hasStartedRef = useRef(false);

  const beginRound = useCallback(() => {
    let trackWithLyrics = nextLyricsTrack();

    if (!trackWithLyrics) {
      // Pool exhausted: reshuffle
      const reshuffled = shuffle(lyricsPool);
      setLyricsPool(reshuffled);
      trackWithLyrics = reshuffled[0] ?? null;
      if (!trackWithLyrics) return;
    }

    const { track, lyrics } = trackWithLyrics;
    const lineCount = getLineCount(lyricsMode, difficulty);

    let snippetLines: readonly string[] = [];
    let decoyResult: DecoyResult | undefined;

    if (lyricsMode === "name-that-song") {
      const preferChorus = difficulty === "easy";
      const excludeChorus = difficulty === "hard";
      const snippet = extractSnippet(
        lyrics.lines,
        lineCount,
        preferChorus,
        excludeChorus,
      );
      snippetLines = sanitiseSnippet(snippet.lines, track.title);

      // Generate title options for MC mode
      if (difficulty !== "hard") {
        const allTracks =
          allTracksRef.current.length > 0
            ? allTracksRef.current
            : lyricsPool.map((tw) => tw.track);
        const opts = generateOptions(track, allTracks);
        setOptions(opts);
      }
    } else if (lyricsMode === "lyrics-or-lie") {
      decoyResult = selectDecoyOrReal(
        lyrics.lines,
        decoyPool,
        difficulty,
        lyrics.sourceAlbum,
      );
    }

    setRoundData({
      trackWithLyrics,
      snippetLines,
      decoyResult,
    });
    setRoundState("playing");
    setLastResult(null);
    setTimerActive(true);
    roundStartTimeRef.current = Date.now();
    poolIndexRef.current += 1;
  }, [
    nextLyricsTrack,
    lyricsPool,
    setLyricsPool,
    lyricsMode,
    difficulty,
    decoyPool,
  ]);

  // Start first round
  if (!hasStartedRef.current && lyricsPool.length > 0) {
    hasStartedRef.current = true;
    // Store all tracks for option generation and background pre-fetching
    allTracksRef.current =
      lyricsAvailableTracks.length > 0
        ? lyricsAvailableTracks
        : lyricsPool.map((tw) => tw.track);
    // Use setTimeout to avoid state update during render
    setTimeout(() => beginRound(), 0);
  }

  const handleAnswer = useCallback(
    (answer: number | string | boolean) => {
      if (!roundData || roundState !== "playing") return;

      setTimerActive(false);
      const { trackWithLyrics, decoyResult } = roundData;
      const track = trackWithLyrics.track;
      const timeElapsed = Date.now() - roundStartTimeRef.current;

      let correct = false;

      if (lyricsMode === "name-that-song") {
        correct = checkAnswer(answer as number | string, track, difficulty);
      } else if (lyricsMode === "lyrics-or-lie" && decoyResult) {
        const playerSaidReal = answer === true;
        correct = playerSaidReal === decoyResult.isReal;
      }

      setLastResult(correct);
      setRoundState("answered");

      if (correct) {
        answerCorrect(track);
        if (lyricsMode) {
          incrementLyricsStat(lyricsMode);
        }

        const updatedProgress = {
          ...progress,
          stats: {
            ...progress.stats,
            totalCorrect: progress.stats.totalCorrect + 1,
            totalLyricsCorrect: progress.stats.totalLyricsCorrect + 1,
          },
        };
        checkAndUnlock({
          correct: true,
          streak: streak + 1,
          quackCount: 0,
          difficulty,
          timeElapsed,
          usedFullClip: false,
          progress: updatedProgress,
          quizType: "lyrics",
          lyricsMode: lyricsMode ?? undefined,
          sessionSoundCorrect: useGameStore.getState().sessionSoundCorrect,
          sessionLyricsCorrect:
            useGameStore.getState().sessionLyricsCorrect + 1,
        });
      } else {
        answerIncorrect();
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
          usedFullClip: false,
          progress,
          quizType: "lyrics",
          lyricsMode: lyricsMode ?? undefined,
          sessionSoundCorrect: useGameStore.getState().sessionSoundCorrect,
          sessionLyricsCorrect: useGameStore.getState().sessionLyricsCorrect,
        });
      }

      // Kick off rolling pre-fetch and merge results into pool
      const currentPool = useGameStore.getState().lyricsPool;
      const existingIds = new Set(currentPool.map((tw) => tw.track.id));
      void preFetchMore(allTracksRef.current, existingIds).then((newTracks) => {
        if (newTracks.length > 0) {
          const latestPool = useGameStore.getState().lyricsPool;
          setLyricsPool([...latestPool, ...newTracks]);
        }
      });
    },
    [
      roundData,
      roundState,
      lyricsMode,
      difficulty,
      streak,
      quackCount,
      progress,
      answerCorrect,
      answerIncorrect,
      incrementLyricsStat,
      checkAndUnlock,
      setLyricsPool,
      preFetchMore,
    ],
  );

  const handleTimerExpire = useCallback(() => {
    if (roundState === "playing") {
      if (lyricsMode === "name-that-song") {
        handleAnswer(-1);
      } else if (lyricsMode === "lyrics-or-lie") {
        // Timeout = wrong
        handleAnswer("timeout");
      } else {
        handleAnswer(-1);
      }
    }
  }, [roundState, lyricsMode, handleAnswer]);

  const handleNext = useCallback(() => {
    beginRound();
  }, [beginRound]);

  const timerDuration = getTimerDuration(lyricsMode, difficulty);

  if (!roundData) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-background to-muted/20">
        <p className="text-muted-foreground">Preparing round...</p>
      </div>
    );
  }

  const { trackWithLyrics, snippetLines, decoyResult } = roundData;
  const track = trackWithLyrics.track;

  return (
    <div className="flex min-h-screen flex-col items-center bg-gradient-to-br from-background to-muted/20">
      <div className="flex w-full flex-col items-center gap-6 p-8">
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
              key={`quiz-${poolIndexRef.current}`}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              className="w-full max-w-lg"
            >
              {/* Name That Song */}
              {lyricsMode === "name-that-song" && (
                <div className="flex flex-col items-center gap-6">
                  {difficulty === "easy" && (
                    <p className="text-sm text-muted-foreground">
                      Album: {track.album.title}
                    </p>
                  )}
                  <LyricSnippetCard lines={snippetLines} />
                  <QuizCard
                    difficulty={difficulty}
                    options={options}
                    albumHint={undefined}
                    onAnswer={handleAnswer}
                    disabled={false}
                  />
                </div>
              )}

              {/* Lyrics or Lie */}
              {lyricsMode === "lyrics-or-lie" && decoyResult && (
                <LyricsOrLieCard
                  songTitle={track.titleShort || track.title}
                  albumCover={track.album.coverMedium}
                  showAlbumCover={difficulty === "easy"}
                  lyricLine={decoyResult.line}
                  onAnswer={(isReal) => handleAnswer(isReal)}
                  disabled={false}
                />
              )}
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
                correctTrack={track}
                onNext={handleNext}
                quizType="lyrics"
                lyricsMode={lyricsMode ?? undefined}
                decoySourceSong={decoyResult?.sourceSong}
              />
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
