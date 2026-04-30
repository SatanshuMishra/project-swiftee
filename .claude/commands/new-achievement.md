---
description: Scaffold a new cat-themed achievement — definition, evaluator case, SVG placeholder, unit test.
argument-hint: "<achievement_id> \"<description>\""
---

You are adding an achievement.

Parse `$ARGUMENTS` into `<id>` (snake_case) and `"<description>"` (quoted). If parsing fails, ask the user for both.

## Files to modify

1. **`src/engine/achievements.ts`** — append to `ACHIEVEMENT_DEFS`:
   ```ts
   {
     id: "<id>",
     name: "<Title Case Name>",  // ask user if not derivable
     description: "<description>",
     catFile: "<id>.svg",
   },
   ```

2. **`src/hooks/useAchievements.ts`** — add a `case "<id>":` to `evaluateCondition` switch. Ask the user what condition unlocks it. Common patterns:
   - Cumulative count: `return ctx.progress.stats.<field> >= N;`
   - Streak: `return ctx.streak >= N;`
   - Difficulty-gated: `return ctx.difficulty === "hard" && ...;`
   - Speed: `return ctx.timeElapsed <= MS;`

3. **`src/assets/cats/<id>.svg`** — placeholder SVG (64x64). The user will replace with art:
   ```svg
   <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
     <rect width="64" height="64" fill="#888"/>
     <text x="32" y="36" text-anchor="middle" font-size="10" fill="#fff"><id></text>
   </svg>
   ```

4. **`src/engine/achievements.test.ts`** — add a test asserting the new ID appears in `ACHIEVEMENT_DEFS`.

5. **`src/hooks/useAchievements.test.ts`** (or create) — add a test that the evaluator unlocks under the documented condition.

6. **If the achievement requires a new stat field**, also touch:
   - `src/types/index.ts` `GameStats` interface and `DEFAULT_PROGRESS.stats`
   - `src-tauri/src/models/progress.rs` `GameStats` struct + `Default` impl
   - Increment logic in the relevant store action

7. **Run `/sync-schemas`** if you touched stats.

8. **Run `/verify`**.
