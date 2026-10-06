import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/util/song_title.dart';

typedef ReleaseMatch = ({CatalogueRelease release, String? song});

final RegExp _marks = RegExp('[̀-ͯ]');
final RegExp _apostrophes = RegExp('[‘’]');
final RegExp _other = RegExp("[^a-z0-9' ]+");
final RegExp _spaces = RegExp(r'\s+');

const Map<String, String> _accents = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ñ': 'n',
  'ç': 'c',
};

String foldForSearch(String text) => text
    .toLowerCase()
    .split('')
    .map((letter) => _accents[letter] ?? letter)
    .join()
    .replaceAll(_marks, '')
    .replaceAll(_apostrophes, "'")
    .replaceAll(_other, ' ')
    .replaceAll(_spaces, ' ')
    .trim();

typedef _Entry = ({
  CatalogueRelease release,
  String title,
  List<({String folded, String shown})> songs,
});

final class ReleaseSearch {
  ReleaseSearch(Iterable<CatalogueRelease> releases)
    : _entries = List.unmodifiable([
        for (final release in releases)
          (
            release: release,
            title: foldForSearch(release.title),
            songs: List<({String folded, String shown})>.unmodifiable([
              for (final track in release.tracks)
                (
                  folded: foldForSearch(track.title),
                  shown: displaySongTitle(track.title),
                ),
            ]),
          ),
      ]);

  final List<_Entry> _entries;

  List<ReleaseMatch> matches(String query) {
    final needle = foldForSearch(query);
    return List.unmodifiable([
      for (final entry in _entries) ?_match(entry, needle),
    ]);
  }

  static ReleaseMatch? _match(_Entry entry, String needle) {
    if (needle.isEmpty || entry.title.contains(needle)) {
      return (release: entry.release, song: null);
    }
    for (final song in entry.songs) {
      if (song.folded.contains(needle)) {
        return (release: entry.release, song: song.shown);
      }
    }
    return null;
  }
}
