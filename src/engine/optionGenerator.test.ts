import { describe, it, expect } from "vitest";
import { generateOptions } from "./optionGenerator";
import type { Track } from "../types";

function makeTrack(id: number, title: string): Track {
  return {
    id,
    title,
    titleShort: title,
    duration: 30,
    preview: "https://example.com/preview.mp3",
    artist: { id: 12246, name: "Taylor Swift" },
    album: { id: 1, title: "Test Album", coverMedium: null },
  };
}

describe("generateOptions", () => {
  it("includes the correct track", () => {
    const correct = makeTrack(1, "Enchanted");
    const pool = [
      correct,
      makeTrack(2, "Sparks Fly"),
      makeTrack(3, "Back to December"),
      makeTrack(4, "Haunted"),
      makeTrack(5, "Last Kiss"),
    ];

    const options = generateOptions(correct, pool);
    expect(options.some((t) => t.id === correct.id)).toBe(true);
  });

  it("returns 4 options when pool is large enough", () => {
    const correct = makeTrack(1, "Enchanted");
    const pool = [
      correct,
      makeTrack(2, "Sparks Fly"),
      makeTrack(3, "Back to December"),
      makeTrack(4, "Haunted"),
      makeTrack(5, "Last Kiss"),
    ];

    const options = generateOptions(correct, pool);
    expect(options.length).toBe(4);
  });

  it("de-duplicates by normalized title", () => {
    const correct = makeTrack(1, "Enchanted");
    const pool = [
      correct,
      makeTrack(2, "Enchanted (Taylor's Version)"), // same after normalization
      makeTrack(3, "Sparks Fly"),
      makeTrack(4, "Back to December"),
      makeTrack(5, "Haunted"),
    ];

    const options = generateOptions(correct, pool);
    // Should not include "Enchanted (Taylor's Version)" as a wrong option
    const enchantedCount = options.filter(
      (t) => t.titleShort === "Enchanted" || t.title.startsWith("Enchanted"),
    ).length;
    expect(enchantedCount).toBe(1);
  });

  it("handles small pool gracefully", () => {
    const correct = makeTrack(1, "Enchanted");
    const pool = [correct, makeTrack(2, "Sparks Fly")];

    const options = generateOptions(correct, pool);
    expect(options.length).toBe(2);
    expect(options.some((t) => t.id === 1)).toBe(true);
    expect(options.some((t) => t.id === 2)).toBe(true);
  });
});
