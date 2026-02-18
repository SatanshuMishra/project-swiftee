import { useCallback, useEffect, useRef } from "react";
import { invoke } from "@tauri-apps/api/core";
import type { GameProgress } from "../types";
import { DEFAULT_PROGRESS } from "../types";
import { useGameStore } from "../stores/gameStore";

export function usePersistence() {
  const setProgress = useGameStore((s) => s.setProgress);
  const progress = useGameStore((s) => s.progress);
  const lastSaved = useRef<string>("");

  const load = useCallback(async () => {
    try {
      const loaded = await invoke<GameProgress>("load_progress");
      const mergedSettings = {
        ...DEFAULT_PROGRESS.settings,
        ...loaded.settings,
      };
      setProgress({ ...loaded, settings: mergedSettings });
    } catch {
      setProgress(DEFAULT_PROGRESS);
    }
  }, [setProgress]);

  const save = useCallback(async (progressToSave: GameProgress) => {
    const json = JSON.stringify(progressToSave);
    if (json === lastSaved.current) return;
    lastSaved.current = json;
    try {
      await invoke("save_progress", { progress: progressToSave });
    } catch (err) {
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
