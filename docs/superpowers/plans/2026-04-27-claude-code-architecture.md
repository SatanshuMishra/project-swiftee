# Claude Code Agentic Architecture — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a project-scoped Claude Code agentic architecture (CLAUDE.md, .claude/ permissions+hooks+agents+commands, GitHub Action review, smoke-test bug fix) that catches DTO drift, CSP regressions, and quality issues automatically — without weakening privacy or local DX.

**Architecture:** Seven independently-mergeable PRs, each producing working, useful state on its own. PR1 establishes memory and gitignore. PR2 lands settings + permissions (no hooks yet). PR3 lands hook scripts and wires them. PR4 adds project subagents. PR5 adds slash commands. PR6 adds the GitHub Action. PR7 fixes the GameSettings schema-drift bug as the end-to-end smoke test of all prior PRs.

**Tech Stack:** Markdown (CLAUDE.md, agents, commands, README), JSON (settings.json), Bash + jq (hooks), YAML (GH Action), Rust 2021 (smoke-test fix). Existing project: Tauri 2 + React 18 + TS strict.

**Reference spec:** [docs/superpowers/specs/2026-04-27-claude-code-architecture-design.md](../specs/2026-04-27-claude-code-architecture-design.md)

---

## File Structure

| Path | Created in | Purpose |
|---|---|---|
| `CLAUDE.md` | PR1 | Project memory loaded into every session |
| `.gitignore` (modified) | PR1 | Add Claude/superpowers personal/transient ignores |
| `.claude/README.md` | PR1 | Explains directory contents to a human reader |
| `.claude/settings.json` | PR2 (created), PR3 (hooks block added) | Permissions + MCP firewall + (later) hooks wiring |
| `.claude/settings.local.json.example` | PR2 | Template for personal overrides (file itself gitignored) |
| `.claude/hooks/block-secrets.sh` | PR3 | PreToolUse blocking secret detector |
| `.claude/hooks/block-csp-weakening.sh` | PR3 | PreToolUse blocking CSP guard |
| `.claude/hooks/warn-console-log.sh` | PR3 | PostToolUse warn on console.* in src/ |
| `.claude/hooks/check-rust-after-edit.sh` | PR3 | PostToolUse incremental cargo check |
| `.claude/hooks/stop-reminder.sh` | PR3 | Stop hook reminding to run /verify |
| `.claude/agents/rust-tauri-reviewer.md` | PR4 | Rust + Tauri code review |
| `.claude/agents/react-tauri-reviewer.md` | PR4 | TS + React + IPC code review |
| `.claude/agents/tauri-security-reviewer.md` | PR4 | CSP / capabilities / IPC scope review |
| `.claude/agents/schema-sync-checker.md` | PR4 | DTO drift detector |
| `.claude/agents/audio-engine-reviewer.md` | PR4 | clipSelector / lyricProcessor / useAudio review |
| `.claude/agents/vitest-tdd-guide.md` | PR4 | TDD enforcement for FE work |
| `.claude/commands/verify.md` | PR5 | /verify — run full check suite |
| `.claude/commands/sync-schemas.md` | PR5 | /sync-schemas — drift check via subagent |
| `.claude/commands/review-pr.md` | PR5 | /review-pr — santa-method dual-review |
| `.claude/commands/new-tauri-command.md` | PR5 | /new-tauri-command — scaffold workflow |
| `.claude/commands/new-achievement.md` | PR5 | /new-achievement — scaffold workflow |
| `.claude/commands/release.md` | PR5 | /release — version bump + release PR |
| `.github/workflows/claude-review.yml` | PR6 | Headless santa-method review on PRs |
| `src-tauri/src/models/progress.rs` (modified) | PR7 | Add medium_timer/hard_timer fields + Default |

**Decomposition rationale:** Each PR is self-contained. PR2's `settings.json` works without a `hooks` block — Claude simply has no PostToolUse/PreToolUse handlers. PR3 then adds hooks atop. PR4 (subagents) and PR5 (commands) are additive — agents and commands sitting in `.claude/` without being invoked have no behavior impact. PR6 (CI) is fully orthogonal. PR7 (smoke test) intentionally exercises everything from PRs 1-5.

---

## PR 1 — Foundation: CLAUDE.md, .gitignore, .claude/README

**Branch:** `feat/claude-code-foundation`
**Risk:** Zero. Pure additions and gitignore.
**Validates:** Claude loads CLAUDE.md at session start.

### Task 1.1: Create CLAUDE.md at project root

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: Verify no existing CLAUDE.md**

```bash
test ! -f CLAUDE.md && echo "OK: no existing CLAUDE.md" || echo "EXISTS: review before overwriting"
```
Expected: `OK: no existing CLAUDE.md`

- [ ] **Step 2: Write CLAUDE.md**

Create `CLAUDE.md` with this exact content:

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

- [ ] **Step 3: Verify file written**

```bash
wc -l CLAUDE.md
```
Expected: ~50-60 lines, exit 0.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add CLAUDE.md project memory"
```

### Task 1.2: Update .gitignore

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Read current .gitignore**

```bash
cat .gitignore
```
Note the existing content for the next step's append point.

- [ ] **Step 2: Append Claude + superpowers ignores**

Append the following block to `.gitignore` (do not replace existing content):

```gitignore

# Claude Code — personal/transient only (committed: settings.json, agents/, commands/, hooks/)
.claude/settings.local.json
.claude/sessions/
.claude/state/
.claude/cache/
.claude/*.log
.claude/audit.log

# Superpowers — working drafts only (committed: specs/, plans/)
docs/superpowers/scratch/
docs/superpowers/**/*-wip.md
```

- [ ] **Step 3: Verify the structural files would still be tracked**

```bash
git check-ignore -v .claude/settings.json && echo "BUG: settings.json is ignored" || echo "OK: settings.json not ignored"
git check-ignore -v .claude/agents/foo.md && echo "BUG: agents/ is ignored" || echo "OK: agents/ not ignored"
git check-ignore -v docs/superpowers/specs/foo.md && echo "BUG: specs/ is ignored" || echo "OK: specs/ not ignored"
git check-ignore -v .claude/settings.local.json && echo "OK: local override is ignored" || echo "BUG: local override not ignored"
```
Expected: three `OK: ... not ignored` and one `OK: local override is ignored`.

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore: ignore Claude/superpowers personal and transient files"
```

### Task 1.3: Create .claude/README.md

**Files:**
- Create: `.claude/README.md`

- [ ] **Step 1: Create the file**

```markdown
# .claude/

Project-scoped Claude Code configuration. **Committed** to the repo so the
architecture rides with the codebase.

## Layout

| File / Dir | Status | Purpose |
|---|---|---|
| `settings.json` | committed | Permissions, MCP allowlist/denylist, hooks wiring |
| `settings.local.json` | gitignored | Personal/per-machine overrides |
| `agents/` | committed | Project-aware subagent definitions |
| `commands/` | committed | Slash command definitions (`/verify`, `/review-pr`, ...) |
| `hooks/` | committed | Bash scripts invoked by hooks declared in settings.json |
| `sessions/`, `state/`, `cache/`, `*.log` | gitignored | Transient session data |

## Privacy posture (settings.json)

This project blocks the following MCP servers:
`memory`, `Claude_in_Chrome`, `Claude_Preview`, `fal-ai-media`,
`mcp-registry`, `scheduled-tasks`, and all *write* GitHub MCP operations.

For cross-session notes, write markdown to `docs/decisions/` instead of using
an external memory MCP.

## Hooks (security guards + quality warnings)

| Script | When | Effect on failure |
|---|---|---|
| `block-secrets.sh` | PreToolUse on Write/Edit | Refuses the edit |
| `block-csp-weakening.sh` | PreToolUse on tauri.conf.json / capabilities/* | Refuses the edit |
| `warn-console-log.sh` | PostToolUse on src/*.ts(x) | Warning only |
| `check-rust-after-edit.sh` | PostToolUse on src-tauri/src/*.rs | Warning only |
| `stop-reminder.sh` | Stop | Reminds to run /verify |

## Reference

Architecture rationale: [docs/superpowers/specs/2026-04-27-claude-code-architecture-design.md](../docs/superpowers/specs/2026-04-27-claude-code-architecture-design.md)
```

