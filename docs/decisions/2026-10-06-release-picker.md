# Picking eras and releases

Date: 2026-10-06

## Context

The picker offered the thirteen era tiles only. Fans also think in releases (one album, a deluxe edition, a live record, a run of singles) and in version types (Taylor's Versions only, no live takes). The design was agreed on a clickable mock-up before it was built.

## Decision

**Two tabs whose picks add together.** "Pick your eras" keeps the era tiles. "Pick your releases" lists every release with something to play (97 on the bundled catalogue) under its era, newest era last. A game plays every recording in the picked eras plus every recording on the picked releases, each once. The tabs cannot be two views of one selection, because a release can hold songs from other eras: the reputation Stadium Tour Surprise Song Playlist carries 41 songs from other eras, so picking every reputation release is not the same as picking the reputation era.

**Nothing is picked when the picker opens.** It opens on Eras, unless only releases are picked, so that coming back from Set up shows what was chosen. The menu's "Pick your eras" row is unchanged.

**Releases can be filtered and searched.** All, Albums, EPs and Singles narrow the list. The search matches release titles first, then the songs on each release, and names the song that matched ("with “Cruel Summer”"). It ignores case, punctuation, accents and curly apostrophes, and its folded titles are built once per catalogue.

**Version types are chosen on Set up, for Sound only.** "Which versions" offers Every version, Taylor's Version and No live takes, and the track count updates as it changes. It sits on Set up rather than the picker, so it covers Shuffle everything and tonight's era too. Lyrics games read one studio take per song, so the choice would change nothing there and is not shown.

- Taylor's Version drops an original when the pick holds a re-recording of the same song. Shuffle everything loses 98 of its 420 recordings. A pick holding only originals, such as the Red album, keeps them.
- No live takes drops recordings whose title marks them live or from the Long Pond sessions: 53 of 420.
- A choice that would leave nothing to play, as No live takes would for any of the 13 all-live releases, is dimmed and falls back to Every version.

Picks and the version choice last the session and are not written to `save.json`, so the save format does not change.

## Not decided here

- Combining Taylor's Version with No live takes. The choice is single for now.
- Remembering the version choice across launches. That needs a save format version bump and a migration.
