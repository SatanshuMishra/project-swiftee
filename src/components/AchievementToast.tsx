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
    <div className="pointer-events-auto flex animate-slide-in items-center gap-3 rounded-xl border border-primary/50 bg-card p-4 shadow-lg">
      <span className="text-3xl">🐱</span>
      <div>
        <p className="text-sm font-bold text-foreground">{def.name}</p>
        <p className="text-xs text-muted-foreground">{def.description}</p>
      </div>
      <button
        onClick={onDismiss}
        className="ml-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
      >
        &#10005;
      </button>
    </div>
  );
}
