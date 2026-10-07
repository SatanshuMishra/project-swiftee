# Picking eras and releases

Date: 2026-10-06

## Context

The picker offered the thirteen era tiles only. Fans also think in releases (one album, a deluxe edition, a live record, a run of singles) and in version types (Taylor's Versions only, no live takes). The design was agreed on a clickable mock-up before it was built.

## Decision

**Two tabs whose picks add together.** "Pick your eras" keeps the era tiles. "Pick your releases" lists every release with something to play (97 on the bundled catalogue) under its era, newest era last. A game plays every recording in the picked eras plus every recording on the picked releases, each once. The tabs cannot be two views of one selection, because a release can hold songs from other eras: the reputation Stadium Tour Surprise Song Playlist carries 41 songs from other eras, so picking every reputation release is not the same as picking the reputation era.

**Nothing is picked when the picker opens.** It opens on Eras, unless only releases are picked, so that coming back from Set up shows what was chosen. The menu's "Pick your eras" row is unchanged.

**Releases can be filtered and searched.** All, Albums, EPs and Singles narrow the list. The search matches release titles first, then the songs on each release, and names the song that matched ("with “Cruel Summer”"). It ignores case, punctuation, accents and curly apostrophes, and its folded titles are built once per catalogue.

**Version types are chosen on Set up, for Sound only.** Revised on 2026-10-07: the first version offered Every version, Taylor's Version and No live takes as one single choice, which mixed two questions and could not combine them. Set up now asks two multi-select questions, with every card selected by default, and the track count updates as they change. It sits on Set up rather than the picker, so it covers Shuffle everything and tonight's era too. Lyrics games read one studio take per song, so the questions would change nothing there and are not shown.

- **Recordings: Taylor's Version · Originals.** Shown only when the pick holds a song in both a re-recording and an original, which happens on Fearless, Speak Now, Red and 1989. A recording of such a song plays only when its kind is selected; songs never re-recorded and every vault track, including the ten-minute All Too Well, always play. A recording without a Taylor's Version label counts as an original, so a later take labelled only by its own name, such as the Sad Girl Autumn All Too Well, follows Originals. Taylor's Version alone drops 98 of Shuffle everything's 420 recordings and keeps every song. One kind must stay selected.
- **Also play: Live takes · Acoustic & other takes.** Each card shows only when the pick holds that kind of take, as sorted by `takeOf` (see 2026-10-07-catalogue-growth.md): 53 live and 28 other takes of 420. Studio takes always play.
- A recording plays when both of its labels are selected, so "State Of Grace (Acoustic Version) (Taylor's Version)" needs Taylor's Version and Acoustic & other takes, and "Haunted (Live/2011)" needs Originals and Live takes.
- A card that would leave nothing to play, such as Live takes for an all-live release or the last recording kind left, is dimmed and announced as disabled, and a remembered choice that leaves nothing for a new pick falls back to everything.
- The cards are compact toggles with a check, announced as checkboxes, so Start stays in view in a 1024 by 800 window.

Picks and the version choice last the session and are not written to `save.json`, so the save format does not change.

## Not decided here

- Remembering the version choice across launches. That needs a save format version bump and a migration.
