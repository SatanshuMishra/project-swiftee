import type { AchievementDef } from "../types";

export const ACHIEVEMENT_DEFS: readonly AchievementDef[] = [
  {
    id: "first_meow",
    name: "First Meow",
    description: "Get 1 correct answer",
    catFile: "first_meow.svg",
  },
  {
    id: "getting_warmed_up",
    name: "Getting Warmed Up",
    description: "Get 10 correct answers (all-time)",
    catFile: "getting_warmed_up.svg",
  },
  {
    id: "purrfect_streak",
    name: "Purrfect Streak",
    description: "Get 10 correct in a row",
    catFile: "purrfect_streak.svg",
  },
  {
    id: "album_explorer",
    name: "Album Explorer",
    description: "Play songs from 5 different albums",
    catFile: "album_explorer.svg",
  },
  {
    id: "album_completionist",
    name: "Album Completionist",
    description: "Guess every track on an album",
    catFile: "album_completionist.svg",
  },
  {
    id: "hard_mode_hero",
    name: "Hard Mode Hero",
    description: "Get 5 correct on Hard difficulty",
    catFile: "hard_mode_hero.svg",
  },
  {
    id: "speed_demon",
    name: "Speed Demon",
    description: "Answer correctly within 3 seconds",
    catFile: "speed_demon.svg",
  },
  {
    id: "persistent_listener",
    name: "Persistent Listener",
    description: 'Use "Play full clip" and still get it right',
    catFile: "persistent_listener.svg",
  },
  {
    id: "quack_collector",
    name: "Quack Collector",
    description: "Trigger the level 5 quack explosion",
    catFile: "quack_collector.svg",
  },
  {
    id: "all_ears",
    name: "All Ears",
    description: "Correctly guess 50 songs (all-time)",
    catFile: "all_ears.svg",
  },
];
