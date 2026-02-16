import { describe, it, expect, beforeEach } from "vitest";
import { useGameStore } from "./gameStore";
import type { Track } from "../types";

function makeTrack(id: number): Track {
  return {
    id,
    title: `Track ${id}`,
    titleShort: `Track ${id}`,
    duration: 30,
    preview: "https://example.com/p.mp3",
    artist: { id: 12246, name: "Taylor Swift" },
    album: { id: 100, title: "Album", coverMedium: null },
  };
}

describe("gameStore", () => {
  beforeEach(() => {
    useGameStore.setState(useGameStore.getInitialState());
  });

  it("starts with menu phase", () => {
    expect(useGameStore.getState().phase).toBe("menu");
  });

  it("setPhase updates phase", () => {
    useGameStore.getState().setPhase("settings");
    expect(useGameStore.getState().phase).toBe("settings");
  });

  it("toggleAlbum adds and removes", () => {
    const { toggleAlbum } = useGameStore.getState();
    toggleAlbum(1);
    expect(useGameStore.getState().selectedAlbumIds).toEqual([1]);
    toggleAlbum(2);
    expect(useGameStore.getState().selectedAlbumIds).toEqual([1, 2]);
    toggleAlbum(1);
    expect(useGameStore.getState().selectedAlbumIds).toEqual([2]);
  });

  it("answerCorrect increments streak and resets quackCount", () => {
    const store = useGameStore.getState();
    store.answerIncorrect(); // quackCount = 1
    store.answerIncorrect(); // quackCount = 2
    expect(useGameStore.getState().quackCount).toBe(2);

    const track = makeTrack(1);
    useGameStore.getState().answerCorrect(track);

    const state = useGameStore.getState();
    expect(state.streak).toBe(1);
    expect(state.quackCount).toBe(0);
    expect(state.progress.stats.totalCorrect).toBe(1);
  });

  it("answerIncorrect resets streak and increments quackCount", () => {
    const track = makeTrack(1);
    useGameStore.getState().answerCorrect(track); // streak = 1
    useGameStore.getState().answerIncorrect(); // streak = 0, quack = 1

    const state = useGameStore.getState();
    expect(state.streak).toBe(0);
    expect(state.quackCount).toBe(1);
  });

  it("resetGame returns to menu", () => {
    useGameStore.getState().setPhase("playing");
    useGameStore.getState().resetGame();
    expect(useGameStore.getState().phase).toBe("menu");
    expect(useGameStore.getState().streak).toBe(0);
  });

  it("setTheme updates settings immutably", () => {
    const before = useGameStore.getState().progress;
    useGameStore.getState().setTheme("light");
    const after = useGameStore.getState().progress;

    expect(after.settings.theme).toBe("light");
    expect(before.settings.theme).toBe("dark"); // original unchanged
  });

  it("setVolume updates settings", () => {
    useGameStore.getState().setVolume(0.5);
    expect(useGameStore.getState().progress.settings.volume).toBe(0.5);
  });

  it("tracks albums played in progress", () => {
    const track = makeTrack(1);
    useGameStore.getState().answerCorrect(track);

    const stats = useGameStore.getState().progress.stats;
    expect(stats.albumsPlayed).toContain("100");
    expect(stats.tracksGuessedPerAlbum["100"]).toContain("1");
  });
});
