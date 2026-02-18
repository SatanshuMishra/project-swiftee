import type {
  Difficulty,
  LyricSnippet,
  DecoyResult,
  TrackLyrics,
} from "../types";

// --- Era groupings for lyrics-or-lie decoy selection ---

export const ERA_GROUPS: Record<string, readonly string[]> = {
  country: [
    "Taylor Swift",
    "Fearless (Taylor's Version)",
    "Speak Now (Taylor's Version)",
  ],
  countryPop: ["Red (Taylor's Version)"],
  pop: ["1989 (Taylor's Version)", "reputation"],
  romanticPop: ["Lover"],
  indieFolk: ["folklore", "evermore"],
  midnightsPop: ["Midnights"],
  ttpd: ["THE TORTURED POETS DEPARTMENT"],
  showgirl: ["The Life of a Showgirl"],
};

// --- Chorus Detection ---

function normalizeLine(line: string): string {
  return line
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

interface ChorusRegion {
  readonly start: number;
  readonly end: number;
}

/**
 * Detect chorus regions by finding lines that appear 2+ times.
 * A chorus region is a contiguous block of 2+ flagged lines.
 */
export function detectChorusRegions(
  lines: readonly string[],
): readonly ChorusRegion[] {
  const normalized = lines.map(normalizeLine);

  // Count occurrences of each normalized line
  const counts = new Map<string, number>();
  for (const line of normalized) {
    if (line.length === 0) continue;
    counts.set(line, (counts.get(line) ?? 0) + 1);
  }

  // Flag lines appearing 2+ times
  const isChorus = normalized.map((line) => (counts.get(line) ?? 0) >= 2);

  // Group contiguous flagged lines into regions (min 2 lines)
  const regions: ChorusRegion[] = [];
  let regionStart = -1;
  for (let i = 0; i <= isChorus.length; i++) {
    if (i < isChorus.length && isChorus[i]) {
      if (regionStart === -1) regionStart = i;
    } else {
      if (regionStart !== -1) {
        const length = i - regionStart;
        if (length >= 2) {
          regions.push({ start: regionStart, end: i - 1 });
        }
        regionStart = -1;
      }
    }
  }

  return regions;
}

// --- Snippet Extraction ---

/**
 * Extract a contiguous block of lyric lines.
 * - Never extracts the very first or last line.
 * - preferChorus: extract from a chorus region (Easy mode).
 * - excludeChorus: exclude all chorus regions (Hard mode).
 */
export function extractSnippet(
  allLines: readonly string[],
  lineCount: number,
  preferChorus: boolean,
  excludeChorus: boolean,
): LyricSnippet {
  if (allLines.length <= lineCount) {
    return {
      lines: [...allLines],
      sourceLineIndices: allLines.map((_, i) => i),
    };
  }

  const chorusRegions = detectChorusRegions(allLines);

  if (preferChorus && chorusRegions.length > 0) {
    // Pick a random chorus region
    const region =
      chorusRegions[Math.floor(Math.random() * chorusRegions.length)];
    const regionLength = region.end - region.start + 1;
    const actualCount = Math.min(lineCount, regionLength);
    const maxStart = region.end - actualCount + 1;
    const start =
      region.start + Math.floor(Math.random() * (maxStart - region.start + 1));
    const indices = Array.from({ length: actualCount }, (_, i) => start + i);
    return {
      lines: indices.map((i) => allLines[i]),
      sourceLineIndices: indices,
    };
  }

  // Build eligible indices: skip first and last line
  let eligible: number[];
  if (excludeChorus && chorusRegions.length > 0) {
    const chorusIndices = new Set<number>();
    for (const region of chorusRegions) {
      for (let i = region.start; i <= region.end; i++) {
        chorusIndices.add(i);
      }
    }
    eligible = [];
    for (let i = 1; i < allLines.length - 1; i++) {
      if (!chorusIndices.has(i)) eligible.push(i);
    }
  } else {
    eligible = [];
    for (let i = 1; i < allLines.length - 1; i++) {
      eligible.push(i);
    }
  }

  if (eligible.length < lineCount) {
    // Fall back to all lines except first/last
    eligible = [];
    for (let i = 1; i < allLines.length - 1; i++) {
      eligible.push(i);
    }
  }

  if (eligible.length < lineCount) {
    // Even fallback not enough, use all
    return {
      lines: allLines.slice(0, lineCount),
      sourceLineIndices: Array.from(
        { length: Math.min(lineCount, allLines.length) },
        (_, i) => i,
      ),
    };
  }

  // Find contiguous blocks of `lineCount` within eligible
  const contiguousStarts: number[] = [];
  for (let i = 0; i <= eligible.length - lineCount; i++) {
    let isContiguous = true;
    for (let j = 1; j < lineCount; j++) {
      if (eligible[i + j] !== eligible[i] + j) {
        isContiguous = false;
        break;
      }
    }
    if (isContiguous) {
      contiguousStarts.push(i);
    }
  }

  if (contiguousStarts.length > 0) {
    const startIdx =
      contiguousStarts[Math.floor(Math.random() * contiguousStarts.length)];
    const indices = Array.from(
      { length: lineCount },
      (_, i) => eligible[startIdx + i],
    );
    return {
      lines: indices.map((i) => allLines[i]),
      sourceLineIndices: indices,
    };
  }

  // No contiguous block available, take first N eligible
  const indices = eligible.slice(0, lineCount);
  return {
    lines: indices.map((i) => allLines[i]),
    sourceLineIndices: indices,
  };
}

// --- Title Sanitisation ---

function normalizeForComparison(text: string): string {
  return text
    .toLowerCase()
    .replace(/\s*\([^)]*\)\s*/g, " ")
    .replace(/['''.,?!:;"]/g, "")
    .replace(/-/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Replace occurrences of the song title with "______" in lyric lines.
 * Word-boundary aware, case-insensitive.
 */
export function sanitiseSnippet(
  lines: readonly string[],
  songTitle: string,
): string[] {
  const normalizedTitle = normalizeForComparison(songTitle);
  if (normalizedTitle.length === 0) return [...lines];

  // Escape regex special chars in the title
  const escaped = normalizedTitle.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const pattern = new RegExp(`\\b${escaped}\\b`, "gi");

  return lines.map((line) => {
    // Build a normalized version for matching
    const normalizedLine = line.replace(/[''']/g, "").replace(/-/g, " ");

    // Check if the normalized line contains the title
    if (pattern.test(normalizedLine.toLowerCase())) {
      // Replace in the original line (case-insensitive)
      return line.replace(
        new RegExp(escaped.replace(/\s+/g, "[\\s\\-]+"), "gi"),
        "______",
      );
    }
    return line;
  });
}

