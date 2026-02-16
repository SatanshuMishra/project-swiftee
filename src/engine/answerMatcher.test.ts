import { describe, it, expect } from "vitest";
import { normalizeTitle, checkAnswer } from "./answerMatcher";
import type { Track } from "../types";

function makeTrack(overrides: Partial<Track> = {}): Track {
  return {
    id: 1,
    title: "Enchanted (Taylor's Version)",
    titleShort: "Enchanted",
    duration: 319,
    preview: "https://example.com/preview.mp3",
    artist: { id: 12246, name: "Taylor Swift" },
    album: { id: 1, title: "Speak Now", coverMedium: null },
    ...overrides,
  };
}

describe("normalizeTitle", () => {
  it("lowercases", () => {
    expect(normalizeTitle("Enchanted")).toBe("enchanted");
  });

  it("removes parenthetical suffixes", () => {
    expect(normalizeTitle("Enchanted (Taylor's Version)")).toBe("enchanted");
    expect(
      normalizeTitle("All Too Well (Taylor's Version) (From The Vault)"),
    ).toBe("all too well");
  });

  it("strips punctuation", () => {
    expect(normalizeTitle("Don't Blame Me")).toBe("dont blame me");
    expect(normalizeTitle("...Ready For It?")).toBe("ready for it");
    expect(normalizeTitle("Anti-Hero")).toBe("anti hero");
  });

  it("collapses whitespace", () => {
    expect(normalizeTitle("  hello   world  ")).toBe("hello world");
  });
});

describe("checkAnswer", () => {
  describe("Easy/Medium (multiple choice by ID)", () => {
    it("matches correct track ID", () => {
      const track = makeTrack({ id: 42 });
      expect(checkAnswer(42, track, "easy")).toBe(true);
      expect(checkAnswer(42, track, "medium")).toBe(true);
    });

    it("rejects wrong track ID", () => {
      const track = makeTrack({ id: 42 });
      expect(checkAnswer(99, track, "easy")).toBe(false);
    });
  });

  describe("Hard (text input)", () => {
    it("matches exact title after normalization", () => {
      const track = makeTrack({ title: "Enchanted (Taylor's Version)" });
      expect(checkAnswer("enchanted", track, "hard")).toBe(true);
      expect(checkAnswer("Enchanted", track, "hard")).toBe(true);
    });

    it("matches with parentheticals removed", () => {
      const track = makeTrack({
        title: "All Too Well (Taylor's Version) (From The Vault)",
      });
      expect(checkAnswer("all too well", track, "hard")).toBe(true);
    });

    it("matches with punctuation removed", () => {
      const track = makeTrack({ title: "Don't Blame Me" });
      expect(checkAnswer("dont blame me", track, "hard")).toBe(true);
      expect(checkAnswer("don't blame me", track, "hard")).toBe(true);
    });

    it("allows typos via Levenshtein for long titles", () => {
      const track = makeTrack({ title: "Anti-Hero" });
      expect(checkAnswer("anit hero", track, "hard")).toBe(true); // dist 1
    });

    it("requires exact match for short titles", () => {
      const track = makeTrack({ title: "22" });
      expect(checkAnswer("22", track, "hard")).toBe(true);
      expect(checkAnswer("23", track, "hard")).toBe(false);
    });

    it("handles ...Ready For It?", () => {
      const track = makeTrack({ title: "...Ready For It?" });
      expect(checkAnswer("ready for it", track, "hard")).toBe(true);
    });
  });
});
