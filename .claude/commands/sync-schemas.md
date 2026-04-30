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