- [ ] **Step 2: Commit**

```bash
git add .claude/README.md
git commit -m "docs: explain .claude/ directory contents and posture"
```

### Task 1.4: PR for Foundation

- [ ] **Step 1: Push branch and open PR**

```bash
git push -u origin feat/claude-code-foundation
gh pr create --title "feat: Claude Code foundation (CLAUDE.md + .gitignore + .claude/README)" \
  --body "$(cat <<'EOF'
## Summary
- Adds CLAUDE.md project memory (loaded by Claude Code every session)
- Adds .gitignore entries for personal/transient Claude + superpowers files
- Adds .claude/README explaining directory contents

## Test plan
- [ ] CLAUDE.md visible at repo root
- [ ] git check-ignore -v .claude/settings.json returns OK (not ignored)
- [ ] git check-ignore -v .claude/settings.local.json returns ignored
- [ ] Open Claude Code in this repo — confirm CLAUDE.md loads (visible in /memory or session start)

Part 1/7 of [Claude Code architecture spec](docs/superpowers/specs/2026-04-27-claude-code-architecture-design.md).
EOF
)"
```

---

## PR 2 — Settings + permissions (no hooks block yet)

**Branch:** `feat/claude-code-settings`
**Depends on:** PR 1 merged.
**Risk:** Permissions could surprise. Test by starting a session and trying a denied operation.
**Validates:** Permissions allowlist works, MCP denylist enforced.

### Task 2.1: Create .claude/settings.json without hooks

**Files:**
- Create: `.claude/settings.json`

- [ ] **Step 1: Write settings.json (no hooks key)**

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
      "Write(.env)", "Write(.env.*)",

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
  }
}
```

- [ ] **Step 2: Validate JSON**

```bash
jq . .claude/settings.json > /dev/null && echo "OK: valid JSON" || echo "FAIL"
```
Expected: `OK: valid JSON`.

- [ ] **Step 3: Commit**

```bash
git add .claude/settings.json
git commit -m "feat: project permissions and MCP firewall"
```

### Task 2.2: Create .claude/settings.local.json.example

**Files:**
- Create: `.claude/settings.local.json.example`

- [ ] **Step 1: Write the example template**

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "_comment": "Copy to settings.local.json (gitignored) and add per-machine overrides here.",
  "permissions": {
    "allow": [],
    "deny": []
  }
}
```

- [ ] **Step 2: Verify the .local file is gitignored but example is not**

```bash
git check-ignore .claude/settings.local.json && echo "OK: local is ignored" || echo "BUG"
git check-ignore .claude/settings.local.json.example && echo "BUG: example is ignored" || echo "OK: example tracked"
```
Expected: `OK: local is ignored` then `OK: example tracked`.

- [ ] **Step 3: Commit**

```bash
git add .claude/settings.local.json.example
git commit -m "docs: example settings.local.json template"
```

### Task 2.3: Manual smoke test

- [ ] **Step 1: Start Claude Code session in repo and try a denied bash op**

In a new Claude Code session in this repo, ask Claude:
> "Run: rm -rf /tmp/test-permissions"

Expected: Claude reports the operation was denied by the permissions deny list, not executed.

- [ ] **Step 2: Try a denied MCP**

Ask Claude:
> "Use the memory MCP to store a note"

Expected: Claude reports memory MCP tools are unavailable / denied.

- [ ] **Step 3: Try an allowed bash op**

Ask Claude:
> "Run: npm test --silent"

Expected: Claude executes without prompting (or with a single confirm depending on global override).

### Task 2.4: PR for settings

- [ ] **Step 1: Push and PR**

```bash
git push -u origin feat/claude-code-settings
gh pr create --title "feat: project permissions allowlist + MCP denylist" \
  --body "$(cat <<'EOF'
## Summary
- Adds .claude/settings.json with explicit allow/deny for Bash, Edit, Write, MCP servers
- Blocks: memory, Claude_in_Chrome, Claude_Preview, fal-ai-media, mcp-registry, scheduled-tasks
- Blocks: GitHub *write* MCP ops (write goes through normal git, audit trail preserved)
- Allows: context7, sequential-thinking, playwright (local), GitHub *read* MCP ops
- Adds .claude/settings.local.json.example template (the .local itself is gitignored)
- No hooks block yet — added in PR 3 with the scripts

## Test plan
- [ ] jq . .claude/settings.json passes
- [ ] Manual smoke test: denied bash op refused, denied MCP unavailable, allowed bash op works

Part 2/7 of [spec](docs/superpowers/specs/2026-04-27-claude-code-architecture-design.md).
EOF
)"
```

---

## PR 3 — Hook scripts + wire into settings.json

**Branch:** `feat/claude-code-hooks`
**Depends on:** PR 2 merged.
**Risk:** Hooks can mis-fire and block legitimate work. Test each in isolation before wiring.
**Validates:** Each hook fires on the right tool calls and not others.

### Task 3.1: Create hooks directory and verify jq

**Files:** `.claude/hooks/` (created implicitly)

- [ ] **Step 1: Verify jq available**

```bash
command -v jq && jq --version
```
Expected: prints a path and version. If missing, install via `brew install jq` (macOS) or `apt install jq` (Linux).

- [ ] **Step 2: Create directory**

```bash
mkdir -p .claude/hooks
```

### Task 3.2: block-secrets.sh

**Files:**
- Create: `.claude/hooks/block-secrets.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# block-secrets.sh — PreToolUse blocking hook
# Refuses Write/Edit if the new content contains common secret patterns.

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

- [ ] **Step 2: Make executable**

```bash
chmod +x .claude/hooks/block-secrets.sh
```

- [ ] **Step 3: Test — should pass on benign content**

```bash
echo '{"tool_input":{"content":"const x = 42;"}}' | .claude/hooks/block-secrets.sh
echo "exit: $?"
```
Expected: `exit: 0`.

- [ ] **Step 4: Test — should block on a secret**

```bash
echo '{"tool_input":{"content":"const k = \"sk-abcdefghijklmnopqrstuvwxyz0123456789\""}}' | .claude/hooks/block-secrets.sh 2>&1
echo "exit: $?"
```
Expected: `BLOCKED:` line printed and `exit: 1`.

- [ ] **Step 5: Commit**

```bash
git add .claude/hooks/block-secrets.sh
git commit -m "feat: hook to block edits containing secrets"
```

### Task 3.3: block-csp-weakening.sh

**Files:**
- Create: `.claude/hooks/block-csp-weakening.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# block-csp-weakening.sh — PreToolUse blocking hook
# Refuses changes to tauri.conf.json or capabilities/*.json that weaken security.

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
echo "$content" | grep -qE 'default-src[^"]*\*' \
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

- [ ] **Step 2: Make executable**

```bash
chmod +x .claude/hooks/block-csp-weakening.sh
```

- [ ] **Step 3: Test — non-CSP file should pass through**

```bash
echo '{"tool_input":{"file_path":"src/App.tsx","content":"whatever"}}' | .claude/hooks/block-csp-weakening.sh
echo "exit: $?"
```
Expected: `exit: 0`.

- [ ] **Step 4: Test — CSP file with valid content should pass**

```bash
cat src-tauri/tauri.conf.json | jq -c '{tool_input:{file_path:"src-tauri/tauri.conf.json", content:tostring}}' | .claude/hooks/block-csp-weakening.sh
echo "exit: $?"
```
Expected: `exit: 0` (current CSP is compliant).

- [ ] **Step 5: Test — CSP file with weakened content should block**

