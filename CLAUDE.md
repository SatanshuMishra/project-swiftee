# Project Swiftie — Project Instructions

Project Swiftie (formerly Swiftie Quiz): Flutter desktop trivia game for macOS and Windows
(Dart, Riverpod) using public Deezer and LRCLIB APIs. No user PII, no auth.

## Stack
Flutter 3.47.5 · Dart 3.13 · Riverpod 3 · flutter_soloud · flutter_svg · window_manager · http
flutter_test · fake_async · NSIS (Windows installer) · GitHub Actions

## Commands
- `flutter pub get`
- `flutter run -d macos` (use this for visual verification)
- `flutter test` / `flutter test test/path/to/file_test.dart --plain-name "<name>"`
- `flutter analyze --fatal-infos`
- `dart format lib test tool` (CI runs `dart format --output=none --set-exit-if-changed lib test tool`)

## Architecture (one-screen tour)
- lib/domain/ — pure rules and models: engine/ (quiz, clip selection, lyrics, achievements, relisten schedule) and models/ (save format, tracks, lyrics, updater types)
- lib/data/ — Deezer and LRCLIB clients (catalog/, lyrics/) and the save store (save/)
- lib/services/ — audio through flutter_soloud (audio/) and the updater (updater/)
- lib/state/ — Riverpod 3 Notifier controllers; shared collaborators in providers.dart
- lib/ui/ — screens, gameplay widgets, overlays, cat icon and loader, theme tokens
- lib/app/ — app shell, window setup and phase routing; entry point lib/main.dart
- Models and state are immutable: final fields, const constructors, copyWith, unmodifiable collections
- Side effects (network, files, audio, process launching) live only in lib/data/ and lib/services/, behind injected collaborators
- installer/windows/ — NSIS script; tool/release/ — packaging, release checks and latest.json

## Project-specific rules (extend ~/.claude/rules globals)
1. **Save format stays compatible with the Tauri-era save.json.** Same location
   (com.swiftiequiz.desktop app data folder), camelCase keys, version 3. Any shape change
   bumps the version and adds a migration in lib/data/save/migrations.dart, with a test
   that loads the previous version. Existing players' saves must load unchanged.
2. **The updater protocol stays compatible.** latest.json (URL, schema, platform keys),
   the minisign public key in lib/services/updater/update_config.dart and the artifact
   formats are what installed copies update through. Never change them without a release plan.
3. **lib/domain stays pure.** No package:flutter, dart:io or dart:ui imports under lib/domain/.
4. **No print or debugPrint in lib/.** Tests only. Hook will warn.
5. **Visual verification required for UI work.** `flutter run -d macos` + exercise the
   flow before claiming done. Analyze passing ≠ feature works.

## Where to look
| I want to...                    | Look at... |
|---------------------------------|------------|
| Add an achievement              | lib/domain/engine/achievements.dart + achievementConditionMet in lib/state/achievements_controller.dart:31 |
| Add a game phase/screen         | GamePhase in lib/domain/models/game_types.dart:3 + phase switch in lib/app/app.dart:175 + new widget in lib/ui/screens/ |
| Change save format              | bump currentSaveVersion in lib/data/save/migrations.dart:5 and defaultProgress in lib/domain/models/progress.dart:9 + a migration step in migrations.dart |
| Fix smart-clip behaviour        | lib/domain/engine/clip_selector.dart + lib/data/lyrics/danger_zones.dart |
| Change how songs and lyrics avoid repeating | lib/domain/engine/play_order.dart + lib/state/play_history_controller.dart + docs/decisions/2026-10-06-repetition.md |
| Change how new releases, eras and takes are sorted | lib/domain/engine/catalogue_rules.dart + takeOf in lib/domain/util/song_title.dart + lib/data/catalog/catalogue_store.dart + docs/decisions/2026-10-07-catalogue-growth.md |
| Change the era and release picker | lib/ui/screens/album_grid.dart + Catalogue.releases in lib/domain/models/catalogue.dart + lib/domain/engine/release_search.dart + docs/decisions/2026-10-06-release-picker.md |
| Change which versions a sound game plays | lib/domain/engine/version_filter.dart + the versions section in lib/ui/screens/setup_screen.dart |
| Change a Deezer or LRCLIB call  | lib/data/catalog/deezer_client.dart or lib/data/lyrics/lrclib_client.dart + providers in lib/state/providers.dart |
| Change which certificates the app trusts | lib/services/network/bundled_roots.dart + assets/certs/cacert.pem + docs/decisions/2026-10-07-windows-trusted-roots.md |
| Change the updater              | lib/services/updater/ (protocol) + lib/state/updater_controller.dart (schedule and states) |
| Change the Windows installer    | installer/windows/swiftie-quiz.nsi + test/installer/nsis_script_test.dart + docs/decisions/2026-10-06-windows-update-exit.md |
| Change CI or the release flow   | .github/workflows/ + tool/release/ + docs/decisions/2026-10-04-ci-hardening.md + docs/decisions/2026-10-05-release-streamlining.md; required check is the `CI OK` job name |

## Preferred skills (project-scoped)
- `/verify`         — dart format check, flutter analyze, flutter test before claiming done
- `/review-pr`      — santa-method dual-review (flutter-reviewer + audio-engine-reviewer) on uncommitted changes
- `/new-achievement <id> "<description>"` — scaffolds definition + unlock condition + tests
- `/release patch|minor|major` — bumps pubspec.yaml, writes the CHANGELOG entry, opens the release PR

## Skills to skip here
- `e2e-testing` (Playwright) — there is no web surface; flutter_test widget tests plus VMLab runs cover it.
- `brainstorming` for trivial fixes — overkill.

## Privacy
.claude/settings.json blocks `memory` and `Claude_in_Chrome` MCPs. For cross-session
notes, write markdown to docs/decisions/ — don't reach for external memory.
