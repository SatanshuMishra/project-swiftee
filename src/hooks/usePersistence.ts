import { useCallback, useEffect, useRef } from "react";
import { invoke } from "@tauri-apps/api/core";

import type { GameProgress, LoadResult } from "../types";
import { DEFAULT_PROGRESS, assertNever } from "../types";
import { useGameStore } from "../stores/gameStore";
import { showToast } from "../lib/toast";

export function usePersistence() {
  const setProgress = useGameStore((s) => s.setProgress);
  const progress = useGameStore((s) => s.progress);
  const lastSaved = useRef<string>("");

  const applyProgress = useCallback(
    (p: GameProgress) =>
      setProgress({
        ...p,
        settings: { ...DEFAULT_PROGRESS.settings, ...p.settings },
      }),
    [setProgress],
  );

  const load = useCallback(async () => {
    try {
      const result = await invoke<LoadResult>("load_progress");
      switch (result.kind) {
        case "fresh":
          // First run — leave the store at DEFAULT_PROGRESS. No toast.
          break;
        case "loaded":
          applyProgress(result.progress);
          break;
        case "migrated": {
          applyProgress(result.progress);
          const message =
            result.fromVersion !== null
              ? `Welcome back! Your progress has been preserved. (Migrated from save format v${result.fromVersion}.)`
              : "Welcome back! Your progress has been preserved.";
          showToast(message);
          break;
        }
        default:
          assertNever(result);
      }
    } catch {
      // Backend errored (e.g., FutureSaveVersion or filesystem failure).
      // Fall back to defaults so the app remains usable; user can
      // restore from backup via Settings if needed.
      setProgress(DEFAULT_PROGRESS);
    }
  }, [setProgress, applyProgress]);

  const save = useCallback(async (progressToSave: GameProgress) => {
    const json = JSON.stringify(progressToSave);
    if (json === lastSaved.current) return;
    lastSaved.current = json;
    try {
      await invoke("save_progress", { progress: progressToSave });
    } catch (err) {
      // Project rule allows console.error (rule is no console.log specifically);
      // saving failures are operational events worth surfacing in dev tools.
      console.error("Failed to save progress:", err);
    }
  }, []);

  // Load on mount
  useEffect(() => {
    load();
  }, [load]);

  // Auto-save when progress changes (debounced 1s)
  useEffect(() => {
    const timer = setTimeout(() => {
      save(progress);
    }, 1000);
    return () => clearTimeout(timer);
  }, [progress, save]);

  return { load, save };
}
