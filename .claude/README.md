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
