# Charter for the Project Swiftie redesign build

Binding on every builder. Your task text is complete; this charter only restates the project's standing rules.

## Scope

- Change only the files your task lists. Other builders work on other files at the same time.
- Leave git alone: no commits, stashes, resets, checkouts, rebases or branch changes. The orchestrator commits your work.
- Do not touch lib/app/app.dart or pubspec.yaml; the routing scaffold owns them.
- Build nothing for Play together (multiplayer); it is out of scope.
- Never port code tagged PROTOTYPE-ONLY in docs/specs/project-swiftie-redesign.design/Project Swiftie.dc.html.

## Project rules (CLAUDE.md)

1. The save format stays compatible with the Tauri-era save.json: same location (com.swiftiequiz.desktop app data folder), camelCase keys. Any shape change bumps the version and adds a migration in lib/data/save/migrations.dart with a test that loads the previous version. Existing players' saves must load unchanged.
2. The updater protocol stays compatible: latest.json (URL, schema, platform keys), the minisign public key in lib/services/updater/update_config.dart and the artefact formats. Only additive changes, with a written release plan.
3. lib/domain stays pure: no package:flutter, dart:io or dart:ui imports.
4. No print or debugPrint in lib/.
5. Models and state are immutable: final fields, const constructors, copyWith, unmodifiable collections. Side effects live only in lib/data/ and lib/services/ behind injected collaborators.

## House rules

- Never write code comments, docstrings or section-header comments. Never use emojis.
- Create new objects instead of mutating existing ones.
- Reuse what exists (CatLoader, CatIcon, relisten schedule, answer matcher, Deezer and LRCLIB clients, updater services); never copy logic that already has a home.

## Verification before you finish

- dart format lib test tool (no changes left)
- flutter analyze --fatal-infos (clean)
- flutter test (whole suite green), including your acceptance tests by their exact names
- Do not launch the app; the orchestrator verifies every screen visually on the integrated macOS build.
