import { useCallback } from "react";
import { check, type Update } from "@tauri-apps/plugin-updater";

import { useGameStore } from "../stores/gameStore";
import type { UpdateManifest, UpdaterMachineState } from "../types";

export interface UseUpdater {
  state: UpdaterMachineState;
  check(opts?: { manual?: boolean }): Promise<void>;
  download(): Promise<void>;
  install(): Promise<void>;
  cancel(): void;
  skipVersion(version: string): void;
  remindLater(): void;
  dismiss(): void;
}

// Module-scope holder for the Update object: the Tauri Update has methods
// (download/install) that can't survive serialization through Zustand,
// so we keep a non-serializable handle here. Acknowledged v1 simplification
// per the design spec; future improvement would be an opaque ID issued by
// a Rust command and dereferenced on each call.
interface InternalCtx {
  pendingUpdate: Update | null;
}
const ctx: InternalCtx = { pendingUpdate: null };

function manifestFromUpdate(u: Update): UpdateManifest {
  return {
    version: u.version,
    notes: u.body ?? "",
    pubDate: u.date ?? "",
  };
}

export function useUpdater(): UseUpdater {
  const state = useGameStore((s) => s.updaterState);
  const setState = useGameStore((s) => s.setUpdaterState);
  const progress = useGameStore((s) => s.progress);
  const setProgress = useGameStore((s) => s.setProgress);

  const doCheck = useCallback(async () => {
    setState({ kind: "checking" });
    try {
      const update = await check();
      if (!update) {
        ctx.pendingUpdate = null;
        setState({ kind: "up-to-date" });
        return;
      }
      ctx.pendingUpdate = update;
      setState({ kind: "available", manifest: manifestFromUpdate(update) });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setState({ kind: "error", subtype: "check", message });
    }
  }, [setState]);

  const doDownload = useCallback(async () => {
    if (!ctx.pendingUpdate) {
      setState({
        kind: "error",
        subtype: "download",
        message: "No pending update",
      });
      return;
    }
    const manifest = manifestFromUpdate(ctx.pendingUpdate);
    setState({ kind: "downloading", manifest, progress: 0 });
    try {
      let received = 0;
      let total = 0;
      await ctx.pendingUpdate.download((event) => {
        if (event.event === "Started") {
          total = event.data?.contentLength ?? 0;
        } else if (event.event === "Progress") {
          received += event.data?.chunkLength ?? 0;
          const pct = total > 0 ? Math.round((received / total) * 100) : 0;
          setState({ kind: "downloading", manifest, progress: pct });
        }
      });
      setState({ kind: "ready", manifest });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      const subtype = /signature|verif/i.test(message) ? "signature" : "download";
      setState({ kind: "error", subtype, message });
    }
  }, [setState]);

  const doInstall = useCallback(async () => {
    if (!ctx.pendingUpdate) {
      setState({
        kind: "error",
        subtype: "install",
        message: "No update to install",
      });
      return;
    }
    setState({ kind: "installing" });
    try {
      await ctx.pendingUpdate.install();
      // App relaunches; control flow doesn't return.
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setState({ kind: "error", subtype: "install", message });
    }
  }, [setState]);

  const cancel = useCallback(() => {
    ctx.pendingUpdate = null;
    setState({ kind: "idle" });
  }, [setState]);

  // skipVersion appends the version to progress.updater.skippedVersions.
  // remindLater writes an ISO timestamp 24h in the future to
  // progress.updater.remindLaterUntil. Both go through gameStore.setProgress
  // so the existing save_progress IPC persists them to disk.
  const skipVersion = useCallback(
    (version: string) => {
      setProgress({
        ...progress,
        updater: {
          ...progress.updater,
          skippedVersions: [...progress.updater.skippedVersions, version],
        },
      });
      ctx.pendingUpdate = null;
      setState({ kind: "idle" });
    },
    [progress, setProgress, setState],
  );

  const remindLater = useCallback(() => {
    const until = new Date(Date.now() + 24 * 3600 * 1000).toISOString();
    setProgress({
      ...progress,
      updater: { ...progress.updater, remindLaterUntil: until },
    });
    ctx.pendingUpdate = null;
    setState({ kind: "idle" });
  }, [progress, setProgress, setState]);

  const dismiss = useCallback(() => setState({ kind: "idle" }), [setState]);

  return {
    state,
    check: doCheck,
    download: doDownload,
    install: doInstall,
    cancel,
    skipVersion,
    remindLater,
    dismiss,
  };
}