```bash
echo '{"tool_input":{"file_path":"src-tauri/tauri.conf.json","content":"\"dangerousDisableAssetCspModification\": true"}}' | .claude/hooks/block-csp-weakening.sh 2>&1
echo "exit: $?"
```
Expected: `BLOCKED:` line and `exit: 1`.

- [ ] **Step 6: Commit**

```bash
git add .claude/hooks/block-csp-weakening.sh
git commit -m "feat: hook to block Tauri CSP weakening"
```

### Task 3.4: warn-console-log.sh

**Files:**
- Create: `.claude/hooks/warn-console-log.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# warn-console-log.sh — PostToolUse non-blocking warning
# Flags console.* statements in src/ production code.

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
[[ -f "$file" ]] || exit 0
if grep -nE 'console\.(log|warn|error|debug|info)' "$file" >/dev/null 2>&1; then
  echo "WARNING: console.* in $file (project rule 4 — tests only):" >&2
  grep -nE 'console\.(log|warn|error|debug|info)' "$file" >&2
fi
exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x .claude/hooks/warn-console-log.sh
```

- [ ] **Step 3: Test — should warn on a known-offender file**

```bash
echo '{"tool_input":{"file_path":"src/hooks/useAudio.ts"}}' | .claude/hooks/warn-console-log.sh 2>&1
echo "exit: $?"
```
Expected: `WARNING: console.*` printed, `exit: 0`.

- [ ] **Step 4: Test — should be silent on a clean file**

```bash
echo '{"tool_input":{"file_path":"src/lib/cn.ts"}}' | .claude/hooks/warn-console-log.sh 2>&1
echo "exit: $?"
```
Expected: no output (or no WARNING line), `exit: 0`.

- [ ] **Step 5: Test — should ignore test files**

```bash
echo '{"tool_input":{"file_path":"src/lib/levenshtein.test.ts"}}' | .claude/hooks/warn-console-log.sh 2>&1
echo "exit: $?"
```
Expected: no output, `exit: 0`.

- [ ] **Step 6: Commit**

```bash
git add .claude/hooks/warn-console-log.sh
git commit -m "feat: hook warning on console.* in production src/"
```

### Task 3.5: check-rust-after-edit.sh

**Files:**
- Create: `.claude/hooks/check-rust-after-edit.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# check-rust-after-edit.sh — PostToolUse, non-blocking
# Runs cargo check on the manifest after a Rust file edit.

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

- [ ] **Step 2: Make executable**

```bash
chmod +x .claude/hooks/check-rust-after-edit.sh
```

- [ ] **Step 3: Test — non-Rust file should be no-op**

```bash
echo '{"tool_input":{"file_path":"src/App.tsx"}}' | .claude/hooks/check-rust-after-edit.sh
echo "exit: $?"
```
Expected: `exit: 0`, no output.

- [ ] **Step 4: Test — Rust file should run cargo check (slow first time)**

```bash
echo '{"tool_input":{"file_path":"src-tauri/src/lib.rs"}}' | .claude/hooks/check-rust-after-edit.sh 2>&1
echo "exit: $?"
```
Expected: `exit: 0`, no error output (assuming current code compiles). May take 30s+ first run.

- [ ] **Step 5: Commit**

```bash
git add .claude/hooks/check-rust-after-edit.sh
git commit -m "feat: hook running cargo check after Rust file edits"
```

### Task 3.6: stop-reminder.sh

**Files:**
- Create: `.claude/hooks/stop-reminder.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# stop-reminder.sh — Stop hook
# Reminds Claude to run /verify if there are uncommitted source changes.

set -euo pipefail
cd "$(git rev-parse --show-toplevel)" 2>/dev/null || exit 0
if ! git diff --quiet -- src/ src-tauri/src/ 2>/dev/null \
   || ! git diff --cached --quiet -- src/ src-tauri/src/ 2>/dev/null; then
  echo "Source files changed this session. Run /verify before claiming done." >&2
fi
exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x .claude/hooks/stop-reminder.sh
```

- [ ] **Step 3: Test — clean repo should be silent**

```bash
git stash --include-untracked >/dev/null 2>&1 || true
.claude/hooks/stop-reminder.sh 2>&1
echo "exit: $?"
git stash pop >/dev/null 2>&1 || true
```
Expected: no output, `exit: 0`.

- [ ] **Step 4: Test — dirty src/ should print reminder**

```bash
echo "// scratch" >> src/App.tsx
.claude/hooks/stop-reminder.sh 2>&1
echo "exit: $?"
git checkout -- src/App.tsx
```
Expected: `Source files changed this session.` printed, `exit: 0`.

- [ ] **Step 5: Commit**

```bash
git add .claude/hooks/stop-reminder.sh
git commit -m "feat: stop hook reminding to run /verify"
```

### Task 3.7: Add hooks block to settings.json

**Files:**
- Modify: `.claude/settings.json`

- [ ] **Step 1: Add the hooks key**

Edit `.claude/settings.json`. Append `"hooks": { ... }` after the `"permissions"` block. The closing brace of the file moves down one. Final structure:

```json
{
  "$schema": "...",
  "permissions": { ... },
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

- [ ] **Step 2: Validate JSON**

```bash
jq . .claude/settings.json > /dev/null && echo "OK" || echo "FAIL"
```
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add .claude/settings.json
git commit -m "feat: wire hooks into settings.json"
```

### Task 3.8: PR for hooks

- [ ] **Step 1: Push and PR**

```bash
git push -u origin feat/claude-code-hooks
gh pr create --title "feat: Claude Code hooks (security guards + quality warnings)" \
  --body "$(cat <<'EOF'
## Summary
- 5 bash hooks in .claude/hooks/, all tested in isolation
- block-secrets.sh, block-csp-weakening.sh — PreToolUse blockers
- warn-console-log.sh, check-rust-after-edit.sh — PostToolUse warnings
- stop-reminder.sh — Stop hook
- Wired into settings.json hooks block

## Test plan
- [ ] All 5 scripts have +x permission
- [ ] Each script tested with positive and negative input (see commits)
- [ ] jq . .claude/settings.json passes
- [ ] Try editing tauri.conf.json with dangerousDisableAssetCspModification: true — must be refused
- [ ] Try writing 'sk-' followed by 32+ chars to a file — must be refused
- [ ] Edit src/hooks/useAudio.ts (which has console.error) and confirm warning appears

Part 3/7 of [spec](docs/superpowers/specs/2026-04-27-claude-code-architecture-design.md).
EOF
)"
```

---

## PR 4 — Subagents (.claude/agents/)

**Branch:** `feat/claude-code-subagents`
**Depends on:** PR 2 merged (PR 3 not strictly required, but recommended).
**Risk:** Zero behavior change until invoked.
**Validates:** Each agent loadable; on-demand invocation produces project-aware findings.

> **Each agent file uses YAML frontmatter** with three keys: `name`, `description`, `tools`. Body is the system prompt.

### Task 4.1: rust-tauri-reviewer.md

**Files:**
- Create: `.claude/agents/rust-tauri-reviewer.md`

- [ ] **Step 1: Write the file**

````markdown
---
name: rust-tauri-reviewer
description: Reviews Rust changes in src-tauri/. Knows project-specific patterns (rate limiter, ResponseCache, AppError, mockito). Flags std::Mutex held across .await, non-camelCase serde output, AppError::Display strings that aren't user-friendly. Use after any edit to src-tauri/src/**.
tools: Read, Grep, Glob, Bash
---

You are a project-specific Rust reviewer for the Swiftie Quiz Tauri 2 codebase.

## What you know about this codebase

- **AppState** at `src-tauri/src/state.rs` holds: `deezer_client: DeezerClient`, `lrclib_client: LrclibClient`, `cache: Mutex<ResponseCache>`, `rate_limiter: Mutex<RateLimiter>`. Both `Mutex` are `std::sync::Mutex` (not tokio).
- **ResponseCache** (`services/cache.rs`) is an unbounded `HashMap<String, serde_json::Value>` — no TTL, intentional for desktop session lifetime.
- **RateLimiter** (`services/rate_limiter.rs`) is a 50-token-per-60s token bucket. `try_acquire()` is the only API.
- **AppError** (`models/error.rs`) implements `Display` with **user-facing strings** that ship verbatim to the React UI via serde. Reviewer-friendly messages must remain user-friendly.
- **Track / Album / Artist** (`models/track.rs`) deserialize snake_case from Deezer, serialize camelCase to the frontend.
- **Tests** use `mockito` for HTTP boundaries and `tempfile` for filesystem. Inline `#[cfg(test)] mod tests` at the bottom of each file.
- **Tauri commands** live in `commands/{deezer,lyrics,storage}.rs`, registered in `lib.rs:15` `invoke_handler` macro.

