# Bundled catalogue of every Taylor-led recording

Date: 2026-10-06

## Context

Swiftie Quiz v0.3.0 listed all of Deezer's releases for Taylor Swift (118 in October 2026), most of them repeats. The redesign narrowed "Pick your eras" to one standard album per era, which made songs unreachable: The Encore's new songs, singles such as "I Knew It, I Knew You", and tracks past Deezer's 25-track cut-off on `/album/{id}`. "Shuffle everything" used Deezer's top tracks, which stop at 99.

## Decision

- **Who sings.** A recording plays when Taylor Swift is its lead artist on Deezer. Duets she leads stay in, for example "The Life of a Showgirl" with Sabrina Carpenter. Songs led by other artists, remixes, karaoke, instrumentals, commentary and tracks under a minute stay out.
- **What a track is.** A recording is identified by its ISRC, so an edition that repeats a recording adds nothing. Taylor's Versions, originals, live, acoustic and demo recordings are separate tracks. Answers stay at the song level, so two versions of one song never appear as separate options.
- **Era tiles.** There are twelve era tiles plus Singles & soundtracks. A release joins an era by its title, then by which era's songs it mostly holds, and otherwise joins Singles & soundtracks. A recording belongs to the era of the first album that holds it, so every playable recording sits in exactly one tile and Shuffle everything is the union of all thirteen.
- **Where the data comes from.** `assets/catalog/catalogue.json` holds the raw Deezer releases with their full, paged tracklists. The rules in `lib/domain/engine/catalogue_rules.dart` run when the app starts. Once a session the app asks Deezer for releases it has not seen and keeps them in `catalogue_updates.json` beside the save. A track's preview link is fetched when it plays, because Deezer's links expire after fifteen minutes.

## Regenerating the bundled catalogue

```
dart run tool/catalog/build_catalogue.dart
```

The script asks Deezer for about 120 pages at four requests a second, which takes under two minutes. Commit the new `assets/catalog/catalogue.json` with the release that ships it.

## Not decided here

Picking individual releases, recordings or songs is being explored as a separate proof of concept. It is not part of this change.
