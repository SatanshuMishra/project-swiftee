# How new releases join the catalogue

Date: 2026-10-07

## Context

The app ships a bundled catalogue and adds releases Deezer publishes later. Sorting songs into eras and versions only matters if a new album, single or edition lands in the right place without an app update, and on a first launch the bundled catalogue plus whatever is newer must sort the same way.

Before this change four things got in the way:
- The app checked Deezer once per session, because the first successful check was reused for the rest of the session.
- It fetched at most 8 new releases per check, so a fresh install of an old build caught up 8 releases at a time.
- It never fetched a known release again, so tracks Deezer added to a release, or previews switched on after the first fetch, never arrived until an app update shipped a new bundle.
- Era tiles were a hard-coded list matched by album title, so a thirteenth album and its songs would land in Singles & soundtracks.

Version sorting also guessed: any bracketed label that was not Taylor's Version, a vault mark, a feature or a soundtrack counted as an alternate take, which misfiled real songs such as "Mary's Song (Oh My My My)" and "I Can Fix Him (No Really I Can)".

## Decision

**Everything is derived from the data each time the catalogue is built.** Eras, takes and Taylor's Versions are computed from release and track titles whenever the catalogue is built, from the bundled releases and the downloaded ones alike. Nothing is stored per song, so a rule change reaches every song, and a first launch sorts exactly as an updated install does.

**Takes come from explicit labels.** `takeOf` in `lib/domain/util/song_title.dart` reads each bracketed or dashed part of a title. Live and Long Pond labels make a live take; acoustic, piano, demo, stripped, rehearsal, remix and named versions (such as "cabin in candlelight version") make an alternate take; Taylor's Version, vault marks, features, soundtracks, "10 Minute Version", "bonus track" and known song subtitles are studio. Live wins over alternate. A label the rules do not know counts as studio, and a test fails when the bundled catalogue holds one, so every new label gets a decision when the catalogue is regenerated. In the bundled catalogue: 339 studio, 53 live and 28 alternate recordings.

**A new album starts its own era.** After the twelve curated eras claim their songs by title, an album that is not one of them starts a new era when it has at least five playable songs and more than half of them belong to no era yet. The era takes the album's title without edition suffixes, its year and its cover. Its lead single, editions and live albums join it by the songs they share, the same way editions already joined curated eras. The bundled catalogue starts no new era. A new Taylor's Version joins its original era by title. "Tonight's era" still rotates through the curated twelve, so the main menu does not depend on the catalogue.

**Every check looks again and fetches everything.** The release check runs with every update check, at launch and every six hours. It fetches every release it has not seen, and fetches releases dated in the last 90 days again to pick up added tracks and newly available previews; an unchanged release is not written. Each saved release records when it was fetched, and whichever copy of a release was fetched last, bundled or saved, wins. If Deezer fails partway, the releases fetched so far are kept and the rest wait for the next check.
