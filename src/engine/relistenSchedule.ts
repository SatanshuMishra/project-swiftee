/**
 * Escalation schedule for relisten stages (0-indexed).
 * Index 0 = first relisten (stage 1), index 1 = second relisten (stage 2), etc.
 *
 * All scheduled stages play from the smart start position.
 * Stages beyond the array length fall through to full-clip playback (from position 0).
 */
const SCHEDULE: readonly number[] = [
  10, // relisten 1: same 10s slice
  10, // relisten 2: same 10s slice
  15, // relisten 3: 15s from smart start
  15, // relisten 4: 15s from smart start
  20, // relisten 5: 20s from smart start
  20, // relisten 6: 20s from smart start
  // relisten 7+: full clip (handled by fallback)
];

const BASE_DURATION = SCHEDULE[0]; // 10

/**
 * The relistenCount at which full-clip playback activates.
 * +1 because relistenCount is incremented before playSlice() in useAudio.ts,
 * so after stage-7 replay, relistenCount === SCHEDULE.length + 1.
 */
export const FULL_CLIP_THRESHOLD = SCHEDULE.length + 1; // 7

/**
 * The relistenCount at which clips are first extended beyond the base duration.
 * Derived from the schedule so it stays in sync automatically.
 */
const firstEscalationIndex = SCHEDULE.findIndex((d) => d > BASE_DURATION);
export const FIRST_ESCALATION_RELISTEN = firstEscalationIndex + 1; // 3

export interface RelistenSlice {
  readonly offset: number;
  readonly duration: number;
}

/**
 * Given the relisten stage (1-based), the smart start position, and the
 * buffer duration, returns the offset and duration for playSlice().
 */
export function getRelistenSlice(
  stage: number,
  smartStart: number,
  bufferDuration: number,
): RelistenSlice {
  const index = stage - 1;

  if (index < 0 || index >= SCHEDULE.length) {
    return { offset: 0, duration: bufferDuration };
  }

  const duration = Math.min(SCHEDULE[index], bufferDuration - smartStart);
  return { offset: smartStart, duration };
}
