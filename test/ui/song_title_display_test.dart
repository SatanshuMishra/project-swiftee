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
}
