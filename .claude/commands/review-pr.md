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
