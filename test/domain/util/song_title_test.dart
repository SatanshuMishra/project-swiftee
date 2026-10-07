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

  group('takeOf', () {
    test('counts album, re-recorded, vault, featured, soundtrack and '
        'subtitled songs as studio takes', () {
      for (final title in [
        'Fearless',
        "Fearless (Taylor's Version)",
        "Run (Taylor's Version) (From The Vault)",
        'Everything Has Changed (feat. Ed Sheeran)',
        'Snow On The Beach (feat. More Lana Del Rey)',
        'I Knew It, I Knew You (From "Toy Story 5")',
        "Safe & Sound (From The Hunger Games Soundtrack) (Taylor's Version)",
        "All Too Well (10 Minute Version) (Taylor's Version) (From The Vault)",
        "Mary's Song (Oh My My My)",
        'I Can Fix Him (No Really I Can)',
        'Right Where You Left Me (bonus track)',
        'Only The Young (Featured in Miss Americana)',
      ]) {
        expect(takeOf(title), Take.studio, reason: title);
      }
    });

    test('spots live and Long Pond takes from their labels', () {
      for (final title in [
        'Fearless (Live from Clear Channel Stripped 2008)',
        'Speak Now (Live/2011)',
        'Cruel Summer (Live from TS | The Eras Tour)',
        'invisible string (the long pond studio sessions)',
        'All Too Well (Sad Girl Autumn Version) - Recorded at Long Pond '
            'Studios',
        'Christmas Tree Farm (Recorded Live at the 2019 iHeartRadio Jingle '
            'Ball)',
      ]) {
        expect(takeOf(title), Take.live, reason: title);
      }
      expect(takeOf('Long Live'), Take.studio);
      expect(takeOf("Long Live (Taylor's Version)"), Take.studio);
    });

    test('spots acoustic, piano, demo and other named takes', () {
      for (final title in [
        'Forever & Always (Piano Version)',
        'Fearless - Demo',
        'Red (Original Demo Recording)',
        "Wildest Dreams (Taylor's Version) - Acoustic",
        "State Of Grace (Acoustic Version) (Taylor's Version)",
        'Teardrops on My Guitar (Pop Version)',
        'cardigan (cabin in candlelight version)',
        'the lakes (original version)',
        'All Too Well (10 Minute Version) (The Short Film)',
        'I Knew It, I Knew You (Piano Version From "Toy Story 5")',
        'Lover (Remix) (feat. Shawn Mendes)',
      ]) {
        expect(takeOf(title), Take.alternate, reason: title);
      }
    });

    test('names the labels it does not know, and counts them as studio', () {
      expect(unknownTitleLabels('Fearless'), isEmpty);
      expect(unknownTitleLabels("Mary's Song (Oh My My My)"), isEmpty);
      expect(unknownTitleLabels('Tim McGraw (Some New Subtitle) (Acoustic)'), [
        'Some New Subtitle',
      ]);
      expect(takeOf('Tim McGraw (Some New Subtitle)'), Take.studio);
    });
  });

  group('version marks', () {
    test("spots a Taylor's Version title", () {
      expect(isTaylorsVersion("Red (Taylor's Version)"), isTrue);
      expect(isTaylorsVersion('Red (Taylor’s Version)'), isTrue);
      expect(
        isTaylorsVersion("Run (Taylor's Version) (From The Vault)"),
        isTrue,
      );
      expect(isTaylorsVersion('Red'), isFalse);
      expect(isTaylorsVersion("Taylor's Version"), isFalse);
    });
  });
}
