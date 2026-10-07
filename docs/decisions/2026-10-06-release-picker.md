# Picking eras and releases

Date: 2026-10-06

## Context

The picker offered the thirteen era tiles only. Fans also think in releases (one album, a deluxe edition, a live record, a run of singles) and in version types (Taylor's Versions only, no live takes). The design was agreed on a clickable mock-up before it was built.

## Decision

**Two tabs whose picks add together.** "Pick your eras" keeps the era tiles. "Pick your releases" lists every release with something to play (97 on the bundled catalogue) under its era, newest era last. A game plays every recording in the picked eras plus every recording on the picked releases, each once. The tabs cannot be two views of one selection, because a release can hold songs from other eras: the reputation Stadium Tour Surprise Song Playlist carries 41 songs from other eras, so picking every reputation release is not the same as picking the reputation era.

**Nothing is picked when the picker opens.** It opens on Eras, unless only releases are picked, so that coming back from Set up shows what was chosen. The menu's "Pick your eras" row is unchanged.

**Releases can be filtered and searched.** All, Albums, EPs and Singles narrow the list. The search matches release titles first, then the songs on each release, and names the song that matched ("with “Cruel Summer”"). It ignores case, punctuation, accents and curly apostrophes, and its folded titles are built once per catalogue.

**Version types are chosen on Set up and on Host a room, for Sound only.** Revised twice on 2026-10-07. The first version offered Every version, Taylor's Version and No live takes as one single choice, which mixed two questions. The second asked "Recordings" and "Also play", but hid a card whenever the pick had none of that kind, so Live takes vanished for a pick of The Tortured Poets Department and The Life of a Showgirl and read as a bug, and "Acoustic & other takes" told a player nothing about what "other" meant. Play together played every version with no way to choose. Both screens now ask the same two questions with the same controls (`lib/ui/widgets/version_choices.dart`), and the track count updates as they change. Lyrics games read one studio take per song, so the questions would change nothing there and are not shown, which also covers Lyrics or Lie.

- **Versions: Studio · Live · Acoustic & remixes.** Tick any; every card is ticked by default and shows how many recordings of its kind the pick holds, as sorted by `takeOf` (see 2026-10-07-catalogue-growth.md): 339 studio, 53 live and 28 acoustic or remixed recordings of 420. Acoustic & remixes holds the acoustic and piano versions (15) and the remixes, demos and special edits (13), such as the willow witch remixes and the Red demos. A card whose kind is missing from the pick stays visible, dimmed, and reads "None in your pick" instead of vanishing.
- **Re-recorded songs: Taylor's Version · Original · Both.** One choice, Both by default, on the same pill control as Rounds and Difficulty. Shown only when the pick holds a song in both a re-recording and an original, which happens on Fearless, Speak Now, Red and 1989. A recording of such a song plays only when its kind is chosen; songs never re-recorded and every vault track, including the ten-minute All Too Well, always play. A recording without a Taylor's Version label counts as an original, so a later take labelled only by its own name, such as the Sad Girl Autumn All Too Well, follows Original. Taylor's Version alone drops 98 of Shuffle everything's 420 recordings and keeps every song.
- A recording plays when its version and its recording are both chosen, so "State Of Grace (Acoustic Version) (Taylor's Version)" needs Acoustic & remixes and Taylor's Version or Both, and "Haunted (Live/2011)" needs Live and Original or Both.
- A choice that would leave nothing to play, such as turning off Live for an all-live release, turning off the last version left, or Taylor's Version when only original live recordings remain, is dimmed and announced as disabled. A remembered choice that leaves nothing for a new pick falls back to everything, for single-player games and rooms alike.
- The version cards are compact toggles with a check, announced as checkboxes, and the recording choice is one pill row, so Start stays in view in a 1024 by 800 window. The pill row shrinks only when it cannot fit, as at 225 percent text in a 900 pixel window.
- A card whose recordings are all left out by the recording choice says which choice did it, "None in Taylor's Version" or "None in the originals", rather than "None in your pick".
- In Play together the choice travels with the room settings, and the room summary names it when it is not everything, for example "10 rounds · Medium · Shuffle everything · Studio, Acoustic & remixes · Taylor's Version". When the host changes the pick, the choice is fitted to it: a kind the new pick lacks counts as ticked and a recording choice it cannot use returns to Both, so the summary never names a filter that does nothing. The pick's track count in the summary counts only the recordings that will play.

Picks and the version choice last the session and are not written to `save.json`, so the save format does not change.

## Not decided here

- Remembering the version choice across launches. That needs a save format version bump and a migration.
