# Project Swiftie redesign

Pathway: prototype.

Date: 2026-10-06.

## 1. Request

Review the following Claude Code prototype:

```text
Use the claude_design MCP (https://api.anthropic.com/v1/design/mcp, auth via /design-login) to import this project:
https://claude.ai/design/p/27738b4d-96c4-4170-87aa-d19b2f0407f2?file=design_handoff_project_swiftie%2FProject+Swiftie.dc.html

Focus on these files (the whole project is readable):
- `design_handoff_project_swiftie/Project Swiftie.dc.html`
- `design_handoff_project_swiftie/assets/app-icon/app-icon-macos-small.svg`
- `design_handoff_project_swiftie/assets/app-icon/app-icon-macos.svg`
- `design_handoff_project_swiftie/assets/app-icon/app-icon-small.svg`
- `design_handoff_project_swiftie/assets/app-icon/app-icon.svg`
- `design_handoff_project_swiftie/assets/app-icon/mark.svg`
- `design_handoff_project_swiftie/assets/cat-icon-v2.svg`
- `design_handoff_project_swiftie/cat-loader-v2.js`
- `design_handoff_project_swiftie/README.md`
- `design_handoff_project_swiftie/support.js`

Implement: the selected files
```

This prototype visualizes a complete re-work of the app UI/UX. Review and implement this new UI/UX design into the live `flutter` application.

Few things to keep in mind:

1. The app name is now `Project Swifte` and NOT `Swiftie Quiz`.
2. There are two versions of the app. One personalized for my friend, Ana (who this app was primarily built for). Two, Open (for anyone else). Make sure to distinctly identify the differences in the UI/UX, available functionality, etc. between these two versions.
3. The app will continue to be built for macOS and windows. There will be three releases. One macOS (open edition). Two windows (ana and open editions). i.e., you are adding a new release.
4. Recognize the OS specific details. e.g., Windows (like macOS), now blends it's top menu bar into the app.
5. Make sure to understand and implement both dark and light mode.

Development Instructions:

* You will use `interphase:prototype` to complete this task.
* You will work autonomously without any expectation of clarifications from me. I intend on starting this task, going to bed.
* You will `spec` the prototype implementation and then dispatch the task using `mitosis`.
* When I wake up, I expect the implementation to be fully complete with all PRs open for me to review.
* `interphase:prototype` was designed to ask questions regarding intent, gaps, etc. You have the original application for my intent. The new UI/UX design above is simply a re-design/face-lift.

Do the above instructions make sense? You have one chance to ask me questions (if any). Otherwise. proceed with the task. Go.

## 2. Source artefacts

| Artefact | Where it lives | Runnable |
|---|---|---|
| Claude Design project "Cat Asset Redesign Review" | https://claude.ai/design/p/27738b4d-96c4-4170-87aa-d19b2f0407f2, folder design_handoff_project_swiftie/ | Yes, in the Claude Design editor |
| Prototype `Project Swiftie.dc.html` | copied byte-for-byte to docs/specs/project-swiftie-redesign.design/Project Swiftie.dc.html (196 137 bytes; markup lines 1 to 1021, logic lines 1022 to 1958) | Yes, in a browser beside support.js and cat-loader-v2.js; it reads live Deezer data |
| Handoff README | docs/specs/project-swiftie-redesign.design/README.md | Not applicable |
| support.js, cat-loader-v2.js | docs/specs/project-swiftie-redesign.design/ | Prototype runtime and cat loader reference |
| App icon SVGs (macOS, macOS small, full, small, mark) | docs/specs/project-swiftie-redesign.design/assets/app-icon/ | Not applicable |
| Misu vector cat-icon-v2.svg | docs/specs/project-swiftie-redesign.design/assets/cat-icon-v2.svg; identical apart from metadata to assets/cat/cat-icon.svg already in the app | Not applicable |
| The live v0.3.0 Flutter app | this repository, branch main at 5f3ce5e | Yes, flutter run -d macos |

The cat loader of the handoff (cat-loader-v2.js) is already implemented in the app as CatLoader with the same geometry (lib/ui/cat/cat_loader.dart, cat_loader_geometry.dart), and the Misu vector is already the app's assets/cat/cat-icon.svg; both are reused.

## 3. Intended and incidental

The handoff states its own fidelity: colours, type, spacing, motion and copy are final (README section Fidelity), confirmed by the design author in the README. Deliberate and built: the vinyl visual language, the token sets for both themes, the two editions, Misu's visits, the record shelf, the merged set-up screen, Tonight's era quick round with its summary, the bracelet, the anti-peek record flip, the blended title bars on macOS and Windows, the new update badge and dialog copy, and the new app icon.

Incidental, as the README marks them PROTOTYPE-ONLY and not built: SAMPLE lyric lines and their captions, FALL fallback titles, jsonp and the album fetch code, seedStats and seedUnlocked demo progress, the synthesized quack, simulated update timings and backups, simulated multiplayer players and room codes, the Tweaks props (platform, window size, network, update, birthday), and the desktop backdrop and fake window frame drawing. The prototype's traffic-light coordinates illustrate the native macOS buttons and are not reproduced by moving them (orchestrator decision, decisions file). The prototype's "you's record shelf" for a nameless Open player is an accident; the app writes "Your record shelf".

Deliberate in the mockup but not built, by orchestrator decision under the user's face-lift instruction: Play together (hub, host, join, lobby, multiplayer rounds, standings, final standings), because its networking is not designed (README line 9).

## 4. Screens and journeys

| Screen | Final or exploratory | Journeys |
|---|---|---|
| Title bar (macOS 28 px, Windows 32 px with caption buttons) | Final | Every journey; update badge opens the update dialog |
| First launch (nickname) | Final, Open edition only | First run of the Open edition |
| Main menu | Final | Greeting; birthday card (Ana); Tonight's era quick round; Shuffle everything; Pick your eras; record shelf; settings |
| Pick your eras | Final | Choose eras, then set up |
| Set up | Final | Choose Sound or Lyrics, lyrics game, difficulty, start |
| Lyrics loading | Final | Lyrics games before the first round |
| Game (sound, Name That Song lyrics, Lyrics or Lie) | Final | Play rounds; quick round of 10 |
| Round summary | Final | End of Tonight's era quick round |
| Record shelf | Final | Review records; hover to hear |
| Settings | Final | Theme, volume, Misu visits, nickname (Open), timers, updates, backups, reset, about |
| Overlays: Misu visit, toasts, confirm dialog, update dialog, restarting cover, birthday card (Ana), between-songs loader | Final | As triggered |
| Play together screens | Exploratory for this release (networking not designed) | Not built |