## Hard rules

1. **No `std::Mutex` held across `.await`.** It blocks the tokio runtime worker. Acceptable: brief HashMap ops inside a `{ }` scope before the await.
2. **`AppError::Display` strings are user-facing.** Don't change them to engineer-speak.
3. **`#[serde(rename_all(serialize = "camelCase"))]` on outbound DTOs.** Inbound from Deezer stays snake_case.
4. **Every new `#[tauri::command]` must be registered** in `lib.rs:15` `generate_handler!` macro.
5. **No `unwrap()` in command bodies.** Use `?` with `AppError`.
6. **No new `unsafe` blocks** without explicit justification.

## Output format

Return a numbered list of findings. For each:
- **Severity**: CRITICAL / HIGH / MEDIUM / LOW
- **File:line**
- **Issue**: one sentence
- **Fix**: one sentence
- **Why this matters in this project**: tie back to the rule or pattern

Only flag what you actually see. If no issues, say "Reviewed N files, no findings."
````

- [ ] **Step 2: Verify YAML frontmatter parseable**

```bash
head -5 .claude/agents/rust-tauri-reviewer.md | grep -E '^(name|description|tools):' | wc -l
```
Expected: `3`.

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/rust-tauri-reviewer.md
git commit -m "feat: rust-tauri-reviewer subagent"
```

### Task 4.2: react-tauri-reviewer.md

**Files:**
- Create: `.claude/agents/react-tauri-reviewer.md`

- [ ] **Step 1: Write the file**

````markdown
---
name: react-tauri-reviewer
description: Reviews TS/React changes in src/. Knows project-specific patterns (playVersionRef epoch counter, Zustand spread updates, AbortController on Tauri invoke, phase-machine in App.tsx + types/index.ts). Flags non-immutable Zustand updates, missing AbortController, console.* in production code. Use after any edit to src/**.
tools: Read, Grep, Glob, Bash
---

You are a project-specific React/TS reviewer for the Swiftie Quiz Tauri 2 codebase.

## What you know about this codebase

- **State**: single Zustand store at `src/stores/gameStore.ts`. All updates use spread (`...state.x`); never mutate.
- **Phase machine**: `GamePhase` union in `src/types/index.ts:30` is the source of truth. Every value in the union must have a case in `App.tsx:40`'s `renderPhase` switch.
- **Tauri IPC**: `invoke<T>(commandName, args)` from `@tauri-apps/api/core`. Effects that fire IPC must use `AbortController` + an aborted-check after each await (see `src/components/GameScreen.tsx:78-115` for the pattern).
- **Audio race control**: `useAudio.ts` uses a `playVersionRef` epoch counter; every async stage checks `playVersionRef.current !== version` and bails. Same pattern in `LoadingGate`-style flows.
- **Engine purity rule**: `src/engine/*` MUST NOT import React, `react-dom`, or DOM APIs (`AudioContext`, `document`, `window`). It's pure-function library code, tested in isolation.
- **DTOs**: `src/types/index.ts` mirrors Rust structs. Fields are `readonly`. The interface AND `DEFAULT_PROGRESS` move together.
- **No `console.*` in `src/` production files.** Tests only. Project rule 4.

## Hard rules

1. **Zustand updates are immutable.** No `state.x.push(y)` — use `[...state.x, y]`.
2. **Tauri `invoke()` calls in `useEffect` need `AbortController`.** Otherwise StrictMode double-invoke leaks.
3. **Engine purity.** Files under `src/engine/` may not import from `react`, `react-dom`, or use DOM globals.
4. **Phase additions touch all three places.** `types/index.ts:30` union, `App.tsx:40` switch case, the new component file.
5. **No `console.*` in `src/`** outside `*.test.ts(x)`.
6. **Hook deps arrays** must include all referenced state — do not silence with `eslint-disable` unless commented why.

## Output format

Numbered findings. For each:
- **Severity**: CRITICAL / HIGH / MEDIUM / LOW
- **File:line**
- **Issue**: one sentence
- **Fix**: one sentence
- **Why this matters here**: cite the project rule or pattern

If clean: "Reviewed N files, no findings."
````

- [ ] **Step 2: Commit**

```bash
git add .claude/agents/react-tauri-reviewer.md
git commit -m "feat: react-tauri-reviewer subagent"
```

### Task 4.3: tauri-security-reviewer.md

**Files:**
- Create: `.claude/agents/tauri-security-reviewer.md`

- [ ] **Step 1: Write the file**

````markdown
---
name: tauri-security-reviewer
description: Security-focused review for Tauri config and capabilities. Knows the current CSP allowlist (Deezer + LRCLIB), https_only reqwest config, intentional IPC scope. Flags any CSP weakening, allowlist removal, capability scope expansion, or new IPC surface. Use after any edit to tauri.conf.json or capabilities/*.
tools: Read, Grep, Glob
---

You are the Tauri security reviewer for the Swiftie Quiz desktop app.

## What you know about this codebase

- **CSP** in `src-tauri/tauri.conf.json:25` allows exactly:
  - `default-src 'self'`
  - `media-src https://cdns-preview-*.dzcdn.net https://cdnt-preview.dzcdn.net`
  - `connect-src ipc: http://ipc.localhost https://cdns-preview-*.dzcdn.net https://cdnt-preview.dzcdn.net https://lrclib.net`
  - `img-src 'self' https://api.deezer.com https://*.dzcdn.net`
- **`dangerousDisableAssetCspModification`** is `false` and must stay that way.
- **HTTPS-only reqwest** (`services/deezer_client.rs:26`, `services/lrclib_client.rs:24`) — `https_only(true)`.
- **IPC scope** in `src-tauri/capabilities/default.json` is intentionally narrow.
- **No auth, no PII.** The threat model is: malicious page content could try to phone home or exfiltrate. CSP is the primary defense.

## Hard rules

1. **CSP must contain** `'self'` default, the three Deezer CDN origins, `lrclib.net`, and `ipc:` / `http://ipc.localhost`.
2. **No `unsafe-eval`, `unsafe-inline`, wildcards** (`*` in source lists).
3. **`dangerousDisableAssetCspModification` stays `false`.**
4. **No new IPC capability** without naming the threat it mitigates / introduces.
5. **No HTTP (non-HTTPS) URLs** anywhere — `https_only(true)` would reject them at runtime, fail loudly at review time.
6. **No external script `<script src=...>`** in any HTML.

## Output format

Numbered findings. For each:
- **Severity**: CRITICAL (security regression) / HIGH (capability expansion) / MEDIUM (CSP imprecision) / LOW (style)
- **File:line**
- **Issue**: one sentence
- **Fix**: one sentence

If clean: "Reviewed N files, no security findings."
````

- [ ] **Step 2: Commit**

```bash
git add .claude/agents/tauri-security-reviewer.md
git commit -m "feat: tauri-security-reviewer subagent"
```

### Task 4.4: schema-sync-checker.md

**Files:**
- Create: `.claude/agents/schema-sync-checker.md`

- [ ] **Step 1: Write the file**

````markdown
---
name: schema-sync-checker
description: Detects DTO drift between Rust models in src-tauri/src/models/ and TS types in src/types/index.ts. Specifically validates the four-place rule for GameProgress / GameSettings / GameStats. Use after any edit to either side, or invoked by /sync-schemas command.
tools: Read, Grep, Glob, Bash
---

You are the schema-sync checker. Your job is to ensure four sites stay aligned for any DTO that crosses the IPC boundary.

## The four sites (for GameProgress and its nested types)

1. **Rust struct definition** in `src-tauri/src/models/progress.rs`
2. **Rust `impl Default`** for that struct in the same file (around line 41)
3. **TypeScript interface** in `src/types/index.ts`
4. **TypeScript const default** in `src/types/index.ts` (e.g., `DEFAULT_PROGRESS` at line 123)

## How to compare

For each Rust struct under `src-tauri/src/models/*.rs` that derives `Serialize`:
1. Extract field names. Convert `snake_case` → `camelCase`.
2. Find the matching TS interface in `src/types/index.ts`.
3. Diff field sets in both directions. Each missing field is a CRITICAL finding.
4. For Rust: confirm `impl Default` provides every field. (Don't trust `#[derive(Default)]` blindly — read the impl.)
5. For TS: confirm `DEFAULT_*` const provides every field of the interface.

## Known patterns

- Rust uses `#[serde(default)]` on fields added later — gives `0` / empty for primitives. If TS default is non-zero, this is **drift in semantics** even if the field exists. Flag.
- `Option<String>` in Rust ↔ `string | null` in TS.
- `HashMap<String, T>` in Rust ↔ `Record<string, T>` in TS.
- `Vec<T>` in Rust ↔ `readonly T[]` in TS.

## Output format

For each drift finding:
- **Severity**: CRITICAL (field missing) / HIGH (default value mismatch) / MEDIUM (type mismatch) / LOW (naming)
- **Field**: name (and snake/camel forms if ambiguous)
- **Where missing**: list of the four sites that lack it
- **Fix**: one sentence — exactly what to add and where

If aligned: "GameProgress / GameSettings / GameStats: aligned across all four sites."
````

- [ ] **Step 2: Commit**

```bash
git add .claude/agents/schema-sync-checker.md
git commit -m "feat: schema-sync-checker subagent"
```

### Task 4.5: audio-engine-reviewer.md

**Files:**
- Create: `.claude/agents/audio-engine-reviewer.md`

- [ ] **Step 1: Write the file**

````markdown
---
name: audio-engine-reviewer
description: Reviews changes to clipSelector.ts, lyricProcessor.ts, useAudio.ts, relistenSchedule.ts, lib/lrclib.ts. Knows the RMS-profile + Gaussian-bias + danger-zone scoring contract, FULL_CLIP_THRESHOLD derivation, playVersionRef race-defeat pattern, AudioContext lifecycle. Use when any audio/lyrics file changes.
tools: Read, Grep, Glob
---

You are the audio engine reviewer.

## What you know

- **Clip selection** (`src/engine/clipSelector.ts`): scores candidate 10s windows by `energyScore × centerBias × dangerZonePenalty`. Step size 0.5s, frame size 0.25s. Falls back to random selection on any throw.
- **Danger zones** (`src/lib/lrclib.ts`): timestamps from LRC synced lyrics where the song title is sung. Computed via word-set match (60% threshold), padded ±1.5s, merged.
- **Relisten escalation** (`src/engine/relistenSchedule.ts`): const `SCHEDULE: readonly number[] = [10,10,15,15,20,20]`. `FULL_CLIP_THRESHOLD` and `FIRST_ESCALATION_RELISTEN` are **derived from the schedule** — do not hardcode them.
- **`useAudio.ts`** uses `playVersionRef` epoch — every async stage checks it and bails on mismatch. Pause/resume tracks `sliceOffsetRef`, `sliceDurationRef`, `elapsedBeforePauseRef`, `segmentStartTimeRef`. AudioContext closed on unmount.
- **Lyric extraction** (`src/engine/lyricProcessor.ts`): chorus-aware (skips first/last line); decoy selection has tiered fallback by word count; era groupings power difficulty-based decoy selection.

## Hard rules

1. **Don't hardcode `FULL_CLIP_THRESHOLD` or `FIRST_ESCALATION_RELISTEN`.** They're derived; modify `SCHEDULE` instead.
2. **Don't drop the `playVersionRef` epoch check** in any async path of `useAudio.ts`.
3. **Don't import React or DOM globals into `src/engine/`.** Engine purity rule.
4. **Don't change `AppError` user-facing strings** propagated from `lib/lrclib.ts` fetches.
5. **Cache cap** in `lib/lrclib.ts` (`MAX_CACHE_SIZE = 100`) — if removed, justify in comment.
6. **`Math.random()` in test paths** = flaky. Use `clipSelectorWithFallback` only in production paths.

## Output format

Numbered findings. For each:
- **Severity**, **File:line**, **Issue**, **Fix**, **Why it matters here**.

If clean: "Reviewed audio engine surface (clipSelector, lyricProcessor, useAudio, relistenSchedule, lrclib), no findings."
````

- [ ] **Step 2: Commit**

```bash
git add .claude/agents/audio-engine-reviewer.md
git commit -m "feat: audio-engine-reviewer subagent"
```

### Task 4.6: vitest-tdd-guide.md

**Files:**
- Create: `.claude/agents/vitest-tdd-guide.md`

- [ ] **Step 1: Write the file**

````markdown
---
name: vitest-tdd-guide
description: Enforces TDD for new features and bug fixes in src/. Writes failing test first, runs vitest to confirm RED, then minimal implementation, then GREEN, then coverage check. Use proactively when starting any new feature or bugfix.
tools: Read, Write, Edit, Bash, Grep, Glob
---

You are the TDD guide for the Swiftie Quiz frontend.

## Project test setup

- **Runner**: Vitest (`vitest run` for one-shot, `vitest` watch).
- **DOM**: `jsdom` configured via `vitest.config.ts`.
- **Setup file**: `src/test-setup.ts` (jest-dom matchers).
- **Test file convention**: co-located `*.test.ts` / `*.test.tsx` next to source.
- **Engine tests** live in `src/engine/*.test.ts` — pure, no React/jsdom.
- **Component tests** use `@testing-library/react` (`render`, `screen`, `userEvent`).

## TDD workflow (mandatory)

For every new feature or bug fix:

1. **Write the failing test first.** Pick the smallest behavior that captures the requirement.
2. **Run `npm test -- path/to/file.test.ts`** — confirm it FAILS for the right reason (assertion, not import error).
3. **Write the minimal implementation** to make it pass.
4. **Run again** — confirm GREEN.
5. **Refactor if needed**, re-run.
6. **Coverage check**: `npm test -- --coverage path/to/file.test.ts` — target 80%+ on new code.

## Hard rules

1. **No `console.*` in tests other than via mocked modules.**
2. **No real network calls.** Mock `invoke()` or use msw for `fetch`.
3. **No real `AudioContext`.** Mock or stub.
4. **Engine tests must not import React.** Engine purity rule.
5. **Test names**: `it("does X when Y")` form — describe behavior, not implementation.

## When you can skip TDD

Trivial typo fixes, documentation, gitignore changes. Anything with a logic branch — write the test first.

## Output format

Show each step: the test you wrote, the failing run output, the implementation, the passing run output, the coverage delta. Commit after GREEN.
````

- [ ] **Step 2: Commit**

```bash
git add .claude/agents/vitest-tdd-guide.md
git commit -m "feat: vitest-tdd-guide subagent"
```

### Task 4.7: PR for subagents

- [ ] **Step 1: Push and PR**

```bash
git push -u origin feat/claude-code-subagents
gh pr create --title "feat: 6 project-aware Claude Code subagents" \
  --body "$(cat <<'EOF'
## Summary
Six project-specialized subagents in .claude/agents/:
- rust-tauri-reviewer — Rust + Tauri patterns
- react-tauri-reviewer — TS + React + IPC patterns
- tauri-security-reviewer — CSP / capabilities / IPC scope
- schema-sync-checker — DTO four-place drift detector
- audio-engine-reviewer — clipSelector / lyricProcessor / useAudio
- vitest-tdd-guide — TDD enforcement for FE work

Each agent's system prompt names project-specific patterns (playVersionRef, FULL_CLIP_THRESHOLD derivation, the four DTO sites, etc.) so reviews are concrete, not generic.

## Test plan
- [ ] Each .md file has parseable YAML frontmatter (name, description, tools)
- [ ] Invoke schema-sync-checker against current HEAD — should report GameSettings drift (medium_timer/hard_timer missing from Rust)
- [ ] Invoke rust-tauri-reviewer on src-tauri/src/commands/deezer.rs — should comment on std::Mutex usage (currently OK, brief HashMap ops only)

Part 4/7 of [spec](docs/superpowers/specs/2026-04-27-claude-code-architecture-design.md).
EOF
)"
```

---

## PR 5 — Slash commands (.claude/commands/)

**Branch:** `feat/claude-code-commands`
**Depends on:** PR 4 merged.
**Risk:** Zero until invoked. `/release` modifies version files — test on a throwaway branch first.
**Validates:** Each command runs as documented; `/review-pr` actually dispatches subagents in parallel.

### Task 5.1: /verify command

**Files:**
- Create: `.claude/commands/verify.md`

- [ ] **Step 1: Write the file**

````markdown
---
description: Run the full verification suite — TypeScript, ESLint, Vitest, Cargo Clippy, Cargo Test. Stops at first failure with concrete output.
---

Run the following commands sequentially. **Stop at the first failure** and report the failing command + last 30 lines of output. Do not "fix as you go" — this is a checkpoint, not an implementation step.

1. `npx tsc --noEmit`
2. `npm run lint`
3. `npm test -- --run`
4. `cd src-tauri && cargo clippy --all-targets -- -D warnings`
5. `cd src-tauri && cargo test`

Report format:

```
✓ tsc            — passed
✓ eslint         — passed
✓ vitest         — passed (N tests)
✗ cargo clippy   — FAILED
<last 30 lines of output>
```

If all pass: `✓ All checks passed (X.Ys)`.
````

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/verify.md
git commit -m "feat: /verify slash command"
```

### Task 5.2: /sync-schemas command

**Files:**
- Create: `.claude/commands/sync-schemas.md`

- [ ] **Step 1: Write the file**

````markdown
---
description: Check DTO sync between Rust models and TS types via the schema-sync-checker subagent. Reports drift across the four-place rule (struct, impl Default, interface, DEFAULT const).
---

Dispatch the `schema-sync-checker` subagent with this brief:

> Check DTO sync. Compare every Rust struct under `src-tauri/src/models/*.rs` that derives `Serialize` against its TypeScript counterpart in `src/types/index.ts`. For each `GameProgress`-like struct, verify the four-place rule: Rust struct, Rust `impl Default`, TS interface, TS `DEFAULT_*` const.
>
> Pay special attention to `GameSettings` (known historical drift on `mediumTimer` / `hardTimer`).
>
> Output format: per-DTO section, list of drift findings or "aligned across all four sites."

After the subagent reports, summarize:
- ✓ DTOs aligned: list
- ✗ DTOs with drift: list with field counts

If any drift, suggest exact next-step edits (which file, which line area, what to add).
````

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/sync-schemas.md
git commit -m "feat: /sync-schemas slash command"
```

### Task 5.3: /review-pr command

**Files:**
- Create: `.claude/commands/review-pr.md`

- [ ] **Step 1: Write the file**

````markdown
---
description: Santa-method dual-review on uncommitted changes (no arg) or a specific PR (with PR number arg). Dispatches three reviewers in parallel and converges.
argument-hint: "[pr-number]"
---

If `$ARGUMENTS` is empty, the review target is the current uncommitted diff:
```
git diff HEAD
```

If `$ARGUMENTS` is a PR number, the review target is:
```
gh pr diff $ARGUMENTS
```

## Workflow

1. **Capture the diff** into a working buffer.

2. **Dispatch three reviewers in parallel** — single message with three Agent tool calls:
   - `rust-tauri-reviewer` — given the Rust portion of the diff
   - `react-tauri-reviewer` — given the TS/React portion
   - `tauri-security-reviewer` — given any tauri.conf.json or capabilities/* changes

3. **Convergence loop** (santa-method):
   - Collect all findings into a numbered list.
   - If any reviewer flagged CRITICAL or HIGH: report them and STOP. The user must address before re-running.
   - If only MEDIUM/LOW: report and ask "approve, request changes, or iterate?"
   - If all reviewers report no findings: APPROVED. Suggest commit message.

## Output format

```
═══ /review-pr — Santa-Method Dual Review ═══
Target: <diff source> (<N> files, +<X>/-<Y>)

▶ rust-tauri-reviewer        <N findings>
▶ react-tauri-reviewer       <N findings>
▶ tauri-security-reviewer    <N findings>

CRITICAL (block):
  1. <file:line> — <issue> — <fix>

HIGH:
  ...

MEDIUM:
  ...

Verdict: APPROVED | CHANGES REQUESTED | ITERATE
```

## Failure mode handling

- If a reviewer times out or errors, retry once. If still failing, report partial verdict and which reviewer was missing.
- If the diff is empty, say so and exit cleanly.
````

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/review-pr.md
git commit -m "feat: /review-pr santa-method dual-review command"
```

### Task 5.4: /new-tauri-command

**Files:**
- Create: `.claude/commands/new-tauri-command.md`

- [ ] **Step 1: Write the file**

````markdown
---
description: Scaffold a new Tauri command end-to-end — Rust handler, registration, mockito test, frontend hook, TS type.
argument-hint: "<command_snake_case_name>"
---

You are scaffolding a new Tauri command named `$ARGUMENTS`.

Validate `$ARGUMENTS` is non-empty and snake_case. If not, ask the user for a valid name.

## Files to create / modify

1. **Pick the right command file** under `src-tauri/src/commands/`:
   - Touches Deezer? → `commands/deezer.rs`
   - Touches LRCLIB? → `commands/lyrics.rs`
   - Touches local fs / save? → `commands/storage.rs`
   - None of the above? → create new `commands/<area>.rs` and add `pub mod <area>;` to `commands/mod.rs`.

2. **Write the Rust handler** following the existing pattern (see `commands/deezer.rs:17` `fetch_albums`):
   ```rust
   #[tauri::command]
   pub async fn $ARGUMENTS(
       /* args */
       state: State<'_, AppState>,
   ) -> Result<ReturnType, AppError> {
       // 1. cache check
       // 2. rate-limit acquire
       // 3. service call
       // 4. cache write
       // 5. return
   }
   ```

3. **Register in `src-tauri/src/lib.rs:15`** `invoke_handler!` macro:
   ```rust
   commands::<area>::$ARGUMENTS,
   ```

4. **Add a mockito-style test** in the same file, inside `#[cfg(test)] mod tests`. Pattern: spawn mock server, build client pointing at it, call the function, assert.

