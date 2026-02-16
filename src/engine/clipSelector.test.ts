import { describe, it, expect } from "vitest";
import {
  computeRmsProfile,
  computeEnergyScore,
  computeCenterBias,
  computeDangerZonePenalty,
  selectClipStart,
  selectClipStartWithFallback,
} from "./clipSelector";
import type { DangerZone } from "../lib/lrclib";

// --- Helpers ---

function makeMockAudioBuffer(
  duration: number,
  sampleRate: number = 44100,
  channelDataOverride?: Float32Array,
): AudioBuffer {
  const length = Math.floor(duration * sampleRate);
  const channelData =
    channelDataOverride ?? new Float32Array(length).fill(0.5);

  return {
    duration,
    sampleRate,
    length,
    numberOfChannels: 1,
    getChannelData: (_channel: number) => channelData,
    copyFromChannel: () => {},
    copyToChannel: () => {},
  } as unknown as AudioBuffer;
}

// --- computeRmsProfile ---

describe("computeRmsProfile", () => {
  it("computes correct RMS for constant signal", () => {
    const data = new Float32Array(44100).fill(0.5); // 1 second at 44100Hz
    const profile = computeRmsProfile(data, 44100, 0.25);
    // 4 frames of 0.25s each
    expect(profile).toHaveLength(4);
    // RMS of constant 0.5 = 0.5
    for (const rms of profile) {
      expect(rms).toBeCloseTo(0.5, 3);
    }
  });

  it("computes correct RMS for silence", () => {
    const data = new Float32Array(44100).fill(0);
    const profile = computeRmsProfile(data, 44100, 0.25);
    expect(profile).toHaveLength(4);
    for (const rms of profile) {
      expect(rms).toBe(0);
    }
  });

  it("handles varying signal levels", () => {
    const sampleRate = 1000;
    const data = new Float32Array(2000);
    // First second: amplitude 0.2
    for (let i = 0; i < 1000; i++) data[i] = 0.2;
    // Second second: amplitude 0.8
    for (let i = 1000; i < 2000; i++) data[i] = 0.8;

    const profile = computeRmsProfile(data, sampleRate, 0.5);
    expect(profile).toHaveLength(4);
    // First two frames: RMS ~0.2
    expect(profile[0]).toBeCloseTo(0.2, 2);
    expect(profile[1]).toBeCloseTo(0.2, 2);
    // Last two frames: RMS ~0.8
    expect(profile[2]).toBeCloseTo(0.8, 2);
    expect(profile[3]).toBeCloseTo(0.8, 2);
  });

  it("returns empty array for zero frame size", () => {
    const data = new Float32Array(100).fill(0.5);
    expect(computeRmsProfile(data, 44100, 0)).toEqual([]);
  });

  it("drops partial frames at the end", () => {
    // 1.5 seconds of data at 1000 Hz with 1s frames
    const data = new Float32Array(1500).fill(0.3);
    const profile = computeRmsProfile(data, 1000, 1.0);
    expect(profile).toHaveLength(1); // only 1 full frame
  });
});

// --- computeEnergyScore ---

describe("computeEnergyScore", () => {
  it("returns 1 when globalMaxRms is 0", () => {
    expect(computeEnergyScore([], 0, 0.25, 0, 10)).toBe(1);
  });

  it("returns 1 when profile is empty", () => {
    expect(computeEnergyScore([], 0.5, 0.25, 0, 10)).toBe(1);
  });

  it("returns 0 for the loudest window", () => {
    // 4 frames, each 0.25s — the whole thing is one uniform level
    const profile = [0.5, 0.5, 0.5, 0.5];
    const score = computeEnergyScore(profile, 0.5, 0.25, 0, 1);
    expect(score).toBeCloseTo(0, 2);
  });

  it("returns high score for quiet window", () => {
    // 8 frames: first 4 quiet, last 4 loud
    const profile = [0.1, 0.1, 0.1, 0.1, 0.9, 0.9, 0.9, 0.9];
    const score = computeEnergyScore(profile, 0.9, 0.25, 0, 1);
    // maxInWindow = 0.1, score = 1 - 0.1/0.9 ≈ 0.889
    expect(score).toBeCloseTo(0.889, 2);
  });

  it("handles startFrame >= endFrame", () => {
    const profile = [0.5];
    expect(computeEnergyScore(profile, 0.5, 0.25, 10, 1)).toBe(1);
  });
});

// --- computeCenterBias ---

describe("computeCenterBias", () => {
  it("returns 1 at the center of the buffer", () => {
    // Buffer 30s, window 10s, start at 10 → center of window at 15 = buffer center
    expect(computeCenterBias(10, 30, 10)).toBeCloseTo(1, 5);
  });

  it("returns lower value at edges", () => {
    const centerScore = computeCenterBias(10, 30, 10);
    const edgeScore = computeCenterBias(0, 30, 10);
    expect(edgeScore).toBeLessThan(centerScore);
  });

  it("is symmetric around center", () => {
    const left = computeCenterBias(2, 30, 10);
    const right = computeCenterBias(18, 30, 10);
    expect(left).toBeCloseTo(right, 5);
  });

  it("returns 1 when sigma is 0 (zero duration)", () => {
    expect(computeCenterBias(0, 0, 0)).toBe(1);
  });

  it("returns value between 0 and 1", () => {
    for (let s = 0; s <= 20; s += 2) {
      const score = computeCenterBias(s, 30, 10);
      expect(score).toBeGreaterThan(0);
      expect(score).toBeLessThanOrEqual(1);
    }
  });
});

// --- computeDangerZonePenalty ---

