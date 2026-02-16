import { useGameStore } from "../stores/gameStore";

export function MainMenu() {
  const setPhase = useGameStore((s) => s.setPhase);
  const setMode = useGameStore((s) => s.setMode);

  const handleRandom = () => {
    setMode("random");
    setPhase("difficulty-select");
  };

  const handlePickAlbums = () => {
    setMode("album");
    setPhase("album-select");
  };

  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-8">
      <h1
        className="text-5xl font-bold"
        style={{ color: "var(--color-accent)" }}
      >
        Swiftie Quiz
      </h1>

      <div className="flex w-72 flex-col gap-4">
        <MenuButton onClick={handleRandom} label="Random Mode" icon="▶" />
        <MenuButton onClick={handlePickAlbums} label="Pick Albums" icon="♪" />
        <MenuButton
          onClick={() => setPhase("cat-gallery")}
          label="Cat Gallery"
          icon="🐾"
        />
        <MenuButton
          onClick={() => setPhase("settings")}
          label="Settings"
          icon="⚙"
        />
      </div>
    </div>
  );
}

function MenuButton({
  onClick,
  label,
  icon,
}: {
  readonly onClick: () => void;
  readonly label: string;
  readonly icon: string;
}) {
  return (
    <button
      onClick={onClick}
      className="flex items-center justify-center gap-3 rounded-lg px-6 py-4 text-lg font-medium transition-colors"
      style={{
        backgroundColor: "var(--color-surface)",
        border: "1px solid var(--color-border)",
        color: "var(--color-text-primary)",
      }}
    >
      <span>{icon}</span>
      <span>{label}</span>
    </button>
  );
}