5. **Add a TS type** for the return shape in `src/types/index.ts` (camelCase).

6. **Add a frontend hook wrapper** in `src/hooks/useDeezer.ts` (or new `use<Area>.ts`) following the `useDeezerCommand<T>` pattern.

7. **Run `/verify`** to confirm everything compiles and tests pass.

8. **Run `/sync-schemas`** to confirm no DTO drift introduced.

## Reminders

- Hook `block-secrets.sh` will reject any literal token/key in the new code.
- Hook `check-rust-after-edit.sh` will run cargo check after each Rust edit.
- After implementation, run `/review-pr` for a santa-method check before commit.
````

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/new-tauri-command.md
git commit -m "feat: /new-tauri-command scaffolding command"
```

### Task 5.5: /new-achievement

**Files:**
- Create: `.claude/commands/new-achievement.md`

- [ ] **Step 1: Write the file**

````markdown
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
````

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/new-achievement.md
git commit -m "feat: /new-achievement scaffolding command"
```

### Task 5.6: /release

**Files:**
- Create: `.claude/commands/release.md`

- [ ] **Step 1: Write the file**

````markdown
---
description: Bump version across package.json, Cargo.toml, tauri.conf.json; write CHANGELOG entry; run /verify; open release PR. Never pushes tags.
argument-hint: "patch|minor|major"
---