## 5. State matrix

| Screen | Ideal | Empty | Loading | Partial | Error |
|---|---|---|---|---|---|
| Nickname | Name typed, button enabled | Button at 45 % and inert | Not applicable | Not applicable | Blank input is ignored |
| Main menu | Greeting, rows, tonight's cover | Shelf link reads 0 of 15 | Tonight's era shows its placeholder colour until the cover loads | Missing cover keeps the placeholder | Catalogue failure only affects the cover |
| Pick your eras | 12 tiles | "Pick at least one era", Continue inert | Cat loader "Loading albums..." | Eras Deezer does not return are skipped | "The record store is closed." with Try again and Back to menu |
| Set up | Choices and feature list | Not applicable | Song count reads "Every song, every era" until known | Not applicable | Not applicable |
| Lyrics loading | Messages, bar, "N of M songs" | "Getting the songs ready…" | Itself | Progress bar partly filled | "The lyric sheets got lost." with Try again and Back to menu |
| Game | Record, transport, answers | Not applicable | "Loading tracks..." first; "Loading next track..." between songs for at least 450 ms | Missing cover keeps the placeholder | "The needle won't drop." with retry and a way back |
| Round summary | Score, beads, covers | Covers grid hidden at 0 right with "Not a single one. The vault stays locked." | Not applicable | Not applicable | Not applicable |
| Record shelf | Records and dashed slots | All 15 dashed | Covers fill in when albums load | Legacy records show only their date | Hover audio fails silently |
| Settings | All sections | Backups section lists none when there are none | Check now shows a spinner | Not applicable | Check result shows the updater's error |
| Update dialog | Available, downloading, ready | Up to date: "No updates" | Downloading progress; installing cover | Not applicable | "The update hit a snag" with the error |

## 6. Content variation

Long song and album titles ellipsize in toasts and wrap in headings (text-wrap balance in the mockup becomes normal wrapping). Missing covers fall back to the era's placeholder colour (oklch(0.46 0.07 hue) converted to sRGB in the era table) or the card colour. Achievement records unlocked before save version 4 have no song: the shelf shows only the date and plays nothing on hover; their toast never reappears. Nicknames are capped at 20 characters. An Open player with no nickname reads as "you" ("Your record shelf", "your record shelf and stats"). Track numbers appear only when known.

## 7. Interactions not shown

| Interaction | Behaviour |
|---|---|
| Keyboard in games | 1 to 4 answer on Easy and Medium, Space plays or pauses, R and F answer Lyrics or Lie, Enter goes to the next song once enabled; typing in the Hard field never triggers shortcuts |
| Esc | Closes the birthday card, then a confirm dialog, then the update dialog, then sends Misu away |
| Window drag and double-click | The title bar drags the window; double-click zooms on macOS and toggles maximise on Windows |
| Theme change | All colours cross-fade over 300 ms |
| Reduced motion | Every animation is instant |
| Leaving the shelf mid-preview | The preview stops |
| Focus | Every interactive element is reachable by Tab with a visible coral focus ring |

## 8. Data sources

| Data | Source | When it fails or is slow |
|---|---|---|
| Album covers, tracks, 30 s previews | Deezer public API through lib/data/catalog/deezer_client.dart (rate-limited, cached) | Eras grid error state; game error state; covers keep placeholders |
| Lyrics | LRCLIB through lib/data/lyrics/lrclib_client.dart and danger_zones.dart | Lyrics loading error state |
| Progress, settings, records, nickname | save.json through lib/data/save/ (version 4) | Load failure falls back to defaults as v0.3.0 does |
| Updates | latest.json on GitHub releases through lib/services/updater/ | Badge "Update issue" and the dialog's error banner |
| Edition | --dart-define=EDITION at build time | Missing value builds the Open edition |
| Time of day, date | Local clock (clockProvider) | Not applicable |

## 9. Validation and errors

Nickname: trimmed, at most 20 characters, blank ignored, no error message (the button stays inert). Hard answers: no length limit; typo tolerance unchanged (answer_matcher.dart). Error copy, exact: "The record store is closed.", "The lyric sheets got lost.", "The needle won't drop.", "The update hit a snag", "Could not reach the update server." (when the updater has no message), "Update issue".

## 10. Auth and permissions

Not applicable: no accounts, no sign-in, no server of our own. The edition is fixed at build time and cannot be switched at runtime. Updates are verified with the existing minisign key before install.

## 11. Persistence and concurrency

Save format version 4 with a migration from version 3 (decisions file). Saving keeps v0.3.0's debounced writes, backups and restore. One player per installation; no concurrent editing. Ana and Open editions share the save location, so one machine runs one edition.

## 12. Accessibility

