# Flutter rewrite

Date: 2026-10-05

## Context

Swiftie Quiz ran as a web page inside each operating system's browser engine (Tauri 2), with screens in React and TypeScript and networking, saving and updating in Rust. That meant two languages, three toolchains (Node, Rust, the Tauri CLI) and a look that depended on the platform's web engine. The owner asked for one Flutter codebase that is a rewrite, not a redesign, with the redrawn cat as the only visual change and a review of the free music APIs behind the game. The full specification is `docs/specs/flutter-rewrite.md`; the choices made under the owner's standing directive are in `docs/specs/flutter-rewrite.decisions.md`.

## Decisions

| Decision | Why |
|---|---|
| One Flutter app at the repository root replaces `src/`, `src-tauri/` and the Node and Rust toolchains | Flutter draws the UI itself, so macOS and Windows look identical; the logic is small and pure, so porting it costs less than bridging it. Rejected: a Flutter UI over the Rust core through flutter_rust_bridge, which keeps two languages and an FFI layer for no gain at this size |
| Same screens, text, flows, rules, timings, sounds and colours; only the cat icon and cat loader change | The request was a rewrite, not a redesign. Where the old look came from the web engine (sliders, checkbox, confirm dialogs, scrollbars, dates), the Windows (Chromium) rendering is kept |
| The save file keeps its location, name, JSON shape and version 3 | `save.json` stays in the `com.swiftiequiz.desktop` app data folder (`~/Library/Application Support/` on macOS, `%APPDATA%` on Windows), so every player's progress loads unchanged; migrations from v1 and the three rolling backups are kept |
| The Flutter updater speaks the Tauri updater protocol | Same `latest.json` URL and schema, the same four platform keys, the same minisign key pair and secrets, and the same artifact formats (`.app.tar.gz` bundle swap on macOS, NSIS setup with `/P /UPDATE /R /ARGS` on Windows). No new key or secret is needed. Rejected: Sparkle and WinSparkle, which need a new key pair and a second feed |
| Keep Deezer (catalog, previews, covers) and LRCLIB (lyrics) | No alternative is free, keyless and allowed by its own terms for a quiz game: Spotify bans trivia games and dropped previews, the Apple Music API and Musixmatch synced lyrics are paid, iTunes preview terms forbid entertainment use, Genius has no lyrics endpoint, and MusicBrainz has no audio. Deezer listed the 2026-09-25 album the week it came out |
| Four API fixes ship with the rewrite | 1. Follow Deezer's `next` link, because the artist has 118 albums and one `limit=100` request dropped 18. 2. Treat a Deezer `error` body as a failure even with HTTP 200 (the quota error arrives that way). 3. Keep preview links fresh: expire a cached track 60 s before its signed link's `exp`, and on a 403 re-read the track once from `/track/{id}`; links now expire about 15 minutes after they are fetched. 4. Use LRCLIB politely: send a `SwiftieQuiz/<version>` User-Agent and, on a 429, wait for `Retry-After` (at most 10 s) and retry once |
| macOS 12 or later on Apple Silicon; Windows 10 and 11 x64 | Flutter does not support macOS 11, so it is dropped; Intel Macs, Linux, mobile and web stay unsupported as before |
| The version becomes 0.3.0 | Marks the rewrite; the release PR moves the `[Unreleased]` CHANGELOG entry under `[0.3.0]` and sets its date |

## Bridge release

The first Flutter release, v0.3.0, is installed by existing Tauri copies (v0.2.1 or later) through their own updater. Its artifacts keep Tauri's names, formats and signatures, and `latest.json` lists them under the same platform keys, so an installed copy offers, downloads, verifies and installs it like any other update, then relaunches into the Flutter app with the same save. On Windows the NSIS installer writes the same per-user location (`%LOCALAPPDATA%\Swiftie Quiz`), executable name and uninstall registry keys as Tauri's, and removes the Tauri-era files it replaces.

Before publishing, a dry run serves a local `latest.json` that points at locally signed v0.3.0 artifacts to a v0.2.2 test build and confirms it installs and opens the Flutter app. Two questions stay with the release, not the rewrite: whether a v0.2.4 of the Tauri app should refuse the update on macOS 11, where the Flutter build cannot open, and when to publish v0.3.0 relative to v0.2.3.