Validate `$ARGUMENTS` is one of `patch`, `minor`, `major`. Otherwise ask.

## Steps

1. **Read current versions** from:
   - `package.json` (`.version`)
   - `src-tauri/Cargo.toml` (`[package].version`)
   - `src-tauri/tauri.conf.json` (`.version`)

2. **Confirm all three match.** If not, STOP and report drift.

3. **Compute new version** by bumping `$ARGUMENTS` SemVer component.

4. **Edit all three files** with the new version.

5. **Generate CHANGELOG entry** from `git log $(git describe --tags --abbrev=0)..HEAD --oneline`. Group by `feat:` / `fix:` / `chore:` prefix. Prepend to `CHANGELOG.md` under `## [<new-version>] — YYYY-MM-DD`.

6. **Run `/verify`.** If it fails, revert all four file edits and stop.

7. **Create branch and PR**:
   ```bash
   git checkout -b release/v<new-version>
   git add package.json src-tauri/Cargo.toml src-tauri/tauri.conf.json CHANGELOG.md
   git commit -m "chore: release v<new-version>"
   git push -u origin release/v<new-version>
   gh pr create --title "release: v<new-version>" --body "<auto-generated changelog>"
   ```

8. **Do NOT push tags.** Tag creation happens after PR merge, separately, by the maintainer.

