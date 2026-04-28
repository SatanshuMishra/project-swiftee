# Swiftie Quiz — Project Instructions

Tauri 2 desktop trivia game (React 18 + TS strict + Rust 2021) using public Deezer
and LRCLIB APIs. No user PII, no auth.

## Stack
React 18 · TypeScript strict · Zustand · Tailwind v4 · Vite 6 · Motion · Vitest
Rust 2021 · Tauri 2 · tokio · reqwest (rustls) · serde · mockito

## Commands
- `npm run dev` / `npm run tauri dev` (use the latter for visual verification)
- `npm test` / `npm run lint`
- `cd src-tauri && cargo test`
- `cd src-tauri && cargo clippy -- -D warnings`

## Architecture (one-screen tour)
- 7 Tauri commands in src-tauri/src/commands/{deezer,lyrics,storage}.rs (registered in lib.rs:15)
- Single Zustand store at src/stores/gameStore.ts — all state, immutable updates only
- Pure game logic in src/engine/ — testable without React/jsdom/AudioContext
- Side effects (audio, IPC, persistence) confined to src/hooks/
- Rust DTOs in src-tauri/src/models/ mirror TS types in src/types/index.ts (camelCase via serde)

## Project-specific rules (extend ~/.claude/rules globals)
1. **DTO sync is mandatory.** Editing src/types/index.ts OR src-tauri/src/models/*.rs
   requires updating BOTH sides AND DEFAULT_PROGRESS (TS) AND Default for GameProgress (Rust).
   Schema drift is the #1 historical bug source. Run `/sync-schemas` after.
2. **Tauri CSP is load-bearing.** Never weaken tauri.conf.json security.csp.
   Hook will block such edits.
3. **Game logic stays pure.** src/engine/* must not import React or DOM APIs.
4. **No console.log in src/ production code.** Tests only. Hook will warn.
5. **Visual verification required for UI work.** `npm run tauri dev` + exercise the
   flow before claiming done. Type-check passing ≠ feature works.

## Where to look
| I want to...                    | Look at... |
|---------------------------------|------------|
| Add a Tauri command             | src-tauri/src/commands/ + register in lib.rs:15 |
| Add an achievement              | engine/achievements.ts + useAchievements.ts + cat SVG |
| Add a game phase/screen         | types/index.ts:30 union + App.tsx:40 switch + new component |
| Change save format              | bump version in progress.rs:44 + migration in storage.rs:56 |
| Fix smart-clip behaviour        | engine/clipSelector.ts + lib/lrclib.ts |

## Preferred skills (project-scoped)
- `/verify`         — full check suite before claiming done
- `/sync-schemas`   — diffs Rust↔TS DTOs (catches rule-1 violations)
- `/review-pr`      — santa-method dual-review on uncommitted changes
- `/new-tauri-command <name>` — scaffolds command + handler + test + FE hook

## Skills to skip here
- `e2e-testing` (Playwright) — premature; current Vitest coverage suffices.
- `brainstorming` for trivial fixes — overkill.

## Privacy
.claude/settings.json blocks `memory` and `Claude_in_Chrome` MCPs. For cross-session
notes, write markdown to docs/decisions/ — don't reach for external memory.
