import { describe, it, expect } from "vitest";
import {
  getRelistenSlice,
  FULL_CLIP_THRESHOLD,
  FIRST_ESCALATION_RELISTEN,
} from "./relistenSchedule";

const SMART_START = 5;
const BUFFER_DURATION = 30;

describe("getRelistenSlice", () => {
  // ── Free replays (same 10s) ───────────────────────────────────────

  it("stage 1: 10s from smart start", () => {
    expect(getRelistenSlice(1, SMART_START, BUFFER_DURATION)).toEqual({
      offset: 5,
      duration: 10,
    });
  });

  it("stage 2: 10s from smart start", () => {
    expect(getRelistenSlice(2, SMART_START, BUFFER_DURATION)).toEqual({
      offset: 5,
      duration: 10,
    });
  });

  // ── First escalation (15s) ────────────────────────────────────────

  it("stage 3: 15s from smart start", () => {
    expect(getRelistenSlice(3, SMART_START, BUFFER_DURATION)).toEqual({
      offset: 5,
      duration: 15,
    });
  });

  it("stage 4: 15s from smart start", () => {
    expect(getRelistenSlice(4, SMART_START, BUFFER_DURATION)).toEqual({
      offset: 5,
      duration: 15,
    });
  });

  // ── Second escalation (20s) ───────────────────────────────────────

  it("stage 5: 20s from smart start", () => {
    expect(getRelistenSlice(5, SMART_START, BUFFER_DURATION)).toEqual({
      offset: 5,
      duration: 20,
    });
  });

  it("stage 6: 20s from smart start", () => {
    expect(getRelistenSlice(6, SMART_START, BUFFER_DURATION)).toEqual({
      offset: 5,
      duration: 20,
    });
  });

  // ── Full clip ─────────────────────────────────────────────────────

  it("stage 7: full buffer from position 0", () => {
    expect(getRelistenSlice(7, SMART_START, BUFFER_DURATION)).toEqual({
      offset: 0,
      duration: 30,
    });
  });

  it("stage 10: full buffer (high stage)", () => {
    expect(getRelistenSlice(10, SMART_START, BUFFER_DURATION)).toEqual({
      offset: 0,
      duration: 30,
    });
  });

  // ── Duration clamping ─────────────────────────────────────────────

  it("clamps duration when buffer is shorter than requested", () => {
    // smartStart=25, buffer=30 → only 5s remaining, stage 3 wants 15s
    expect(getRelistenSlice(3, 25, 30)).toEqual({
      offset: 25,
      duration: 5,
    });
  });

  it("clamps 20s request near end of buffer", () => {
    // smartStart=15, buffer=30 → only 15s remaining, stage 5 wants 20s
    expect(getRelistenSlice(5, 15, 30)).toEqual({
      offset: 15,
      duration: 15,
    });
  });

  // ── Edge cases ────────────────────────────────────────────────────

  it("stage 0: falls through to full clip", () => {
    expect(getRelistenSlice(0, SMART_START, BUFFER_DURATION)).toEqual({
      offset: 0,
      duration: 30,
    });
  });

  it("negative stage: falls through to full clip", () => {
    expect(getRelistenSlice(-1, SMART_START, BUFFER_DURATION)).toEqual({
      offset: 0,
      duration: 30,
    });
  });

  it("smartStart at 0", () => {
    expect(getRelistenSlice(1, 0, 30)).toEqual({
      offset: 0,
      duration: 10,
    });
  });

  it("very short buffer", () => {
    expect(getRelistenSlice(1, 0, 5)).toEqual({
      offset: 0,
      duration: 5,
    });
  });
});

describe("constants", () => {
  it("FULL_CLIP_THRESHOLD equals 7", () => {
    expect(FULL_CLIP_THRESHOLD).toBe(7);
  });

  it("FIRST_ESCALATION_RELISTEN equals 3", () => {
    expect(FIRST_ESCALATION_RELISTEN).toBe(3);
  });

  it("FULL_CLIP_THRESHOLD aligns with schedule: stage at threshold returns full clip", () => {
    const result = getRelistenSlice(FULL_CLIP_THRESHOLD, 5, 30);
    expect(result.offset).toBe(0);
    expect(result.duration).toBe(30);
  });

  it("stage before FULL_CLIP_THRESHOLD is NOT full clip", () => {
    const result = getRelistenSlice(FULL_CLIP_THRESHOLD - 1, 5, 30);
    expect(result.offset).toBe(5);
    expect(result.duration).toBeLessThan(30);
  });

  it("FIRST_ESCALATION_RELISTEN aligns with schedule: stage at threshold is > 10s", () => {
    const result = getRelistenSlice(FIRST_ESCALATION_RELISTEN, 0, 30);
    expect(result.duration).toBeGreaterThan(10);
  });

  it("stage before FIRST_ESCALATION_RELISTEN is still 10s", () => {
    const result = getRelistenSlice(FIRST_ESCALATION_RELISTEN - 1, 0, 30);
    expect(result.duration).toBe(10);
  });
});
