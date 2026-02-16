import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  parseLrc,
  estimatePreviewOffset,
  findTitleDangerZones,
  fetchDangerZones,
  clearDangerZoneCache,
} from "./lrclib";
import type { LrcLine } from "./lrclib";

describe("parseLrc", () => {
  it("parses standard LRC lines with centiseconds", () => {
    const raw = "[00:12.34] Hello world\n[01:05.67] Second line";
    const result = parseLrc(raw);
    expect(result).toHaveLength(2);
    expect(result[0].timeSeconds).toBeCloseTo(12.34, 1);
    expect(result[0].text).toBe("Hello world");
    expect(result[1].timeSeconds).toBeCloseTo(65.67, 1);
    expect(result[1].text).toBe("Second line");
  });

  it("parses lines with two-digit centiseconds", () => {
    const raw = "[00:27.93] Some lyric text";
    const result = parseLrc(raw);
    expect(result).toHaveLength(1);
    expect(result[0].timeSeconds).toBeCloseTo(27.93, 1);
  });

  it("parses lines without centiseconds", () => {
    const raw = "[02:30] No decimals here";
    const result = parseLrc(raw);
    expect(result).toHaveLength(1);
    expect(result[0].timeSeconds).toBe(150);
  });

  it("skips empty text lines", () => {
    const raw = "[00:00.00]   \n[00:05.00] Real line";
    const result = parseLrc(raw);
    expect(result).toHaveLength(1);
    expect(result[0].text).toBe("Real line");
  });

  it("sorts lines by time", () => {
    const raw = "[01:00.00] Later\n[00:30.00] Earlier";
    const result = parseLrc(raw);
    expect(result[0].text).toBe("Earlier");
    expect(result[1].text).toBe("Later");
  });

  it("handles empty string", () => {
    expect(parseLrc("")).toHaveLength(0);
  });

  it("handles three-digit milliseconds", () => {
    const raw = "[00:10.123] Three digit";
    const result = parseLrc(raw);
    expect(result[0].timeSeconds).toBeCloseTo(10.123, 2);
  });

  it("handles single-digit minutes", () => {
    const raw = "[3:45.00] Single digit minute";
    const result = parseLrc(raw);
    expect(result[0].timeSeconds).toBeCloseTo(225, 0);
  });
});

describe("estimatePreviewOffset", () => {
  it("returns 30% of duration when fewer than 4 lines", () => {
    const lines: LrcLine[] = [
      { timeSeconds: 10, text: "Line one" },
      { timeSeconds: 20, text: "Line two" },
    ];
    expect(estimatePreviewOffset(lines, 200)).toBe(60);
  });

  it("returns 30% when no repeated lines found", () => {
    const lines: LrcLine[] = [
      { timeSeconds: 10, text: "Unique line one here" },
      { timeSeconds: 20, text: "Unique line two here" },
      { timeSeconds: 30, text: "Unique line three here" },
      { timeSeconds: 40, text: "Unique line four here" },
    ];
    expect(estimatePreviewOffset(lines, 200)).toBe(60);
  });

  it("finds first repeated line as chorus start", () => {
    const lines: LrcLine[] = [
      { timeSeconds: 10, text: "Verse one is here now" },
      { timeSeconds: 20, text: "This is the chorus line" },
      { timeSeconds: 30, text: "Verse two is here now" },
      { timeSeconds: 40, text: "This is the chorus line" },
    ];
    // First occurrence of repeated line is at 20s, minus 2 = 18
    expect(estimatePreviewOffset(lines, 200)).toBe(18);
  });

  it("clamps offset to 0 if chorus is very early", () => {
    const lines: LrcLine[] = [
      { timeSeconds: 1, text: "Opening chorus repeated" },
      { timeSeconds: 5, text: "Some verse lyric here" },
      { timeSeconds: 10, text: "Another verse line here" },
      { timeSeconds: 15, text: "Opening chorus repeated" },
    ];
    expect(estimatePreviewOffset(lines, 200)).toBe(0);
  });

  it("skips short lines when detecting chorus", () => {
    const lines: LrcLine[] = [
      { timeSeconds: 10, text: "Oh oh" },
      { timeSeconds: 20, text: "A longer meaningful verse" },
      { timeSeconds: 30, text: "Oh oh" },
      { timeSeconds: 40, text: "Another meaningful verse" },
    ];
    // "Oh oh" is too short (<10 chars) — should fall back to 30%
    expect(estimatePreviewOffset(lines, 200)).toBe(60);
  });
});

