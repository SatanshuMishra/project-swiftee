---
description: Run the full verification suite — dart format check, flutter analyze, flutter test. Stops at first failure with concrete output.
---

Run the following commands sequentially from the repository root. **Stop at the first failure** and report the failing command plus the last 30 lines of its output. Do not "fix as you go" — this is a checkpoint, not an implementation step.

1. `dart format --output=none --set-exit-if-changed lib test tool`
2. `flutter analyze --fatal-infos`
3. `flutter test`

Run `flutter pub get` first only if a command reports missing packages.

Report format:

```
PASS dart format     — no changes needed
PASS flutter analyze — no issues
FAIL flutter test    — N failed
<last 30 lines of output>
```

If all pass: `All checks passed (X.Ys)`.
