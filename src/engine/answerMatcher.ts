import { isCloseMatch } from "../lib/levenshtein";
import type { Difficulty, Track } from "../types";

/**
 * Normalise a track title for comparison:
 * 1. Lowercase
 * 2. Remove all parenthetical suffixes
 * 3. Strip punctuation
 * 4. Trim and collapse whitespace
 */
export function normalizeTitle(title: string): string {
  let result = title.toLowerCase();
  // Remove all parenthetical content (including nested)
  result = result.replace(/\s*\([^)]*\)\s*/g, " ");
  // Replace hyphens with spaces (Anti-Hero → Anti Hero)
  result = result.replace(/-/g, " ");
  // Remove punctuation: apostrophes, periods, commas, ?, !
  result = result.replace(/['''.,?!:;"]/g, "");
  // Collapse whitespace and trim
  result = result.replace(/\s+/g, " ").trim();
  return result;
}

/**
 * Check if a player's answer is correct.
 * Easy/Medium: match by track ID (multiple choice).
 * Hard: normalise both strings, then Levenshtein comparison.
 */
export function checkAnswer(
  input: string | number,
  correctTrack: Track,
  difficulty: Difficulty,
): boolean {
  if (difficulty === "easy" || difficulty === "medium") {
    return input === correctTrack.id;
  }

  // Hard mode: text comparison
  if (typeof input !== "string") return false;

  const normalizedInput = normalizeTitle(input);
  const normalizedCorrect = normalizeTitle(correctTrack.title);

  return isCloseMatch(normalizedInput, normalizedCorrect);
}
