import { useEffect, useState } from "react";
import { motion } from "motion/react";
import {
  ArrowLeft,
  Moon,
  Sun,
  Monitor,
  Volume2,
  Clock,
  Trash2,
  Bell,
  Archive,
} from "lucide-react";
import { invoke } from "@tauri-apps/api/core";
import type { BackupEntry, GameProgress, Theme } from "../types";
import { useGameStore } from "../stores/gameStore";
import { useUpdater } from "../hooks/useUpdater";
import { cn } from "../lib/cn";
import type { ReactNode } from "react";

const THEMES: readonly {
  readonly id: Theme;
  readonly label: string;
  readonly icon: ReactNode;
}[] = [
  { id: "dark", label: "Dark", icon: <Moon className="h-4 w-4" /> },
  { id: "light", label: "Light", icon: <Sun className="h-4 w-4" /> },
  { id: "system", label: "System", icon: <Monitor className="h-4 w-4" /> },
];

export function Settings() {
  const setPhase = useGameStore((s) => s.setPhase);
  const theme = useGameStore((s) => s.progress.settings.theme);
  const volume = useGameStore((s) => s.progress.settings.volume);
  const setTheme = useGameStore((s) => s.setTheme);
  const setVolume = useGameStore((s) => s.setVolume);
  const mediumTimer = useGameStore((s) => s.progress.settings.mediumTimer);
  const hardTimer = useGameStore((s) => s.progress.settings.hardTimer);
  const setMediumTimer = useGameStore((s) => s.setMediumTimer);
  const setHardTimer = useGameStore((s) => s.setHardTimer);
  const resetProgress = useGameStore((s) => s.resetProgress);
  const progress = useGameStore((s) => s.progress);
  const setProgress = useGameStore((s) => s.setProgress);
  const updater = useUpdater();
  const [confirmReset, setConfirmReset] = useState(false);
  const [backups, setBackups] = useState<readonly BackupEntry[]>([]);

  useEffect(() => {
    invoke<readonly BackupEntry[]>("list_save_backups")
      .then(setBackups)
      .catch(() => setBackups([]));
  }, []);

  const handleReset = () => {
    if (confirmReset) {
      resetProgress();
      setConfirmReset(false);
    } else {
      setConfirmReset(true);
    }
  };

  const handleRestore = async (timestamp: number) => {
    if (
      !window.confirm(
        "Restore this backup? Your current save will be replaced.",
      )
    ) {
      return;
    }
    try {
      await invoke("restore_save_backup", { timestamp });
      const result = await invoke<unknown>("load_progress");
      if (
        result &&
        typeof result === "object" &&
        "kind" in result &&
        "progress" in result
      ) {
        setProgress((result as { progress: GameProgress }).progress);
      }
    } catch (err) {
      // Surface via state if needed; v1 swallows since the modal isn't wired here.
      void err;
    }
  };

  const toggleAutoCheck = (next: boolean) => {
    setProgress({
      ...progress,
      updater: { ...progress.updater, autoCheckEnabled: next },
    });
  };

  const lastChecked = progress.updater.lastCheckedAt
    ? new Date(progress.updater.lastCheckedAt).toLocaleString()
    : "Never";

  return (
    <div className="flex min-h-screen flex-col items-center gap-8 bg-gradient-to-br from-background to-muted/20 p-8">
      {/* Header */}
      <div className="flex w-full max-w-md items-center justify-between">
        <motion.button
          initial={{ opacity: 0, x: -10 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ type: "spring", stiffness: 300, damping: 30 }}
          onClick={() => setPhase("menu")}
          className="flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" />
          Back
        </motion.button>
        <div />
      </div>

      {/* Title */}
      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ type: "spring", stiffness: 300, damping: 30 }}
        className="text-center"
      >
        <h2 className="text-4xl font-bold tracking-tight">Settings</h2>
        <p className="mt-2 text-muted-foreground">Customize your experience</p>
      </motion.div>

      {/* Settings card */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.1, type: "spring", stiffness: 300, damping: 30 }}
        className="w-full max-w-md overflow-hidden rounded-2xl border border-border bg-card"
      >
        {/* Appearance section */}
        <div className="flex items-center justify-between p-6">
          <div className="flex items-center gap-3">
            <div className="inline-flex rounded-lg bg-muted p-2">
              <Moon className="h-4 w-4 text-muted-foreground" />
            </div>
            <div>
              <p className="text-sm font-medium text-foreground">Appearance</p>
              <p className="text-xs text-muted-foreground">Choose your theme</p>
            </div>
          </div>
          <div className="flex gap-1 rounded-lg bg-muted p-1">
            {THEMES.map((t) => (
              <button
                key={t.id}
                onClick={() => setTheme(t.id)}
                className={cn(
                  "flex items-center gap-1.5 rounded-md px-3 py-1.5 text-xs font-medium transition-all",
                  theme === t.id
                    ? "bg-primary text-primary-foreground shadow-sm"
                    : "text-muted-foreground hover:text-foreground",
                )}
              >
                {t.icon}
                {t.label}
              </button>
            ))}
          </div>
        </div>

        <div className="mx-6 h-px bg-border" />

        {/* Audio section */}
        <div className="flex items-center justify-between gap-4 p-6">
          <div className="flex items-center gap-3">
            <div className="inline-flex rounded-lg bg-muted p-2">
              <Volume2 className="h-4 w-4 text-muted-foreground" />
            </div>
            <div>
              <p className="text-sm font-medium text-foreground">Volume</p>
              <p className="text-xs text-muted-foreground">
                {Math.round(volume * 100)}%
              </p>
            </div>
          </div>
          <input
            type="range"
            min="0"
            max="1"
            step="0.01"
            value={volume}
            onChange={(e) => setVolume(parseFloat(e.target.value))}
            className="w-32"
          />
        </div>

        <div className="mx-6 h-px bg-border" />

        {/* Timer section */}
        <div className="space-y-4 p-6">
          <div className="flex items-center gap-3">
            <div className="inline-flex rounded-lg bg-muted p-2">
              <Clock className="h-4 w-4 text-muted-foreground" />
            </div>
            <div>
              <p className="text-sm font-medium text-foreground">Timers</p>
              <p className="text-xs text-muted-foreground">
                Adjust time limits for timed modes
              </p>
            </div>
          </div>
          <div className="flex items-center justify-between gap-4 pl-11">
            <p className="text-sm text-muted-foreground">Medium</p>
            <div className="flex items-center gap-2">
              <input
                type="range"
                min="10"
                max="40"
                step="5"
                value={mediumTimer}
                onChange={(e) => setMediumTimer(parseInt(e.target.value, 10))}
                className="w-24"
              />
              <span className="w-8 text-right text-sm text-foreground">
                {mediumTimer}s
              </span>
            </div>
          </div>
          <div className="flex items-center justify-between gap-4 pl-11">
            <p className="text-sm text-muted-foreground">Hard</p>
            <div className="flex items-center gap-2">
              <input
                type="range"
                min="10"
                max="40"
                step="5"
                value={hardTimer}
                onChange={(e) => setHardTimer(parseInt(e.target.value, 10))}
                className="w-24"
              />
              <span className="w-8 text-right text-sm text-foreground">
                {hardTimer}s
              </span>
            </div>
          </div>
        </div>

        <div className="mx-6 h-px bg-border" />

        {/* Reset section */}
        <div className="flex items-center justify-between p-6">
          <div className="flex items-center gap-3">
            <div className="inline-flex rounded-lg bg-muted p-2">
              <Trash2 className="h-4 w-4 text-muted-foreground" />
            </div>
            <div>
              <p className="text-sm font-medium text-foreground">
                Reset Progress
              </p>
              <p className="text-xs text-muted-foreground">
                Erase all achievements
              </p>
            </div>
          </div>
          <div className="flex flex-col items-end gap-1">
            <button
              onClick={handleReset}
              className={cn(
                "rounded-lg px-4 py-2 text-xs font-medium transition-all",
                confirmReset
                  ? "bg-destructive text-white"
                  : "border border-destructive/50 text-destructive hover:bg-destructive/10",
              )}
            >
              {confirmReset ? "Confirm Reset" : "Reset"}
            </button>
            {confirmReset && (
              <button
                onClick={() => setConfirmReset(false)}
                className="text-xs text-muted-foreground hover:text-foreground"
              >
                Cancel
              </button>
            )}
          </div>
        </div>

        <div className="mx-6 h-px bg-border" />

        {/* About section */}
        <div className="flex items-center gap-3 p-6">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 64 64"
            width={32}
            height={32}
            aria-hidden="true"
          >
            <circle cx="32" cy="32" r="32" fill="#E97F6A" />
            <g fill="#ffffff" transform="translate(18, 12)">
              <rect x="20" y="0" width="4" height="28" rx="2" />
              <circle cx="8" cy="34" r="8" />
              <rect x="20" y="0" width="10" height="4" rx="2" />
            </g>
          </svg>
          <div>
            <p className="text-sm font-medium text-foreground">Swiftie Quiz</p>
            <p className="text-xs text-muted-foreground">Made by Satanshu</p>
          </div>
        </div>
      </motion.div>

      {/* Updates section */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.2, type: "spring", stiffness: 300, damping: 30 }}
        className="w-full max-w-md overflow-hidden rounded-2xl border border-border bg-card"
      >
        <div className="p-6">
          <div className="flex items-start gap-3">
            <div className="inline-flex rounded-lg bg-muted p-2">
              <Bell className="h-4 w-4 text-muted-foreground" />
            </div>
            <div className="flex-1">
              <p className="text-sm font-medium text-foreground">Updates</p>
              <p className="text-xs text-muted-foreground">
                Current version:{" "}
                <code>v{__APP_VERSION__ ?? "?"}</code>
              </p>
              <p className="mt-1 text-xs text-muted-foreground">
                Last checked: {lastChecked}
              </p>
            </div>
            <button
              type="button"
              onClick={() => updater.check({ manual: true })}
              className="rounded-md border border-border px-3 py-1.5 text-xs hover:bg-muted/40"
            >
              Check now
            </button>
          </div>
          <label className="mt-4 flex cursor-pointer items-start gap-2 pl-11">
            <input
              type="checkbox"
              checked={progress.updater.autoCheckEnabled}
              onChange={(e) => toggleAutoCheck(e.target.checked)}
              className="mt-1"
            />
            <span className="text-xs">
              Automatically check for updates
              <span className="block text-[11px] text-muted-foreground">
                Sends only app version, OS, and architecture. No analytics or
                unique identifiers.
              </span>
            </span>
          </label>
        </div>
      </motion.div>

      {/* Backups section */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{
          delay: 0.25,
          type: "spring",
          stiffness: 300,
          damping: 30,
        }}
        className="w-full max-w-md overflow-hidden rounded-2xl border border-border bg-card"
      >
        <div className="p-6">
          <div className="flex items-center gap-3">
            <div className="inline-flex rounded-lg bg-muted p-2">
              <Archive className="h-4 w-4 text-muted-foreground" />
            </div>
            <div>
              <p className="text-sm font-medium text-foreground">Backups</p>
              <p className="text-xs text-muted-foreground">
                The 3 most recent automatic save backups are kept.
              </p>
            </div>
          </div>
          {backups.length === 0 ? (
            <p className="mt-4 pl-11 text-xs text-muted-foreground">
              No backups yet.
            </p>
          ) : (
            <ul className="mt-4 space-y-2">
              {backups.map((b) => (
                <li
                  key={b.timestamp}
                  className="flex items-center justify-between rounded-md border border-border bg-card px-3 py-2"
                >
                  <div className="text-xs">
                    <div>{new Date(b.timestamp * 1000).toLocaleString()}</div>
                    <div className="text-[11px] text-muted-foreground">
                      {(b.sizeBytes / 1024).toFixed(1)} KB
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => handleRestore(b.timestamp)}
                    className="rounded-md border border-border px-3 py-1 text-xs hover:bg-muted/40"
                  >
                    Restore
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      </motion.div>
    </div>
  );
}
