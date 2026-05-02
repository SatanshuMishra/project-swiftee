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
  // Auto-save is gated on a successful load. Until load_progress returns a
  // recognized LoadResult variant (Fresh / Loaded / Migrated), we MUST NOT
  // write the in-memory DEFAULT_PROGRESS to disk — doing so would silently
  // destroy a user's existing save when the file errored on read (e.g.
  // FutureSaveVersion after a downgrade, or a corrupted JSON).
  const loadCompletedSuccessfully = useRef(false);

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
      loadCompletedSuccessfully.current = true;
    } catch {
      // Load failed — most likely FutureSaveVersion (user downgraded) or a
      // corrupt save.json. Surface to the user via toast so they know to
      // restore from backup. Crucially, DO NOT overwrite the file: we leave
      // loadCompletedSuccessfully=false so the auto-save effect skips the
      // write.
      showToast(
        "Couldn't load your save. Open Settings → Backups to restore from a backup.",
      );
    }
  }, [applyProgress]);

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

  // Load on mount.
  useEffect(() => {
    load();
  }, [load]);

  // Auto-save when progress changes (debounced 1s) — but ONLY if load
  // succeeded. Otherwise we'd be writing DEFAULT_PROGRESS over the user's
  // real (possibly recoverable) save.
  useEffect(() => {
    if (!loadCompletedSuccessfully.current) return;
    const timer = setTimeout(() => {
      save(progress);
    }, 1000);
    return () => clearTimeout(timer);
  }, [progress, save]);

  return { load, save };
}
