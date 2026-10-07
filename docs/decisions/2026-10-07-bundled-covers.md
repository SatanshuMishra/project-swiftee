# Album covers ship with the app

Date: 2026-10-07

## Context

On 2026-10-07 the era picker showed coloured placeholders for 11 of its 13 covers on macOS. Every cover came straight from Deezer's image servers each time it was shown, with no copy kept and no retry, and a failure silently fell back to the placeholder. From this Mac, behind a VPN whose exit is a datacenter address, Deezer's image servers answered every cover, at every size and from both image hosts, with "403 Forbidden", including covers of other artists and Taylor's artist photo. Deezer's API and its song previews answered normally from the same address, and the API returned the same cover addresses the app already held, so the addresses were current. The same request from a GitHub runner succeeded. Any player on a network Deezer's image servers refuse, such as a VPN or a school or office network, sees placeholders everywhere a cover appears.

Song audio is not cached: previews stream from signed addresses that expire. Only the song list ships with the app, and the catalogue refresh adds new releases at runtime.

## Decision

**Every cover in the bundled song list ships with the app.** `assets/covers/` holds one JPEG per distinct cover, named by Deezer's image key: 109 covers, 1,985,334 bytes. The 13 era covers are 500 by 500 pixels, because era tiles are drawn about 480 pixels wide on a Retina screen; the other 96 are 250 by 250, the size the app showed before. That adds about 2 MB to each download. `dart run tool/catalog/bundle_covers.dart` fetches any cover the list names that is missing or at the wrong size, and reports files the list no longer names. A test fails when the song list changes without the covers, when a cover is at the wrong size, when a stale file remains, or when the folder grows past 5 MB. The tool needs a network Deezer's image servers accept; the first run used a temporary GitHub Actions workflow on a throwaway branch.

**One store loads every cover** (`lib/data/covers/cover_store.dart`), in this order: the bundled copy; a kept copy, only when saving covers is on; then Deezer, through the app's HTTP client so Windows still trusts the bundled roots. Only https links on Deezer's two image hosts count as Deezer covers; any other link still downloads but is never kept, so a link passed along by another player in Play together cannot plant an image under a release's name. A download that times out after 10 seconds is abandoned and, like a 408, 429 or server error, tried once more after a second; a refusal such as 403 is not. A response that is not a JPEG, PNG or WebP image is refused and never kept, and a kept file that is not an image is replaced. Every screen draws covers through `CoverPicture`. The app holds one store for its whole run and reads the setting at each load, so changing the setting does not reload covers already on screen.

**A cover that fails is tried again the next time it is shown.** Flutter's image cache does not drop a failed image by itself; `CoverImage` evicts its own entry on failure, as Flutter's network image does, so returning to a screen retries.

**Saving covers is a setting, off by default.** Settings shows "Save album covers" under a new Storage heading. When it is on, a cover downloaded because it is not bundled, in practice a new release found by the catalogue refresh, is written to a `covers` folder beside `save.json` and read from there afterwards, even offline. Turning it off deletes that folder, including a cover that finishes downloading afterwards; restoring a backup that has it off does the same, and so does every launch whose save loads with it off, which also clears a folder an earlier delete could not remove. If the app-data folder cannot be found, covers still load and simply are not kept. The setting is `saveCovers` in the save file, which moved to version 6; a version 5 save loads with it off and is otherwise unchanged.

## Consequences

- A new release shows its cover only once Deezer's image servers answer, unless a later app version bundles it; on a refused network it keeps its placeholder.
- Running `tool/catalog/build_catalogue.dart` should be followed by `tool/catalog/bundle_covers.dart`; the test names the missing covers until it is.
