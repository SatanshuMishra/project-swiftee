import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/util/song_title.dart';

void main() {
  group('displaySongTitle', () {
    test('drops the taylor version and vault labels', () {
      expect(displaySongTitle("22 (Taylor's Version)"), '22');
      expect(
        displaySongTitle("Run (Taylor's Version) (From The Vault)"),
        'Run',
      );
      expect(
        displaySongTitle(
          'When Emma Falls in Love (Taylor’s Version) (From The Vault)',
        ),
        'When Emma Falls in Love',
      );
      expect(
        displaySongTitle(
          "Mr. Perfectly Fine (Taylor's Version) [From The Vault]",
        ),
        'Mr. Perfectly Fine',
      );
    });

    test('keeps every other version label', () {
      expect(
        displaySongTitle(
          "All Too Well (10 Minute Version) (Taylor's Version) (From The Vault)",
        ),
        'All Too Well (10 Minute Version)',
      );
      expect(
        displaySongTitle('Christmas Tree Farm (Old Timey Version)'),
        'Christmas Tree Farm (Old Timey Version)',
      );
      expect(displaySongTitle('willow'), 'willow');
    });
  });
}
