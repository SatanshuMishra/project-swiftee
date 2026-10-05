# .claude/

Project-scoped Claude Code configuration for the Flutter app. **Committed** to
the repo so the architecture rides with the codebase.

## Layout

| File / Dir | Status | Purpose |
|---|---|---|
| `settings.json` | committed | Permissions, MCP allowlist/denylist, hooks wiring |
| `settings.local.json` | gitignored | Personal/per-machine overrides; start from `settings.local.json.example` |
| `agents/` | committed | Project-aware subagent definitions |
| `commands/` | committed | Slash command definitions (`/verify`, `/review-pr`, ...) |
| `hooks/` | committed | Bash scripts invoked by hooks declared in settings.json |
| `sessions/`, `state/`, `cache/`, `*.log` | gitignored | Transient session data |

## Permissions (settings.json)

Edits and writes are allowed under `lib/`, `test/`, `tool/`, `assets/`, `docs/`
and `.claude/`. Shell commands allowed without a prompt are `flutter test`,
`flutter analyze`, `flutter build`, `flutter run`, `dart format` and
`dart run tool/release/...`, plus everyday git (status, diff, log, branch, add,
commit, plain push and pull) and the `gh pr` / `gh issue` CLIs. Force pushes,
hard resets, `rm -rf`, and edits to `pubspec.lock`, `build/`, `.git/` and
`.env` files are denied.

## Privacy posture (settings.json)

This project blocks the following MCP servers:
`memory`, `Claude_in_Chrome`, `Claude_Preview`, `fal-ai-media`,
`mcp-registry`, `scheduled-tasks`, and all *write* GitHub MCP operations.

For cross-session notes, write markdown to `docs/decisions/` instead of using
an external memory MCP.

## Agents

| Agent | Use |
|---|---|
| `flutter-reviewer` | After any edit to `lib/` or `test/`: immutability, Riverpod usage, no print, `lib/domain` purity, save-format and updater-protocol compatibility |
| `audio-engine-reviewer` | After any edit to clip selection, danger zones, `lib/services/audio/` or the audio controller |
| `flutter-tdd-guide` | Before a feature or bug fix: failing `flutter_test` test first, then the implementation |

## Commands

| Command | Does |
|---|---|
| `/verify` | `dart format` check, `flutter analyze --fatal-infos`, `flutter test`; stops at the first failure |
| `/review-pr` | Runs `flutter-reviewer` and `audio-engine-reviewer` in parallel on the diff or a PR and converges |
| `/new-achievement` | Scaffolds an achievement: definition, unlock condition, cat SVG, tests |
| `/release` | Bumps `pubspec.yaml`, writes the CHANGELOG entry, runs `/verify`, opens the release PR; never pushes tags |

## Hooks (security guards + quality warnings)

| Script | When | Effect on failure |
|---|---|---|
| `block-secrets.sh` | PreToolUse on Write/Edit | Refuses the edit |
| `warn-print.sh` | PostToolUse on Write/Edit of `lib/**/*.dart` | Warns when the file contains `print(` or `debugPrint(` |
| `stop-reminder.sh` | Stop | Reminds to run /verify when app sources changed |

## Reference

Architecture rationale: [docs/superpowers/specs/2026-04-27-claude-code-architecture-design.md](../docs/superpowers/specs/2026-04-27-claude-code-architecture-design.md)
Flutter rewrite: [docs/decisions/2026-10-05-flutter-rewrite.md](../docs/decisions/2026-10-05-flutter-rewrite.md)
