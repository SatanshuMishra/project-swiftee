import { useEffect, useState } from "react";
import { motion } from "motion/react";
import { Check, X } from "lucide-react";
import type { Track } from "../types";

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

const NEXT_DELAY_MS = 2000;

/**
 * Fisher-Yates shuffle (returns new array, does not mutate).
 */
function shuffle<T>(arr: readonly T[]): T[] {
  const result = [...arr];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

/** Module-level shuffle bag state */
let messageQueue: string[] = [];
let lastMessage = "";

/**
 * Draw the next message from a shuffle bag.
 * Every message is shown before any can repeat.
 * At cycle boundaries, ensures the last message of the previous cycle
 * is not the first message of the new cycle.
 */
export function drawNextMessage(): string {
  if (messageQueue.length === 0) {
    messageQueue = shuffle(POSITIVE_MESSAGES);
    const last = messageQueue.length - 1;
    if (messageQueue[last] === lastMessage && messageQueue.length > 1) {
      const swapIdx = Math.floor(Math.random() * last);
      [messageQueue[last], messageQueue[swapIdx]] = [
        messageQueue[swapIdx],
        messageQueue[last],
      ];
    }
  }
  const message = messageQueue.pop()!;
  lastMessage = message;
  return message;
}

interface ResultFeedbackProps {
  readonly correct: boolean;
  readonly correctTrack: Track;
  readonly onNext: () => void;
}

export function ResultFeedback({
  correct,
  correctTrack,
  onNext,
}: ResultFeedbackProps) {
  const [ready, setReady] = useState(false);
  const [message] = useState(drawNextMessage);

  useEffect(() => {
    const timer = setTimeout(() => setReady(true), NEXT_DELAY_MS);
    return () => clearTimeout(timer);
  }, []);

  return (
    <div className="flex flex-col items-center gap-4">
      <motion.div
        initial={{ opacity: 0, scale: 0.9 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ type: "spring", stiffness: 300, damping: 20 }}
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
            <p className="text-lg font-bold text-red-400">
              It was &ldquo;{correctTrack.titleShort || correctTrack.title}
              &rdquo;
            </p>
            <p className="text-sm text-red-400/70">
              by {correctTrack.artist.name}
            </p>
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
