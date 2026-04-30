# Claude Code / Agentic Architecture for Swiftie Quiz

**Date:** 2026-04-27
**Status:** Design — pending implementation plan
**Scope:** Establish project-scoped Claude Code configuration, subagents, slash commands, hooks, and CI integration to support privacy-centric, secure, and verifiable agentic development on this repo.

---

## 1. Context

Swiftie Quiz is a Tauri 2 desktop trivia game (React 18 + TypeScript strict + Rust 2021) consuming the public Deezer and LRCLIB APIs. The codebase audit on 2026-04-26 surfaced specific recurring risks:

- **DTO schema drift** between Rust models and TS types (most recently `mediumTimer` / `hardTimer` missing from Rust `Default`).
- **Tauri CSP** is load-bearing for the desktop sandbox; an accidental relaxation has user-facing security impact.
- **Engine purity** rule (no React/DOM imports under `src/engine/`) is conventional but not enforced.
- `console.*` calls in production code despite a global rule prohibiting them.
- Manual visual verification is the only end-to-end check; type-checking does not catch UI regressions.

This spec designs the AI/agentic layer that catches these classes of regressions automatically and makes future work safer, faster, and reproducible across machines and CI.

## 2. Goals and non-goals

### Goals

1. Project-scoped Claude Code configuration that overrides global rules where the project demands stricter behavior.
2. Privacy-centric MCP allowlist that blocks data exfiltration vectors not needed by this project.
3. Hook-enforced security guarantees (CSP, secrets) that cannot be bypassed by accident.
4. Project-aware subagents that produce findings a generic reviewer would miss.
5. Low-friction slash commands for the most common multi-file workflows.
6. CI integration that reproduces local review verdicts on every PR.
7. A first concrete task that exercises every component end-to-end as a smoke test.

### Non-goals

- Replacing existing global rules at `~/.claude/rules/`. The project layer extends, never duplicates.
- Adding Playwright/E2E tests. Current Vitest + Rust unit coverage is sufficient at this stage.
- Introducing additional MCP servers. The architecture works with what is already installed.
- Automating releases beyond version bumping and PR creation. Tag pushes and store submissions remain manual.

## 3. Decisions (rationale recap)

| Decision | Choice | Rationale |
|---|---|---|
| Architecture ambition | Full agentic + autonomous quality loop | User-selected Option C; the project is past the prototype phase and warrants permanent scaffolding. |
| MCP egress policy | **Balanced** — block `memory`, `Claude_in_Chrome`, `Claude_Preview`, `fal-ai-media`, `mcp-registry`, `scheduled-tasks`; allow `context7`, `sequential-thinking`, `playwright` (local), GitHub read-only. | Public-data app, no PII. Threat surface is leaking *codebase intent* to third parties. Strict mode is overkill; open-with-audit assumes a discipline that does not survive contact with reality. |
| Hook strictness | **Block security, warn quality** | Security regressions are user-impacting; style violations are not. Style warnings encourage periodic cleanup runs without interrupting flow. |
| Repo persistence | **Commit shared config, ignore personal/transient** | Architecture is useless if it does not ride with the repo (CI loads `settings: ".claude/settings.json"`). Personal overrides + session caches stay local. |

## 4. Architecture overview

```
project-swiftee/
├── CLAUDE.md                          § 5  project memory (slim, inherits global)
├── .claude/
│   ├── settings.json                  § 6  permissions + MCP allowlist + hooks wiring
│   ├── settings.local.json            (gitignored, personal overrides)
│   ├── agents/                        § 7  6 project subagents
│   │   ├── rust-tauri-reviewer.md
│   │   ├── react-tauri-reviewer.md
│   │   ├── tauri-security-reviewer.md
│   │   ├── schema-sync-checker.md
│   │   ├── audio-engine-reviewer.md
│   │   └── vitest-tdd-guide.md
│   ├── commands/                      § 8  6 slash commands
│   │   ├── verify.md
│   │   ├── sync-schemas.md
│   │   ├── review-pr.md
│   │   ├── new-tauri-command.md
│   │   ├── new-achievement.md
│   │   └── release.md
│   ├── hooks/                         § 9  5 hook scripts
│   │   ├── block-secrets.sh
│   │   ├── block-csp-weakening.sh
│   │   ├── warn-console-log.sh
│   │   ├── check-rust-after-edit.sh
│   │   └── stop-reminder.sh
│   └── README.md
├── docs/
│   ├── superpowers/specs/             (this file)
│   ├── superpowers/plans/             (next step: implementation plan)
│   └── decisions/                     ADR-style notes (replaces external "memory" MCP)
└── .github/workflows/
    └── claude-review.yml              § 10 santa-method dual-review on PRs
```

