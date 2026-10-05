---
description: Scaffold a new cat-themed achievement — definition, unlock condition, cat SVG, tests.
argument-hint: "<achievement_id> \"<description>\""
---

You are adding an achievement.

Parse `$ARGUMENTS` into `<id>` (snake_case) and `"<description>"` (quoted). If parsing fails, ask the user for both.

## Files to modify

1. **`test/domain/engine/achievements_test.dart`** — first, update the expected count and the expected ID list so the new `<id>` is required. Run `flutter test test/domain/engine/achievements_test.dart` and confirm it fails.

2. **`lib/domain/engine/achievements.dart`** — append to `achievementDefs`:
   ```dart
   AchievementDef(
     id: '<id>',
     name: '<Title Case Name>',
     description: '<description>',
     catFile: '<id>.svg',
   ),
   ```
   Ask the user for the name if it cannot be derived from the ID.

3. **`test/state/achievements_controller_test.dart`** — add a test that `achievementConditionMet('<id>', context)` is true under the unlocking condition and false just short of it. Ask the user what unlocks it. Run it and confirm it fails.

4. **`lib/state/achievements_controller.dart`** — add a `'<id>' => ...` arm to the `switch` in `achievementConditionMet`. Common patterns:
   - Cumulative count: `stats.totalCorrect >= N`
   - Streak: `context.streak >= N`
   - Difficulty-gated: `context.difficulty == Difficulty.hard && ...`
   - Speed: `context.timeElapsed <= const Duration(seconds: N)`

5. **`assets/cats/<id>.svg`** — the cat art. If the user has none yet, add a 64 x 64 placeholder:
   ```svg
   <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
     <rect width="64" height="64" fill="#888"/>
     <text x="32" y="36" text-anchor="middle" font-size="10" fill="#fff"><id></text>
   </svg>
   ```
   Then add the file's SHA-256 to `achievementCatDigests` in `test/scaffold/assets_test.dart`, which checks every bundled cat byte for byte.

6. **If the achievement needs a new stat field**, also touch `GameStats` in `lib/domain/models/progress.dart` (field, constructor, `fromJson`, `toJson`, `copyWith`, equality) and `defaultProgress`, plus the increment in the relevant controller in `lib/state/`. A new field must read as its default when missing so older saves still load; a renamed or removed field needs a save version bump and a step in `lib/data/save/migrations.dart`.

7. **Run `/verify`.**
