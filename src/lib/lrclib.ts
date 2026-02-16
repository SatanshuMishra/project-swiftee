import { normalizeTitle } from "../engine/answerMatcher";

// --- Types ---

export interface LrcLine {
  readonly timeSeconds: number;
  readonly text: string;
}

export interface DangerZone {
  readonly start: number;
  readonly end: number;
}

interface LrclibResponse {
  readonly syncedLyrics?: string | null;
}

// --- Constants ---

const LRCLIB_BASE = "https://lrclib.net/api";
const FETCH_TIMEOUT_MS = 2_000;
const DANGER_ZONE_PADDING_S = 1.5; // seconds before/after matching line
const STOP_WORDS = new Set([
  "the",
  "a",
  "an",
  "i",
  "me",
  "my",
  "you",
  "your",
  "we",
  "our",
  "it",
  "its",
  "is",
  "am",
  "are",
  "was",
  "were",
  "be",
  "been",
  "do",
  "did",
  "to",
  "of",
  "in",
  "on",
  "at",
  "for",
  "and",
  "or",
  "so",
  "no",
  "not",
  "but",
  "if",
  "up",
  "out",
  "all",
  "just",
  "like",
  "this",
  "that",
  "with",
  "from",
]);

// --- Module-level cache ---

const MAX_CACHE_SIZE = 100;
const dangerZoneCache = new Map<string, readonly DangerZone[]>();

function setCache(key: string, value: readonly DangerZone[]): void {
  if (dangerZoneCache.size >= MAX_CACHE_SIZE) {
    const firstKey = dangerZoneCache.keys().next().value;
    if (firstKey !== undefined) {
      dangerZoneCache.delete(firstKey);
    }
  }
  dangerZoneCache.set(key, value);
}

// --- LRC Parsing ---

/**
 * Parse LRC-format lyrics into sorted timestamped lines.
 * Handles format: [mm:ss.xx] text
 */
export function parseLrc(raw: string): readonly LrcLine[] {
  const regex = /\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\][ \t]*(.*)/g;
  const lines: LrcLine[] = [];

  let match: RegExpExecArray | null;
  while ((match = regex.exec(raw)) !== null) {
    const minutes = parseInt(match[1], 10);
    const seconds = parseInt(match[2], 10);
    const milliseconds = match[3] ? parseInt(match[3].padEnd(3, "0"), 10) : 0;
    const timeSeconds = minutes * 60 + seconds + milliseconds / 1000;
    const text = match[4].trim();

    if (text.length > 0) {
      lines.push({ timeSeconds, text });
    }
  }

  return [...lines].sort((a, b) => a.timeSeconds - b.timeSeconds);
}

// --- Preview Offset Estimation ---

/**
 * Estimate where Deezer's 30s preview starts within the full song.
 * Strategy: find the first repeated lyric group (chorus), else default to 30%.
 */
export function estimatePreviewOffset(
  lines: readonly LrcLine[],
  songDurationSeconds: number,
): number {
  if (lines.length < 4) {
    return songDurationSeconds * 0.3;
  }

  // Normalize all lines for comparison
  const normalized = lines.map((l) => l.text.toLowerCase().trim());

  // Find first line that appears more than once — likely chorus start
  for (let i = 0; i < normalized.length; i++) {
    if (normalized[i].length < 10) continue; // skip short/instrumental lines
    const firstOccurrence = normalized.indexOf(normalized[i]);
    if (firstOccurrence < i) {
      // This line appeared earlier; the earlier occurrence is likely the chorus
      return Math.max(0, lines[firstOccurrence].timeSeconds - 2);
    }
  }

  // No repeated lines found — use 30% heuristic
  return songDurationSeconds * 0.3;
}

// --- Title Danger Zones ---

/**
 * Build words from a title, filtering out stop words.
 */
function extractTitleWords(title: string): readonly string[] {
  const normalized = normalizeTitle(title);
  return normalized
    .split(/\s+/)
    .filter((w) => w.length > 1 && !STOP_WORDS.has(w));
}

