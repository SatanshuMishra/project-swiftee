import { useGameStore } from "../stores/gameStore";
import { ACHIEVEMENT_DEFS } from "../engine/achievements";

export function CatGallery() {
  const setPhase = useGameStore((s) => s.setPhase);
  const achievements = useGameStore((s) => s.progress.achievements);

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
          Cat Gallery
        </h2>
        <div className="w-12" />
      </div>

      <div className="grid grid-cols-2 gap-6 sm:grid-cols-3 md:grid-cols-5">
        {ACHIEVEMENT_DEFS.map((def) => {
          const state = achievements[def.id];
          const unlocked = state?.unlocked ?? false;

          return (
            <div
              key={def.id}
              className="flex flex-col items-center gap-2 rounded-xl p-4"
              style={{
                backgroundColor: "var(--color-surface)",
                border: "1px solid var(--color-border)",
                opacity: unlocked ? 1 : 0.4,
              }}
            >
              <div className="flex h-24 w-24 items-center justify-center rounded-lg text-4xl">
                {unlocked ? "🐱" : "❓"}
              </div>
              <span
                className="text-center text-sm font-medium"
                style={{ color: "var(--color-text-primary)" }}
              >
                {unlocked ? def.name : "???"}
              </span>
              <span
                className="text-center text-xs"
                style={{ color: "var(--color-text-secondary)" }}
              >
                {unlocked
                  ? def.description
                  : "Keep playing to unlock."}
              </span>
              {unlocked && state?.unlockedAt && (
                <span
                  className="text-xs"
                  style={{ color: "var(--color-text-secondary)" }}
                >
                  {new Date(state.unlockedAt).toLocaleDateString()}
                </span>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
