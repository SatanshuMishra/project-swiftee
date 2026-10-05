# Swiftie Quiz: rewrite in Flutter

Pathway: feature.

Date: 2026-10-05.

## 1. Request

Use `interphase:feature` to complete the following task. `spec` a complete re-write of `project-swiftee` from it's current stack to using `flutter`.

From a design point of view everything stays exactly as today (for simplicity). The ONLY change to make to the design is the use of an updated improve `cat` model for both the static, loading indicator, etc. versions. Review the following Claude Design: (Claude Design project 27738b4d-96c4-4170-87aa-d19b2f0407f2, file Cat Asset Review.dc.html, with assets/cat-icon-v2.svg, cat-loader-v2.js, github.md, the screenshots, src/assets/cat-icon.svg, src/components/CatLoader.css, support.js and the uploads.)

For the back-end, the ONLY area to consider a change is with the open APIs used to fetch the lyrics, songs, album covers, etc. I want you to determine if these are the BEST solutions to use. The requirements are that the solution MUST be free, reliable and actively supported. e.g., Taylor Swift recently released a new album and it automatically showed up in the app with no updates. This is exactly what I'm looking for.

Your directives are as follows:

1. Audit and understand the existing app structure to re-build in `flutter`.
2. Research and determine the best solution(s) for the open APIs used.
3. Review the Claude Code design and extract the improved `cat` resources.
4. Write up the `spec` for the complete re-write.
5. Ship using `mitosis`.

Things to keep in mind:

1. A parallel Claude Code session is releasing changes to fix app updating logic. Make sure to incorporate this into the `flutter` re-write. PR #19 & future PR #20 for v0.2.3 release.
2. Continue to ship this app ONLY for `macOS` and `windows`.
3. Work autonomously. `interphase` gets you to ask me clarification questions to make sure you have my intent. You are NOT allowed to ask me any questions. I'm starting this work before going to bed. I want you to work fully autonomously such that when I wake up, I am expecting a fully shipped flutter re-write using `mitosis` with PRs open ready for me to review. When you are unsure about a decision, ask the following questions: Which option is the most performant? Which option is more optimized? Which option is more secure? Which option is more reliable? Which option is in-line with industry standards? This is a re-write. Not a re-design. Baring small details, the entire app remains the same. You thus, have my intent, more clearly than any direction I could provide. You have the actual application in front of you.
4. If the UI's for `windows` and `macOS` are separately designed under the current tech stack, use the `windows` version (given `flutter` will make sure UI/UX is shared across all devices).
5. Re-working the CI pipeline and other aspects of the repo is part of this re-write to match the migration to `flutter`.

## 2. Problem and why now

Swiftie Quiz runs as a web page inside each operating system's browser engine (Tauri 2), with screens in React and TypeScript and networking, saving and updating in Rust. The owner wants one Flutter codebase that draws the same UI itself on macOS and Windows. They also want the improved cat from the design review to ship with it, and confirmation that the free music APIs behind the game are the best available. It is the owner's problem: they maintain two languages, three toolchains (Node, Rust, Tauri) and a UI whose look depends on four browser engines.

The audit and research found two live defects that make "now" matter, because both break the "new album shows up with no update" promise. Taylor Swift has 118 albums on Deezer, so today's single `limit=100` request drops 18 of them. Deezer preview links now expire about 15 minutes after they are fetched, and today's session cache keeps them forever, so rounds fail late in a session.

The benefit is measured by:
- every acceptance criterion in section 7 passing in CI on macOS and Windows;
- an existing player's save loading unchanged in the Flutter app;
- all 118 albums listing;
- a 30-minute session playing without preview failures;
- existing Tauri installs updating themselves to the Flutter build.

## 3. Users and stories

Players are Taylor Swift fans on macOS 12 or later (Apple Silicon) and Windows 10 or 11 (x64). They must not have to do anything differently, except that macOS 11 users cannot run the Flutter build. The maintainer works in Dart and Flutter instead of TypeScript, React and Rust, and releases through the same tag-driven GitHub workflow.

- As a player, I want the game to look and play exactly as before, so that the rewrite costs me nothing.
- As a player, I want my unlocked cats, stats and settings to carry over, so that I keep my progress.
- As a player, I want every album, including one released last week, so that the quiz covers the whole catalogue.
- As a player, I want songs to keep playing however long I play, so that late rounds do not fail.
- As a player on an installed Tauri version, I want the app to update itself to the new version, so that I never reinstall by hand.
- As a player, I want the redrawn cat on the menu button and in every loader, so that it looks finished at every size.
- As the maintainer, I want one Dart codebase with tests and CI equivalent to today's, so that changes stay safe.

## 4. Goals and non-goals

Goals (the release stops without each):
- Feature parity: every screen, flow, rule, text, timing, sound and animation of the React app, on macOS and Windows.
- The v2 cat icon and the v2 two-size vector cat loader everywhere the cat appears.
- Save compatibility: the same save.json format and location, with migrations and backups.
- Update compatibility: the same latest.json channel, minisign key and artifact formats, and PR #19's updater behaviour.
- The API review decided and applied: keep Deezer and LRCLIB, with album pagination, error bodies treated as failures, fresh preview links, and polite LRCLIB use.
- CI and release workflows rebuilt for Flutter, keeping the CI OK required check, draft releases, manifest verification and SLSA attestations.
- The Tauri, React and Rust stack and its project automation removed.

