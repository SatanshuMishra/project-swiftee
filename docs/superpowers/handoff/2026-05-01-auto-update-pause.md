# Auto-Update Implementation — Paused 2026-05-01

**Branch:** `feat/auto-update-system`
**Plan:** [docs/superpowers/plans/2026-05-01-auto-update-system.md](../plans/2026-05-01-auto-update-system.md)
**Spec:** [docs/superpowers/specs/2026-04-30-auto-update-system-design.md](../specs/2026-04-30-auto-update-system-design.md)
**Execution skill:** `superpowers:subagent-driven-development`

---

## Where we are

| Phase | Tasks | Status |
|---|---|---|
| **Phase 1: Storage refactor** | 1–6 | ✅ Implemented · ✅ Spec-compliance review · ✅ Code-quality review (Approved with minor follow-ups). Committed at `d3aff08`. |
| Phase 2: Schema bump v2→v3 | 7–8 | ⏸ Pending |
| Phase 3: Plugin integration | 9–12 | ⏸ Pending |
| Phase 4: Hook + store slice | 13–16 | ⏸ Pending |
| Phase 5: UI components + Settings | 17–20 | ⏸ Pending |
| Phase 6: First-launch-after-upgrade UX | 21 | ⏸ Pending |
| Phase 7: CI release pipeline | 22 | ⏸ Pending |
| Phase 8: Docs (CHANGELOG / INSTALL / README) | 23–25 | ⏸ Pending |
| Phase 9: Pre-release version bump | 26 | ⏸ Pending |
| Final code review across full implementation | — | ⏸ Pending |
| Operator handoff: Task 27 (manual swap test + tag + publish) | 27 | ⏸ Pending |

### Branch state at pause

- **`main`** at `bc05ebe` — spec + plan committed (no implementation).
- **`feat/auto-update-system`** at `d3aff08` (1 commit ahead of main).
  - Working tree clean.
  - 74/74 cargo tests pass.
  - `cargo clippy -- -D warnings` clean.
  - **Frontend cannot boot the app right now** — `load_progress` IPC return type changed from `GameProgress` to `LoadResult`; the frontend won't be updated until Phase 6/Task 21. This is expected mid-feature-branch and is documented in the plan.

### Phase 1 commit

```
d3aff08 refactor: extract storage logic into dedicated module
```

Created files:
- `src-tauri/src/storage/mod.rs`
- `src-tauri/src/storage/save.rs`
- `src-tauri/src/storage/migrations.rs`
- `src-tauri/src/storage/backup.rs`
- `src-tauri/src/storage/load.rs`

Modified files:
- `src-tauri/src/commands/storage.rs` (slimmed to thin wrappers)
- `src-tauri/src/lib.rs` (registered `pub mod storage;` + 2 new commands)
- `src-tauri/src/models/error.rs` (added `MissingMigration(u32)` variant)

---

## Code-quality reviewer follow-ups (from Phase 1 review)

The code reviewer approved Phase 1 with minor follow-ups. These are NOT blockers — they're improvements worth folding in either as a small "Phase 1.5" cleanup or while doing Phase 2 (schema bump touches the same migration file).

### Important (worth addressing before Phase 6)

- **I-1.** `from_version` ambiguity when the `version` field is missing in the save file. Currently `unwrap_or(1)` treats "missing version" identically to "explicitly v1" — both surface as `Migrated { from_version: 1 }`. Consider `Option<u32>` for `from_version`, or a `LoadResult::Corrupted` variant, so the frontend toast in Phase 6 can say "version unknown" rather than misleadingly say "v1." Files: [src-tauri/src/storage/load.rs:26-29](../../../src-tauri/src/storage/load.rs), [src-tauri/src/storage/migrations.rs:14-18](../../../src-tauri/src/storage/migrations.rs).
- **I-2.** `load_and_migrate` does not handle `from_version > CURRENT_VERSION` (downgrade scenario — e.g., user manually reinstalls an older version after an auto-update). Currently falls through to `else` branch and tries to deserialize a newer-shape `GameProgress` which may silently drop fields or fail confusingly. Recommend an explicit `AppError::FutureSaveVersion(u32)` guard. Spec §7 doesn't strictly require it, but the migration story is incomplete without it. File: [src-tauri/src/storage/load.rs:31-39](../../../src-tauri/src/storage/load.rs).
- **I-3.** `load_and_migrate` clones the migrated `Value` to deserialize while writing the raw `Value` to disk. Better pattern: deserialize first into typed `GameProgress`, then write the typed struct so the on-disk shape is guaranteed to match what `GameProgress` will round-trip. Smaller, cleaner, and forces a forward-compatibility invariant. File: [src-tauri/src/storage/load.rs:34-35](../../../src-tauri/src/storage/load.rs).

### Minor (polish)

- **M-1.** `prune_old_backups` silently swallows `fs::remove_file` errors. Defensible (non-fatal cleanup) but worth a `// WHY` comment per project rules. File: [src-tauri/src/storage/backup.rs:82](../../../src-tauri/src/storage/backup.rs).
- **M-2.** Add a `debug_assert_eq!` to the migration driver verifying each step writes the expected new version into the JSON. Cheap insurance against a future migration step forgetting `state["version"] = json!(N+1)`. File: [src-tauri/src/storage/migrations.rs:13-23](../../../src-tauri/src/storage/migrations.rs).
- **M-3.** Document that `BackupEntry.path` is informational only — `restore_save_backup` reconstructs the path from `timestamp`, not from this field. One-line `// WHY` comment.
- **M-4.** Test gap: no test for `restore_from_backup` failing when the backup file is missing. One-liner to add.

### Reviewer's full report

Available in the agent transcript from the spec/quality review subagents. Both passed Phase 1.

---

## How to resume

1. **Verify branch state:**
   ```bash
   cd /Users/satanshumishra/Documents/DevLabs/project-swiftee
   git status              # expect: on feat/auto-update-system, working tree clean
   git log --oneline main..HEAD   # expect: d3aff08 refactor: extract storage logic ...
   cd src-tauri && cargo test --lib   # expect: 74 passed
   ```

2. **Re-invoke the execution skill:**
   ```
   /superpowers:subagent-driven-development
   ```
   With a prompt like: *"Resume the auto-update implementation. Phase 1 is complete (commit `d3aff08`). Address the code-quality follow-ups I-1, I-2, I-3 from `docs/superpowers/handoff/2026-05-01-auto-update-pause.md` before/during Phase 2, then continue with Phase 2 (Tasks 7–8 in the plan)."*

3. **Or to keep momentum simple:** skip the I-1/I-2/I-3 follow-ups for now and just dispatch Phase 2 directly. The follow-ups are improvements, not bugs. The decision is yours when you pick this up.

4. **Phase 2 scope reminder:** Tasks 7–8 add `UpdaterState` to `GameProgress`, bump schema version 2→3, and add `migrate_v2_to_v3` to the registry. Both Rust (`models/progress.rs`, `storage/migrations.rs`) and TS (`types/index.ts`, `DEFAULT_PROGRESS`) sides change in the same commit per project rule 1.

---

## Plan + spec status

Both unchanged from when execution started. No revisions needed before resuming.

- Plan: `docs/superpowers/plans/2026-05-01-auto-update-system.md` — 27 tasks, no edits since commit `bc05ebe`.
- Spec: `docs/superpowers/specs/2026-04-30-auto-update-system-design.md` — no edits since commit `74f9506`.

---

## What's deliberately not committed

Nothing. The branch is clean. All Phase 1 work is in `d3aff08`. This handoff doc is the only addition to the branch beyond Phase 1.
