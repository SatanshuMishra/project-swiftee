import { useEffect, useState } from "react";
import { motion } from "motion/react";
import { Check, X } from "lucide-react";
import type { Track, QuizType, LyricsMode } from "../types";
import { shuffle } from "../lib/shuffle";

const POSITIVE_MESSAGES = [
  "Purrfection",
  "Meow, that's impressive.",
  "You've earned a head boop.",
  "A meow-ster guess! Incredible.",
  "Nine lives, zero wrong answers.",
  "You belong with this song.",
  "Fearless guess.",
  "You're in your music era.",
  "Enchanting performance.",
  "This is why we can't have nice quizzes — you keep winning.",
  "You knew it all too well.",
  "No blank space in your knowledge.",
  "You need to calm down — you're too good.",
  "Cruel summer? More like cool guesser.",
  "It's me, hi, you're the winner, it's you.",
  "Are you sure you aren't Taylor?",
  "Elizabeth Taylor couldn't have done it better.",
  "Uncancellable.",
  "Take a bow, showgirl.",
  "Who's afraid of little old you? The quiz is.",
  "The prophecy was right about you.",
  "Pure alchemy.",
] as const;

const LYRICS_POSITIVE_MESSAGES = [
  "You read that like poetry.",
  "The pen is mightier — and you know every word.",
  "Straight from the page to your brain.",
  "You don't need a melody. The words are enough.",
  "That lyric never stood a chance.",
  "Reading between the lines? You're reading the actual lines.",
  "Ink in your veins.",
  "The manuscript reveals its secrets to you.",
  "No audiobook needed.",
  "Your lyric radar is flawless.",
  "Words are your instrument.",
  "Every syllable, accounted for.",
  "You could recite this catalogue in your sleep.",
  "Chapter and verse. You know it all.",
  "The songwriter would be impressed.",
  "The cat read the lyrics. The cat approves.",
  "Purrfectly quoted.",
  "Even nine lives aren't enough to learn all these lyrics. But you did it.",
  "A well-read cat is a powerful cat.",
  "Curiosity read the songbook.",
  "Cat-alogued every lyric.",
  "Feline poetry appreciation at its finest.",
  "The cat librarian nods in approval.",
  "Whiskers twitching with pride.",
  "A meow-sterpiece of lyric knowledge.",
  "Written in the stars — and you read them.",
  "The manuscript is safe with you.",
  "Guilty of being lyrically brilliant.",
  "Down bad for the right words.",
  "Take a bow, you lyric showgirl.",
] as const;

const NEXT_DELAY_MS = 2000;

/** Module-level shuffle bag state for sound messages */
let soundMessageQueue: string[] = [];
let lastSoundMessage = "";

/** Module-level shuffle bag state for lyrics messages */
let lyricsMessageQueue: string[] = [];
let lastLyricsMessage = "";

function drawFromBag(
  messages: readonly string[],
  queue: { current: string[] },
  last: { current: string },
): string {
  if (queue.current.length === 0) {
    queue.current = shuffle(messages);
    const end = queue.current.length - 1;
    if (queue.current[end] === last.current && queue.current.length > 1) {
      const swapIdx = Math.floor(Math.random() * end);
      [queue.current[end], queue.current[swapIdx]] = [
        queue.current[swapIdx],
        queue.current[end],
      ];
    }
  }
  const message = queue.current.pop()!;
  last.current = message;
  return message;
}

// Wrappers using module-level mutable refs
const soundQueueRef = { current: soundMessageQueue };
const soundLastRef = { current: lastSoundMessage };
const lyricsQueueRef = { current: lyricsMessageQueue };
const lyricsLastRef = { current: lastLyricsMessage };

export function drawNextMessage(quizType?: QuizType): string {
  if (quizType === "lyrics") {
    return drawFromBag(LYRICS_POSITIVE_MESSAGES, lyricsQueueRef, lyricsLastRef);
  }
  return drawFromBag(POSITIVE_MESSAGES, soundQueueRef, soundLastRef);
}

interface ResultFeedbackProps {
  readonly correct: boolean;
  readonly correctTrack: Track;
  readonly onNext: () => void;
  readonly quizType?: QuizType;
  readonly lyricsMode?: LyricsMode;
  readonly decoySourceSong?: string;
}

export function ResultFeedback({
  correct,
  correctTrack,
  onNext,
  quizType,
  lyricsMode,
  decoySourceSong,
}: ResultFeedbackProps) {
  const [ready, setReady] = useState(false);
  const [message] = useState(() => drawNextMessage(quizType));

  useEffect(() => {
    const timer = setTimeout(() => setReady(true), NEXT_DELAY_MS);
    return () => clearTimeout(timer);
  }, []);

  const renderIncorrectMessage = () => {
    if (quizType === "lyrics" && lyricsMode === "lyrics-or-lie") {
      if (decoySourceSong) {
        return (
          <p className="text-lg font-bold text-red-400">
            That&apos;s actually from &ldquo;{decoySourceSong}&rdquo;.
          </p>
        );
      }
      return (
        <p className="text-lg font-bold text-red-400">
          Nope &mdash; that one&apos;s real!
        </p>
      );
    }

    // Default: Name That Song / Sound mode
    return (
      <>
        <p className="text-lg font-bold text-red-400">
          It was &ldquo;{correctTrack.titleShort || correctTrack.title}&rdquo;
        </p>
        <p className="text-sm text-red-400/70">by {correctTrack.artist.name}</p>
      </>
    );
  };

  return (
    <div className="flex flex-col items-center gap-4">
      <motion.div
        initial={{ opacity: 0, scale: 0.9 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ type: "spring", stiffness: 300, damping: 30 }}
        className={
          correct
            ? "flex items-center gap-3 rounded-xl border border-green-500/20 bg-green-500/10 p-6"
            : "flex flex-col items-center gap-2 rounded-xl border border-red-500/20 bg-red-500/10 p-6"
        }
      >
        {correct ? (
          <>
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-green-500/20">
              <Check className="h-5 w-5 text-green-400" />
            </div>
            <p className="text-lg font-bold text-green-400">{message}</p>
          </>
        ) : (
          <>
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-red-500/20">
              <X className="h-5 w-5 text-red-400" />
            </div>
            {renderIncorrectMessage()}
          </>
        )}
      </motion.div>

      <button
        onClick={onNext}
        disabled={!ready}
        className="rounded-xl bg-primary px-8 py-3 font-medium text-primary-foreground transition-opacity"
        style={{
          opacity: ready ? 1 : 0.5,
          cursor: ready ? "pointer" : "not-allowed",
        }}
      >
        {ready ? "Next" : "Next..."}
      </button>
    </div>
  );
}
