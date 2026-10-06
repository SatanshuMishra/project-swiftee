import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/catalogue_rules.dart';

void main() {
  group('playable title', () {
    test('keeps standard song', () {
      expect(isPlayableTitle('Cruel Summer', '', 179), isTrue);
    });

    test("keeps taylor's version", () {
      expect(isPlayableTitle("Love Story (Taylor's Version)", '', 235), isTrue);
    });

    test('keeps from the vault', () {
      expect(
        isPlayableTitle(
          "Mr. Perfectly Fine (From The Vault) (Taylor's Version)",
          '',
          244,
        ),
        isTrue,
      );
    });

    test('keeps 10 minute version', () {
      expect(
        isPlayableTitle(
          "All Too Well (10 Minute Version) (Taylor's Version) "
              '(From The Vault)',
          '',
          613,
        ),
        isTrue,
      );
    });

    test('keeps feature collab', () {
      expect(
        isPlayableTitle('Life of a Showgirl (with Sabrina Carpenter)', '', 190),
        isTrue,
      );
    });

    test('keeps acoustic version', () {
      expect(isPlayableTitle('Lover (Acoustic)', '(Acoustic)', 210), isTrue);
    });

    test('keeps live version', () {
      expect(isPlayableTitle('Love Story (Live)', '(Live)', 245), isTrue);
    });

    test('keeps deluxe bonus track', () {
      expect(isPlayableTitle('New Romantics', '', 231), isTrue);
    });

    test('discards chainsmokers remix', () {
      expect(
        isPlayableTitle(
          'The Fate of Ophelia (The Chainsmokers Remix)',
          '(The Chainsmokers Remix)',
          226,
        ),
        isFalse,
      );
    });

    test('discards generic remix', () {
      expect(
        isPlayableTitle('I Knew You Were Trouble (Remix)', '(Remix)', 219),
        isFalse,
      );
    });

    test('discards karaoke', () {
      expect(
        isPlayableTitle(
          'Shake It Off (Karaoke Version)',
          '(Karaoke Version)',
          219,
        ),
        isFalse,
      );
    });

    test('discards instrumental', () {
      expect(
        isPlayableTitle('Anti-Hero (Instrumental)', '(Instrumental)', 200),
        isFalse,
      );
    });

    test('discards short track', () {
      expect(isPlayableTitle('Short Interlude', '', 45), isFalse);
    });

    test('discards exactly 59 seconds', () {
      expect(isPlayableTitle('Almost There', '', 59), isFalse);
    });

    test('keeps exactly 60 seconds', () {
      expect(isPlayableTitle('Just Long Enough', '', 60), isTrue);
    });

    test('discards track-by-track', () {
      expect(isPlayableTitle('Love Story - Track-by-Track', '', 120), isFalse);
    });

    test('discards track by track spaced', () {
      expect(isPlayableTitle('Love Story - Track by Track', '', 120), isFalse);
    });

    test('discards commentary', () {
      expect(isPlayableTitle('Fearless Commentary', '', 300), isFalse);
    });

    test('discards voice memo', () {
      expect(isPlayableTitle('cardigan Voice Memo', '', 200), isFalse);
    });

    test('discards spoken word', () {
      expect(isPlayableTitle('A Spoken Word Piece', '', 180), isFalse);
    });

    test('discards skit', () {
      expect(isPlayableTitle('Interlude Skit', '', 90), isFalse);
    });

    test('discards instrumental in title only', () {
      expect(isPlayableTitle('Anti-Hero (Instrumental)', '', 200), isFalse);
    });

    test('whitespace only title version is kept', () {
      expect(isPlayableTitle('Blank Space', '   ', 231), isTrue);
    });

    test('remix detection is case insensitive', () {
      expect(isPlayableTitle('Bad Blood (REMIX)', '(REMIX)', 211), isFalse);
    });

    test('non song detection is case insensitive', () {
      expect(isPlayableTitle('Fearless COMMENTARY', '', 300), isFalse);
    });

    test("taylor's version in title version is kept", () {
      expect(
        isPlayableTitle(
          "Love Story (Taylor's Version)",
          "(Taylor's Version)",
          235,
        ),
        isTrue,
      );
    });
  });
}