// --- Helpers for multi-line selection ---

/**
 * Check if a lyric line contains the song title (word-boundary aware).
 * Mirrors sanitiseSnippet's regex approach to avoid false positives on
 * short titles like "Red" matching inside "surrendered".
 */
function containsTitle(line: string, songTitle: string): boolean {
  const normalizedTitle = normalizeForComparison(songTitle);
  if (normalizedTitle.length === 0) return false;
  const escaped = normalizedTitle.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const pattern = new RegExp(`\\b${escaped}\\b`, "i");
  const normalizedLine = normalizeForComparison(line);
  return pattern.test(normalizedLine);
}

/**
 * Pick a contiguous block of N lines from a lyrics array.
 * Works in original index space to preserve contiguity even when
 * some indices are excluded (e.g. title-containing lines).
 * - Skips first and last lines of the source.
 * - Each line in the block must have 4-15 words.
 * - Falls back gracefully through multiple tiers.
 */
function pickContiguousBlock(
  allLines: readonly string[],
  lineCount: number,
  excludeIndices?: ReadonlySet<number>,
): readonly string[] {
  if (lineCount <= 0 || allLines.length === 0) return [];

  // For lineCount === 1, preserve existing single-line behavior
  if (lineCount === 1) {
    const validLines: string[] = [];
    for (let i = 0; i < allLines.length; i++) {
      if (excludeIndices?.has(i)) continue;
      const words = allLines[i].split(/\s+/).length;
      if (words >= 4 && words <= 15) validLines.push(allLines[i]);
    }
    if (validLines.length === 0) {
      // Fallback: any non-excluded line
      for (let i = 0; i < allLines.length; i++) {
        if (!excludeIndices?.has(i)) validLines.push(allLines[i]);
      }
    }
    const pool = validLines.length > 0 ? validLines : [...allLines];
    return [pool[Math.floor(Math.random() * pool.length)]];
  }

  // Multi-line: build eligible indices (skip first/last, skip excluded)
  const minIdx = allLines.length > 2 ? 1 : 0;
  const maxIdx =
    allLines.length > 2 ? allLines.length - 2 : allLines.length - 1;

  const eligible: number[] = [];
  for (let i = minIdx; i <= maxIdx; i++) {
    if (!excludeIndices?.has(i)) eligible.push(i);
  }

  // Find contiguous runs of eligible indices where ALL lines have 4-15 words
  const strictStarts: number[] = [];
  for (let i = 0; i <= eligible.length - lineCount; i++) {
    let valid = true;
    for (let j = 0; j < lineCount; j++) {
      if (j > 0 && eligible[i + j] !== eligible[i + j - 1] + 1) {
        valid = false;
        break;
      }
      const words = allLines[eligible[i + j]].split(/\s+/).length;
      if (words < 4 || words > 15) {
        valid = false;
        break;
      }
    }
    if (valid) strictStarts.push(i);
  }

  if (strictStarts.length > 0) {
    const s = strictStarts[Math.floor(Math.random() * strictStarts.length)];
    return Array.from(
      { length: lineCount },
      (_, j) => allLines[eligible[s + j]],
    );
  }

  // Fallback: contiguous in original, ignore word count
  const relaxedStarts: number[] = [];
  for (let i = 0; i <= eligible.length - lineCount; i++) {
    let contiguous = true;
    for (let j = 1; j < lineCount; j++) {
      if (eligible[i + j] !== eligible[i + j - 1] + 1) {
        contiguous = false;
        break;
      }
    }
    if (contiguous) relaxedStarts.push(i);
  }

  if (relaxedStarts.length > 0) {
    const s = relaxedStarts[Math.floor(Math.random() * relaxedStarts.length)];
    return Array.from(
      { length: lineCount },
      (_, j) => allLines[eligible[s + j]],
    );
  }

  // Ultimate fallback: first N eligible lines (may not be contiguous)
  if (eligible.length >= lineCount) {
    return eligible.slice(0, lineCount).map((i) => allLines[i]);
  }

  // Absolute fallback: first N lines
  return allLines.slice(0, Math.min(lineCount, allLines.length));
}

