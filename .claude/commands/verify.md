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
