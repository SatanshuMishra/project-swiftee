import { describe, it, expect } from "vitest";
import {
  detectChorusRegions,
  extractSnippet,
  sanitiseSnippet,
  selectDecoyOrReal,
} from "./lyricProcessor";
import type { TrackLyrics } from "../types";

describe("detectChorusRegions", () => {
  it("detects repeated lines as chorus", () => {
    const lines = [
      "Verse line one",
      "Verse line two",
      "Chorus line A",
      "Chorus line B",
      "Verse line three",
      "Chorus line A",
      "Chorus line B",
      "Outro line",
    ];
    const regions = detectChorusRegions(lines);
    expect(regions.length).toBeGreaterThan(0);
  });

  it("returns empty for all unique lines", () => {
    const lines = ["Line one", "Line two", "Line three", "Line four"];
    const regions = detectChorusRegions(lines);
    expect(regions.length).toBe(0);
  });

  it("ignores single repeated lines (needs contiguous block of 2+)", () => {
    const lines = [
      "Unique one",
      "Repeated",
      "Unique two",
      "Repeated",
      "Unique three",
    ];
    const regions = detectChorusRegions(lines);
    // "Repeated" appears twice but never as a contiguous block of 2+
    expect(regions.length).toBe(0);
  });
});

describe("extractSnippet", () => {
  const lines = [
    "First line of song",
    "Second line",
    "Third line",
    "Fourth line",
    "Fifth line",
    "Sixth line",
    "Last line of song",
  ];

  it("extracts the requested number of lines", () => {
    const snippet = extractSnippet(lines, 3, false, false);
    expect(snippet.lines.length).toBe(3);
    expect(snippet.sourceLineIndices.length).toBe(3);
  });

  it("returns all lines when song has fewer than requested", () => {
    const short = ["Only line one", "Only line two"];
    const snippet = extractSnippet(short, 4, false, false);
    expect(snippet.lines.length).toBe(2);
  });

  it("extracts contiguous lines", () => {
    const snippet = extractSnippet(lines, 3, false, false);
    const indices = snippet.sourceLineIndices;
    for (let i = 1; i < indices.length; i++) {
      expect(indices[i] - indices[i - 1]).toBe(1);
    }
  });

  it("never extracts first line when possible", () => {
    // With enough lines, first line should be avoided
    const longLines = Array.from({ length: 20 }, (_, i) => `Line ${i + 1}`);
    let firstIncluded = false;
    for (let i = 0; i < 50; i++) {
      const snippet = extractSnippet(longLines, 3, false, false);
      if (snippet.sourceLineIndices.includes(0)) {
        firstIncluded = true;
        break;
      }
    }
    expect(firstIncluded).toBe(false);
  });
});

describe("sanitiseSnippet", () => {
  it("replaces song title with blanks", () => {
    const lines = ["I knew you were Enchanted to meet me"];
    const result = sanitiseSnippet(lines, "Enchanted");
    expect(result[0]).toContain("______");
    expect(result[0]).not.toContain("Enchanted");
  });

  it("handles case insensitive replacement", () => {
    const lines = ["she said cardigan on the floor"];
    const result = sanitiseSnippet(lines, "Cardigan");
    expect(result[0]).toContain("______");
  });

  it("does not modify lines without the title", () => {
    const lines = ["This line has nothing to do with it"];
    const result = sanitiseSnippet(lines, "Enchanted");
    expect(result[0]).toBe("This line has nothing to do with it");
  });

  it("strips parentheticals from title before matching", () => {
    const lines = ["enchanted by the moonlight"];
    const result = sanitiseSnippet(lines, "Enchanted (Taylor's Version)");
    expect(result[0]).toContain("______");
  });

  it("handles empty title gracefully", () => {
    const lines = ["Some lyric line"];
    const result = sanitiseSnippet(lines, "");
    expect(result[0]).toBe("Some lyric line");
  });
});

describe("selectDecoyOrReal", () => {
  const currentLines = [
    "Line one of current song with enough words here",
    "Line two of current song and some more content",
    "Line three with sufficient word count for testing",
    "Line four also has plenty of words for the filter",
  ];

  const decoyLyrics: TrackLyrics = {
    lrclibId: 999,
    lines: [
      "A different song line one with many words",
      "A different song line two with enough content",
      "Short",
      "Another long line from the different song here",
    ],
    lineCount: 4,
    sourceTrack: "Different Song",
    sourceAlbum: "Some Album",
  };

  it("returns a result with line and isReal flag", () => {
    const pool = new Map<number, TrackLyrics>([[999, decoyLyrics]]);
    const result = selectDecoyOrReal(currentLines, pool, "medium");
    expect(result.line).toBeTruthy();
    expect(typeof result.isReal).toBe("boolean");
  });

  it("includes sourceSong when fake", () => {
    const pool = new Map<number, TrackLyrics>([[999, decoyLyrics]]);
    // Run multiple times to get a fake result
    let foundFake = false;
    for (let i = 0; i < 50; i++) {
      const result = selectDecoyOrReal(currentLines, pool, "medium");
      if (!result.isReal) {
        expect(result.sourceSong).toBe("Different Song");
        foundFake = true;
        break;
      }
    }
    expect(foundFake).toBe(true);
  });

  it("falls back to real when decoy pool is empty", () => {
    const emptyPool = new Map<number, TrackLyrics>();
    const result = selectDecoyOrReal(currentLines, emptyPool, "medium");
    expect(result.isReal).toBe(true);
  });
});
