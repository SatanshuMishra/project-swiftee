import { describe, it, expect } from "vitest";
import { createTrackPool, drawNextTrack } from "./gameEngine";
import type { Track } from "../types";

function makeTrack(id: number, preview = "https://example.com/p.mp3"): Track {
  return {
    id,
    title: `Track ${id}`,
    titleShort: `Track ${id}`,
    duration: 30,
    preview,
    artist: { id: 12246, name: "Taylor Swift" },
    album: { id: 1, title: "Album", coverMedium: null },
  };
}

describe("createTrackPool", () => {
  it("filters out tracks without preview URLs", () => {
    const tracks = [makeTrack(1), makeTrack(2, ""), makeTrack(3)];
    const pool = createTrackPool(tracks);
    expect(pool.length).toBe(2);
    expect(pool.every((t) => t.preview.length > 0)).toBe(true);
  });

  it("shuffles the pool", () => {
    const tracks = Array.from({ length: 20 }, (_, i) => makeTrack(i));
    const pool = createTrackPool(tracks);
    expect(pool.length).toBe(20);
    // We just check it's a valid permutation
    const ids = pool.map((t) => t.id).sort((a, b) => a - b);
    expect(ids).toEqual(Array.from({ length: 20 }, (_, i) => i));
  });
});

describe("drawNextTrack", () => {
  it("draws from pool and returns remainder", () => {
    const tracks = [makeTrack(1), makeTrack(2), makeTrack(3)];
    const { track, remaining } = drawNextTrack(tracks, tracks);
    expect(track.id).toBe(1);
    expect(remaining.length).toBe(2);
  });

  it("reshuffles when pool is empty", () => {
    const allTracks = [makeTrack(1), makeTrack(2)];
    const { track, remaining } = drawNextTrack([], allTracks);
    expect(track).toBeDefined();
    expect(remaining.length).toBe(1);
  });
});
