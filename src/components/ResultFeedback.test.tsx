import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, act } from "@testing-library/react";
import { ResultFeedback, drawNextMessage } from "./ResultFeedback";
import type { Track } from "../types";

function makeTrack(): Track {
  return {
    id: 1,
    title: "Love Story",
    titleShort: "Love Story",
    duration: 30,
    preview: "https://example.com/p.mp3",
    artist: { id: 12246, name: "Taylor Swift" },
    album: { id: 100, title: "Fearless", coverMedium: null },
  };
}

const POSITIVE_MESSAGE_PATTERN =
  /Purrfection|Meow, that's impressive\.|You've earned a head boop\.|A meow-ster guess! Incredible\.|Nine lives, zero wrong answers\.|You belong with this song\.|Fearless guess\.|You're in your music era\.|Enchanting performance\.|This is why we can't have nice quizzes|You knew it all too well\.|No blank space in your knowledge\.|You need to calm down|Cruel summer\? More like cool guesser\.|It's me, hi, you're the winner, it's you\.|Are you sure you aren't Taylor\?|Elizabeth Taylor couldn't have done it better\.|Uncancellable\.|Take a bow, showgirl\.|Who's afraid of little old you\?|The prophecy was right about you\.|Pure alchemy\./;

describe("ResultFeedback", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("renders Next button disabled initially with 'Next...' text", () => {
    const onNext = vi.fn();
    render(
      <ResultFeedback
        correct={true}
        correctTrack={makeTrack()}
        onNext={onNext}
      />,
    );

    const button = screen.getByRole("button", { name: "Next..." });
    expect(button).toBeDisabled();
  });

  it("enables Next button after 2 seconds", () => {
    const onNext = vi.fn();
    render(
      <ResultFeedback
        correct={true}
        correctTrack={makeTrack()}
        onNext={onNext}
      />,
    );

    act(() => {
      vi.advanceTimersByTime(2000);
    });

    const button = screen.getByRole("button", { name: "Next" });
    expect(button).toBeEnabled();
  });

  it("shows correct track info on incorrect answer", () => {
    const onNext = vi.fn();
    const track = makeTrack();
    render(
      <ResultFeedback correct={false} correctTrack={track} onNext={onNext} />,
    );

    expect(screen.getByText(/Love Story/)).toBeInTheDocument();
    expect(screen.getByText(/Taylor Swift/)).toBeInTheDocument();
  });

  it("shows a positive message on correct answer", () => {
    const onNext = vi.fn();
    render(
      <ResultFeedback
        correct={true}
        correctTrack={makeTrack()}
        onNext={onNext}
      />,
    );

    const resultArea = screen.getByText(POSITIVE_MESSAGE_PATTERN);
    expect(resultArea).toBeInTheDocument();
  });

  it("does not call onNext when button is clicked while disabled", () => {
    const onNext = vi.fn();
    render(
      <ResultFeedback
        correct={true}
        correctTrack={makeTrack()}
        onNext={onNext}
      />,
    );

    const button = screen.getByRole("button", { name: "Next..." });
    button.click();
    expect(onNext).not.toHaveBeenCalled();
  });

  it("does not change the positive message after the 2s re-render", () => {
    const onNext = vi.fn();
    render(
      <ResultFeedback
        correct={true}
        correctTrack={makeTrack()}
        onNext={onNext}
      />,
    );

    const messageBefore = screen.getByText(
      POSITIVE_MESSAGE_PATTERN,
    ).textContent;

    act(() => {
      vi.advanceTimersByTime(2000);
    });

    const messageAfter = screen.getByText(POSITIVE_MESSAGE_PATTERN).textContent;
    expect(messageAfter).toBe(messageBefore);
  });
});

describe("drawNextMessage", () => {
  it("never returns the same message twice in a row", () => {
    let prev = drawNextMessage();
    for (let i = 0; i < 100; i++) {
      const next = drawNextMessage();
      expect(next).not.toBe(prev);
      prev = next;
    }
  });

  it("cycles through all 22 messages within two full cycles", () => {
    const seen = new Set<string>();
    // Draw 44 messages (2 full cycles) to account for any partially
    // consumed queue from prior tests sharing module-level state.
    for (let i = 0; i < 44; i++) {
      seen.add(drawNextMessage());
    }
    expect(seen.size).toBe(22);
  });
});
