import { useEffect } from "react";
import { useGameStore } from "./stores/gameStore";
import { usePersistence } from "./hooks/usePersistence";
import { MainMenu } from "./components/MainMenu";
import { AlbumGrid } from "./components/AlbumGrid";
import { DifficultySelect } from "./components/DifficultySelect";
import { GameScreen } from "./components/GameScreen";
import { QuizTypeSelect } from "./components/QuizTypeSelect";
import { LyricsModeSelect } from "./components/LyricsModeSelect";
import { LyricsLoadingScreen } from "./components/LyricsLoadingScreen";
import { LyricsGameScreen } from "./components/LyricsGameScreen";
import { CatGallery } from "./components/CatGallery";
import { Settings } from "./components/Settings";
import { AchievementToasts } from "./components/AchievementToast";

function useTheme() {
  const theme = useGameStore((s) => s.progress.settings.theme);

  useEffect(() => {
    const root = document.documentElement;

    if (theme === "system") {
      const prefersDark = window.matchMedia(
        "(prefers-color-scheme: dark)",
      ).matches;
      root.classList.toggle("light", !prefersDark);
    } else {
      root.classList.toggle("light", theme === "light");
    }
  }, [theme]);
}

export function App() {
  const phase = useGameStore((s) => s.phase);
  const quizType = useGameStore((s) => s.quizType);

  useTheme();
  usePersistence();

  const renderPhase = () => {
    switch (phase) {
      case "menu":
        return <MainMenu />;
      case "album-select":
        return <AlbumGrid />;
      case "quiz-type-select":
        return <QuizTypeSelect />;
      case "lyrics-mode-select":
        return <LyricsModeSelect />;
      case "difficulty-select":
        return <DifficultySelect />;
      case "lyrics-loading":
        return <LyricsLoadingScreen />;
      case "playing":
        return quizType === "lyrics" ? <LyricsGameScreen /> : <GameScreen />;
      case "cat-gallery":
        return <CatGallery />;
      case "settings":
        return <Settings />;
    }
  };

  return (
    <div className="min-h-screen bg-background">
      {renderPhase()}
      <AchievementToasts />
    </div>
  );
}
