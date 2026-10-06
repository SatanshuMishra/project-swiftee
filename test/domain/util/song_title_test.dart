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

  group('versionLabel', () {
    test('names every part of the title the answer does not show', () {
      expect(
        versionLabel(
          'Ruin The Friendship (My Advice Version)',
          shown: 'Ruin The Friendship',
        ),
        'My Advice Version',
      );
      expect(
        versionLabel(
          'Christmas Tree Farm (Recorded Live at the 2019 iHeartRadio Jingle Ball)',
          shown: 'Christmas Tree Farm',
        ),
        'Recorded Live at the 2019 iHeartRadio Jingle Ball',
      );
      expect(
        versionLabel(
          'Snow On The Beach (feat. More Lana Del Rey)',
          shown: 'Snow On The Beach',
        ),
        'feat. More Lana Del Rey',
      );
      expect(
        versionLabel('Long Live (Live/2011)', shown: 'Long Live'),
        'Live/2011',
      );
    });

    test('names a vault track once and a re-recording once', () {
      expect(
        versionLabel("Run (Taylor's Version) (From The Vault)", shown: 'Run'),
        'From The Vault',
      );
      expect(
        versionLabel(
          'Mr. Perfectly Fine (Taylor’s Version) [From The Vault]',
          shown: 'Mr. Perfectly Fine',
        ),
        'From The Vault',
      );
      expect(
        versionLabel('Love Story (Taylor’s Version)', shown: 'Love Story'),
        "Taylor's Version",
      );
    });

    test('skips what the answer already shows', () {
      expect(
        versionLabel(
          "All Too Well (10 Minute Version) (Taylor's Version) (From The Vault)",
          shown: 'All Too Well (10 Minute Version)',
        ),
        'From The Vault',
      );
      expect(
        versionLabel(
          'All Too Well (Sad Girl Autumn Version) - Recorded at Long Pond Studios',
          shown: 'All Too Well (Sad Girl Autumn Version) - Recorded at Long Pond Studios',
        ),
        isNull,
      );
      expect(versionLabel('willow', shown: 'willow'), isNull);
      expect(versionLabel('Long Live', shown: 'Long Live'), isNull);
      expect(
        versionLabel("Long Live (Taylor's Version)", shown: 'Long Live'),
        "Taylor's Version",
      );
    });
  });
}
