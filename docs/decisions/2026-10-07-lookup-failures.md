# How lookups fail

Date: 2026-10-07

## Context

Songs and lyrics are the game, and both come from the network: clips from Deezer's preview CDN, lyrics from LRCLIB. The song list itself ships with the app, so a game never waits on Deezer to start. An audit after lyrics games failed on Windows found three ways a lookup failure reached the player badly:

- A lyrics game told the player there were not enough songs with lyrics when LRCLIB could not be reached at all. The client counted every failed request as a song without lyrics, so the real cause never showed, on Windows or on a dropped connection.
- A lyrics game looked at only the first eight songs. When fewer than five of them had lyrics it gave up, even with hundreds of songs left to try.
- In a sound game, one clip that failed to download ended the game on "The needle won't drop", even when the next song would have played. A single dropped connection or server error was never tried again, and a server error on LRCLIB's search was remembered as "no lyrics" for the rest of the session.

## Decision

**Every request has a ceiling and one quick retry.** Each Deezer, LRCLIB and preview request gives up after 10 seconds. A request that fails quickly, with a dropped connection, a server error or a rate limit, is tried once more: after 1 second for LRCLIB (or the server's Retry-After, at most 10 seconds) and after 500 ms for a clip. A request that timed out is not tried again, because it has already used its 10 seconds. A refusal (403, 404) or an untrusted link is never retried; an expired clip link (403) is refreshed from Deezer once, as before.

**A song that could not be checked is not a song without lyrics.** `LrclibClient.fetchLyricsBatch` leaves out a track it could not check, so its caller can tell the two apart, and only real answers are cached.

**The lyrics loader keeps looking.** `LyricsController.preFetchInitial` checks eight songs at a time, up to 24, until five have lyrics. It stops at the first batch it could not check at all and reports LRCLIB as unreachable, and it reports the same when too few songs were found because some could not be checked. The loading screen then shows "We couldn't fetch lyrics from LRCLIB. Check your connection and try again." with Try again and Back to menu, in place of "Not enough songs". The whole load still gives up after 30 seconds.

**A sound game skips a song it cannot play.** A clip that still fails after its retry is treated like a song with no preview: the round draws another song, and the song is left out for the rest of the game. After three skipped songs in a row the game shows "The needle won't drop" with Try again and Back to menu; Try again starts a fresh run of three. An audio error that arrives after the player has answered is ignored.

## What the player waits for

| Situation | What the player sees | Longest wait |
|---|---|---|
| Lyrics game starting | The cat loader, a rotating line, "n of m songs" and a Back to menu link | 30 seconds, then the timeout message with Try again |
| LRCLIB unreachable | The same loader, then the connection message | A few seconds when the connection fails outright; 30 seconds when requests hang |
| Sound round, clip slow | The round loader for up to 8 seconds, then the round with its timer held until the clip is ready | 10 seconds for the clip, or 20 when its link must first be fetched from Deezer, before the song is skipped |
| Sound round, clips keep failing | Songs are swapped silently | Four songs: a few seconds when requests fail outright, 40 to 80 seconds when every request hangs, then the failure screen |
| Play together host | "Couldn't get the songs ready. Try again." for lyrics; a clip that will not load is redrawn up to three times | The same ceilings |

The player can leave at any point: every loader and round has Back to menu or Exit.

## Not decided here

Smart clips still fall back to a random start when LRCLIB's synced lyrics take longer than 2 seconds; that only affects where a clip starts, so it stays silent. A Play together guest whose clip fails still plays the round without sound.
