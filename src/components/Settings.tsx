import { useState } from "react";
import type { Theme } from "../types";
import { useGameStore } from "../stores/gameStore";

const THEMES: readonly { readonly id: Theme; readonly label: string }[] = [
  { id: "dark", label: "Dark" },
  { id: "light", label: "Light" },
  { id: "system", label: "System" },
];

export function Settings() {
  const setPhase = useGameStore((s) => s.setPhase);
  const theme = useGameStore((s) => s.progress.settings.theme);
  const volume = useGameStore((s) => s.progress.settings.volume);
  const setTheme = useGameStore((s) => s.setTheme);
  const setVolume = useGameStore((s) => s.setVolume);
  const resetProgress = useGameStore((s) => s.resetProgress);
  const [confirmReset, setConfirmReset] = useState(false);

  const handleReset = () => {
    if (confirmReset) {
      resetProgress();
      setConfirmReset(false);
    } else {
      setConfirmReset(true);
    }
  };

  return (
    <div className="flex min-h-screen flex-col items-center gap-8 p-8">
      <div className="flex w-full items-center justify-between">
        <button
          onClick={() => setPhase("menu")}
          className="text-sm"
          style={{ color: "var(--color-text-secondary)" }}
        >
          ← Back
        </button>
        <h2
          className="text-2xl font-bold"
          style={{ color: "var(--color-text-primary)" }}
        >
          Settings
        </h2>
        <div className="w-12" />
      </div>

      <div
        className="flex w-full max-w-md flex-col gap-6 rounded-xl p-6"
        style={{
          backgroundColor: "var(--color-surface)",
          border: "1px solid var(--color-border)",
        }}
      >
        {/* Theme */}
        <div className="flex flex-col gap-2">
          <label
            className="text-sm font-medium"
            style={{ color: "var(--color-text-secondary)" }}
          >
            Theme
          </label>
          <div className="flex gap-2">
            {THEMES.map((t) => (
              <button
                key={t.id}
                onClick={() => setTheme(t.id)}
                className="flex-1 rounded-lg px-4 py-2 text-sm font-medium"
                style={{
                  backgroundColor:
                    theme === t.id
                      ? "var(--color-accent)"
                      : "var(--color-bg)",
                  color:
                    theme === t.id
                      ? "#ffffff"
                      : "var(--color-text-primary)",
                }}
              >
                {t.label}
              </button>
            ))}
          </div>
        </div>

        {/* Volume */}
        <div className="flex flex-col gap-2">
          <label
            className="text-sm font-medium"
            style={{ color: "var(--color-text-secondary)" }}
          >
            Volume: {Math.round(volume * 100)}%
          </label>
          <input
            type="range"
            min="0"
            max="1"
            step="0.01"
            value={volume}
            onChange={(e) => setVolume(parseFloat(e.target.value))}
            className="w-full"
          />
        </div>

        {/* Reset */}
        <div className="flex flex-col gap-2 border-t pt-4" style={{ borderColor: "var(--color-border)" }}>
          <button
            onClick={handleReset}
            className="rounded-lg px-4 py-2 text-sm font-medium"
            style={{
              backgroundColor: confirmReset
                ? "var(--color-incorrect)"
                : "var(--color-surface)",
              color: confirmReset
                ? "#ffffff"
                : "var(--color-incorrect)",
              border: confirmReset
                ? "none"
                : "1px solid var(--color-incorrect)",
            }}
          >
            {confirmReset
              ? "Are you sure? This will erase all achievements."
              : "Reset Progress"}
          </button>
          {confirmReset && (
            <button
              onClick={() => setConfirmReset(false)}
              className="text-sm"
              style={{ color: "var(--color-text-secondary)" }}
            >
              Cancel
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
