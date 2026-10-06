# Keeping songs and lyrics from repeating

Date: 2026-10-06

## Context

The catalogue treats every Taylor's Version, original, live and acoustic recording as its own track (see 2026-10-06-catalogue.md). A plain shuffle then plays two versions of one song in the same ten-song game 69% of the time on Red, 77% on Speak Now, 82% on The Life of a Showgirl and 88% on folklore.

Lyrics games read every recording, so the same words came up once per version. Since v0.3.0, loading more lyrics mid-game also reset the game's place in its song list, so the next round replayed the first song. Two loads that overlapped could fetch and add the same songs twice, a load still running when a game ended could add its songs to the next game, and five songs in a row with no lyrics stopped the pool from growing.

## Decision

Sound and lyrics repeat in different ways, so they follow different rules. Both are built round by round, the way radio schedulers place songs: each round takes the first candidate by these tests, in order, and breaks the final tie at random.

**Sound rounds: the recording is what repeats.** Two versions of one song can sound nothing alike: the piano version of "Forever & Always" is a different arrangement from the album version.
1. A song does not come back within ten rounds, or within three quarters of the songs in a small pick. This holds across consecutive games and counts every version, so a live take heard in a Taylor Swift game keeps the song out of the Fearless game after it.
2. Every recording in the pick plays before any recording plays twice, except a version held back by rule 1, which plays as soon as its song is clear. When a song comes back, it comes back in the version heard least this session.
3. When a small pick cannot keep a song's versions apart, the extra versions wait for the next pass instead of playing close together.
4. A recording counts as heard once its clip loads. One that cannot play does not hold its song back.

**Lyrics rounds: the song is what repeats.** Versions share their words.
1. Each song is read from one recording, preferring a studio take over a live or demo one.
2. Every song in the pick is shown once before any song is shown again.
3. Between passes, a song read in the last half of the pick's songs does not open the next pass.
4. A line shown this session is not shown again while the song has unseen lines that make a playable lyric. This covers lines first shown as a Lyrics or Lie fake, and an Easy round moves on from a chorus already shown to verses not yet seen.

When sound rules 1 and 2 meet, rule 1 wins: playing every recording first would bring a song back within ten rounds, which is the repeat players hear. Ties are never broken by last-played order, so a new pass does not replay the previous one. Measured on the bundled catalogue, a ten-song game of any era or of Shuffle everything now plays no song twice, and neither do the ten rounds that straddle two games in a row. Before, two versions of one song shared a ten-song game 55 to 95% of the time on ten of the thirteen era tiles.

The memory lasts one session and is never written to `save.json`, so the save format does not change.

## Cost

Ordering the whole catalogue (420 recordings) takes about 1 ms. One era takes about 0.1 ms, and ordering the lyrics pool for the whole catalogue takes about 2 ms. It runs once when a game starts and once each time a pass runs out.

## Sources

- Spotify Engineering, "Shuffle: making random feel more human" (2025), which penalises recently played tracks: https://engineering.atspotify.com/2025/11/shuffle-making-random-feel-more-human
- MusicMaster, title keyword separation for multiple versions of a song: https://musicmaster.com/?p=7555
- RCS GSelector, minimum separation and packets that rotate a live and a studio version as one song: https://www.rcsworks.com/blog/schedule-like-the-pros-gselectors-rotation-rules-window/ and https://www.rcsworks.com/blog/a-conversation-with-bill-webber-scheduler-development-director/
- TetrisWiki, the 7-bag randomizer and the history randomizer: https://tetris.wiki/Random_Generator and https://tetris.wiki/TGM_randomizer
- Open Trivia DB, session tokens that never repeat a question: https://opentdb.com/api_config.php
- IFPI ISRC Handbook (a new recording gets a new ISRC) and ISWC (the work, including its lyrics, is identified apart from its recordings): https://www.ifpi.org/isrc_handbook/ and https://www.iswc.org/iswc

## Not decided here

- Remembering across launches. That needs a save format version bump and a migration.
- Sharing one history between sound and lyrics rounds, so the same song is not the answer in back-to-back games of different types.
