import { describe, it, expect } from "vitest";
import { ACHIEVEMENT_DEFS } from "./achievements";

describe("ACHIEVEMENT_DEFS", () => {
  it("has exactly 10 achievements", () => {
    expect(ACHIEVEMENT_DEFS.length).toBe(10);
  });

  it("has unique IDs", () => {
    const ids = ACHIEVEMENT_DEFS.map((a) => a.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it("all have required fields", () => {
    for (const def of ACHIEVEMENT_DEFS) {
      expect(def.id).toBeTruthy();
      expect(def.name).toBeTruthy();
      expect(def.description).toBeTruthy();
      expect(def.catFile).toBeTruthy();
    }
  });

  it("includes all expected achievement IDs", () => {
    const ids = ACHIEVEMENT_DEFS.map((a) => a.id);
    expect(ids).toContain("first_meow");
    expect(ids).toContain("getting_warmed_up");
    expect(ids).toContain("purrfect_streak");
    expect(ids).toContain("album_explorer");
    expect(ids).toContain("album_completionist");
    expect(ids).toContain("hard_mode_hero");
    expect(ids).toContain("speed_demon");
    expect(ids).toContain("persistent_listener");
    expect(ids).toContain("quack_collector");
    expect(ids).toContain("all_ears");
  });
});
