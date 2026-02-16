import { useEffect } from "react";
import { useGameStore } from "../stores/gameStore";
import { ACHIEVEMENT_DEFS } from "../engine/achievements";

export function AchievementToasts() {
  const pendingToasts = useGameStore((s) => s.pendingToasts);
  const dismissToast = useGameStore((s) => s.dismissToast);

  return (
    <div className="pointer-events-none fixed right-4 top-4 z-50 flex flex-col gap-2">
      {pendingToasts.map((id) => (
        <Toast key={id} achievementId={id} onDismiss={() => dismissToast(id)} />
      ))}
    </div>
  );
}

function Toast({
  achievementId,
  onDismiss,
}: {
  readonly achievementId: string;
  readonly onDismiss: () => void;
}) {
  const def = ACHIEVEMENT_DEFS.find((d) => d.id === achievementId);

  useEffect(() => {
    const timer = setTimeout(onDismiss, 4000);
    return () => clearTimeout(timer);
  }, [onDismiss]);

  if (!def) return null;

  return (
    <div
      className="pointer-events-auto flex animate-slide-in items-center gap-3 rounded-lg p-4 shadow-lg"
      style={{
        backgroundColor: "var(--color-surface)",
        border: "1px solid var(--color-accent)",
      }}
    >
      <span className="text-3xl">🐱</span>
      <div>
        <p
          className="text-sm font-bold"
          style={{ color: "var(--color-accent)" }}
        >
          {def.name}
        </p>
        <p
          className="text-xs"
          style={{ color: "var(--color-text-secondary)" }}
        >
          {def.description}
        </p>
      </div>
      <button
        onClick={onDismiss}
        className="ml-2 text-sm"
        style={{ color: "var(--color-text-secondary)" }}
      >
        ✕
      </button>
    </div>
  );
}