describe("findTitleDangerZones", () => {
  const makeLines = (
    entries: ReadonlyArray<readonly [number, string]>,
  ): readonly LrcLine[] =>
    entries.map(([timeSeconds, text]) => ({ timeSeconds, text }));

  it("creates danger zones for lines containing title words", () => {
    const lines = makeLines([
      [65, "Verse words here"],
      [70, "I am enchanted to meet you"],
      [75, "More lyrics follow"],
    ]);
    const zones = findTitleDangerZones(lines, "Enchanted", "Enchanted", 60);
    expect(zones.length).toBeGreaterThan(0);
    // The matching line is at 70s absolute = 10s relative to preview
    expect(zones[0].start).toBeCloseTo(8.5, 1); // 10 - 1.5
    expect(zones[0].end).toBeCloseTo(11.5, 1); // 10 + 1.5
  });

  it("returns empty when no title words match", () => {
    const lines = makeLines([
      [65, "Some random words"],
      [70, "Nothing related here"],
    ]);
    const zones = findTitleDangerZones(lines, "Enchanted", "Enchanted", 60);
    expect(zones).toHaveLength(0);
  });

  it("ignores lines outside the preview window", () => {
    const lines = makeLines([
      [10, "Enchanted early on"], // before preview (offset=60)
      [100, "Enchanted way late"], // after preview (60+30=90)
    ]);
    const zones = findTitleDangerZones(lines, "Enchanted", "Enchanted", 60);
    expect(zones).toHaveLength(0);
  });

  it("merges overlapping danger zones", () => {
    const lines = makeLines([
      [70, "Anti hero in the mirror"],
      [71, "I'm the anti hero now"],
    ]);
    // Both lines within 2s of each other, zones should merge
    const zones = findTitleDangerZones(lines, "Anti-Hero", "Anti-Hero", 60);
    expect(zones).toHaveLength(1);
  });

  it("clamps zones to preview boundaries (0-30)", () => {
    const lines = makeLines([[60.5, "Enchanted right at start"]]);
    const zones = findTitleDangerZones(lines, "Enchanted", "Enchanted", 60);
    expect(zones).toHaveLength(1);
    expect(zones[0].start).toBe(0); // clamped from -1
  });

  it("filters stop words from title matching", () => {
    // "All The" are stop words — only "Stars" should count
    const lines = makeLines([[65, "Look at all the stars tonight"]]);
    const zones = findTitleDangerZones(
      lines,
      "All The Stars",
      "All The Stars",
      60,
    );
    // "stars" matches, so should create a zone
    expect(zones.length).toBeGreaterThan(0);
  });

  it("uses titleShort when it has more meaningful words", () => {
    const lines = makeLines([[70, "I keep enchanted feelings"]]);
    const zones = findTitleDangerZones(
      lines,
      "Enchanted (Taylor's Version)",
      "Enchanted",
      60,
    );
    expect(zones.length).toBeGreaterThan(0);
  });

  it("handles multi-word title matching with 60% threshold", () => {
    const lines = makeLines([
      [70, "We are never ever getting back together now"],
    ]);
    const zones = findTitleDangerZones(
      lines,
      "We Are Never Getting Back Together",
      "We Are Never Getting Back Together",
      60,
    );
    // After removing stop words: "never", "getting", "back", "together"
    // Line contains all of them → match
    expect(zones.length).toBeGreaterThan(0);
  });
});

describe("fetchDangerZones", () => {
  beforeEach(() => {
    clearDangerZoneCache();
    vi.restoreAllMocks();
  });

  afterEach(() => {
    clearDangerZoneCache();
  });

  it("returns cached result on second call", async () => {
    const fetchSpy = vi.fn().mockResolvedValueOnce({
      ok: true,
      json: () =>
        Promise.resolve({
          syncedLyrics: "[00:10.00] Some lyrics here\n[00:20.00] More lyrics",
        }),
    });
    vi.stubGlobal("fetch", fetchSpy);

    await fetchDangerZones("Enchanted", "Taylor Swift", "Enchanted", 300);
    await fetchDangerZones("Enchanted", "Taylor Swift", "Enchanted", 300);

    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it("returns empty array on non-ok response", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValueOnce({ ok: false }));

    const result = await fetchDangerZones(
      "Unknown Song",
      "Unknown Artist",
      "Unknown Song",
      200,
    );
    expect(result).toEqual([]);
  });

  it("returns empty array when syncedLyrics is null", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ syncedLyrics: null }),
      }),
    );

    const result = await fetchDangerZones(
      "Some Song",
      "Some Artist",
      "Some Song",
      200,
    );
    expect(result).toEqual([]);
  });

  it("returns empty array on network error", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockRejectedValueOnce(new Error("Network error")),
    );

    const result = await fetchDangerZones(
      "Test Song",
      "Test Artist",
      "Test Song",
      200,
    );
    expect(result).toEqual([]);
  });

  it("returns empty array on abort (timeout)", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockRejectedValueOnce(new DOMException("Aborted", "AbortError")),
    );

    const result = await fetchDangerZones(
      "Slow Song",
      "Slow Artist",
      "Slow Song",
      200,
    );
    expect(result).toEqual([]);
  });

  it("builds correct URL with query params", async () => {
    const fetchSpy = vi.fn().mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve({ syncedLyrics: null }),
    });
    vi.stubGlobal("fetch", fetchSpy);

    await fetchDangerZones("Anti-Hero", "Taylor Swift", "Anti-Hero", 200);

    const calledUrl = fetchSpy.mock.calls[0][0] as string;
    expect(calledUrl).toContain("lrclib.net/api/get?");
    expect(calledUrl).toContain("artist_name=Taylor+Swift");
    expect(calledUrl).toContain("track_name=Anti-Hero");
  });

  it("uses AbortController signal", async () => {
    const fetchSpy = vi.fn().mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve({ syncedLyrics: null }),
    });
    vi.stubGlobal("fetch", fetchSpy);

    await fetchDangerZones("Test", "Artist", "Test", 200);

    const options = fetchSpy.mock.calls[0][1] as RequestInit;
    expect(options.signal).toBeInstanceOf(AbortSignal);
  });
});
