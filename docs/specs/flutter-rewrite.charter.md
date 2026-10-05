# Charter for the Flutter rewrite of Swiftie Quiz

Every Worker building a Step of `docs/specs/flutter-rewrite.md` follows these rules. They override any habit or default.

## What this work is

Swiftie Quiz is a desktop Taylor Swift trivia game for macOS and Windows. It is being rewritten from Tauri 2 + React 19 + TypeScript + Rust into one Flutter app at the repository root. It is a rewrite, not a redesign: the same screens, words, flows, rules, numbers, colours, sizes, animations, timings and sounds. The only intended visual change is the cat icon and the cat loader, whose new design lives in `design/cat-v2/`.

The existing implementation is the specification. Until the last Step removes them, `src/` (TypeScript, React) and `src-tauri/` (Rust) stay on every branch. Read them for exact behaviour, copy their constants and strings exactly, and port their tests. When your brief and the old code disagree, your brief wins; when your brief is silent, the old code wins.

## Working in a shared tree

- Other Workers are writing in the same worktree at the same time. Create or change only the files your brief lists. Never delete, move, format or "fix" a file outside that list, even one that looks broken.
- Never run `git add`, `git commit`, `git stash`, `git reset`, `git checkout` or anything else that touches the index or history. The orchestrator commits.
- Never edit `pubspec.yaml` or `pubspec.lock` unless your brief lists them. Use only the packages already declared there. If something seems to need a new package, build it with what is declared.
- Run `flutter pub get` before testing. If it reports a lock conflict, wait a few seconds and retry.

## Code rules

- No comments of any kind in any language you write: no `//`, `///`, `/* */`, `#` comment lines, NSIS `;` comments or doc comments. Three functional exceptions: tool pragmas such as `// ignore: rule_name` when unavoidable, the `#!` shebang line of an executable script, and the `# vX.Y.Z` note after a commit-SHA-pinned GitHub Action, which Dependabot reads to update the pin. Name things so the code explains itself.
- No emojis in code. The exceptions are user-facing strings the current app shows that already contain them (for example the cat emoji and the music-note placeholder), which must stay exact.
- Immutable data. Model and state classes have only `final` fields, `const` constructors where possible, and `copyWith`. Never mutate a collection held in state; build a new one (`[...old, item]`, `{...map, key: value}`) and expose collections as unmodifiable.
- No `print` or `debugPrint` in `lib/`. Tests may print.
- Game rules and pure logic under `lib/domain/` import nothing from Flutter (`package:flutter/...`) and nothing from `dart:io` or `dart:ui`.
- Side effects (network, files, audio, process launching) live only under `lib/data/` and `lib/services/`, behind classes whose collaborators (an `http.Client`, a base directory, an audio engine, a clock) are passed in, so tests can substitute fakes.
- Package name `swiftie_quiz`. Import project files with `package:swiftie_quiz/...`.
- Format with `dart format`. `flutter analyze --fatal-infos` must report nothing for the files you wrote.

## Tests

- Use `flutter_test` (and `package:http/testing.dart` `MockClient`, `package:fake_async` for timers). Tests never touch the network, real audio, the real home directory or the real clock.
- Each acceptance test named in your brief must exist with exactly that name. A test passes `--plain-name` matching when its full name (group names plus test name) contains the given text, so you may name a `group` with the acceptance name and put several `test`s inside it.
- When you port a TypeScript or Rust test file, port every case in it, keeping the inputs and expected values.
- Load the code under test inside the test body or `setUp`, never in a top-level variable initialiser, so a missing implementation fails the named test instead of the whole file failing to load.
- Before you finish, run `flutter test` on every test file you wrote, and `flutter analyze --fatal-infos` and `dart format --output=none --set-exit-if-changed` on every file you wrote. All must pass.

## Finishing

- Never start background agents, background subagents or background shell tasks. This session runs non-interactively and is terminated, without your return line, when background work outlives it. If you want an independent review of your diff, run it in the foreground, wait for its result, and act on it before finishing.
- Your last output must be the one-line JSON return your brief asks for, and nothing after it.
- If the files of your write-set already exist when you start (an earlier attempt wrote them), read them, finish or fix the work, verify it, and return; do not start over.

## Commands

- `flutter pub get`
- `flutter test test/path/to/file_test.dart`
- `flutter test test/path/to/file_test.dart --plain-name "acceptance name"`
- `flutter analyze --fatal-infos`
- `dart format --output=none --set-exit-if-changed lib test tool`

Toolchain: Flutter 3.47.5 stable, Dart 3.13.4, Xcode 26.6, on macOS (Apple Silicon). Windows builds run only in CI.
