import type { DangerZone } from "../lib/lrclib";

// --- Constants ---

const FRAME_SIZE_SEC = 0.25; // 250ms RMS frames
const STEP_SIZE_SEC = 0.5; // candidate start position step
const DEFAULT_SLICE_DURATION = 10;

// --- RMS Profile ---

/**
 * Compute RMS energy per frame from audio channel data.
 * Single-pass, no allocations beyond the result array.
 */
export function computeRmsProfile(
  channelData: Float32Array,
  sampleRate: number,
  frameSizeSec: number = FRAME_SIZE_SEC,
): readonly number[] {
  const frameSamples = Math.floor(sampleRate * frameSizeSec);
  if (frameSamples === 0) return [];

  const frameCount = Math.floor(channelData.length / frameSamples);
  const rms: number[] = new Array(frameCount);

  for (let f = 0; f < frameCount; f++) {
    let sumSquares = 0;
    const offset = f * frameSamples;
    for (let s = 0; s < frameSamples; s++) {
      const sample = channelData[offset + s];
      sumSquares += sample * sample;
    }
    rms[f] = Math.sqrt(sumSquares / frameSamples);
  }

  return rms;
}

// --- Scoring Helpers ---

/**
 * Compute energy score for a window: quieter = higher score.
 * Returns 1 - (maxRmsInWindow / globalMaxRms).
 */
export function computeEnergyScore(
  rmsProfile: readonly number[],
  globalMaxRms: number,
  frameSizeSec: number,
  startTime: number,
  sliceDuration: number,
): number {
  if (globalMaxRms === 0 || rmsProfile.length === 0) return 1;

  const startFrame = Math.floor(startTime / frameSizeSec);
  const endFrame = Math.min(
    rmsProfile.length,
    Math.ceil((startTime + sliceDuration) / frameSizeSec),
  );

  if (startFrame >= endFrame) return 1;

  let maxInWindow = 0;
  for (let i = startFrame; i < endFrame; i++) {
    if (rmsProfile[i] > maxInWindow) {
      maxInWindow = rmsProfile[i];
    }
  }

  return 1 - maxInWindow / globalMaxRms;
}

/**
 * Gaussian center bias: peaks at buffer midpoint, sigma = duration/4.
 * Returns value in (0, 1].
 */
export function computeCenterBias(
  startTime: number,
  bufferDuration: number,
  sliceDuration: number,
): number {
  const center = bufferDuration / 2;
  const windowCenter = startTime + sliceDuration / 2;
  const sigma = bufferDuration / 4;

  if (sigma === 0) return 1;

  const diff = windowCenter - center;
  return Math.exp(-(diff * diff) / (2 * sigma * sigma));
}

/**
 * Penalty for overlap with danger zones where the title might be sung.
 * Returns 0.0 if >=2s overlap, 0.3 if <2s overlap, 1.0 if no overlap.
 */
export function computeDangerZonePenalty(
  startTime: number,
  sliceDuration: number,
  dangerZones: readonly DangerZone[],
): number {
  if (dangerZones.length === 0) return 1;

  const windowEnd = startTime + sliceDuration;
  let totalOverlap = 0;

  for (const zone of dangerZones) {
    const overlapStart = Math.max(startTime, zone.start);
    const overlapEnd = Math.min(windowEnd, zone.end);
    if (overlapEnd > overlapStart) {
      totalOverlap += overlapEnd - overlapStart;
    }
  }

  if (totalOverlap >= 2) return 0;
  if (totalOverlap > 0) return 0.3;
  return 1;
}

// --- Main Selection ---

export interface ClipSelectionOptions {
  readonly audioBuffer: AudioBuffer;
  readonly dangerZones: readonly DangerZone[];
  readonly sliceDuration?: number;
}

/**
 * Select the best 10s window start position using scoring:
 * score(s) = energyScore(s) * centerBias(s) * dangerPenalty(s)
 */
export function selectClipStart({
  audioBuffer,
  dangerZones,
  sliceDuration = DEFAULT_SLICE_DURATION,
}: ClipSelectionOptions): number {
  const maxStart = Math.max(0, audioBuffer.duration - sliceDuration);
  if (maxStart === 0) return 0;

  // Extract channel data and compute RMS profile
  const channelData = audioBuffer.getChannelData(0);
  const sampleRate = audioBuffer.sampleRate;
  const rmsProfile = computeRmsProfile(channelData, sampleRate, FRAME_SIZE_SEC);

  // Find global max RMS
  let globalMaxRms = 0;
  for (const rms of rmsProfile) {
    if (rms > globalMaxRms) {
      globalMaxRms = rms;
    }
  }

  // Score each candidate position
  let bestStart = 0;
  let bestScore = -1;

  for (let s = 0; s <= maxStart; s += STEP_SIZE_SEC) {
    const energy = computeEnergyScore(
      rmsProfile,
      globalMaxRms,
      FRAME_SIZE_SEC,
      s,
      sliceDuration,
    );
    const center = computeCenterBias(s, audioBuffer.duration, sliceDuration);
    const danger = computeDangerZonePenalty(s, sliceDuration, dangerZones);

    const score = energy * center * danger;

    if (score > bestScore) {
      bestScore = score;
      bestStart = s;
    }
  }

  return bestStart;
}

/**
 * Wrapper with try/catch fallback to random selection.
 */
export function selectClipStartWithFallback(
  audioBuffer: AudioBuffer,
  dangerZones: readonly DangerZone[],
): number {
  try {
    return selectClipStart({ audioBuffer, dangerZones });
  } catch (error) {
    console.warn("Smart clip selection failed, using random fallback:", error);
    const sliceDuration = DEFAULT_SLICE_DURATION;
    const maxStart = Math.max(0, audioBuffer.duration - sliceDuration);
    return Math.random() * maxStart;
  }
}
