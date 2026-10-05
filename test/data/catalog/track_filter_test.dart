import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/catalog/deezer_json.dart';
import 'package:swiftie_quiz/data/catalog/track_filter.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

DeezerTrack makeTrack(String title, String titleVersion, int duration) => (
  track: Track(
    id: 1,
    title: title,
    titleShort: title,
    duration: duration,
    preview: 'https://example.com/preview.mp3',
    artist: const Artist(id: 12246, name: 'Taylor Swift'),
    album: const Album(id: 1, title: 'Test Album', coverMedium: null),
  ),
  titleVersion: titleVersion,
);

void main() {
  group('track filter parity', () {
    test('keeps standard song', () {
      expect(isPlayableSong(makeTrack('Cruel Summer', '', 179)), isTrue);
    });

    test("keeps taylor's version", () {
      expect(
        isPlayableSong(makeTrack("Love Story (Taylor's Version)", '', 235)),
        isTrue,
      );
    });

    test('keeps from the vault', () {
      expect(
        isPlayableSong(
          makeTrack(
            "Mr. Perfectly Fine (From The Vault) (Taylor's Version)",
            '',
            244,
          ),
        ),
        isTrue,
      );
    });

    test('keeps 10 minute version', () {
      expect(
        isPlayableSong(
          makeTrack(
            "All Too Well (10 Minute Version) (Taylor's Version) "
                '(From The Vault)',
            '',
            613,
          ),
        ),
        isTrue,
      );
    });

    test('keeps feature collab', () {
      expect(
        isPlayableSong(
          makeTrack('Life of a Showgirl (with Sabrina Carpenter)', '', 190),
        ),
        isTrue,
      );
    });

    test('keeps acoustic version', () {
      expect(
        isPlayableSong(makeTrack('Lover (Acoustic)', '(Acoustic)', 210)),
        isTrue,
      );
    });

    test('keeps live version', () {
      expect(
        isPlayableSong(makeTrack('Love Story (Live)', '(Live)', 245)),
        isTrue,
      );
    });

    test('keeps deluxe bonus track', () {
      expect(isPlayableSong(makeTrack('New Romantics', '', 231)), isTrue);
    });

    test('discards chainsmokers remix', () {
      expect(
        isPlayableSong(
          makeTrack(
            'The Fate of Ophelia (The Chainsmokers Remix)',
            '(The Chainsmokers Remix)',
            226,
          ),
        ),
        isFalse,
      );
    });

    test('discards generic remix', () {
      expect(
        isPlayableSong(
          makeTrack('I Knew You Were Trouble (Remix)', '(Remix)', 219),
        ),
        isFalse,
      );
    });

    test('discards karaoke', () {
      expect(
        isPlayableSong(
          makeTrack('Shake It Off (Karaoke Version)', '(Karaoke Version)', 219),
        ),
        isFalse,
      );
    });

    test('discards instrumental', () {
      expect(
        isPlayableSong(
          makeTrack('Anti-Hero (Instrumental)', '(Instrumental)', 200),
        ),
        isFalse,
      );
    });

    test('discards short track', () {
      expect(isPlayableSong(makeTrack('Short Interlude', '', 45)), isFalse);
    });

    test('discards exactly 59 seconds', () {
      expect(isPlayableSong(makeTrack('Almost There', '', 59)), isFalse);
    });

    test('keeps exactly 60 seconds', () {
      expect(isPlayableSong(makeTrack('Just Long Enough', '', 60)), isTrue);
    });

    test('discards track-by-track', () {
      expect(
        isPlayableSong(makeTrack('Love Story - Track-by-Track', '', 120)),
        isFalse,
      );
    });

    test('discards track by track spaced', () {
      expect(
        isPlayableSong(makeTrack('Love Story - Track by Track', '', 120)),
        isFalse,
      );
    });

    test('discards commentary', () {
      expect(
        isPlayableSong(makeTrack('Fearless Commentary', '', 300)),
        isFalse,
      );
    });

    test('discards voice memo', () {
      expect(
        isPlayableSong(makeTrack('cardigan Voice Memo', '', 200)),
        isFalse,
      );
    });

    test('discards spoken word', () {
      expect(
        isPlayableSong(makeTrack('A Spoken Word Piece', '', 180)),
        isFalse,
      );
    });

    test('discards skit', () {
      expect(isPlayableSong(makeTrack('Interlude Skit', '', 90)), isFalse);
    });

    test('discards instrumental in title only', () {
      expect(
        isPlayableSong(makeTrack('Anti-Hero (Instrumental)', '', 200)),
        isFalse,
      );
    });

    test('whitespace only title version is kept', () {
      expect(isPlayableSong(makeTrack('Blank Space', '   ', 231)), isTrue);
    });

    test('remix detection is case insensitive', () {
      expect(
        isPlayableSong(makeTrack('Bad Blood (REMIX)', '(REMIX)', 211)),
        isFalse,
      );
    });

    test('non song detection is case insensitive', () {
      expect(
        isPlayableSong(makeTrack('Fearless COMMENTARY', '', 300)),
        isFalse,
      );
    });

    test("taylor's version in title version is kept", () {
      expect(
        isPlayableSong(
          makeTrack("Love Story (Taylor's Version)", "(Taylor's Version)", 235),
        ),
        isTrue,
      );
    });
  });
}