// --- Decoy Selection (Lyrics or Lie) ---

/**
 * Select either real lyric lines or decoy lines from another song.
 * 50/50 split between real and fake.
 *
 * @param lineCount Number of contiguous lines to return (default 1)
 * @param currentTrackTitle Song title to exclude from real-line candidates
 */
export function selectDecoyOrReal(
  currentTrackLyrics: readonly string[],
  decoyPool: ReadonlyMap<number, TrackLyrics>,
  difficulty: Difficulty,
  currentTrackAlbum?: string,
  lineCount: number = 1,
  currentTrackTitle?: string,
): DecoyResult {
  const showReal = Math.random() < 0.5;

  // Build title-exclusion set for "real" picks
  const titleExcluded = currentTrackTitle
    ? new Set(
        currentTrackLyrics
          .map((line, i) => (containsTitle(line, currentTrackTitle) ? i : -1))
          .filter((i): i is number => i >= 0),
      )
    : undefined;

  if (showReal) {
    const lines = pickContiguousBlock(
      currentTrackLyrics,
      lineCount,
      titleExcluded,
    );
    return { lines, isReal: true };
  }

  // Select a decoy from another song
  const decoyEntries = Array.from(decoyPool.entries());
  if (decoyEntries.length === 0) {
    // Fallback to real if no decoys available
    const lines = pickContiguousBlock(
      currentTrackLyrics,
      lineCount,
      titleExcluded,
    );
    return { lines, isReal: true };
  }

  const avgWordCount =
    currentTrackLyrics.reduce((sum, l) => sum + l.split(/\s+/).length, 0) /
    currentTrackLyrics.length;

  // Filter decoy sources based on difficulty
  let candidates = decoyEntries;

  if (difficulty === "hard" && currentTrackAlbum) {
    const sameAlbum = candidates.filter(
      ([, lyrics]) => lyrics.sourceAlbum === currentTrackAlbum,
    );
    if (sameAlbum.length > 0) candidates = sameAlbum;
  } else if (difficulty === "easy") {
    const currentEra = findEraGroup(currentTrackAlbum ?? "");
    if (currentEra) {
      const differentEra = candidates.filter(([, lyrics]) => {
        const decoyEra = findEraGroup(lyrics.sourceAlbum);
        return decoyEra && decoyEra !== currentEra;
      });
      if (differentEra.length > 0) candidates = differentEra;
    }
  }

  const [, decoyLyrics] =
    candidates[Math.floor(Math.random() * candidates.length)];

  if (lineCount === 1) {
    // Preserve existing single-line decoy behavior: word-count + tolerance
    const tolerance = avgWordCount * 0.3;
    let decoyLines = decoyLyrics.lines.filter((line) => {
      const words = line.split(/\s+/).length;
      return (
        words >= 4 && words <= 15 && Math.abs(words - avgWordCount) <= tolerance
      );
    });

    if (decoyLines.length === 0) {
      decoyLines = decoyLyrics.lines.filter(
        (line) => line.split(/\s+/).length >= 4,
      );
    }

    if (decoyLines.length === 0) {
      decoyLines = [...decoyLyrics.lines];
    }

    const line = decoyLines[Math.floor(Math.random() * decoyLines.length)];
    return {
      lines: [line],
      isReal: false,
      sourceSong: decoyLyrics.sourceTrack,
    };
  }

  // Multi-line decoy: pick contiguous block
  const lines = pickContiguousBlock(decoyLyrics.lines, lineCount);
  return { lines, isReal: false, sourceSong: decoyLyrics.sourceTrack };
}

function findEraGroup(albumTitle: string): string | null {
  for (const [era, albums] of Object.entries(ERA_GROUPS)) {
    if (albums.some((a) => albumTitle.includes(a) || a.includes(albumTitle))) {
      return era;
    }
  }
  return null;
}