describe("computeDangerZonePenalty", () => {
  it("returns 1 when no danger zones", () => {
    expect(computeDangerZonePenalty(5, 10, [])).toBe(1);
  });

  it("returns 0 for heavy overlap (>=2s)", () => {
    const zones: DangerZone[] = [{ start: 5, end: 10 }];
    // Window 3-13 overlaps zone 5-10 by 5s
    expect(computeDangerZonePenalty(3, 10, zones)).toBe(0);
  });

  it("returns 0.3 for light overlap (<2s)", () => {
    const zones: DangerZone[] = [{ start: 12, end: 14 }];
    // Window 5-15 overlaps zone 12-14 by 2s → exactly 2, so 0
    expect(computeDangerZonePenalty(5, 10, zones)).toBe(0);

    // Window 5-15 overlaps zone 13.5-14.5 by 1s → 0.3
    const zones2: DangerZone[] = [{ start: 13.5, end: 14.5 }];
    expect(computeDangerZonePenalty(5, 10, zones2)).toBe(0.3);
  });

  it("returns 1 when window doesn't overlap any zone", () => {
    const zones: DangerZone[] = [{ start: 20, end: 25 }];
    expect(computeDangerZonePenalty(0, 10, zones)).toBe(1);
  });

  it("accumulates overlap across multiple zones", () => {
    const zones: DangerZone[] = [
      { start: 2, end: 3 },   // 1s overlap
      { start: 7, end: 8.5 }, // 1.5s overlap → total 2.5s
    ];
    // Window 0-10 overlaps both: total 2.5s → 0
    expect(computeDangerZonePenalty(0, 10, zones)).toBe(0);
  });
});

// --- selectClipStart ---

describe("selectClipStart", () => {
  it("returns 0 for buffer shorter than slice duration", () => {
    const buffer = makeMockAudioBuffer(5);
    const start = selectClipStart({ audioBuffer: buffer, dangerZones: [] });
    expect(start).toBe(0);
  });

  it("avoids loud sections", () => {
    const sampleRate = 1000;
    const duration = 30;
    const data = new Float32Array(sampleRate * duration);

    // Make seconds 0-10 quiet and 10-20 loud
    for (let i = 0; i < sampleRate * 10; i++) data[i] = 0.1;
    for (let i = sampleRate * 10; i < sampleRate * 20; i++) data[i] = 0.9;
    for (let i = sampleRate * 20; i < sampleRate * 30; i++) data[i] = 0.3;

    const buffer = makeMockAudioBuffer(duration, sampleRate, data);
    const start = selectClipStart({ audioBuffer: buffer, dangerZones: [] });

    // Should prefer starting at 0 (quiet) over 10 (loud), though center bias
    // will shift slightly. Should not be in the loud 10-20 range.
    expect(start).toBeLessThan(10);
  });

  it("avoids danger zones", () => {
    const sampleRate = 1000;
    const duration = 30;
    // Uniform signal so energy score is equal everywhere
    const data = new Float32Array(sampleRate * duration).fill(0.5);
    const buffer = makeMockAudioBuffer(duration, sampleRate, data);

    const dangerZones: DangerZone[] = [
      { start: 8, end: 15 }, // center of buffer is dangerous
    ];

    const start = selectClipStart({ audioBuffer: buffer, dangerZones });

    // Window starting at 5 would overlap danger zone 8-15 by 5s → should be penalized
    // Should pick a start that avoids this zone
    const windowEnd = start + 10;
    const overlapStart = Math.max(start, 8);
    const overlapEnd = Math.min(windowEnd, 15);
    const overlap = Math.max(0, overlapEnd - overlapStart);
    // Allow some overlap but it shouldn't be the maximum-overlap position
    expect(overlap).toBeLessThan(7);
  });

  it("returns a number within valid range", () => {
    const buffer = makeMockAudioBuffer(30);
    const start = selectClipStart({ audioBuffer: buffer, dangerZones: [] });
    expect(start).toBeGreaterThanOrEqual(0);
    expect(start).toBeLessThanOrEqual(20); // 30 - 10
  });

  it("handles uniform silence gracefully", () => {
    const data = new Float32Array(30000).fill(0);
    const buffer = makeMockAudioBuffer(30, 1000, data);
    const start = selectClipStart({ audioBuffer: buffer, dangerZones: [] });
    // Should still return a valid position (center-biased)
    expect(start).toBeGreaterThanOrEqual(0);
    expect(start).toBeLessThanOrEqual(20);
  });
});

// --- selectClipStartWithFallback ---

describe("selectClipStartWithFallback", () => {
  it("returns valid position for normal buffer", () => {
    const buffer = makeMockAudioBuffer(30);
    const start = selectClipStartWithFallback(buffer, []);
    expect(start).toBeGreaterThanOrEqual(0);
    expect(start).toBeLessThanOrEqual(20);
  });

  it("falls back to random on error", () => {
    // Create a buffer that will cause getChannelData to throw
    const buffer = {
      duration: 30,
      sampleRate: 44100,
      length: 30 * 44100,
      numberOfChannels: 1,
      getChannelData: () => {
        throw new Error("Simulated failure");
      },
    } as unknown as AudioBuffer;

    const start = selectClipStartWithFallback(buffer, []);
    expect(start).toBeGreaterThanOrEqual(0);
    expect(start).toBeLessThanOrEqual(20);
  });

  it("returns 0 for short buffer", () => {
    const buffer = makeMockAudioBuffer(5);
    const start = selectClipStartWithFallback(buffer, []);
    expect(start).toBe(0);
  });
});
