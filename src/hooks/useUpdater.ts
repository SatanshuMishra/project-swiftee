import { useCallback } from "react";
import { check, type Update } from "@tauri-apps/plugin-updater";
import { relaunch } from "@tauri-apps/plugin-process";

import { useGameStore } from "../stores/gameStore";
import type { UpdateManifest, UpdaterMachineState } from "../types";

const REMIND_LATER_INTERVAL_MS = 24 * 60 * 60 * 1000;

const UPDATE_IN_HAND: ReadonlySet<UpdaterMachineState["kind"]> = new Set([
  "downloading",
  "ready",
  "installing",
  "installed",
]);

function updateInHand(): boolean {
  return UPDATE_IN_HAND.has(useGameStore.getState().updaterState.kind);
}

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
  const setProgress = useGameStore((s) => s.setProgress);

  const doCheck = useCallback(async (opts?: { manual?: boolean }) => {
    if (updateInHand()) return;
    const isManual = opts?.manual === true;
    const current = useGameStore.getState().progress.updater;

    // Auto-mode gates: respect user preferences. Manual checks (Settings →
    // Check now) bypass autoCheckEnabled and remindLaterUntil but still
    // honor skippedVersions for consistency.
    if (!isManual) {
      if (!current.autoCheckEnabled) return;
      if (current.remindLaterUntil) {
        const until = Date.parse(current.remindLaterUntil);
        if (!Number.isNaN(until) && until > Date.now()) return;
      }
    }

    setState({ kind: "checking" });
    try {
      const update = await check();
      const nowIso = new Date().toISOString();

      const latest = useGameStore.getState().progress;
      setProgress({
        ...latest,
        updater: { ...latest.updater, lastCheckedAt: nowIso },
      });

      if (updateInHand()) return;

      if (!update) {
        ctx.pendingUpdate = null;
        setState({ kind: "up-to-date" });
        return;
      }

      // Honor skippedVersions even on auto OR manual.
      if (latest.updater.skippedVersions.includes(update.version)) {
        ctx.pendingUpdate = null;
        setState({ kind: "up-to-date" });
        return;
      }

      ctx.pendingUpdate = update;
      setState({ kind: "available", manifest: manifestFromUpdate(update) });
    } catch (err) {
      if (updateInHand()) return;
      const message = err instanceof Error ? err.message : String(err);
      setState({ kind: "error", subtype: "check", message });
    }
  }, [setProgress, setState]);

  const doDownload = useCallback(async () => {
    const update = ctx.pendingUpdate;
    if (!update) {
      setState({
        kind: "error",
        subtype: "download",
        message: "No pending update",
      });
      return;
    }
    const manifest = manifestFromUpdate(update);
    setState({ kind: "downloading", manifest, progress: 0 });
    try {
      let received = 0;
      let total = 0;
      await update.download((event) => {
        if (ctx.pendingUpdate !== update) return;
        if (event.event === "Started") {
          total = event.data?.contentLength ?? 0;
        } else if (event.event === "Progress") {
          received += event.data?.chunkLength ?? 0;
          const pct = total > 0 ? Math.round((received / total) * 100) : 0;
          setState({ kind: "downloading", manifest, progress: pct });
        }
      });
      if (ctx.pendingUpdate !== update) return;
      setState({ kind: "ready", manifest });
    } catch (err) {
      if (ctx.pendingUpdate !== update) return;
      const message = err instanceof Error ? err.message : String(err);
      const subtype = /signature|verif/i.test(message) ? "signature" : "download";
      setState({ kind: "error", subtype, message });
    }
  }, [setState]);

  const doInstall = useCallback(async () => {
    const update = ctx.pendingUpdate;
    if (!update) {
      setState({
        kind: "error",
        subtype: "install",
        message: "No update to install",
      });
      return;
    }
    setState({ kind: "installing" });
    try {
      await update.install();
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setState({ kind: "error", subtype: "install", message });
      return;
    }
    try {
      await relaunch();
    } catch {
      setState({ kind: "installed", manifest: manifestFromUpdate(update) });
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
      const progress = useGameStore.getState().progress;
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
    [setProgress, setState],
  );

  const remindLater = useCallback(() => {
    const until = new Date(Date.now() + REMIND_LATER_INTERVAL_MS).toISOString();
    const progress = useGameStore.getState().progress;
    setProgress({
      ...progress,
      updater: { ...progress.updater, remindLaterUntil: until },
    });
    ctx.pendingUpdate = null;
    setState({ kind: "idle" });
  }, [setProgress, setState]);

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

// Test-only helper. Resets the module-scope pending-update state. Not part
// of the public hook API; do NOT call this from production code.
export function __resetUpdaterCtxForTests(): void {
  ctx.pendingUpdate = null;
}
