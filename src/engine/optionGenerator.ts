import type { Track } from "../types";
import { normalizeTitle } from "./answerMatcher";

/**
 * Fisher-Yates shuffle (returns new array, does not mutate).
 */
function shuffle<T>(arr: readonly T[]): T[] {
  const result = [...arr];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

/**
 * Generate 4 de-duplicated multiple-choice options:
 * 1 correct + 3 wrong from the pool.
 */
export function generateOptions(
  correctTrack: Track,
  pool: readonly Track[],
): Track[] {
  const normalizedCorrect = normalizeTitle(correctTrack.title);

  // Filter pool: exclude tracks that normalize to the same title
  const candidates = pool.filter((t) => {
    if (t.id === correctTrack.id) return false;
    return normalizeTitle(t.title) !== normalizedCorrect;
  });

  // De-duplicate candidates by normalized title
  const seen = new Set<string>();
  const uniqueCandidates: Track[] = [];
  for (const track of shuffle(candidates)) {
    const normalized = normalizeTitle(track.title);
    if (!seen.has(normalized)) {
      seen.add(normalized);
      uniqueCandidates.push(track);
    }
    if (uniqueCandidates.length >= 3) break;
  }

  return shuffle([correctTrack, ...uniqueCandidates]);
}
