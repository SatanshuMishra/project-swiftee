import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, act } from "@testing-library/react";
import { ResultFeedback } from "./ResultFeedback";
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

    // Should show one of the positive messages (any text in the result area)
    const resultArea = screen.getByText(
      /Nice one!|You got it!|Nailed it!|Perfect!|Spot on!|Impressive!|Well done!|Crushed it!|Too easy!|Swiftie certified!/,
    );
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
});