Non-goals:
- Redesigning anything other than the cat; restyling native-looking controls beyond matching the Windows rendering.
- New features, including an offline catalogue cache, a second music provider, live following of the OS theme while running, Linux, mobile or web builds, and Intel Mac builds.
- Code signing with an Apple Developer ID or a Windows certificate (today's builds are ad-hoc signed and unsigned).
- Changing achievements, scoring, difficulty rules or the save format version.
- Publishing a release or merging any pull request.

## 5. Boundaries

- Do not change the save file's location, name, JSON shape or version (3); existing saves must load.
- Do not change the update endpoint, latest.json schema, platform keys, artifact formats or the minisign key pair; do not add GitHub secrets.
- Do not change the music providers (Deezer, LRCLIB), the artist id 12246, the 50 requests per minute self-limit or the 10 s and 2 s timeouts.
- Do not change the bundle identifier com.swiftiequiz.desktop, product name "Swiftie Quiz", the Windows per-user install location or the executable name swiftie-quiz.
- Do not weaken the release gates (version and CHANGELOG checks, dev-key guard, draft-only releases, manifest verification, attestations) or the `CI OK` check name, which branch protection requires.
- Do not touch the parallel session's work: PR #20 and its v0.2.3 release branch.
- No step depends on a network service at test time; tests use fixtures and fakes.

## 6. Requirements

1. Same UI. Each React component is ported to a Flutter widget with the same text, layout, Tailwind sizes, colours (oklch tokens converted to sRGB), radii, shadows, gradients, icons (Lucide SVGs), entrance and hover animations, and timings. Example: the main menu title is "Swiftie Quiz" at 48 px weight 800, and the cards enter 0.1, 0.2, 0.3 and 0.4 s after the menu with a stiffness-300, damping-30 spring.
2. Windows look where the web engine drew the control. Example: the volume slider uses Chromium's #0075FF accent, and "Reset progress" confirms in an in-app dialog instead of window.confirm.
3. New cat. The static icon is design/cat-v2/cat-icon-v2.svg (87 x 174 viewBox). The loader is the ring-bent cat of cat-loader-v2.js, with a large drawing (300 px art in a 480 x 360 box) and a small one (80 px, heavier outline). It loops every 2.74 s, or 6.85 s when the platform asks to reduce motion. Example: the audio player's loading slot shows the small drawing whole instead of today's cropped fragment.
4. Same rules. The quiz, clip-selection and lyric engines are ported with their test suites. Example: the relisten schedule stays 10, 10, 15, 15, 20, 20 s and then the full preview.
5. Same save. The file is save.json in Tauri's app data folder for com.swiftiequiz.desktop: version 3, camelCase keys, atomic writes, up to three backups, migration from v1. Example: on macOS, /Users/a/Library/Application Support/com.swiftiequiz.desktop/save.json.
6. Same update channel. The app reads latest.json from the GitHub latest release and verifies minisign signatures with the existing key. It installs the .app.tar.gz bundle swap on macOS and runs the NSIS setup with /P /UPDATE /R /ARGS on Windows. It checks 1.5 s after launch and every 6 hours, following PR #19. Example: 0.3.0 is offered to 0.2.2 but 0.2.2 is not offered to 0.3.0.
7. Bridge. The first Flutter release's artifacts keep Tauri's names, formats and signatures, so installed Tauri copies install it through their own updater. Example: a v0.2.3 copy relaunches straight into the Flutter app on macOS.
8. APIs. Keep Deezer and LRCLIB:
   - follow Deezer `next` links;
   - treat a Deezer `error` body as a failure, even with HTTP 200;
   - expire cached tracks 60 s before their preview token's `exp`;
   - on a 403, refresh the track once from /track/{id};
   - send a SwiftieQuiz User-Agent;
   - on an LRCLIB 429, honour Retry-After (at most 10 s, one retry).

   Example: a 100-album page plus an 18-album page lists 118 albums.
9. Packaging. macOS builds produce an ad-hoc signed "Swiftie Quiz.app", "Swiftie Quiz_<version>_aarch64.dmg" and "Swiftie Quiz.app.tar.gz". Windows builds produce "Swiftie Quiz_<version>_x64-setup.exe" from an NSIS script that installs per user into %LOCALAPPDATA%\Swiftie Quiz.
10. CI and release. Flutter 3.47.5 runs format, analyze and tests on ubuntu-24.04, then builds and packages on macos-26 and windows-2025. The `CI OK` aggregator is kept, and actions stay pinned by SHA. Tags v* create a draft release with signed artifacts, latest.json and attestations.
11. Repository. The old stack is deleted, and the docs and project automation are rewritten for Flutter. The version becomes 0.3.0, with an Unreleased CHANGELOG entry.

Non-functional needs:
- Performance: window shown in under 1 s on Apple Silicon; clip analysis reads decoded samples at 8,000 per second; no frame drops in loader animation on a 60 Hz display.
- Security: HTTPS only to fixed hosts; update bytes accepted only with a valid minisign signature from the embedded key; no secrets in the app; the macOS app is not sandboxed, as today, and asks only for outgoing network access.
- Privacy: no accounts, no personal data; the only identifier sent is the app's User-Agent.
- Compatibility: macOS 12 or later on Apple Silicon (Flutter's minimum; macOS 11 is dropped), Windows 10 and 11 x64.
- Migration: existing saves load as is; existing installs upgrade through their updater.

## 7. Acceptance criteria

### 7.1 Platform identity

WHEN the macOS and Windows runners are configured, THE SYSTEM SHALL use bundle identifier com.swiftiequiz.desktop, product name "Swiftie Quiz", macOS deployment target 12.0, App Sandbox off with outgoing network allowed in both macOS entitlements files, Windows executable name swiftie-quiz, and Windows file description and product name "Swiftie Quiz".

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/scaffold/platform_config_test.dart` `platform identity matches the Tauri app`: AppInfo.xcconfig, both entitlements files, the Xcode project deployment target, windows/CMakeLists.txt BINARY_NAME and Runner.rc carry the identity values Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.2 Bundled assets

WHEN the app is built, THE SYSTEM SHALL bundle assets/cat/cat-icon.svg byte-identical to design/cat-v2/cat-icon-v2.svg, the 16 achievement cat SVGs and quack.mp3 byte-identical to their src/assets originals, and declare every asset folder in pubspec.yaml.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/scaffold/assets_test.dart` `bundled assets match the design and the Tauri assets`: byte equality of each asset with its source and pubspec asset declarations Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.3 Save format

WHEN progress is written and read, THE SYSTEM SHALL produce and accept the Tauri app's save.json shape: camelCase keys, version 3, the DEFAULT_PROGRESS values (theme dark, volume 0.8, mediumTimer 30, hardTimer 20, autoCheckEnabled true, empty skippedVersions), unknown-free round trip, and defaults for fields a v1 or v2 save lacks (mediumTimer 30, hardTimer 20, lyrics counters 0, updater defaults).

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/domain/models/progress_test.dart` `progress json matches the Tauri save format`: toJson of the default equals the DEFAULT_PROGRESS JSON; fromJson of the Rust test fixtures; round trip equality Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.4 Theme tokens

WHEN the theme is dark or light, THE SYSTEM SHALL resolve every token in src/styles/index.css to its sRGB colour (oklch converted with the CSS Color 4 formula, rounded to the nearest 8-bit channel), for example dark background #0A0A0A and light foreground #030213.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/ui/theme/app_tokens_test.dart` `tokens match index.css`: each dark and light token's ARGB value Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.5 Icons and logo

WHEN a screen asks for any of the 29 Lucide icons the React UI uses, THE SYSTEM SHALL render the bundled SVG of that icon tinted with the requested colour at the requested size, and the Swiftie logo SHALL render the #E97F6A circle with the white note at the requested size, hidden from accessibility.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/ui/widgets/app_icon_test.dart` `every lucide icon the UI uses is bundled`: each glyph's asset exists, parses and renders at 16 and 24 px Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/ui/widgets/swiftie_logo_test.dart` `swiftie logo parity`: the cases of SwiftieLogo.test.tsx Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.6 Loader choreography

WHEN the cat loader is at phase p in [0, 1), THE SYSTEM SHALL rotate the frame by spin(p) and end the body at bodyEnd(p) computed by the monotone cubic spline of design/cat-v2/cat-loader-v2.js, matching the JavaScript to within 0.01 degrees at p = 0, 0.1, 0.2, 0.3, 0.4, 0.45, 0.5, 0.65, 0.8, 0.9 and 0.99, and equal to the keyframe values at keyframe times.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/ui/cat/cat_loader_geometry_test.dart` `loader spline matches the design keyframes`: spin and bodyEnd against reference values computed from the JavaScript Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.7 Loader widget

WHEN CatLoader is shown, THE SYSTEM SHALL draw the large drawing as 300 x 300 art centred in a 480 x 360 box, the small drawing in an 80 x 80 box with the heavier outline, put the label 16 px below in 14 px weight 500 text only when the label is non-empty, run a 2.74 s cycle, and a 6.85 s cycle when the platform asks to reduce motion; and LoadingGate SHALL keep its LoadingGate.test.tsx behaviour.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/ui/cat/cat_loader_test.dart` `cat loader follows the v2 design`: box sizes, label presence and style, cycle durations Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/ui/cat/loading_gate_test.dart` `loading gate parity`: the cases of LoadingGate.test.tsx Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.8 Cat icon button

WHEN the cat icon button is shown at size s, THE SYSTEM SHALL draw assets/cat/cat-icon.svg at s/2 wide and s tall inside a hit area of at least 44 x 44, labelled "Open birthday card" for accessibility, and call its callback on tap.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/ui/cat/cat_icon_button_test.dart` `cat icon button uses the v2 icon`: asset, size, hit area, semantics label and tap; the cases of CatIconButton.test.tsx Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.9 Quiz engine parity

WHEN the ported quiz rules run on the inputs of the TypeScript suites, THE SYSTEM SHALL return the same outputs: track pools and draws, answer options, answer matching with close-match tolerance, achievement definitions and evaluation, the relisten schedule (10, 10, 15, 15, 20, 20 s then the full preview, extension notice from the third relisten), Levenshtein distance, shuffling and the birthday window.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/domain/engine/game_engine_test.dart` `game engine parity`: every case of src/engine/gameEngine.test.ts Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/domain/engine/option_generator_test.dart` `option generator parity`: every case of src/engine/optionGenerator.test.ts Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/domain/engine/answer_matcher_test.dart` `answer matcher parity`: every case of src/engine/answerMatcher.test.ts Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/domain/engine/achievements_test.dart` `achievements parity`: every case of src/engine/achievements.test.ts Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/domain/engine/relisten_schedule_test.dart` `relisten schedule parity`: every case of src/engine/relistenSchedule.test.ts Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/domain/util/levenshtein_test.dart` `levenshtein parity`: every case of src/lib/levenshtein.test.ts Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/domain/util/shuffle_test.dart` `shuffle parity`: every case of src/lib/shuffle.test.ts Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/domain/util/birthday_test.dart` `birthday parity`: every case of src/lib/birthday.test.ts Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.10 Clip and lyric engine parity

WHEN clip selection and lyric processing run on the inputs of the TypeScript suites, THE SYSTEM SHALL return the same outputs: the 250 ms RMS profile, energy score, centre bias, danger-zone penalty and chosen start with random fallback; chorus detection, snippet extraction, sanitising and the decoy-or-real choice with era groups.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/domain/engine/clip_selector_test.dart` `clip selector parity`: every case of src/engine/clipSelector.test.ts Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/domain/engine/lyric_processor_test.dart` `lyric processor parity`: every case of src/engine/lyricProcessor.test.ts Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.11 All albums load

WHEN Deezer answers the artist albums request with a next link, THE SYSTEM SHALL follow every next link and return all albums in order; for example a first page of 100 and a second page of 18 yield 118 albums.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/data/catalog/deezer_client_test.dart` `albums follow the next link`: two-page fixture returns 118 albums and two requests Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.12 Deezer errors

WHEN Deezer answers with a body containing an error object, including quota error code 4 with HTTP 200, THE SYSTEM SHALL fail the call with the rate-limit message "Taking a breather — try again in a moment." for code 4 and "API error: <message>" otherwise, and cache nothing.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/data/catalog/deezer_client_test.dart` `deezer error bodies are failures`: quota and other error bodies raise the mapped errors and a retry hits the network Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.13 Preview links stay fresh

WHEN cached album or top tracks hold preview links whose hdnea exp time is less than 60 seconds away, THE SYSTEM SHALL fetch them again instead of serving the cache; and refreshTrack(id) SHALL return the track from /track/{id} with its new preview link.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/data/catalog/deezer_client_test.dart` `cached tracks expire with their preview token`: fake clock before and after exp minus 60 s; refreshTrack request path Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.14 Track filter and rate limit parity

WHEN tracks are filtered and requests are counted, THE SYSTEM SHALL keep exactly the songs track_filter.rs keeps (60 s minimum, remix and non-song patterns, case-insensitive) and allow 50 requests per 60 s window as rate_limiter.rs does.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/data/catalog/track_filter_test.dart` `track filter parity`: every case of track_filter.rs tests Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/data/catalog/rate_limiter_test.dart` `rate limiter parity`: every case of rate_limiter.rs tests plus refill after 60 s Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.15 Lyrics fetch

WHEN lyrics are requested, THE SYSTEM SHALL try LRCLIB /get with track, artist, album and duration, then /search with the normalised title choosing the closest duration, process plain lyrics as lrclib_client.rs does, fetch batches five at a time, send the SwiftieQuiz User-Agent, and on HTTP 429 wait Retry-After seconds (at most 10) and retry once.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/data/lyrics/lrclib_client_test.dart` `lrclib client parity`: every case of lrclib_client.rs and commands/lyrics.rs tests Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/data/lyrics/lrclib_client_test.dart` `lrclib 429 honours retry-after`: a 429 with Retry-After 2 waits 2 s on a fake clock and retries once Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.16 Danger zones

WHEN synced lyrics are looked up for clip selection, THE SYSTEM SHALL return the same danger zones as src/lib/lrclib.ts: LRC parsing, preview offset estimate, title-word matching with stop words, 1.5 s padding, merged zones, a 100-entry cache and an empty list after 2 s or on any failure.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/data/lyrics/danger_zones_test.dart` `danger zones parity`: every case of src/lib/lrclib.test.ts Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.17 Save location

WHEN the app runs on macOS with HOME=/Users/a, THE SYSTEM SHALL read and write /Users/a/Library/Application Support/com.swiftiequiz.desktop/save.json; on Windows with APPDATA=C:\Users\a\AppData\Roaming it SHALL use C:\Users\a\AppData\Roaming\com.swiftiequiz.desktop\save.json.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/data/save/save_location_test.dart` `save path matches the Tauri app data directory`: path for injected macOS and Windows environments Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.18 Save load, migration and backups

WHEN the save is loaded, written, migrated, backed up, listed or restored, THE SYSTEM SHALL behave as the Rust storage module: fresh when missing, loaded when current, migrated with a backup first and persisted when older, an error naming the version when newer, atomic writes through save.json.tmp, pretty-printed JSON, at most three backups named save.backup.<unix seconds>.json listed newest first, restore by timestamp.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/data/save/save_store_test.dart` `save store parity`: every case of load.rs, save.rs and backup.rs tests Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/data/save/migrations_test.dart` `migrations parity`: every case of migrations.rs tests Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.19 Update manifest

WHEN latest.json is fetched, THE SYSTEM SHALL read version, notes, pub_date and platforms, pick darwin-aarch64 on macOS and windows-x86_64 on Windows, and offer the update only when its semantic version is strictly greater than the running version (0.2.0 rejects 0.2.0 and 0.1.5, accepts 0.2.1, 0.3.0 and 1.0.0).

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/services/updater/update_manifest_client_test.dart` `manifest selection and version gate`: platform choice, field parsing and the lib.rs version cases Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.20 Signature check

WHEN an update file is downloaded, THE SYSTEM SHALL accept it only if its minisign signature (Tauri format, Ed25519 over the BLAKE2b-512 prehash, with a valid trusted-comment global signature) verifies with the embedded public key, and SHALL reject tampered bytes, a different key id and a malformed signature.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/services/updater/minisign_test.dart` `minisign verification`: fixture signed by the Tauri CLI signer verifies; three negative cases fail Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.21 Installers mirror Tauri

WHEN an update installs on macOS, THE SYSTEM SHALL unpack the .app.tar.gz skipping each entry's first path component, move the running bundle aside, move the new bundle into its place and restore the old one if that fails; on Windows it SHALL write the setup .exe to a temporary file and start it detached with the arguments /P /UPDATE /R /ARGS, then exit.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/services/updater/update_installer_test.dart` `installers mirror the Tauri updater`: bundle swap and rollback on temporary directories; Windows command line built by a pure function Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.22 Game controller parity

WHEN game actions run, THE SYSTEM SHALL produce the state changes of src/stores/gameStore.ts, including streak and quack counters, per-album guessed tracks, session counters kept across resetGame, lyrics pool cycling and immutable updates.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/state/game_controller_test.dart` `game controller parity`: every case of src/stores/gameStore.test.ts Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.23 Persistence parity

WHEN the app starts and progress changes, THE SYSTEM SHALL load once, never save before a successful load, save at most once per second of quiet with identical progress skipped, show "Welcome back! Your progress has been preserved. (Migrated from save format v<n>.)" after a migration, and "Couldn't load your save. Open Settings → Backups to restore from a backup." when loading fails.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/state/persistence_controller_test.dart` `persistence parity`: every case of src/hooks/usePersistence.test.ts Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.24 Achievements, lyrics and catalog controllers

WHEN rounds are answered and pools are prepared, THE SYSTEM SHALL unlock and toast achievements as useAchievements does, prepare and extend the lyrics pool as useLyrics does (top tracks or selected albums, at least five songs, decoy pool), and load albums and tracks as useDeezer does.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/state/achievements_controller_test.dart` `achievements controller parity`: unlock conditions, unlockedAt, toast ids, no duplicate unlocks Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/state/lyrics_controller_test.dart` `lyrics controller parity`: pool building, decoys, progress, more-fetching Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/state/catalog_controller_test.dart` `catalog controller parity`: album cache use, track pool for random and album modes Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.25 Audio controller parity

WHEN a round plays, THE SYSTEM SHALL behave as src/hooks/useAudio.ts: download and decode the preview, choose a 10 s slice with smart clip selection and danger zones, report loading, progress and clip duration, pause and resume from the same point, play the relisten schedule, ignore results of a superseded play, play the quack at min(volume x 0.9, 1); and when the preview download answers 403 it SHALL refresh the track once and retry with the new link.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/state/audio_controller_test.dart` `audio controller parity`: every case of src/hooks/useAudio.test.ts with a fake engine Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/state/audio_controller_test.dart` `expired preview is refreshed once`: 403 then refreshTrack then success; a second 403 surfaces an error Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.26 Updater state machine

WHEN update checks, downloads, installs, skips, reminders and cancels happen, THE SYSTEM SHALL follow src/hooks/useUpdater.ts as fixed by PR #19: auto checks honour autoCheckEnabled and remindLaterUntil, manual checks bypass them, skipped versions are never offered, a check never disturbs a downloading, ready, installing or installed update, lastCheckedAt is written from the latest progress, cancel abandons the download for good, retry after a failed check checks again, and after install the app relaunches or shows the installed state when relaunch fails.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/state/updater_controller_test.dart` `updater controller parity`: every case of src/hooks/useUpdater.test.ts on main at 8c0130e Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.27 Menu and selection screens

WHEN the player uses the main menu and the selection screens, THE SYSTEM SHALL navigate exactly as today: Random Mode to quiz type, Pick Albums to album select, Cat Gallery, Settings, sound to difficulty, lyrics to lyrics mode, every back link to its React target, and the difficulty cards listing the same features for each quiz type and timer setting.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/ui/screens/navigation_screens_test.dart` `menu and selection navigation`: taps on each card and back link land on the expected phase; difficulty feature text Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.28 Settings

WHEN the Settings screen is used, THE SYSTEM SHALL offer Dark, Light and System themes, volume 0 to 1 in steps of 0.01, medium and hard timers 10 to 40 s in steps of 5, a two-step reset, the version from the build, last-checked time, Check now and the auto-check switch, and the backups list with Restore, with today's texts.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/ui/screens/settings_screen_test.dart` `settings parity`: each control changes the matching progress field; reset needs two steps; backups restore calls the store Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.29 Gallery, albums and birthday card

WHEN the gallery, album grid or birthday card is shown, THE SYSTEM SHALL show "N of 15 achievements unlocked" with locked and unlocked tiles, album tiles that toggle selection with the Start Quiz footer, and the birthday card behaviour of BirthdayCard.test.tsx with readable body text in light theme.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/ui/overlays/birthday_card_test.dart` `birthday card parity`: every case of BirthdayCard.test.tsx and the light-theme text colour Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/ui/screens/cat_gallery_test.dart` `cat gallery parity`: counts, locked and unlocked tiles Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/ui/screens/album_grid_test.dart` `album grid parity`: selection toggling, footer label and Clear all Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.30 Sound round

WHEN a sound round runs, THE SYSTEM SHALL show the small cat loader while the clip loads, options on easy and medium and a text box on hard, the album hint only on easy, the timer only on medium and hard, add one to the streak on a right answer and reset it with a quack on a wrong answer or timeout, and show "Loading next track..." with the large loader between rounds for 400 ms to 8 s.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/ui/screens/game_screen_test.dart` `sound round flow`: fake audio and catalog drive easy, medium and hard rounds Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.31 Lyrics rounds

WHEN lyrics rounds run, THE SYSTEM SHALL show the lyrics loading screen with the ten rotating messages every 3 s and the large loader, start once five songs are ready, and run Name That Song and Lyrics or Lie with the line counts per difficulty of LyricsGameScreen.tsx.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/ui/screens/lyrics_game_screen_test.dart` `lyrics round flow`: both modes, line counts per difficulty, answers update streak and stats Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/ui/screens/lyrics_loading_screen_test.dart` `lyrics loading screen`: message rotation, auto start at five songs, error state Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.32 Gameplay widgets

WHEN gameplay widgets render, THE SYSTEM SHALL match their React tests and props: result feedback messages and the 2 s disabled Next, the streak badge, quiz options and the hard-mode input with Enter to submit, the timer bar turning destructive at 30 percent left, and the audio player button states and progress text.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/ui/game/result_feedback_test.dart` `result feedback parity`: every case of ResultFeedback.test.tsx Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/ui/game/streak_badge_test.dart` `streak badge parity`: every case of StreakBadge.test.tsx Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/ui/game/quiz_card_test.dart` `quiz card parity`: options, disabled state, hard input autofocus and Enter Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/ui/game/timer_bar_test.dart` `timer bar parity`: 100 ms ticks, expiry callback, colour switch at 30 percent Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/ui/game/audio_player_test.dart` `audio player parity`: play, pause, resume, relisten actions, extension notice, small loader while loading Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.33 Update badge and dialog

WHEN the updater is available, downloading, ready or in error, THE SYSTEM SHALL show the corner badge with today's label and colour, open the update dialog on click with the per-state content of UpdateModal.tsx, and close the dialog on Escape.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/ui/overlays/update_badge_test.dart` `update badge parity`: every case of UpdateBadge.test.tsx Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/ui/overlays/update_modal_test.dart` `update modal parity`: every case of UpdateModal.test.tsx Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.34 Toasts

WHEN an achievement unlocks or the app shows a message, THE SYSTEM SHALL stack achievement toasts top right, each dismissing after 4 s or on its close button, and show the message toast at the bottom centre for 5 s.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/ui/overlays/achievement_toasts_test.dart` `achievement toasts`: stacking, 4 s auto dismiss per toast independent of new toasts, close button Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).
- `test/ui/overlays/toast_host_test.dart` `toast host`: message shown then gone after 5 s Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.35 Phase routing

WHEN the game phase changes, THE SYSTEM SHALL show the matching screen for each of the nine phases, LyricsGameScreen for playing with the lyrics quiz type and GameScreen otherwise, with the toasts, update badge and update dialog layered over every screen, and the theme following the saved setting.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/app/app_test.dart` `phase routing`: each phase renders its screen; overlays present; dark, light and system themes Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.36 Update schedule

WHEN the app runs, THE SYSTEM SHALL check for updates 1.5 s after launch and then every 6 hours, and never more often, even as progress changes (the PR #19 loop regression).

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/app/app_test.dart` `update checks run once at launch and every six hours`: fake async: one check at 1.5 s, none after 30 s of progress changes, one more at 6 h Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.37 Window

WHEN the app starts, THE SYSTEM SHALL open a window titled "Swiftie Quiz" sized 1024 x 800, centred, with a minimum size of 686 x 571.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/app/window_setup_test.dart` `window matches the Tauri window`: the window options passed to window_manager Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.38 Windows installer script

WHEN the NSIS script is compiled, THE SYSTEM SHALL install per user into $LOCALAPPDATA\Swiftie Quiz with swiftie-quiz.exe, write the uninstall key Software\Microsoft\Windows\CurrentVersion\Uninstall\Swiftie Quiz, create the Start menu and desktop shortcuts Tauri's template creates, remove the Tauri-era files the Flutter build no longer ships, and honour /P, /S, /UPDATE, /R and /ARGS as Tauri's template does.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/installer/nsis_script_test.dart` `installer is compatible with Tauri installs and updater flags`: required directives, paths, registry keys and option handling are present in the script Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.39 Windows install on a real machine

WHEN the built setup .exe runs on Windows 11 over an existing Tauri v0.2.x install, THE SYSTEM SHALL replace it in place, keep the save, and start the Flutter app.

Where passing proves it: the Flutter Windows desktop app and its NSIS installer on Windows 11 x64.

Unproven: Workers run on macOS and cannot run Windows; checked after the run on the CI Windows build and the VMLab Windows 11 image.

### 7.40 latest.json generation

WHEN the release tool builds latest.json from a version, notes, a publish date and the four signed artifacts, THE SYSTEM SHALL write version, notes, pub_date and platforms darwin-aarch64, darwin-aarch64-app, windows-x86_64 and windows-x86_64-nsis, each with the signature file's text and the release asset download URL.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/tool/make_manifest_test.dart` `latest.json carries every platform`: the JSON written for a fixture set of artifacts Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.41 Release checks

WHEN a tag v<x> is released, THE SYSTEM SHALL refuse unless pubspec.yaml's version (before any +build) equals x, CHANGELOG.md has a "## [x]" section with text, and the embedded updater public key is present, valid base64 and not the development key 2A43CC33F3FB57BB; and SHALL print that section as the release notes.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/tool/check_release_test.dart` `release checks`: each refusal and the notes extraction on fixtures Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.42 Workflows

WHEN the workflows run, THE SYSTEM SHALL keep a job named "CI OK" that needs every other CI job, pin every third-party action by a 40-character commit SHA, pin Flutter 3.47.5, run format, analyze and tests, build and package on macos-26 and windows-2025, and in the release workflow keep the draft release, manifest verification and SLSA attestation jobs.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/tool/workflows_test.dart` `ci and release workflows`: parsed YAML job names, needs, action pins, commands Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.43 Old stack retired

WHEN the rewrite lands, THE SYSTEM SHALL contain no src/, src-tauri/, package.json, package-lock.json, index.html, public/, vite, vitest, eslint, tsconfig or rust-toolchain files, no project automation that builds or tests with npm, cargo or the Tauri CLI (the release workflow's use of the Tauri CLI signer to sign artifacts with the existing key is the one exception), and CLAUDE.md, AGENTS.md, README.md and docs/INSTALL.md SHALL give the Flutter commands.

Where passing proves it: flutter test on the macOS host Dart VM (unit and widget tests, no device).

- `test/repo/repo_layout_test.dart` `tauri stack is gone and docs describe flutter`: paths absent; no npm, cargo or tauri commands in docs and .claude; flutter commands present Runs in: flutter test on the macOS host Dart VM (unit and widget tests, no device).

### 7.44 Existing installs update to the Flutter app

WHEN v0.3.0 is published and an installed Tauri copy (v0.2.1 or later) checks for updates, THE SYSTEM SHALL offer, download, verify and install the Flutter build through that copy's own updater, and the Flutter app SHALL open with the player's save.

Where passing proves it: the Flutter macOS desktop app on Apple Silicon, macOS 26; the Flutter Windows desktop app and its NSIS installer on Windows 11 x64.

Unproven: It needs a published GitHub release; checked by a dry run against a locally served latest.json before the release is published.

### 7.45 Looks the same

WHEN each screen of the Flutter app is put beside the same screen of the Tauri app at 1024 x 800 in both themes, THE SYSTEM SHALL show the same layout, text, colours and sizes, except the cat icon and cat loader.

Where passing proves it: the Flutter macOS desktop app on Apple Silicon, macOS 26; the Flutter Windows desktop app and its NSIS installer on Windows 11 x64.

Unproven: Side-by-side comparison is a visual judgement; done after the run by building both apps and comparing screenshots.

## 8. Edge cases

- Albums: zero albums gives today's empty grid. Exactly 100 albums with no `next` makes one request. A `next` link to another host is not followed.
- Album id 0 is rejected with "API error: Invalid album ID", as today.
- Previews:
  - A track whose preview URL has no `hdnea` token is cached for 10 minutes.
  - A token already expired forces a refetch.
  - A second 403 after one refresh shows the round's error state with "Back to Menu".
- Deezer quota: a quota error mid-session shows "Taking a breather — try again in a moment." and nothing broken is cached.
- LRCLIB:
  - A 429 without Retry-After waits 1 s.
  - A Retry-After above 10 is capped at 10 s.
  - A second 429 reports "Lyrics service unavailable — try again later."
  - Danger-zone lookups give up after 2 s and play a smart clip without them.
- Lyrics pool: fewer than five songs with lyrics keeps the loading screen, then the 30 s timeout error, as today.
- Save file:
  - A missing save starts fresh with no toast.
  - A save with no version or a non-numeric version migrates from v1 and reports no version.
  - A save from a newer version blocks saving and shows the backup hint.
  - A failed backup delete keeps more than three backups.
  - A missing HOME or APPDATA is a file error.
- Updates:
  - The same or an older version is never offered.
  - A skipped version is never offered, even on a manual check.
  - A check during a download changes nothing.
  - A cancelled download's late events are ignored.
  - A relaunch failure shows the installed state and asks the player to reopen.
- Units and precision: volume 0 to 1 in 0.01 steps; timers 10 to 40 s in 5 s steps; progress percentages are whole numbers; dates use the system locale's short format; times are stored as ISO 8601 UTC strings.
- Window: no resizing below 686 x 571; content scrolls vertically at the minimum size; there is no horizontal scroll.
- Reduced motion: the loader slows to 6.85 s; the update dialog skips its scale animation; the badge spinner stops.

## 9. Code map

| Today | Flutter |
|---|---|
| src/types/index.ts, src-tauri/src/models/ | lib/domain/models/ |
| src/engine/, src/lib/{levenshtein,shuffle,birthday}.ts | lib/domain/engine/, lib/domain/util/ |
| src-tauri/src/services/deezer_client.rs, track_filter.rs, rate_limiter.rs, cache.rs, commands/deezer.rs | lib/data/catalog/ |
| src-tauri/src/services/lrclib_client.rs, commands/lyrics.rs, src/lib/lrclib.ts | lib/data/lyrics/ |
| src-tauri/src/storage/, commands/storage.rs | lib/data/save/ |
| tauri-plugin-updater 2.13, tauri.conf.json updater block | lib/services/updater/ |
| src/hooks/useAudio.ts, src/engine/quackManager.ts | lib/services/audio/, lib/state/audio_controller.dart |
| src/stores/gameStore.ts, src/hooks/use{Persistence,Deezer,Lyrics,Achievements,Updater}.ts, src/lib/toast.ts | lib/state/ |
| src/styles/index.css, shared component patterns | lib/ui/theme/, lib/ui/widgets/ |
| src/components/CatIconButton.tsx, CatLoader.tsx, CatLoader.css, LoadingGate.tsx | lib/ui/cat/ (v2 design) |
| src/components/*.tsx screens and overlays | lib/ui/screens/, lib/ui/game/, lib/ui/overlays/ |
| src/App.tsx, src/main.tsx, ErrorBoundary.tsx, tauri.conf.json window | lib/app/, lib/main.dart |
| Tauri NSIS bundler | installer/windows/swiftie-quiz.nsi |
| .github/workflows/, tauri-action | .github/workflows/, tool/release/ |

The pattern to follow is the charter at docs/specs/flutter-rewrite.charter.md:
- immutable state and models;
- pure Dart in lib/domain;
- side effects behind injected collaborators;
- one ported test group per TypeScript or Rust test file;
- no comments;
- Riverpod 3 Notifiers.

The command that runs one test is `flutter test test/domain/engine/answer_matcher_test.dart --plain-name "answer matcher parity"`.

## 10. Approach and alternatives

Chosen: a full port to one Flutter app at the repository root. Each React component, hook, engine module and Rust service is ported one-for-one, and its tests are ported with it. The work ships as six stacked groups of pull requests built in parallel by mitosis:
- foundation;
- logic and data;
- state and services;
- screens;
- packaging and CI;
- retiring the old stack.

The decisive reasons:
- Flutter draws the UI itself, so both platforms look identical.
- The logic is small and pure, so porting it costs less than bridging it.
- Keeping the Tauri update protocol lets existing installs upgrade without new keys or secrets.

Alternatives considered:
- Flutter UI over the existing Rust core through flutter_rust_bridge. Rejected: it keeps two languages and an FFI layer for about 2,500 lines of simple networking and file code, with no performance gain at this scale.
- Sparkle and WinSparkle for updates. Rejected: they need a new key pair and secrets that cannot be created unattended. They also need a second feed while Tauri copies still read latest.json.
- just_audio or media_kit for audio. Rejected: neither exposes decoded samples, so smart clip selection could not be ported.
- iTunes Search, MusicBrainz plus Cover Art Archive, Spotify, Apple Music, Musixmatch or Genius instead of Deezer and LRCLIB. Rejected:
  - Spotify bans trivia games and dropped previews.
  - Apple Music and Musixmatch synced lyrics are paid.
  - iTunes preview terms forbid entertainment use.
  - MusicBrainz has no audio.
  - Genius has no lyrics endpoint.
- MSIX or Inno Setup on Windows. Rejected: the installed Tauri updater launches an .exe with NSIS flags.

## 11. Assumptions

- Decided under the user's standing directive: every choice in docs/specs/flutter-rewrite.decisions.md not quoted from the user.
- No component branches on the operating system, so the "use the Windows version" rule applies only to controls the web engine drew (sliders, checkbox, confirm and alert dialogs, scrollbars, dates).
- Tauri derives the manufacturer "swiftiequiz" from the identifier com.swiftiequiz.desktop. The NSIS script writes HKCU\Software\swiftiequiz\Swiftie Quiz and the uninstall key "Swiftie Quiz", as Tauri 2.12's template does.
- Equally spaced decoded samples at 8,000 per second rank quiet windows the same as full-rate RMS for 30 s previews.
- Fixing four visible bugs counts as a small detail, not a redesign:
  - the cropped small loader;
  - the toast timer restarting;
  - the missing dialog exit animation;
  - white-on-white birthday text in light theme.
- The development minisign key id 2A43CC33F3FB57BB is still the one the release guard must reject.
- PR #20 (v0.2.3) changes only the Tauri app and its release; the rewrite starts from main at 8c0130e and needs nothing from it.
- Version 0.3.0 marks the rewrite; the release PR sets the CHANGELOG date.
- Flutter 3.47.5 and the package versions resolved on 2026-10-05 are the pinned toolchain.

## 12. Open questions

1. Should v0.2.4 of the Tauri app refuse updates on macOS 11 before v0.3.0 is published? Safe to leave open: it is a release-time decision about the old app, and nothing in this rewrite depends on it. Without it, a macOS 11 Tauri copy would install a Flutter build that does not open there.
2. When should the bridge release go out relative to v0.2.3? Safe to leave open: publishing is a human step after review, and the artifacts work either way.

## 13. Verification

- Per step: `flutter test <file> --plain-name "<acceptance name>"` for every acceptance test, then `flutter analyze --fatal-infos` and `dart format --output=none --set-exit-if-changed lib test tool`.
- Integration, after all branches merge locally: `flutter test`; `flutter build macos --release`; `tool/release/package_macos.sh 0.3.0`; then launch the app and play one random sound round, one album round, and one round of each lyrics mode, in both themes.
- Visual comparison: build the Tauri app from main and the Flutter app, open each screen at 1024 x 800 in both themes, compare screenshots, and expect differences only in the cat.
- Save carry-over: copy a real save.json into the Application Support folder, launch the Flutter app, and confirm the gallery and stats are unchanged.
- Windows: run the CI windows-2025 build, then install the setup .exe in a fresh VMLab Windows 11 over a v0.2.2 install, launch it, and confirm the save loads.
- Bridge dry run: serve a local latest.json pointing at locally signed v0.3.0 artifacts, point a v0.2.2 test build at it, and confirm it installs and opens the Flutter app.

## 14. Reuse and change

Reused as is:
- design/cat-v2/cat-icon-v2.svg: the static cat icon asset.
- src/assets/cats/*.svg and src/assets/sounds/quack.mp3: bundled unchanged.
- src-tauri/icons/icon.icns and icon.ico: app icons.
- The minisign key pair and the TAURI_SIGNING_PRIVATE_KEY secrets: update signing.
- Pinned action SHAs (checkout, upload-artifact, download-artifact, attest-build-provenance, setup-node): CI and release.
- docs/decisions/2026-10-04-ci-hardening.md: the CI rules the new workflows keep.

Kept separate:
- lib/data/lyrics/danger_zones.dart and lrclib_client.dart: one serves clip selection with a 2 s budget, the other serves lyric rounds with retries; they change for different reasons, as src/lib/lrclib.ts and lrclib_client.rs did.
- The updater protocol (lib/services/updater/) and the updater state machine (lib/state/updater_controller.dart): transport and policy change independently.

Changed:
- Every file under src/ and src-tauri/: ported to lib/ and then deleted.
- .github/workflows/ci.yml and release.yml: rebuilt for Flutter.
- CLAUDE.md, AGENTS.md, README.md, docs/INSTALL.md, CHANGELOG.md, receipts.config.json and .claude/: rewritten for Flutter.