/**
 * Check if a lyric line likely contains the song title.
 */
function lineContainsTitle(
  lineText: string,
  titleWords: readonly string[],
): boolean {
  if (titleWords.length === 0) return false;

  const normalizedLine = normalizeTitle(lineText);
  const matchCount = titleWords.filter((word) =>
    normalizedLine.includes(word),
  ).length;

  // Require at least 60% of title words to match (minimum 1)
  const threshold = Math.max(1, Math.ceil(titleWords.length * 0.6));
  return matchCount >= threshold;
}

/**
 * Merge overlapping zones into non-overlapping intervals.
 */
function mergeZones(zones: readonly DangerZone[]): readonly DangerZone[] {
  if (zones.length === 0) return [];

  const sorted = [...zones].sort((a, b) => a.start - b.start);
  const merged: DangerZone[] = [sorted[0]];

  for (let i = 1; i < sorted.length; i++) {
    const prev = merged[merged.length - 1];
    const curr = sorted[i];

    if (curr.start <= prev.end) {
      // Overlapping — extend previous zone
      merged[merged.length - 1] = {
        start: prev.start,
        end: Math.max(prev.end, curr.end),
      };
    } else {
      merged.push(curr);
    }
  }

  return merged;
}

/**
 * Find danger zones in lyrics where the song title is likely sung.
 * Times are relative to the preview start (adjusted by previewOffset).
 */
export function findTitleDangerZones(
  lines: readonly LrcLine[],
  title: string,
  titleShort: string,
  previewOffset: number,
): readonly DangerZone[] {
  const titleWords = extractTitleWords(title);
  const shortWords = extractTitleWords(titleShort);

  // Use whichever has more meaningful words, prefer short title
  const words =
    shortWords.length >= titleWords.length ? shortWords : titleWords;

  const zones: DangerZone[] = [];
  const previewEnd = previewOffset + 30;

  for (const line of lines) {
    // Only consider lines within the preview window
    if (line.timeSeconds < previewOffset || line.timeSeconds > previewEnd) {
      continue;
    }

    if (lineContainsTitle(line.text, words)) {
      const relativeTime = line.timeSeconds - previewOffset;
      zones.push({
        start: Math.max(0, relativeTime - DANGER_ZONE_PADDING_S),
        end: Math.min(30, relativeTime + DANGER_ZONE_PADDING_S),
      });
    }
  }

  return mergeZones(zones);
}

// --- LRCLIB API ---

function buildCacheKey(artist: string, title: string): string {
  return `${artist.toLowerCase()}::${title.toLowerCase()}`;
}

/**
 * Fetch danger zones from LRCLIB for a given track.
 * Returns [] on any error (timeout, network, no lyrics).
 * Results are cached in-memory per track.
 */
export async function fetchDangerZones(
  trackTitle: string,
  artistName: string,
  titleShort: string,
  songDurationSeconds: number,
): Promise<readonly DangerZone[]> {
  const key = buildCacheKey(artistName, trackTitle);

  const cached = dangerZoneCache.get(key);
  if (cached !== undefined) {
    return cached;
  }

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

    const params = new URLSearchParams({
      artist_name: artistName,
      track_name: trackTitle,
    });

    const response = await fetch(`${LRCLIB_BASE}/get?${params.toString()}`, {
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      setCache(key, []);
      return [];
    }

    const data: LrclibResponse = await response.json();

    if (!data.syncedLyrics) {
      setCache(key, []);
      return [];
    }

    const lines = parseLrc(data.syncedLyrics);
    const previewOffset = estimatePreviewOffset(lines, songDurationSeconds);
    const zones = findTitleDangerZones(
      lines,
      trackTitle,
      titleShort,
      previewOffset,
    );

    setCache(key, zones);
    return zones;
  } catch {
    // Timeout, network error, parse error — all non-fatal
    setCache(key, []);
    return [];
  }
}

/**
 * Clear the danger zone cache. Useful for testing.
 */
export function clearDangerZoneCache(): void {
  dangerZoneCache.clear();
}