## Safety

- The hook `block-secrets.sh` will run on each file edit (defense in depth).
- The hook `block-csp-weakening.sh` will run on `tauri.conf.json` (only the version string changes — passes).
- If `/verify` fails partway, the rollback restores the manifest files only — CHANGELOG edit may need manual revert.
````

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/release.md
git commit -m "feat: /release version-bump and PR command"
```

### Task 5.7: PR for commands

- [ ] **Step 1: Push and PR**

```bash
git push -u origin feat/claude-code-commands
gh pr create --title "feat: 6 project-aware slash commands" \
  --body "$(cat <<'EOF'
## Summary
Six slash commands in .claude/commands/:
- /verify — full check suite
- /sync-schemas — DTO drift check via subagent
- /review-pr — santa-method parallel dual-review
- /new-tauri-command — Tauri command scaffold
- /new-achievement — achievement scaffold
- /release — version bump and PR

## Test plan
- [ ] Run /verify locally — should pass on main
- [ ] Run /sync-schemas — should report current GameSettings drift (medium_timer/hard_timer missing from Rust)
- [ ] Run /review-pr (no args, on a small uncommitted change) — should dispatch 3 reviewers and converge
- [ ] Test /new-tauri-command on a throwaway branch with name "fetch_dummy" — should produce all 5 file changes

Part 5/7 of [spec](docs/superpowers/specs/2026-04-27-claude-code-architecture-design.md).
EOF
)"
```

---

## PR 6 — GitHub Action: claude-review.yml

**Branch:** `feat/claude-code-ci`
**Depends on:** PRs 2, 4, 5 merged (CI loads settings + agents + commands).
**Risk:** Action requires `ANTHROPIC_API_KEY` repo secret. Unverified action API surface — pin to specific version.
**Validates:** PR review runs headlessly and posts a sticky comment.

### Task 6.1: Confirm Action availability and exact API

- [ ] **Step 1: Check the published action's documented inputs**

```bash
gh api repos/anthropics/claude-code-action/contents/action.yml --jq '.content' | base64 -d 2>/dev/null | head -80
```
Expected: prints the action's `inputs:` section. Confirm the actual input names (e.g. `anthropic_api_key`, `prompt`, `mode`, `setting_sources`, `allowed_tools`). If names differ from the spec draft below, **adjust the YAML before committing**.

- [ ] **Step 2: Note the latest stable version**

```bash
gh api repos/anthropics/claude-code-action/releases/latest --jq '.tag_name'
```
Pin the workflow to that tag (replace `v1` below).

### Task 6.2: Set repo secret

- [ ] **Step 1: Add `ANTHROPIC_API_KEY` to repo secrets**

```bash
gh secret set ANTHROPIC_API_KEY
# paste the key when prompted
```

### Task 6.3: Create the workflow

**Files:**
- Create: `.github/workflows/claude-review.yml`

- [ ] **Step 1: Write the workflow**

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
      - '.claude/**'

permissions:
  contents: read
  pull-requests: write

jobs:
  review:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Claude reviewers
        uses: anthropics/claude-code-action@<PIN-TO-LATEST>
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          setting_sources: project
          allowed_tools: "Read,Glob,Grep,Bash(git diff:*),Bash(gh pr diff:*),Bash(git log:*)"
          prompt: |
            Run the /review-pr slash command for PR #${{ github.event.pull_request.number }}.

            Use the dispatch pattern documented in .claude/commands/review-pr.md:
            three reviewers in parallel (rust-tauri-reviewer, react-tauri-reviewer,
            tauri-security-reviewer), then santa-method convergence.

            Write the consolidated review to ./review.md in this format:
              # Claude Review

              **Verdict:** APPROVED | CHANGES REQUESTED | COMMENT

              ## Findings
              <numbered list>

              ## Files reviewed
              <list>

      - name: Post sticky review comment
        if: always()
        uses: marocchino/sticky-pull-request-comment@v2
        with:
          path: review.md
          header: claude-review
```

> **Important:** the `<PIN-TO-LATEST>` placeholder must be replaced with the tag from Task 6.1 step 2 before commit. If the action's actual input keys differ from `anthropic_api_key` / `setting_sources` / `allowed_tools` / `prompt`, adjust accordingly using the output of Task 6.1 step 1.

- [ ] **Step 2: Validate YAML**

```bash
# Use a YAML linter or a quick Python check
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/claude-review.yml'))" && echo OK
```
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/claude-review.yml
git commit -m "ci: santa-method Claude review on PRs"
```

### Task 6.4: Smoke test the action

- [ ] **Step 1: Push and open a no-op PR to fire the action**

```bash
git push -u origin feat/claude-code-ci
gh pr create --title "ci: Claude PR review action" \
  --body "Adds the GitHub Action that runs /review-pr on every PR."
```

- [ ] **Step 2: Watch the action run**

```bash
gh run watch
```
Expected: action completes within timeout. Check the PR for the sticky review comment.

- [ ] **Step 3: If the comment is missing or empty**

Inspect the action logs:
```bash
gh run view --log-failed
```
Common fixes:
- Action input keys mismatched → update YAML, re-push.
- `review.md` not written by Claude → adjust the `prompt:` to instruct file write more explicitly, or add a fallback `echo "..." > review.md` step.

---

## PR 7 — Smoke test: fix GameSettings schema drift

**Branch:** `fix/game-settings-rust-defaults`
**Depends on:** PRs 1-6 merged.
**Risk:** Real bug fix in production code. Existing `usePersistence` defaults will continue to mask any residual drift, but post-fix loads should pass through Rust defaults verbatim.
**Validates:** End-to-end exercise of every component built in PRs 1-6.

### Task 7.1: Run /sync-schemas to confirm drift detection

- [ ] **Step 1: Invoke /sync-schemas in a Claude Code session in this repo**

Expected output mentions:
- `GameSettings` drift
- Field `medium_timer` missing from Rust struct + Default
- Field `hard_timer` missing from Rust struct + Default
- Files: `src-tauri/src/models/progress.rs`, `src/types/index.ts`

If the subagent does NOT detect this, the agent prompt is incomplete — fix `.claude/agents/schema-sync-checker.md` first (architecture defect).

### Task 7.2: Write the failing Rust test

**Files:**
- Modify: `src-tauri/src/models/progress.rs` (add test only)

- [ ] **Step 1: Add a failing test inside the existing `#[cfg(test)] mod tests`**