Target: keyboard operable with visible focus, targets at least 24 by 24 logical pixels (answer buttons 56 px tall, caption buttons 46 by 32, links 44 px tall), reduced motion respected. Contrast follows the design tokens, which the designer set per theme (coralT darkens to #B4533F in light theme for text).

## 13. Responsive behaviour

| Width | Behaviour |
|---|---|
| Below 900 px (minimum window 686 by 571) | Single column; era and shelf grids 3 columns; sleeve 200 px; padding 32; H1 44 |
| 900 to 1199 px (default 1024 by 800) | Two columns with a 380 px left column; eras 4 columns; shelf 5; sleeve 270; padding 56; H1 56 |
| 1200 px and wider (1280 by 900) | Left column 460; eras 6 columns; sleeve 320; padding 72; H1 64 |

## 14. Analytics

None. The app records no analytics events.

## 15. Non-goals

- Play together: host, join, lobby, multiplayer rounds, standings and its Misu lines.
- Any change to game rules, scoring, achievement conditions, relisten schedule, matching tolerance or decoy selection.
- Switching editions at runtime, accounts or sign-up.
- Moving the macOS traffic lights from their system position.
- Changing the bundle identifier, save folder, Windows executable name, install folder or updater key.
- Removing the v0.3.0 palette aliases, dead widgets and the unused cat achievement art (follow-up after the steps merge).
- Code signing or notarisation beyond what the release workflow already does.

## 16. Acceptance criteria

### 16.1 Design tokens in both themes

WHEN the app renders in the dark or the light theme, THE SYSTEM SHALL use exactly the handoff's token values for bg, fg, mut, faint, line, line2, card, hover, coral, coralT, onCoral, btn, onBtn, paper, paperFg, bubble, bubbleFg, sleeve, sleeveFg, g1, g2, rose, roseBg, shadow, scrim, panel and bar.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/theme/app_tokens_test.dart` `design tokens match the handoff in both themes`: every AppTokens.dark and AppTokens.light design field equals the README value, alpha included Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.2 Three width classes

WHEN the window is narrower than 900 px, at least 1200 px, or between, THE SYSTEM SHALL use the narrow, large or regular layout metrics: padding 32/72/56, H1 44/64/56, left column 250/460/380, sleeve 200/320/270, era columns 3/6/4 and shelf columns 3/5/5.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/theme/app_layout_test.dart` `layout metrics follow the three width classes`: AppLayout.forWidth at 686, 899, 900, 1024, 1199 and 1280 returns the narrow, narrow, regular, regular, regular and large metrics Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.3 Serif display face

WHEN display text renders, THE SYSTEM SHALL draw it in the bundled Instrument Serif (regular or italic) and draw all other text in the platform system font.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/theme/app_type_test.dart` `display text uses the bundled instrument serif`: AppType.display uses the family Instrument Serif, pubspec.yaml declares that family with a regular and an italic asset, and AppType.body names no family Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.4 Shared kit behaviour

WHEN a screen uses the shared kit, THE SYSTEM SHALL stack two-pane layouts into one column below 900 px, draw a disabled pill button at 45 % opacity and ignore its taps, mark the chosen segment with the btn colour, and open a confirm dialog that returns false on Esc or Cancel and true on its confirm button.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

- `test/ui/kit/kit_test.dart` `the chosen segment paints the button colours`: Segmented with three options paints the chosen one btn with onBtn text and the others transparent with mut text, and tapping another calls onChanged with its value Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.
- `test/ui/kit/kit_test.dart` `two pane stacks into one column below 900 px`: at 899 px wide the left and right children share one column and at 1024 px they sit side by side with a 1 px line divider Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.
- `test/ui/kit/kit_test.dart` `a disabled pill button is drawn at 45 percent and ignores taps`: the disabled PillButton's opacity is 0.45 and tapping it never calls onPressed Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.
- `test/ui/kit/kit_test.dart` `the confirm dialog answers false on escape and true on confirm`: showConfirmDialog completes false after Esc and true after its confirm label is tapped Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.58 Theme cross-fade

WHEN the theme setting changes, THE SYSTEM SHALL cross-fade every colour of the window over 300 ms.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/theme/theme_fade_test.dart` `the theme cross-fades over 300 ms`: the app shell's MaterialApp has themeAnimationDuration 300 ms and the shell Material paints the bg token Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.56 Reset keeps the player

WHEN progress is reset, THE SYSTEM SHALL clear the record shelf and stats and keep the theme, volume, timers, Misu visits setting, nickname and updater state.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

- `test/state/game_controller_test.dart` `reset clears the shelf and stats but keeps settings and the nickname`: after resetProgress the achievements and stats equal the defaults while theme light, volume 0.4, misuVisits often and nickname Sam are unchanged Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.57 Album tracks know their position

WHEN an album's tracks load, THE SYSTEM SHALL give each its 1-based position on the album, counted before non-songs are filtered, and leave top tracks without one.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

- `test/data/catalog/deezer_client_test.dart` `album tracks carry their position on the album`: for an album whose third entry is filtered out, the remaining tracks keep positions 1, 2, 4 and 5, and top tracks have no position Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.5 Version 3 saves migrate

WHEN a version 3 save loads, THE SYSTEM SHALL migrate it to version 4 with misuVisits sometimes, nickname null and null song, albumId and trackId on every achievement record, keeping every version 3 value unchanged.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/data/save/migrations_test.dart` `a version 3 save migrates to version 4 unchanged`: migrateToLatest on a full version 3 save returns version 4, the new defaults, and every original key and value Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.6 Version 4 round trip

WHEN progress is saved and loaded, THE SYSTEM SHALL round-trip misuVisits, nickname and each record's song, albumId and trackId, and new players start at version 4.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

- `test/domain/models/progress_test.dart` `version 4 settings and achievement records round trip`: GameProgress.fromJson(progress.toJson()) equals progress for a progress carrying every new field, and defaultProgress.version is 4 Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.7 Records remember their song

WHEN an achievement unlocks on an answer to a track, THE SYSTEM SHALL store that track's title, album id and track id with the unlock time on the record.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

- `test/state/achievements_controller_test.dart` `an unlock records the song it was earned on`: after a first correct answer to a given track, first_meow's record holds that title, album id and track id Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.8 Quick round lifecycle

WHEN Tonight's era starts a quick round, THE SYSTEM SHALL play Medium Sound from tonight's era for exactly 10 rounds, record each outcome, and on finishing show the round summary with all 10 outcomes.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

- `test/state/game_controller_test.dart` `a quick round lasts ten songs and ends on the summary`: startQuickRound sets tonight, sound, medium and total 10; after ten rounds isLastQuickRound is true and finishQuickRound moves to roundSummary keeping ten outcomes Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.9 Nickname rules

WHEN a nickname is set, THE SYSTEM SHALL store it trimmed and capped at 20 characters, and SHALL ignore an empty or blank one.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

- `test/state/game_controller_test.dart` `nickname is trimmed and capped at twenty characters`: setNickname of a padded 25-character name stores the trimmed first 20 characters and setNickname of spaces leaves it null Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.10 First launch per edition

WHEN the save finishes loading, THE SYSTEM SHALL start the Open edition on the nickname screen while it has no nickname, and the Ana edition on the main menu.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/state/persistence_controller_test.dart` `the open edition without a nickname starts on the nickname screen`: with editionProvider overridden to open and no nickname the phase after load is nickname; with ana it is menu; with open and a nickname it is menu Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.11 Misu's voice per edition

WHEN Misu speaks, THE SYSTEM SHALL use the first-person lines for the Ana edition and the third-person lines for the Open edition, with the greeting chosen by time of day (morning 5 to 11, afternoon 12 to 16, evening 17 to 22, night otherwise).

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

- `test/domain/engine/misu_lines_test.dart` `misu speaks in the first person for ana and the third person for open`: every line kind and day part returns the exact prototype string for both editions, including the number words for streaks Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.12 Misu visit frequency

WHEN game events happen, THE SYSTEM SHALL show Misu's streak and miss visits at most once every 2 rounds for Often and 5 for Now and then, never for Off, greet once per session, always show the Open introduction, and hide a visit after 4.2 s or 7 s for long lines.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

- `test/state/misu_controller_test.dart` `visit frequency follows the misu setting`: with fake time, streak and miss events produce visits only at the allowed round gaps per setting, none when off, introduce shows when off, and visits clear after 4.2 s and 7 s Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.13 Each build reads its own manifest key

WHEN a copy checks for updates, THE SYSTEM SHALL read darwin-aarch64 on macOS, windows-x86_64 on the Windows Ana edition and windows-x86_64-open on the Windows Open edition.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/services/updater/update_manifest_client_test.dart` `each build reads its own manifest key`: UpdatePlatform.forBuild returns the platform whose manifestKey is darwin-aarch64 for macOS with either edition, windows-x86_64 for Windows Ana, windows-x86_64-open for Windows Open and null for Linux, and the client picks that entry from a manifest holding all three Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.14 Manifest maps every build

WHEN a release writes latest.json, THE SYSTEM SHALL point darwin-aarch64 and darwin-aarch64-app at the macOS Open archive, windows-x86_64 and windows-x86_64-nsis at the Windows Ana installer, and windows-x86_64-open at the Windows Open installer, each with its verified signature.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the tag-triggered release workflow on GitHub Actions runners (macos-26, windows-2025, ubuntu-24.04).

- `test/tool/make_manifest_test.dart` `the manifest maps each platform key to its edition's artefact`: buildManifest given the three signed artefacts returns the five keys with the matching url and signature, and refuses a missing Open installer Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.15 Release builds three editions

WHEN a version tag is pushed, THE SYSTEM SHALL build macOS with EDITION=open, Windows with EDITION=ana and Windows with EDITION=open, sign each updater artefact, and refuse to publish unless latest.json carries all five platform keys pointing at assets of that release.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the tag-triggered release workflow on GitHub Actions runners (macos-26, windows-2025, ubuntu-24.04).

- `test/tool/workflows_test.dart` `the release builds macos open and both windows editions`: release.yml passes --dart-define=EDITION=open to the macOS build, builds Windows once with EDITION=ana and once with EDITION=open, uploads both installers, and its publish check lists windows-x86_64-open Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.16 Installer renamed in place

WHEN the Windows installer runs, THE SYSTEM SHALL show Project Swiftie as the product name, shortcuts and uninstall entry, while installing into the unchanged Swiftie Quiz folder under the unchanged uninstall registry key, and SHALL remove the legacy Swiftie Quiz shortcuts.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/installer/nsis_script_test.dart` `the installer shows project swiftie but keeps its install identity`: the NSIS script names the product Project Swiftie for Name, DisplayName and both shortcuts, keeps InstallDir, the uninstall key and MAINBINARYNAME on Swiftie Quiz and swiftie-quiz, and deletes the old Swiftie Quiz.lnk shortcuts Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.17 Platform display names

WHEN the apps are built, THE SYSTEM SHALL name the macOS bundle Project Swiftie with the unchanged bundle identifier and give the Windows executable the Project Swiftie description and product name with the unchanged file name.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/scaffold/platform_config_test.dart` `platform display names read project swiftie`: AppInfo.xcconfig has PRODUCT_NAME = Project Swiftie and the unchanged bundle id, Runner.rc FileDescription and ProductName read Project Swiftie, and OriginalFilename stays swiftie-quiz.exe Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.18 Installed copies update across the rename

WHEN an installed v0.3.0 copy updates to the first redesign release, THE SYSTEM SHALL install it in place (Windows into the existing folder as the Ana edition, macOS into the existing bundle as the Open edition) and keep the save.

Where passing proves it: the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the tag-triggered release workflow on GitHub Actions runners (macos-26, windows-2025, ubuntu-24.04).

Unproven: Needs a tagged release built by GitHub Actions and installs on VMLab macOS and Windows images; no builder can run those.

### 16.19 Misu cat-note platform icons

WHEN the app is installed, THE SYSTEM SHALL show the Misu cat-note icon: the macOS app icon set rendered from app-icon-macos.svg (64 to 1024 px) and app-icon-macos-small.svg (16 and 32 px, at 1x and 2x), and the Windows .ico with 16, 24, 32 px from app-icon-small.svg and 48, 64, 128, 256 px from app-icon.svg.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/scaffold/app_icon_test.dart` `platform icons are the misu cat-note`: each AppIcon.appiconset PNG has its declared size, the 1024 PNG has a transparent corner and the cocoa #3B2F2F background inside the rounded square, and app_icon.ico lists 16, 24, 32, 48, 64, 128 and 256 px images Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.20 macOS title bar

WHEN the app runs on macOS, THE SYSTEM SHALL paint a 28 px title bar in the app background with no divider and "Project Swiftie" centred at 13/16, weight 600, in 80 % fg, under the native traffic lights, and the bar drags the window.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio.

- `test/ui/chrome/title_bar_test.dart` `the macos title bar is 28 px with the centred title`: with the macOS platform the bar is 28 px tall, uses bg, centres Project Swiftie at 13/16 w600 with 0.8 opacity and paints no caption buttons Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.21 Windows title bar

WHEN the app runs on Windows, THE SYSTEM SHALL paint a 32 px title bar in the app background with "Project Swiftie" centred at 12/16 weight 600 and three 46 px caption buttons that minimise, maximise or restore, and close; minimise and maximise hover with the hover token and close hovers #C42B1C with a white glyph.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/chrome/title_bar_test.dart` `the windows title bar has three 46 px caption buttons`: with the Windows platform the bar is 32 px, has minimise, maximise and close buttons 46 px wide that call the injected window controls, and the hovered close button paints #C42B1C with a white glyph Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.22 Update badge in the title bar

WHEN the updater has an update available, is downloading, is ready or failed, THE SYSTEM SHALL show the title-bar pill "Update available · X" (coral), "Downloading · N%" (btn), "Restart to update" (coral) or "Update issue" (rose on roseBg), and clicking it opens the update dialog; otherwise no badge shows.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/overlays/update_badge_test.dart` `the title bar badge reads the design copy for each updater state`: UpdateBadge.lookFor returns the four labels and colours, none for idle, checking, up to date, installing and installed, and tapping the badge opens the dialog Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.23 Window opens as Project Swiftie

WHEN the app starts, THE SYSTEM SHALL open a 1024 by 800 window (minimum 686 by 571) titled Project Swiftie with the native title bar hidden.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/app/window_setup_test.dart` `the window opens as project swiftie with a hidden title bar`: windowOptions has title Project Swiftie, size 1024 by 800, minimum 686 by 571 and TitleBarStyle.hidden Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.24 Native chrome on real systems

WHEN the packaged app runs on macOS 26 and Windows 11, THE SYSTEM SHALL keep the traffic lights, window dragging, double-click zoom or maximise, snapping and the caption buttons working, and the bar SHALL follow the app theme, not the system theme.

Where passing proves it: the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

Unproven: Native window behaviour needs the packaged app on macOS 26 and Windows 11; flutter test has no native window.

### 16.25 Update dialog states

WHEN the update dialog is open, THE SYSTEM SHALL show the design's panel for the updater state: available ("Version X is here", the release notes, Remind me later, Skip this version, Download), downloading ("Downloading X", a 4 px coral progress bar and the percentage, Hide, Cancel download), ready ("X is ready", "Restart Project Swiftie to finish updating. Your progress is saved.", Later, Restart now), error ("The update hit a snag", the error in a rose banner, Close, Try again), up to date ("No updates", "You're on the latest version.", Close), and while installing a full-window cat loader reading "Restarting Project Swiftie...".

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/overlays/update_modal_test.dart` `the update dialog shows the design copy for each state`: for each updater state the open dialog shows the listed title, body and buttons, each button calls the matching UpdaterController method, and installing shows the cat loader with Restarting Project Swiftie... Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.26 Misu visits on screen

WHEN Misu has a visit, THE SYSTEM SHALL raise her 76 by 62 px from the bottom edge at 40 px from the left in games or 48 px from the right elsewhere, show her line 120 ms later in a bubble (bubble colours, serif 20/24, at most 340 px wide, with a tail toward her), and clicking her or pressing Esc sends her away.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/misu/misu_host_test.dart` `misu rises with her line and a click sends her away`: with a right-side visit the host shows the cat and the text in a bubble at most 340 px wide anchored right, a left-side visit anchors left, and tapping the cat calls dismiss Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.27 Shelf unlock toasts

WHEN records unlock, THE SYSTEM SHALL show one toast per record at the top right (16 px in, stacked every 84 px, 300 px wide) reading "New on your shelf", the achievement name and "on <Song>" with a small sleeve and disc of its album, slide it in 24 px from the right over 350 ms, and dismiss it after 4 s or on its close button.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/overlays/achievement_toasts_test.dart` `an unlock toast reads new on your shelf with the song`: a pending toast for first_meow with song Love Story shows New on your shelf, First Meow and on Love Story, a second toast sits 84 px lower, and both leave after 4 s or when closed Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.28 Open edition first launch

WHEN the Open edition opens without a nickname, THE SYSTEM SHALL ask "Hi. What should we call you?" with "It's only used in the app. You can change it in Settings.", accept up to 20 characters in a large italic serif field, keep "Let's go →" at 45 % opacity while empty, save the trimmed name on Enter or the button and open the main menu, and have Misu introduce herself about 0.8 s after the screen appears.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/nickname_screen_test.dart` `a nickname is saved on enter and opens the menu`: typing Ana Lee and pressing Enter stores Ana Lee and moves to the menu; with an empty field the button is at 0.45 opacity and does nothing; input stops at 20 characters; introduce is called after 800 ms Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.29 Greeting by time and edition

WHEN the main menu shows, THE SYSTEM SHALL greet by time of day ("Good morning, ", "Good afternoon, ", "Good evening, " or "Still up, " then the name in coral italic and "." or "?" at night) with the matching subline, using Ana in the Ana edition and the nickname in the Open edition, and greet with Misu once per session about 0.9 s after it first appears.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/main_menu_test.dart` `the greeting follows the time of day and edition`: at 08:00, 14:00, 19:00 and 01:00 the heading and subline match the design for Ana and for an Open player named Sam, and greet is called once after 900 ms Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.30 Birthday card is Ana's only

WHEN the main menu shows in the Ana edition, THE SYSTEM SHALL show Misu with "Misu's keeping your birthday card safe." and "Open it →", which opens the birthday card, and SHALL open the card by itself once per session about 1 s after the menu appears while the existing birthday rule holds; the Open edition shows neither.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/main_menu_test.dart` `only the ana edition keeps the birthday card`: Ana shows the card button and tapping it opens the letter, the card auto-opens once inside the birthday window, and Open shows no card button Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.31 Menu rows and links

WHEN the main menu shows, THE SYSTEM SHALL offer Shuffle everything (coral arrow, to set up with the shuffle pool), Pick your eras (to the eras grid), "Record shelf · N of 15" and Settings, and no Play together row.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/main_menu_test.dart` `menu rows lead to set up, eras, shelf and settings`: Shuffle everything calls beginSetup(GameMode.random), Pick your eras opens albumSelect, the shelf link reads Record shelf · 3 of 15 with three unlocked records and opens recordShelf, Settings opens settings, and no Play together text exists Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.32 Tonight's era

WHEN the main menu shows, THE SYSTEM SHALL show Tonight's era (the curated era for today's day of year) with its sleeve and disc and "A quick round of 10 →", and clicking it starts the 10-round quick round.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/main_menu_test.dart` `tonight's era starts a ten song quick round`: with the clock on 6 October the block names that day's curated era and tapping it calls startQuickRound Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.33 Birthday letter on paper

WHEN the birthday card opens, THE SYSTEM SHALL show the v0.3.0 letter verbatim on paper under a coral header reading "For Ana" and "Happy Birthday!" with Misu peeking from it, and close on the ✕, a scrim click or Esc.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/overlays/birthday_card_test.dart` `the birthday card shows the letter on paper with the coral header`: the card shows For Ana, Happy Birthday!, Dear Ana, every letter paragraph, the signature and the postscript on the paper colour, and the close button, Esc and a scrim tap close it Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.34 Settings sections

WHEN Settings opens, THE SYSTEM SHALL show Look and sound (Theme Dark, Light, System; Volume; Misu visits Often, Now and then, Off; Nickname in the Open edition only), Timers (Medium and Hard, 10 to 40 s in steps of 5), Updates (version, last checked, Check now with its result, the automatic check toggle and its note), Backups (the last 3 with Restore), Progress (Reset…) and About (the new icon at 40 px, Project Swiftie, and "Made for Ana by Satanshu" or "Made by Satanshu").

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/settings_screen_test.dart` `settings shows every section with the edition's rows`: for Ana the Nickname row is absent and About reads Made for Ana by Satanshu; for Open the Nickname field shows and edits the nickname and About reads Made by Satanshu; theme, volume, misu visits and timers write their settings Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.35 Reset and restore confirm

WHEN the player chooses Reset… or a backup's Restore, THE SYSTEM SHALL ask first ("Reset all progress?" with "This clears <Name>'s record shelf and stats. Backups stay available.", or "Restore this backup?" with "Your current save will be replaced with this one.") and act only on confirm.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/settings_screen_test.dart` `reset and restore ask before acting`: Cancel leaves progress and the save untouched; Reset progress resets progress; Restore calls restoreBackup with that backup's timestamp Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.36 Eras grid states

WHEN Pick your eras opens, THE SYSTEM SHALL show the cat loader with "Loading albums..." while albums load, "The record store is closed." with Try again and Back to menu when loading fails, and otherwise the 12 curated eras in design order (3, 4 or 6 columns by width) with era name and sub-label.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/album_grid_test.dart` `the eras grid shows the twelve curated eras`: loading shows the loader label, a failed load shows The record store is closed. with both buttons, and a loaded catalogue shows 12 tiles from Taylor Swift to The Life of a Showgirl in four columns at 1024 px Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.37 Choosing eras

WHEN a player taps eras, THE SYSTEM SHALL toggle each tile (disc slides out 34 %, 2 px coral ring, coral check), show "N eras · M songs" or "Pick at least one era" in the sticky bar with Clear, and enable Continue → only with a selection, which opens set up for those eras.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/album_grid_test.dart` `choosing eras updates the bar and continue opens set up`: tapping two tiles shows 2 eras, Clear empties it, Continue is at 0.45 opacity and inert with nothing selected and calls beginSetup(GameMode.album) with a selection Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.38 Catalogue curated to the eras

WHEN albums load, THE SYSTEM SHALL keep only the 12 curated eras' albums, in era order, skipping any Deezer does not return.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

- `test/state/catalog_controller_test.dart` `albums are curated to the twelve eras in order`: given Deezer albums in shuffled order with extra singles, setAlbums receives only curated albums in curatedEras order and a missing era is skipped Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.39 Set up

WHEN set up opens, THE SYSTEM SHALL show "You're playing" with the source title and a fan of up to 5 covers rotated (i−2)·3°, then Listen or read (Sound, Lyrics), Which lyrics game (only for Lyrics: Name That Song, Lyrics or Lie), Difficulty (Easy, Medium, Hard) with the feature list for the chosen mode and difficulty, and Start →, which opens the game for Sound or the lyrics loader for Lyrics; Back returns to the eras grid for chosen eras and to the menu otherwise.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/setup_screen_test.dart` `set up shows the feature list for the chosen mode and difficulty`: Sound and Hard list Type your answer, No hints and the hard timer text; Lyrics and Lyrics or Lie and Medium list 2 lyric lines, No hints, Fakes from similar albums and the medium timer text; the lyrics game choice appears only for Lyrics Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.
- `test/ui/screens/setup_screen_test.dart` `start opens the game or the lyrics loader`: Start with Sound sets quiz type sound and phase playing; with Lyrics sets lyrics mode and phase lyricsLoading; Back goes to albumSelect in album mode and menu otherwise Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.40 Lyrics loading

WHEN lyrics load, THE SYSTEM SHALL show the cat loader with a message changing every 3 s from the design's list, a 2 px coral progress bar and "N of M songs" ("Getting the songs ready…" before the total is known), and on failure "The lyric sheets got lost." with Try again and Back to menu.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/lyrics_loading_screen_test.dart` `lyrics loading shows progress and the lost sheets error`: with progress 3 of 40 the screen shows 3 of 40 songs and a bar at 7.5 percent, the message changes after 3 s, and a failure shows The lyric sheets got lost. with both buttons Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.41 The record never peeks

WHEN a song is being guessed on Medium or Hard, THE SYSTEM SHALL show the sleeve's plain paper front ("Side A", "33⅓"), flip it to the cover over 550 ms on reveal (always the cover on Easy), slide the disc from 40 % to 52 % of the sleeve on reveal, spin it at 0.2°/ms only while audio plays, and keep the previous album on the back face while flipping back so the next cover is never visible.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/game/record_player_test.dart` `the sleeve never shows the next cover on medium`: moving from a revealed song of album A to an unrevealed song of album B keeps A's cover on the back face through the flip and never paints B's cover Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.
- `test/ui/game/record_player_test.dart` `the sleeve flips to the cover on reveal`: revealed true rotates the sleeve to 180 degrees over 550 ms showing the cover and moves the disc to 52 percent; easy shows the cover while guessing Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.42 Transport and relisten captions

WHEN a clip plays, THE SYSTEM SHALL show a 44 px play, pause or replay button, a 3 px progress bar, "Ns / Ms" and the caption Space to pause, Paused, Loading the clip…, "Listen again (Ns)" or "Play full clip (30s)", adding "Clip extended to help with your guess" from the third listen.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/game/transport_bar_test.dart` `transport captions follow the relisten schedule`: for stages 1 to 7 and each status the caption and time read as the design, and the extension note shows from stage 3 Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.43 Header and bracelet

WHEN a game runs, THE SYSTEM SHALL show "← Exit", "Mode · Difficulty" with "· Round N of 10" in quick rounds, a bracelet of up to 10 beads of 12 px cycling the five bead colours with a paper count tag, and under it a 2 px timer bar that turns rose under 30 % time left.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/game/game_top_bar_test.dart` `the bracelet shows the streak in the design colours`: a streak of 12 shows the last 10 beads in cycling colours with the tag 12, the newest bead pops, the label reads Name That Song · Medium · Round 3 of 10, and the timer bar is rose at 25 percent Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.44 Answer states

WHEN answers show, THE SYSTEM SHALL draw numbered 56 px buttons that turn coral with ✓ for the right one, rose with ✕ for a wrong pick and 55 % for the rest once answered, and Real or Fake buttons the same way.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/game/answer_list_test.dart` `answer buttons show right, wrong and dimmed states`: after a wrong pick the picked button shows the cross on roseBg, the right one shows the check on coral, the others are at 0.55 opacity, and every button is at least 56 px tall Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.45 Quack escalation

WHEN answers are wrong in a row, THE SYSTEM SHALL burst 1 to 4 "quack" words in an arc for 1.3 s, and 14 in a ring at the fifth.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/game/quack_burst_test.dart` `quack words escalate to a ring of fourteen`: level 3 shows three words, level 5 and above shows fourteen, and they are gone after 1.3 s Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.46 Sound game rounds

WHEN a sound round is answered, THE SYSTEM SHALL title it "What's playing?" with "N seconds left." (or "Take your time. The cover is your hint." on Easy), and after answering show "It was <Song>." with a praise line when right, the era and track number when wrong, or "Time's up. It was <Song>." on timeout, enable "Next song →" 2 s later, and accept 1–4, Space, Enter and Esc from the keyboard.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/game_screen_test.dart` `a right answer reads it was the song and next arrives after two seconds`: pressing 2 on the right option shows It was <title>. with a praise line, Next song is at 0.45 opacity until 2 s pass, then Enter starts the next round Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.
- `test/ui/screens/game_screen_test.dart` `a wrong answer shows the era and track and quacks`: a wrong pick shows the era name and track number, marks the right answer, calls answerIncorrect with the track and shows the quack burst Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.47 Hard mode typing

WHEN Hard is played, THE SYSTEM SHALL take a typed answer in an italic serif field with "Small typos are fine.", accept the existing typo tolerance, and say "Close enough. It's spelled “<Song>”." when a typo was accepted, with "You typed “…”." under the field.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/game_screen_test.dart` `hard mode accepts a typo and says how it is spelled`: typing a one-letter typo of a nine-letter title and Enter counts as right and shows Close enough. It's spelled with the title in curly quotes Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.48 Quick round ends on the summary

WHEN a quick round reaches its tenth song, THE SYSTEM SHALL label the header "Round 10 of 10", label the next button "See your round →", and open the round summary.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/game_screen_test.dart` `the tenth song leads to the round summary`: in a quick round on round 10 after answering the next button reads See your round and pressing it calls finishQuickRound Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.49 Lyrics rounds

WHEN a lyrics round shows, THE SYSTEM SHALL show Name That Song lines (4, 3 or 2 by difficulty) on the tilted paper card with "From <Era>" on Easy and the song and era on reveal, and Lyrics or Lie as "Is this lyric from <Song>?" with Real (R) and Fake (F), revealing "It's a real line from <Song>." or "It's a fake. That line is from <Other>."

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/lyrics_game_screen_test.dart` `lyrics or lie reveals where a fake line came from`: pressing F on a decoy round reveals It's a fake. That line is from <decoy song>. and marks Fake right; Name That Song on Easy shows From <era> Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.50 Between songs and failures

WHEN the next song loads, THE SYSTEM SHALL cover the game with the cat loader reading "Loading next track..." for at least 450 ms, and when tracks cannot load SHALL show "The needle won't drop." with a way back.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/game_screen_test.dart` `between songs the loader shows for at least 450 ms`: after Next the cover with Loading next track... stays at least 450 ms even when audio is ready at once, and a failed track load shows The needle won't drop. Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.51 Round summary

WHEN a quick round ends, THE SYSTEM SHALL show "N of 10", the line for that score (8 or more "A near-perfect run.", 5 to 7 "A solid round.", 1 to 4 "Every Swiftie has an off night.", 0 "Not a single one. The vault stays locked."), a row of filled and empty beads, "The ones you knew" as a cover grid when any were right, "Another round →" and "Back to menu", and Misu's summary line about 0.9 s after it appears.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/round_summary_screen_test.dart` `the summary shows the score line and the songs you knew`: with 6 right of 10 it shows 6 of 10, A solid round., six coral and four empty beads and six covers; Another round calls startQuickRound; Back to menu goes to menu; afterQuickRound(6) is called after 900 ms Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.52 Record shelf

WHEN the record shelf opens, THE SYSTEM SHALL title it "<Name>'s record shelf" ("Your record shelf" when the name is you) with "N of 15 · hover a record to hear it", show a grid of 5 columns (3 when narrow) where each earned record is a sleeve with its disc peeking out at the top right, the achievement name in serif italic and "on <Song> · <Mon D>" (only the date for records earned before the shelf existed), and each locked slot is a dashed outline with its hint ("A secret" for Quack Collector).

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/ui/screens/record_shelf_screen_test.dart` `the shelf shows earned records and dashed locked slots`: for Ana with two records it reads Ana's record shelf and 2 of 15, shows on Love Story · Sep 12 under First Meow, shows only the date for a legacy record, 13 dashed slots with their hints and A secret for quack_collector, in 5 columns at 1024 px Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.53 Hover to hear

WHEN the pointer rests on an earned record, THE SYSTEM SHALL slide its disc further out and play about 5 s of its song from 8 s in at 70 % of the volume setting through a freshly fetched preview, stopping when the pointer leaves or the screen closes; records without a track play nothing.

Where passing proves it: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window; the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio; the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

- `test/state/audio_controller_test.dart` `a shelf preview plays five seconds at seventy percent volume`: previewSnippet starts the refreshed preview at 8 s with volume 0.7 times the setting and stops it after 5 s with fake time, and stopSnippet stops it at once Runs in: flutter test on the macOS host Dart VM: unit and widget tests, no device, no window.

### 16.54 Screens match the mockup

WHEN each screen and overlay is shown on the integrated macOS build at 1024 by 800, at 686 by 571 and at 1280 by 900, in the dark and the light theme, for both editions, THE SYSTEM SHALL match the mockup's layout, colours, type and copy.

Where passing proves it: the packaged Project Swiftie app on macOS 26 (Apple silicon): native window chrome, bundled fonts, real Deezer and LRCLIB data, real audio.

Unproven: A side-by-side comparison of the running app with the prototype needs the integrated build of every step and a human eye; the orchestrator does it after the pull requests build, before reporting.

### 16.55 Windows editions on Windows 11

WHEN the Ana and Open Windows installers run on Windows 11, THE SYSTEM SHALL install, launch with the custom title bar, show the right edition, and update from v0.3.0.

Where passing proves it: the packaged Project Swiftie app on Windows 11 x64 (VMLab golden image): custom title bar and caption buttons, NSIS installer, updater.

Unproven: Needs the release artefacts and a Windows 11 machine (VMLab); not reachable from flutter test.

## 17. Assumptions

Every item is marked for the user's confirmation in review; each was decided autonomously under the user's instruction (decisions file).

- [confirm] Product name spelling is "Project Swiftie".
- [confirm] Play together is not built and its menu row is omitted.
- [confirm] Nickname explanation drops the mention of rooms.
- [confirm] Editions come from --dart-define=EDITION, defaulting to Open.
- [confirm] Existing Windows installs are Ana's and stay on windows-x86_64; existing macOS installs become Open.
- [confirm] The new manifest key is windows-x86_64-open.
- [confirm] Install identity (folder, registry key, executable, bundle id) keeps the old name.
- [confirm] Save version 4 adds misuVisits, nickname, song, albumId, trackId.
- [confirm] Pick your eras is limited to the 12 curated eras; Shuffle everything keeps the top-tracks pool.
- [confirm] Tonight's era uses day of year with 1 January as day 1, local time.
- [confirm] Ana's birthday keeps v0.3.0's window rule.
- [confirm] Default theme stays Dark.
- [confirm] Native traffic lights stay where macOS puts them.
- [confirm] Windows caption buttons are custom-drawn; Windows 11 snap-layout flyouts on the maximise button are not reproduced.
- [confirm] Misu's multiplayer lines are not built.
- [confirm] Shelf hover audio uses a refreshed Deezer preview from 8 s at 70 % volume.
- [confirm] Instrument Serif is bundled under the SIL Open Font License.
- [confirm] Cosmetic values not stated in the README are taken from the prototype markup at the cited lines.
- [confirm] A routing scaffold commit by the orchestrator precedes the dispatched steps and moves shared v0.3.0 helpers into their own files.
- [confirm] Reset clears the record shelf and stats but keeps settings and the nickname.
- [confirm] Track numbers come from Deezer's album track order; top-track shuffles show none.

## 18. Open questions

1. Should Play together ship later as a real multiplayer service? Safe to leave: nothing in this work depends on it, and its absence removes no v0.3.0 feature.
2. Should the dead v0.3.0 widgets, palette aliases and cat achievement art be removed? Safe to leave: they are unused after the steps merge and removal is a mechanical follow-up.
3. Should the Windows caption buttons gain the Windows 11 snap-layout flyout? Safe to leave: snapping by drag and keyboard still works; the flyout needs native hit-testing work outside this face-lift.

## 19. Reuse and change

Reused as is:
- lib/ui/cat/cat_loader.dart, cat_loader_geometry.dart, loading_gate.dart: the design's cat loader, already built.
- lib/ui/cat/cat_icon.dart and assets/cat/cat-icon.svg: the design's Misu vector, already present.
- lib/domain/engine/relisten_schedule.dart, answer_matcher.dart, option_generator.dart, lyric_processor.dart, achievements.dart: game rules unchanged.
- lib/domain/util/birthday.dart: birthday window rule.
- lib/data/catalog/deezer_client.dart, lib/data/lyrics/: data sources, including refreshTrack for shelf previews.
- lib/services/updater/ (except update_config.dart): download, verification and install.
- lib/ui/game/result_feedback.dart praise lists: moved unchanged to praise_lines.dart.
- lib/ui/screens/lyrics_loading_screen.dart message list: kept as the single copy.

Kept separate:
- lib/ui/widgets/screen_layout.dart and lib/ui/widgets/motion.dart: v0.3.0 helpers moved out of screens that are rebuilt in parallel.
- New game kit widgets (lib/ui/game/record_player.dart and siblings) beside the old ones until the game screens switch, so the two halves never share a file.
- MisuController apart from GameController: visits change for different reasons than game state.

Changed:
- lib/ui/theme/app_tokens.dart, app_theme.dart, app_motion.dart: design tokens added beside the v0.3.0 fields (kept at their old values until every screen is rebuilt), motion constants, a minimal ThemeData change.
- lib/app/app.dart: 300 ms theme cross-fade and the shell painted in the bg token (design-system step only).
- lib/domain/models/track.dart, lib/data/catalog/deezer_client.dart: album track positions.
- lib/domain/models/progress.dart, lib/data/save/migrations.dart: save version 4.
- lib/state/game_state.dart, game_controller.dart: quick round, round results, nickname and Misu settings; Reset keeps settings.
- lib/state/achievements_controller.dart: records store their song.
- lib/state/persistence_controller.dart: first-launch routing per edition.
- lib/state/catalog_controller.dart: albums curated to the 12 eras.
- lib/state/audio_controller.dart: shelf preview snippet.
- lib/services/updater/update_config.dart, lib/state/updater_controller.dart: edition-specific manifest key.
- lib/app/window_setup.dart, lib/ui/overlays/update_badge.dart, update_modal.dart, achievement_toasts.dart, toast_host.dart, birthday_card.dart and every screen: restyled to the design.
- Release workflow, packaging scripts, manifest writer, NSIS script, platform display names, app icons.

Project rule followed: save format compatibility and migration test (CLAUDE.md rule 1); updater protocol compatibility with a written release plan (CLAUDE.md rule 2); lib/domain purity (CLAUDE.md rule 3).
