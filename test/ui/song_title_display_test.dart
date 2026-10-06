import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/ui/overlays/achievement_toasts.dart';
import 'package:swiftie_quiz/ui/screens/game_screen.dart';
import 'package:swiftie_quiz/ui/screens/lyrics_game_screen.dart';
import 'package:swiftie_quiz/ui/screens/record_shelf_screen.dart';

const String _vaultTitle = "Babe (Taylor's Version) (From The Vault)";

void main() {
  test('every place a song is named drops the version labels', () {
    const track = Track(
      id: 1,
      title: _vaultTitle,
      titleShort: _vaultTitle,
      duration: 224,
      preview: '',
      artist: Artist(id: 12246, name: 'Taylor Swift'),
      album: Album(
        id: 272247412,
        title: "Red (Taylor's Version)",
        coverMedium: null,
      ),
    );
    expect(songTitle(track), 'Babe');
    expect(AchievementToasts.songLine(_vaultTitle), 'on Babe');
    expect(
      RecordShelfScreen.detail(
        const AchievementState(
          unlocked: true,
          unlockedAt: null,
          song: _vaultTitle,
        ),
      ),
      'on Babe',
    );
    expect(
      LyricsGameScreen.fakeLine("Opalite (Taylor's Version)"),
      "It's a fake. That line is from Opalite.",
    );
  });

  test('reveal lines name the era, the version and the track number', () {
    Track recording(String title, String era, int? position, {String? short}) =>
        Track(
          id: 1,
          title: title,
          titleShort: short ?? title,
          duration: 200,
          preview: '',
          artist: const Artist(id: 12246, name: 'Taylor Swift'),
          album: const Album(id: 5, title: 'Release', coverMedium: null),
          trackPosition: position,
          eraKey: era,
        );
    expect(
      trackCaption(recording("Red (Taylor's Version)", 'red', 2)),
      "Red · Taylor's Version · track 2",
    );
    expect(trackCaption(recording('Red', 'red', 3)), 'Red · track 3');
    expect(
      trackCaption(
        recording(
          "All Too Well (10 Minute Version) (Taylor's Version) (From The Vault)",
          'red',
          30,
        ),
      ),
      'Red · From The Vault · track 30',
    );
    expect(
      trackCaption(
        recording(
          'Cruel Summer (Live from The Eras Tour)',
          'lover',
          2,
          short: 'Cruel Summer',
        ),
      ),
      'Lover · Live from The Eras Tour · track 2',
    );
    expect(
      trackCaption(
        recording(
          'Ruin The Friendship (My Advice Version)',
          'showgirl',
          17,
          short: 'Ruin The Friendship',
        ),
      ),
      'The Life of a Showgirl · My Advice Version · track 17',
    );
    expect(
      trackCaption(
        recording(
          "State Of Grace (Acoustic Version) (Taylor's Version)",
          'red',
          21,
        ),
      ),
      "Red · Taylor's Version · track 21",
    );
    expect(
      trackCaption(
        recording('I Knew It, I Knew You (From "Toy Story 5")', 'singles', 1),
      ),
      'Singles & soundtracks',
    );
  });
}