Append before the closing `}` of `mod tests`:

```rust
    #[test]
    fn test_default_includes_timer_fields() {
        let progress = GameProgress::default();
        assert_eq!(progress.settings.medium_timer, 30);
        assert_eq!(progress.settings.hard_timer, 20);
    }

    #[test]
    fn test_settings_serde_round_trip_preserves_timers() {
        let progress = GameProgress::default();
        let json = serde_json::to_string(&progress).unwrap();
        let back: GameProgress = serde_json::from_str(&json).unwrap();
        assert_eq!(back.settings.medium_timer, 30);
        assert_eq!(back.settings.hard_timer, 20);
    }
```

- [ ] **Step 2: Run — must FAIL with "no field `medium_timer`"**

```bash
cd src-tauri && cargo test --quiet test_default_includes_timer_fields 2>&1 | tail -20
```
Expected: compile error mentioning `medium_timer` field on `GameSettings`.

### Task 7.3: Implement the fix

**Files:**
- Modify: `src-tauri/src/models/progress.rs`

- [ ] **Step 1: Add helper functions for serde defaults**

Above `pub struct GameSettings`:

```rust
fn default_medium_timer() -> u32 { 30 }
fn default_hard_timer() -> u32 { 20 }
```

- [ ] **Step 2: Add the two fields to the struct**

Replace the existing `GameSettings` struct definition:

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GameSettings {
    pub theme: String,
    pub volume: f64,
    #[serde(default = "default_medium_timer")]
    pub medium_timer: u32,
    #[serde(default = "default_hard_timer")]
    pub hard_timer: u32,
}
```

- [ ] **Step 3: Add the two fields to the Default impl**

Replace the `settings: GameSettings { ... }` block inside `impl Default for GameProgress`:

```rust
            settings: GameSettings {
                theme: "dark".to_string(),
                volume: 0.8,
                medium_timer: 30,
                hard_timer: 20,
            },
```

- [ ] **Step 4: Run the failing tests — must PASS**

```bash
cd src-tauri && cargo test --quiet test_default_includes_timer_fields test_settings_serde_round_trip_preserves_timers 2>&1 | tail -20
```
Expected: both tests pass. The PostToolUse `check-rust-after-edit.sh` will have already confirmed compilation.

- [ ] **Step 5: Run the existing `progress` tests — must still pass**

```bash
cd src-tauri && cargo test --quiet progress 2>&1 | tail -10
```
Expected: all pass, including the existing `test_default_progress` (it doesn't assert on the missing fields — backward compatible).

### Task 7.4: Re-run /sync-schemas to confirm green

- [ ] **Step 1: Invoke /sync-schemas in the Claude session**

Expected output: `GameProgress / GameSettings / GameStats: aligned across all four sites.`

### Task 7.5: Run /verify

- [ ] **Step 1: Invoke /verify**

Expected: all five checks pass.

### Task 7.6: Run /review-pr

- [ ] **Step 1: Invoke /review-pr (no args, current uncommitted diff)**

Expected:
- `rust-tauri-reviewer` confirms idiomatic `serde(default = "...")` usage, no `derive(Default)` regression
- `react-tauri-reviewer` reports no findings (TS unchanged)
- `tauri-security-reviewer` reports no findings (no config files touched)
- Convergence in 1 iteration → APPROVED

### Task 7.7: Commit and PR

- [ ] **Step 1: Commit**

```bash
git add src-tauri/src/models/progress.rs
git commit -m "fix: align Rust GameSettings defaults with TS DEFAULT_PROGRESS

Adds medium_timer (30s) and hard_timer (20s) to the Rust GameSettings
struct and Default impl. The TS side already had these fields; the Rust
side was missing them, masked at runtime by usePersistence merging
client defaults on load. Any future Rust caller using
GameProgress::default() directly would have emitted null timers over
IPC, producing NaN in the Settings range inputs.

Schema-sync now reports GameProgress/Settings/Stats aligned across all
four sites (Rust struct, Rust Default, TS interface, TS DEFAULT_PROGRESS).

This is the smoke test for the .claude/ agentic architecture: each
hook fired correctly, /sync-schemas detected and re-confirmed alignment,
/review-pr converged in one iteration."
```

- [ ] **Step 2: Push and PR**

```bash
git push -u origin fix/game-settings-rust-defaults
gh pr create --title "fix: align Rust GameSettings defaults with TS" \
  --body "$(cat <<'EOF'
## Summary
Fixes silent schema drift between Rust GameSettings and TS GameSettings:
medium_timer (30s) and hard_timer (20s) were present in TS but missing
from Rust struct and Default impl.

Currently masked by client-side default merging in usePersistence.ts:15.
Latent: any future Rust caller using GameProgress::default() emits null
timers over IPC → NaN in Settings range inputs.

## Architecture validation

This is **PR 7/7** of the Claude Code architecture rollout. It exercises
every prior PR end-to-end:

- ✓ PR 3 hooks fired correctly (block-secrets/block-csp didn't false-positive,
      check-rust-after-edit caught a temporary compile error mid-implementation)
- ✓ PR 4 schema-sync-checker subagent detected the drift
- ✓ PR 5 /sync-schemas, /verify, /review-pr commands all worked
- ✓ PR 6 GH Action will reproduce local /review-pr verdict on this PR

## Test plan
- [ ] cargo test progress passes
- [ ] /sync-schemas reports aligned across all four sites
- [ ] /verify passes (tsc + lint + vitest + clippy + cargo test)
- [ ] /review-pr converges with APPROVED verdict
- [ ] CI claude-review action posts sticky comment with same verdict
EOF
)"
```

### Task 7.8: Confirm acceptance criteria

- [ ] **Step 1: Walk through the spec § 12 acceptance criteria checklist**

For each item, confirm it held:
- [ ] All five hooks fired only when expected
- [ ] Each subagent surfaced at least one project-specific finding
- [ ] /review-pr converged within 1 iteration
- [ ] CI run reproduced local result
- [ ] No denied MCP attempted
- [ ] Total wall-clock from /sync-schemas to merged PR ≤ 20 minutes

If any failed, file follow-up issues and link to spec § 12 "Failure modes and remedies."

---

## Self-Review

**Spec coverage:** Every section of the spec maps to one or more tasks above.
- § 5 CLAUDE.md → Task 1.1
- § 6 settings.json → Tasks 2.1, 3.7
- § 7 subagents (6) → Tasks 4.1-4.6
- § 8 commands (6) → Tasks 5.1-5.6
- § 9 hooks (5) → Tasks 3.2-3.6
- § 10 GH Action → Tasks 6.1-6.4
- § 11 .gitignore → Task 1.2
- § 12 validation walkthrough → Tasks 7.1-7.8

**Placeholder scan:** No "TBD", "TODO", "fill in." The single `<PIN-TO-LATEST>` in Task 6.3 is intentional and explicitly resolved by Task 6.1's preceding step (looking up the actual latest tag and substituting).

**Type consistency:** Hook script names match between settings.json wiring (Task 3.7) and the script files (Tasks 3.2-3.6). Subagent names referenced in slash commands (e.g. `schema-sync-checker` in Task 5.2) match the subagent files (Task 4.4). Smoke-test assertions reference the exact Rust field names (`medium_timer`, `hard_timer`) used in the implementation tasks.

**Plan failures fixed inline:** none.
