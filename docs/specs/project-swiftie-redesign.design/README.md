# Handoff: Project Swiftie, v2 redesign

## Overview
Project Swiftie (formerly "Swiftie Quiz") is a Flutter desktop app (macOS and Windows) made as a birthday gift for Ana, a Taylor Swift fan. The repo is `SatanshuMishra/project-swiftee` on the `main` branch. This redesign keeps all v0.3.0 features and:
- uses a vinyl record as the main visual (sleeve, disc, album label),
- brings in Misu (Ana's cat) through short, context-aware visits from the edge of the window,
- turns achievements into a **record shelf**, where each record is the song she earned it on,
- ships as two **editions** from one codebase: **Ana** (hard-coded) and **Open** (asks for a nickname on first launch),
- adds **Play together** (host or join a room with a 4-letter code; three game modes). This is new UI/UX only. Networking is not designed.
- adds a new app icon, "Misu cat-note".

## About the design files
`Project Swiftie.dc.html` is a **design reference built in HTML**: a working prototype that shows the intended look and behaviour. It is not production code. Recreate it in the existing Flutter codebase using its patterns (Riverpod state, `lib/ui/**`, the existing services). Do not port the web code.

The logic block opens with a **PROTOTYPE vs PRODUCTION** header. Every block tagged `PROTOTYPE-ONLY` exists only so the HTML mock runs without the real services. **Do not implement any of it.** In particular:

| PROTOTYPE-ONLY | Use instead |
|---|---|
| `SAMPLE` invented lyric lines and the "Sample line…" captions | Real lyrics from `lib/data/lyrics/lrclib_client.dart` + `danger_zones.dart`. **Never ship SAMPLE or the captions.** |
| `FALL` fallback track titles | Nothing. Show the error state if Deezer fails. |
| `jsonp()`, `DZ`, album ids in `AL` | `lib/data/catalog/deezer_client.dart` |
| `quackSound()` synth | `assets/sounds/quack.mp3` via `audio_engine.dart` |
| `seedStats` / `seedUnlocked` demo progress | Real persisted progress (`persistence_controller.dart`) |
| `download()` / `install()` timers, backups list | `lib/services/updater`, real backups |
| `bot()`, `mpBot()`, `friends()`, local room code | The future multiplayer service |
| Tweak props `network`, `update`, `birthday`, `windowSize`, `platform` | Real OS, network, updater and date. `edition` becomes a build flavour. |
| Desktop backdrop and window chrome drawing | The real OS window (see *Window chrome*) |

Rules that the prototype **mirrors from Dart** and that should stay as they are: the relisten schedule (`relisten_schedule.dart`), typo-tolerant matching (`answer_matcher.dart`), and the 15 achievement conditions (`achievements_controller.dart`).

## Fidelity
**High fidelity.** Colours, type, spacing, motion and copy are final. Match them exactly.

## Editions
- **Ana edition:** no nickname screen. Copy uses "Ana" directly, and Misu speaks in the first person ("I'm telling everyone."). The birthday card is reachable from the main menu. About reads "Made for Ana by Satanshu".
- **Open edition:** first launch asks "Hi. What should we call you?" (max 20 chars, Enter or "Let's go →"). The nickname is editable in Settings. Misu is spoken about in the third person ("Misu's telling everyone."). There is no birthday card. About reads "Made by Satanshu".
- No accounts, no sign-up, no switching editions at runtime. Build it as a compile-time flavour.

## Window chrome
- **macOS:** 28 px transparent, full-size-content title bar. Traffic lights at x 9, y 8 (12 px dots, 8 px gap). "Project Swiftie" is centred at 13/16, weight 600, 80 % `--fg`. The bar uses the app background, with no divider.
- **Windows:** 32 px custom title bar painted in the app's `--bg`, so it blends in the same way as macOS (use `window_manager` / `bitsdojo_window` with a hidden native title bar). "Project Swiftie" is centred at 12/16, weight 600, in Segoe UI Variable. Caption buttons are 46 px wide on the right. Minimise and maximise hover with `--hover`; close hovers `#C42B1C` with white glyphs. It follows the app theme, not the OS theme.
- **Update badge** at the right of the title bar (before the caption buttons on Windows), as a pill 20–22 px tall: "Update available · 0.3.1" (coral), "Downloading · N%" (`--btn`), "Restart to update" (coral), "Update issue" (rose). Clicking it opens the update dialog.
- Window sizes: default 1024×800, minimum 686×571, large 1280×900. Below 900 px wide the layout collapses (see *Responsive*).

## Design tokens
Fonts: **Instrument Serif** (400, regular and italic) for display text and **system UI** (SF Pro / Segoe UI Variable) for everything else.

Dark theme (default):
```
--bg #1A1514   --fg #F5E5D4   --mut #B8A99C   --faint #8E8076
--line rgba(245,229,212,.10)  --line2 rgba(245,229,212,.18)
--card rgba(245,229,212,.04)  --hover rgba(245,229,212,.07)
--coral #E97F6A  --coralT #E97F6A  --onCoral #1A1514
--btn #F5E5D4  --onBtn #1A1514
--paper #FBF0E6 / --paperFg #3B2F2F (letters, lyric cards)   --bubble #FBF0E6 / #3B2F2F
--sleeve #E9DCCB  --sleeveFg rgba(59,47,47,.55)
--g1 #18120F  --g2 #2E2724 (vinyl grooves)
--rose #E4A0A0  --roseBg rgba(212,160,160,.10) (wrong / destructive)
--shadow rgba(0,0,0,.45)  --scrim rgba(12,9,8,.62)  --panel #231D1B  --bar rgba(26,21,20,.82)
```
Light theme:
```
--bg #FAF7F2  --fg #2A2422  --mut #6B5F59  --faint #857870
--line rgba(42,36,34,.10)  --line2 rgba(42,36,34,.20)  --card #FFFFFF  --hover #F3EDE5
--coral #E97F6A  --coralT #B4533F  --onCoral #1A1514  --btn #2A2422  --onBtn #FAF7F2
--paper #FFFFFF  --sleeve #E9DCCB  --g1 #1A1514  --g2 #3A322E
--rose #A64545  --roseBg rgba(166,69,69,.08)  --shadow rgba(60,40,30,.20)
--scrim rgba(42,36,34,.35)  --panel #FFFFFF  --bar rgba(250,247,242,.86)
```
Theme setting: Dark / Light / System. Colours cross-fade over 300 ms when the theme changes.

Type scale: H1 serif at 44 (narrow) / 56 (default) / 64 (large), line-height 1.0–1.02. Menu row titles serif 30 / 38. Section labels 12/16 weight 600 `--mut`. Body 15–16 / 22–24. Small text 12–13.
Radii: pills 999, choice cards 14, answer buttons 12, dialogs 16, album covers 3–4, toasts 14.
Horizontal padding: 32 / 56 / 72 px (narrow / default / large).

Motion (respect reduced-motion):
- Screen enter: fade from 0 and rise 10 px. Opacity takes 280 ms ease; the rise takes 400 ms `cubic-bezier(.2,.8,.2,1)`.
- Hover lift: −1 px, 200 ms `cubic-bezier(.34,1.56,.64,1)`. Press: scale .97.
- Menu rows: on hover, padding-left grows 0 → 8 px over 250 ms.
- Record flip: rotateY 0 → 180° over 550 ms `cubic-bezier(.4,0,.2,1)`. The disc slides out from 40 % to 52 % of the sleeve width over 550 ms. The disc spins at 0.2°/ms only while audio plays.
- Bead pop: scale 0 → 1.25 → 1 over 450 ms (spring).
- Quack words: 1.3 s burst; 1–4 words in an arc, 14 in a ring at level 5.
- Misu visits: rise from the bottom edge over 450 ms `cubic-bezier(.34,1.3,.64,1)`. The bubble follows 120 ms later. She stays 4.2 s (7 s for long messages) and then sinks back.
- Toasts: slide in 24 px from the right over 350 ms, stack at 84 px intervals, dismiss after 4 s.

## Screens
All two-pane screens use a left column (380 px default, 250 narrow, 460 large) with a 1 px `--line` divider, and a flexible right column. Below 900 px wide they stack into a single column.

1. **First launch** (Open edition only): serif H1, explanatory line, and a large italic serif input (44/52) with a bottom border that turns coral on focus. The coral "Let's go →" pill sits at 45 % opacity while the field is empty.
2. **Main menu:**
   - Left column: greeting by time of day, e.g. "Good evening, *Ana*." (name in coral italic), with a subline.
   - Ana edition: Misu (the 44×88 vector) with "Misu's keeping your birthday card safe." and "Open it →". On hover she scales to 1.1 and the arrow nudges 4 px; on press she scales to .95. Clicking opens the **birthday card** modal, which renders the letter verbatim. On Ana's birthday the card opens by itself once per session, about 1 s after the menu appears.
   - Bottom of the left column: "Tonight's era". A sleeve and disc for the album of the day (day-of-year mod 12); clicking starts a 10-round Medium sound game.
   - Right column: three rows (Shuffle everything [coral arrow], Pick your eras, Play together), then links: "Record shelf · N of 15" and "Settings".
3. **Pick your eras:** a grid of 12 albums (3 / 4 / 6 columns). Each tile is a sleeve with a disc behind it. When selected, the disc slides out 34 %, a 2 px coral ring appears and a coral ✓ springs in. A sticky blurred bottom bar shows "N eras · M songs", a Clear link and "Continue →" (45 % opacity when nothing is selected). Loading uses the cat loader with "Loading albums...". Error: "The record store is closed." with Try again and Back to menu.
4. **Set up:**
   - Left column: "You're playing" with the source title and a fanned stack of up to 5 covers, each rotated by (i−2)·3°.
   - Right column, in order:
     - Listen or read: Sound or Lyrics.
     - Which lyrics game (only when Lyrics is chosen): Name That Song or Lyrics or Lie.
     - Difficulty: Easy, Medium or Hard tiles, with a feature list per mode and difficulty (copy is in `feats`).
     - "Start →".
5. **Lyrics loading:** the cat loader with messages rotating every 3 s (`LOADING_MSGS`), a 2 px progress bar and "N of M songs". Error: "The lyric sheets got lost."
6. **Game** (sound, NTS lyrics and Lyrics or Lie share one layout):
   - **Header:**
     - "← Exit" on the left.
     - "Mode · Difficulty" in the centre, plus "· Round N of 10" in quick rounds.
     - On the right, the **bracelet**: up to 10 beads, 12 px, cycling through `#F5E5D4 #D4A0A0 #6FA8DC #E97F6A #FBF0E6`, on a thread with a paper count tag.
     - Below the header, a 2 px timer bar that turns rose under 30 % time remaining.
   - **Left column: the record.** Sleeve size 200 / 270 / 320. While guessing, the sleeve shows its **front** (plain paper, "Side A", "33⅓"). On reveal, and always on Easy, it flips to the cover and the disc label shows the cover too. **Anti-peek rule:** the back face keeps showing the *previous* album while the sleeve flips back, so the next cover is never visible on Medium or Hard.
   - **Transport** under the sleeve: a 44 px play/pause/replay button, a 3 px progress bar, "Ns / Ms" and a caption ("Space to pause", "Listen again (Ns)", "Play full clip (30s)"). After the 3rd listen it adds "Clip extended to help with your guess". The relisten schedule is 10, 10, 15, 15, 20, 20 s, then the full clip.
   - **Right column:**
     - Title "What's playing?" / "Name that song." and a subline ("N seconds left." or the hint).
     - Easy and Medium: 4 answer buttons, at least 56 px tall, numbered 1–4.
     - Hard: a typed answer in an italic serif input. "Small typos are fine." Typo tolerance by title length: 0 edits up to 4 characters, 1 edit for 5–8, 2 edits for 9 or more.
     - **Right:** the chosen button fills coral with a ✓, the title becomes "It was *Song*." and the subline is a random line from `POS` / `LPOS`. A "Close enough. It's spelled “…”" note appears when a typo was accepted.
     - **Wrong:** the chosen button turns rose with a ✕, the correct one turns coral and the rest fade to 55 %. The subline shows "Era · track N". Quacks escalate on consecutive misses; at 5 the full burst plays and unlocks Quack Collector.
     - **Timeout:** "Time's up. It was …".
     - "Next song →" appears 2 s after answering. Enter also advances.
   - **NTS lyrics:** a paper card rotated −1° holding 4 / 3 / 2 lines (Easy / Medium / Hard). On reveal the song and era appear at the top of the card. Easy also shows "From <Era>" with a small cover.
   - **Lyrics or Lie:** "Is this lyric from *Song*?", a paper card with 3 / 2 / 1 lines, and Real (R) or Fake (F). The reveal shows "It's a fake. That line is from X." Fakes come from distant eras on Easy, nearby albums (±2) on Medium, and the same album on Hard.
   - Between songs: a full-cover cat loader, "Loading next track...", shown for at least 450 ms.
   - Errors: "The needle won't drop."
   - Keyboard: 1–4 to answer, Space to play or pause, R / F, Enter for Next, Esc to close overlays.
7. **Round summary** (after Tonight's era):
   - Left column: a large "N of 10", a line depending on the score, and a bead row with filled and empty beads.
   - Right column: "The ones you knew" as a cover grid, with "Another round →" and "Back to menu".
8. **Record shelf:** "Ana's record shelf" (or "<nickname>'s"), "N of 15 · hover a record to hear it", and a 5-column grid (3 when narrow).
   - Each unlocked record is a sleeve with its disc peeking out at the top right, the achievement name in serif italic, and "on <Song> · <Mon D>" below.
   - On hover the disc slides further out and about 5 s of that song plays at 70 % volume.
   - Locked slots are dashed outlines with a short hint ("A secret" for Quack Collector).
9. **Settings:**
   - Look and sound: Theme (segmented), Volume, Misu visits (Often / Now and then / Off), and Nickname (Open edition only).
   - Timers: Medium and Hard, 10–40 s in steps of 5.
   - Updates: version, last checked, "Check now" with a spinner and its result, and an auto-check toggle with the note "Sends only a standard request to GitHub…".
   - Backups: the last 3, each with Restore (asks to confirm).
   - Progress: Reset… (rose, asks to confirm).
   - About: the new icon at 40 px, "Project Swiftie" and the edition line.
10. **Play together:**
    - **Hub:** Host a room / Join a room.
    - **Host:** pick a game, rounds (5 / 10 / 15) and difficulty (Easy 30 s with cover shown, Medium 20 s, Hard 12 s), then "Open room →".
    - **Join:** a 4-letter code field (A–Z, auto-uppercase), "Join →" with a spinner. Errors: "Room codes are 4 letters." and "Couldn't reach that room…".
    - **Lobby:** the room code in 4 large tiles with "Copy code", game summary, and a player list where each player animates in. Up to 8 players. The host sees "Start game →" (needs at least 2 players); guests see "Waiting for <host> to start…". "← Leave room" asks to confirm.
    - **Round:** a 3‑2‑1 countdown, then the record and the answer options. Your own pick shows as a coral outline and "•" until the reveal.
    - **Standings:** cards 56 px tall that re-sort with a 600 ms slide. Each shows rank, avatar, name, status, the player's own colour of beads, "+gain" and score.
    - **Reveal:** about 6 s, then "Next round in N". The host can press "Next now".
    - **Modes:**
      - **Classic:** 100 points plus up to 100 for speed.
      - **Quick draw:** the first right answer takes the round for 100. A wrong guess sits you out until the next song.
      - **Lyrics or Lie:** 100 for each right call.
    - **Final standings:** "You take it, Ana." or "<Name> takes it.", plus highlights (fastest answer, longest streak). The host gets "Play again →"; everyone gets "Back to menu".
    - Player colours: `#E97F6A` (you), `#6FA8DC`, `#D4A0A0`, `#9DBF8E`.

## Misu visits
- She rises from the bottom edge with a speech bubble (`--bubble`, serif 20/24, max 340 px wide). In games she appears on the left; elsewhere on the right. Clicking her dismisses the visit.
- **Triggers:**
  - The menu greeting, once per session.
  - A streak hitting a multiple of 5, with a special line at 10.
  - 3 misses in a row.
  - The quick-round summary.
  - A close finish in multiplayer (under 0.5 s between the top two, at most once every 3 rounds).
  - Winning a multiplayer game.
  - Open edition: introducing herself on first launch.
- **Frequency:** Often allows a visit every 2 rounds, Now and then every 5, Off disables them (forced messages still show).
- All copy is in `line()`, with first-person lines for the Ana edition and third-person lines for Open.

## Achievements
15 IDs with unchanged conditions (see `ACH`). When a record unlocks it stores `{date, song, album}`. The toast reads "New on your shelf", then the name, then "on <Song>", with a small sleeve and disc.

## Responsive
Width < 900: single column, 3-column grids, 200 px sleeve, 32 px padding. Width ≥ 1200: 6-column era grid, 320 px sleeve, 72 px padding.

## Assets
- `assets/app-icon/`: the **final app icon, "Misu cat-note" (4b)**. A cream note whose head is Misu's face (rose-lined ears, blue `#6FA8DC` eyes, cocoa nose, two-circle muzzle, cream whiskers) and whose flag curls into her tail, on cocoa `#3B2F2F` with five faint cream staff lines (26 % opacity).
  - `app-icon-macos.svg`: Apple grid, an 824 px rounded square (r 185) on a 1024 canvas. Use for `.icns` 64–1024 px.
  - `app-icon-macos-small.svg`: the same without the staff. Use for `.icns` 16 and 32 px (@1x and @2x).
  - `app-icon.svg`: full-bleed square with the staff. Use for Windows `.ico` 48–256 px.
  - `app-icon-small.svg`: no staff. Use for `.ico` 16, 24 and 32 px.
  - `mark.svg`: the mark alone on a transparent background.
  - Export the PNGs from these, then build `.icns` and `.ico`. Replace `macos/Runner/Assets.xcassets/AppIcon.appiconset` and `windows/runner/resources/app_icon.ico`.
- `assets/cat-icon-v2.svg`: the Misu vector, used for the menu card button and the edge visits.
- `cat-loader-v2.js`: a reference implementation of the new cat loader (sizes `lg` and `sm`, with a label). Recreate it as a Flutter widget.
- Album covers and 30 s previews are live from Deezer.

## Files
- `Project Swiftie.dc.html`: the full prototype. Open it in a browser; it needs `support.js` and `cat-loader-v2.js` beside it. The Tweaks panel switches platform, window size, theme, edition, birthday, update state and network.
- `assets/`: as above.