## 5. CLAUDE.md (project memory)

Auto-loaded into every session. Slim — the global rules at `~/.claude/rules/{common,typescript}/*.md` already cover language-agnostic style. This file holds only what is non-derivable about *this* project.

```markdown
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
```

## 6. .claude/settings.json (permissions + MCP firewall + hooks wiring)

Committed to the repo. Inherits from `~/.claude/settings.json` global file; project entries override globals where they conflict.

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",

  "permissions": {
    "allow": [
      "Read", "Glob", "Grep",
      "Edit(src/**)", "Edit(src-tauri/src/**)", "Edit(docs/**)", "Edit(.claude/**)",
      "Write(src/**)", "Write(src-tauri/src/**)", "Write(docs/**)",

      "Bash(npm run dev:*)", "Bash(npm run tauri:*)",
      "Bash(npm test:*)", "Bash(npm run lint:*)", "Bash(npm run build:*)",
      "Bash(cd src-tauri && cargo test:*)",
      "Bash(cd src-tauri && cargo clippy:*)",
      "Bash(cd src-tauri && cargo check:*)",
      "Bash(cd src-tauri && cargo fmt:*)",

      "Bash(git status)", "Bash(git diff:*)", "Bash(git log:*)",
      "Bash(git branch:*)", "Bash(git add:*)", "Bash(git commit:*)",
      "Bash(git push)", "Bash(git pull)",
      "Bash(gh pr:*)", "Bash(gh issue:*)",

      "mcp__context7__*",
      "mcp__plugin_everything-claude-code_context7__*",
      "mcp__sequential-thinking__*",
      "mcp__playwright__*",
      "mcp__plugin_everything-claude-code_playwright__*",
      "mcp__github__list_*",  "mcp__github__get_*",  "mcp__github__search_*",
      "mcp__plugin_everything-claude-code_github__list_*",
      "mcp__plugin_everything-claude-code_github__get_*",
      "mcp__plugin_everything-claude-code_github__search_*"
    ],

    "deny": [
      "Bash(rm -rf:*)",
      "Bash(git push --force:*)", "Bash(git push -f:*)",
      "Bash(git reset --hard:*)", "Bash(git clean -f:*)", "Bash(git branch -D:*)",
      "Bash(npm publish:*)", "Bash(cargo publish:*)",

      "Edit(package-lock.json)", "Edit(src-tauri/Cargo.lock)",
      "Edit(src-tauri/gen/**)", "Edit(node_modules/**)",
      "Edit(dist/**)", "Edit(.git/**)",
      "Write(.env)", "Write(.env.*)", "Edit(.env)", "Edit(.env.*)",

      "mcp__memory__*",
      "mcp__plugin_everything-claude-code_memory__*",
      "mcp__Claude_in_Chrome__*",
      "mcp__Claude_Preview__*",
      "mcp__fal-ai-media__*",
      "mcp__mcp-registry__*",
      "mcp__scheduled-tasks__*",

      "mcp__github__create_*", "mcp__github__update_*",
      "mcp__github__delete_*", "mcp__github__merge_*", "mcp__github__push_*",
      "mcp__plugin_everything-claude-code_github__create_*",
      "mcp__plugin_everything-claude-code_github__update_*",
      "mcp__plugin_everything-claude-code_github__delete_*",
      "mcp__plugin_everything-claude-code_github__merge_*",
      "mcp__plugin_everything-claude-code_github__push_*"
    ]
  },

  "hooks": {
    "PreToolUse": [
      { "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": ".claude/hooks/block-secrets.sh" }] },
      { "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": ".claude/hooks/block-csp-weakening.sh" }] }
    ],
    "PostToolUse": [
      { "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": ".claude/hooks/warn-console-log.sh" }] },
      { "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": ".claude/hooks/check-rust-after-edit.sh" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": ".claude/hooks/stop-reminder.sh" }] }
    ]
  }
}
```

### Block legend

| Block | Effect |
|---|---|
| `permissions.allow` | Everyday safe ops — Claude never prompts. |
| `permissions.deny` | Hard blocks — cannot be overridden in-session. Destructive git, publishes, lockfile/generated edits, four blocked MCPs, GitHub *write* MCP ops. |
| `hooks.PreToolUse` | Runs before Write/Edit. Non-zero exit blocks. Used for secrets + CSP. |
| `hooks.PostToolUse` | Runs after a successful edit. Non-zero exit emits warning, does not block. Used for console.log warnings + Rust incremental check. |
| `hooks.Stop` | Runs at session end — reminds to run `/verify` if source files changed. |

### settings.local.json

A gitignored companion file (`.claude/settings.local.json`) holds personal overrides. Format mirrors `settings.json`. Contents are merged on top of the committed file, allowing per-machine exceptions without polluting the shared posture.

## 7. Subagents (.claude/agents/*.md)

Each agent file is ~30 lines: YAML frontmatter (`name`, `description`, `tools`) followed by a system prompt naming the specific files, patterns, and idioms it should know.

| Agent | Trigger surface | Project-specific knowledge |
|---|---|---|
| **rust-tauri-reviewer** | Rust files change | The `Mutex<ResponseCache>` pattern; rate-limiter token-bucket math; that `AppError::Display` strings ship to the user (must stay friendly); `mockito` is the integration-test pattern. Flags `std::Mutex` held across `.await` boundaries. |
| **react-tauri-reviewer** | `.ts`/`.tsx` change in `src/` | `playVersionRef` epoch-counter idiom for audio race control; `invoke()` calls need `AbortController` on mount; Zustand updates must be spread-based; phase-machine transitions live in `App.tsx:40` and `types/index.ts:30` together. |
| **tauri-security-reviewer** | `tauri.conf.json`, `capabilities/*.json`, or any `connect-src` / `media-src` / `img-src` reference | Allowlisted origins (Deezer CDNs + LRCLIB), `https_only` reqwest config, `dangerousDisableAssetCspModification` is `false` and must stay that way, IPC scope is intentionally narrow. |
| **schema-sync-checker** | `src/types/index.ts` OR `src-tauri/src/models/*.rs` changes | The four places that must move together: TS interface, TS `DEFAULT_PROGRESS`, Rust struct, Rust `impl Default`. The audit's `mediumTimer`/`hardTimer` drift is this agent's reference test case. |
| **audio-engine-reviewer** | `clipSelector.ts`, `lyricProcessor.ts`, `useAudio.ts`, `relistenSchedule.ts` change | RMS-profile + Gaussian-bias + danger-zone scoring contract; `FULL_CLIP_THRESHOLD` is derived (don't hardcode); `playVersionRef` race-defeat pattern; AudioContext lifecycle. |
| **vitest-tdd-guide** | Proactive — when starting any new feature/bugfix in `src/` | Vitest + jsdom + Testing Library setup; engine-purity rule (engine tests must not need React mocks); location of `src/test-setup.ts`. Writes failing test → minimal impl → green → coverage check. |

These are project-specialized variants of the global agents under `~/.claude/agents/`; the global agents remain available as fallbacks for non-project work.

## 8. Slash commands (.claude/commands/*.md)

| Command | Behavior | Why it earns a slot |
|---|---|---|
| **`/verify`** | Sequentially: `tsc --noEmit` → `npm run lint` → `npm test` → `cd src-tauri && cargo clippy -- -D warnings && cargo test`. Stops at first failure; reports concretely. | Single command for "is this actually done?" Used by the Stop hook reminder. |
| **`/sync-schemas`** | Dispatches `schema-sync-checker` against `git diff HEAD`. Returns a punch list of mismatches across the four DTO sites. | Schema drift is the #1 historical bug — one-keystroke trigger after every DTO edit. |
| **`/review-pr [pr-number]`** | Dispatches `rust-tauri-reviewer` + `react-tauri-reviewer` + `tauri-security-reviewer` in **parallel** (single-message multi-tool-call), then runs santa-method convergence loop until all three sign off. With no arg = uncommitted diff; with PR# = `gh pr diff`. | Autonomous quality loop. Independent perspectives, harder to game. |
| **`/new-tauri-command <name>`** | Scaffolds: rust handler stub in the right `commands/*.rs`; registration line in `lib.rs:15`; mockito test; FE hook in the `useDeezer.ts` pattern; TS types in `types/index.ts`. | Adding a command touches 5 files in 4 conventions. |
| **`/new-achievement <id> "<description>"`** | Scaffolds: entry in `ACHIEVEMENT_DEFS`; evaluator case in `useAchievements.ts`; cat SVG placeholder; unit test; optional stat field if needed. | Same multi-file fan-out reasoning. |
| **`/release [patch\|minor\|major]`** | Bumps version in `package.json` + `Cargo.toml` + `tauri.conf.json`; writes CHANGELOG entry from commits since last tag; runs `/verify`; opens a release PR. Never pushes tags. | Version drift between the three manifests is silent and mean. |

## 9. Hook scripts (.claude/hooks/*.sh)

All scripts: read tool-call JSON from stdin via `jq`, signal via exit code, fast.

### 9.1 block-secrets.sh — PreToolUse, blocks

```bash
#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
content=$(echo "$input" | jq -r '.tool_input.content // .tool_input.new_string // ""')
[[ -z "$content" ]] && exit 0

patterns=(
  'sk-[A-Za-z0-9]{32,}'
  'Bearer [A-Za-z0-9_\-\.]{20,}'
  'AKIA[0-9A-Z]{16}'
  'ghp_[A-Za-z0-9]{36}'
  'github_pat_[A-Za-z0-9_]{82}'
  '(API_KEY|SECRET|PASSWORD|TOKEN)[[:space:]]*[:=][[:space:]]*['\''"][^'\''"]{16,}['\''"]'
)
for pat in "${patterns[@]}"; do
  if echo "$content" | grep -qE "$pat"; then
    echo "BLOCKED: edit contains a secret matching: $pat" >&2
    echo "If false-positive: override in .claude/settings.local.json, or move to .env" >&2
    exit 1
  fi
done
exit 0
```

### 9.2 block-csp-weakening.sh — PreToolUse, blocks

```bash
#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
file=$(echo "$input" | jq -r '.tool_input.file_path // ""')
case "$file" in
  *src-tauri/tauri.conf.json|*src-tauri/capabilities/*.json) ;;
  *) exit 0 ;;
esac
content=$(echo "$input" | jq -r '.tool_input.content // .tool_input.new_string // ""')

violations=()
echo "$content" | grep -qE '"dangerousDisableAssetCspModification"[[:space:]]*:[[:space:]]*true' \
  && violations+=("dangerousDisableAssetCspModification flipped to true")
echo "$content" | grep -qE "unsafe-(eval|inline)" \
  && violations+=("CSP contains unsafe-eval or unsafe-inline")
echo "$content" | grep -qE "default-src[^;]*[[:space:]]\\*([[:space:]]|;|\\\"|$)" \
  && violations+=("CSP default-src wildcard '*'")

for origin in "https://lrclib.net" "https://api.deezer.com" "dzcdn.net"; do
  echo "$content" | grep -qF "$origin" || violations+=("Required origin removed: $origin")
done

if (( ${#violations[@]} > 0 )); then
  echo "BLOCKED: Tauri security regression in $file" >&2
  printf '  - %s\n' "${violations[@]}" >&2
  echo "Document justification in docs/decisions/ before retrying." >&2
  exit 1
fi
exit 0
```

### 9.3 warn-console-log.sh — PostToolUse, warns

```bash
#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
file=$(echo "$input" | jq -r '.tool_input.file_path // ""')
case "$file" in
  *src/*.ts|*src/*.tsx) ;;
  *) exit 0 ;;
esac
case "$file" in
  *.test.ts|*.test.tsx|*test-setup*) exit 0 ;;
esac
if grep -nE 'console\.(log|warn|error|debug|info)' "$file" >/dev/null 2>&1; then
  echo "WARNING: console.* in $file (project rule 4 — tests only):" >&2
  grep -nE 'console\.(log|warn|error|debug|info)' "$file" >&2
fi
exit 0
```

### 9.4 check-rust-after-edit.sh — PostToolUse, warns

```bash
#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
file=$(echo "$input" | jq -r '.tool_input.file_path // ""')
case "$file" in *src-tauri/src/*.rs) ;; *) exit 0 ;; esac
cd "$(git rev-parse --show-toplevel)/src-tauri"
if ! out=$(cargo check --message-format=short 2>&1); then
  echo "cargo check failed after edit to $file:" >&2
  echo "$out" | tail -30 >&2
fi
exit 0
```

### 9.5 stop-reminder.sh — Stop, warns

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)" 2>/dev/null || exit 0
if ! git diff --quiet -- src/ src-tauri/src/ 2>/dev/null \
   || ! git diff --cached --quiet -- src/ src-tauri/src/ 2>/dev/null; then
  echo "Source files changed this session. Run /verify before claiming done." >&2
fi
exit 0
```

> **Known limitation (theoretical):** when invoked outside a git working tree, `git rev-parse --show-toplevel` writes to stderr and `cd ""` becomes a no-op, so execution falls through to `git diff` (which then fails). The script still exits 0 (Stop hooks must be non-blocking) and the spurious reminder is harmless. In practice the hook always fires inside the project repo, so this case is unreachable. A defensive variant would be `root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0; cd "$root"`.

### Dependencies

`jq` (for hook stdin parsing) and a Rust toolchain (already required by the project). The implementation plan's setup script will check both.

## 10. CI integration (.github/workflows/claude-review.yml)

Runs the same santa-method dual-review on every PR via the Claude Agent SDK headless API. Posts a single sticky comment to the PR with the consolidated review.

```yaml
name: Claude PR Review
on:
  pull_request:
    types: [opened, synchronize, reopened]
    paths:
      - 'src/**'
      - 'src-tauri/src/**'
      - 'src-tauri/tauri.conf.json'
      - 'src-tauri/capabilities/**'

permissions:
  contents: read
  pull-requests: write

jobs:
  review:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Claude reviewers
        uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          settings: ".claude/settings.json"
          use_sticky_comment: "true"
          claude_args: |
            --allowed-tools "Read,Glob,Grep,Bash(git diff:*),Bash(gh pr diff:*),Bash(git log:*)"
          prompt: |
            Run /review-pr ${{ github.event.pull_request.number }}.
            Post a single consolidated review comment to the PR.
            If any CRITICAL findings, request changes; otherwise approve or comment.
```

### CI safety properties

1. `settings: ".claude/settings.json"` — Action loads project settings from the committed file, including the same MCP allowlist + permissions as locally. (Note: the action's `settings` input takes either a JSON string or a path to a settings file; do NOT use `setting_sources` — that input does not exist on the published action.)
2. `claude_args: --allowed-tools "..."` is narrower than local — CI gets Read/Grep + diff-only Bash. No Edit/Write capability even if the prompt asked. (The action does NOT have a top-level `allowed_tools` input; allowed-tools is passed through `claude_args`.)
3. `use_sticky_comment: true` posts (and updates) a single consolidated review comment per PR — no separate sticky-comment action needed.
3. `ANTHROPIC_API_KEY` is the only required secret.
4. Path filter — Action does not run on PRs that touch only docs/CI/icons.

## 11. .gitignore additions

```gitignore
# Claude Code — personal/transient only
.claude/settings.local.json
.claude/sessions/
.claude/state/
.claude/cache/
.claude/*.log
.claude/audit.log

# Superpowers — working drafts only
docs/superpowers/scratch/
docs/superpowers/**/*-wip.md
```

The structural layer (`.claude/settings.json`, `.claude/agents/`, `.claude/commands/`, `.claude/hooks/`, `.claude/README.md`, `docs/superpowers/specs/`, `docs/superpowers/plans/`) is **committed** so the architecture rides with the repo and CI works.

## 12. Validation task (smoke test)

The architecture is unproven until a real change exercises every component. The audit surfaced a perfect candidate: the `GameSettings` schema drift between Rust and TypeScript.

### The bug

| Layer | File | Has `mediumTimer` / `hardTimer`? |
|---|---|---|
| TS interface | src/types/index.ts:106 | yes |
| TS `DEFAULT_PROGRESS` | src/types/index.ts:134 | yes |
| Rust struct | src-tauri/src/models/progress.rs:36 | no |
| Rust `impl Default` | src-tauri/src/models/progress.rs:53 | no |

Currently masked by client-side default merging in `usePersistence.ts:15`. Latent: any future Rust caller using `GameProgress::default()` directly emits `null` timers over IPC, producing `NaN` in `<input type="range">`.

### Walkthrough

1. **`/sync-schemas`** — should report drift with the four file references above.
2. **Invoke `vitest-tdd-guide`** — write a failing test in `progress.rs` asserting `default().settings.medium_timer == 30` and `hard_timer == 20`.
3. **Edit `progress.rs`** — add `medium_timer: u32`, `hard_timer: u32` to the struct + the `Default` impl. PostToolUse `check-rust-after-edit.sh` fires (passes); PreToolUse `block-secrets.sh` and `block-csp-weakening.sh` fire (do not block — proves no false-positive).
4. **`cd src-tauri && cargo test progress`** — failing test now green.
5. **`/verify`** — full suite passes.
6. **`/review-pr`** — three reviewers in parallel converge in one iteration.
7. **Commit + push** — GH Action reproduces local verdict, sticky-comments PR.
8. **Session ends without `/verify`** (test scenario) — Stop hook reminds.

### Acceptance criteria

- All five hooks fire only when expected.
- Each subagent surfaces at least one finding it could only have made because it knows project-specific patterns.
- `/review-pr` converges within one iteration on this small change.
- CI run reproduces local result.
- No denied MCP attempted (verified by absence in `.claude/audit.log` if logging is enabled).
- Total wall-clock time from `/sync-schemas` to merged PR ≤ 20 minutes.

If any criterion fails, the architecture has a defect — not the bug being fixed.

### Failure modes and remedies

| Symptom | Likely cause | Fix |
|---|---|---|
| `schema-sync-checker` does not see drift | Subagent prompt lacks the four-place enumeration | Edit `.claude/agents/schema-sync-checker.md` to name the four locations explicitly |
| Hook fires on the wrong file | `case` glob in the script is wrong | Test the glob in isolation |
| CI reviewer disagrees with local reviewer | `settings:` path not resolving to .claude/settings.json | Confirm the file exists in the PR's tree; pin Action to a known-good version |
| `/review-pr` runs sequentially | Dispatch not using single-message multi-tool-call | Edit command file to use parallel-dispatch pattern |

## 13. Open questions

None — all scope-defining decisions resolved during brainstorming. Implementation plan (next deliverable) breaks this design into ordered, independently-mergeable PRs.

## 14. Out-of-scope follow-ups

- Playwright E2E once the app reaches a multi-user beta.
- A `/visual-verify` slash command that drives `npm run tauri dev` via the local Playwright MCP for UI regression checks.
- Migrating `~/.claude/rules/` content into a shared subagent rather than a parallel rules file.
