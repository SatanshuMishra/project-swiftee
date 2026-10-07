import 'package:collection/collection.dart';
import 'package:swiftie_quiz/domain/engine/answer_matcher.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

const int taylorArtistId = 12246;
const String _taylorName = 'Taylor Swift';
const int minimumSongSeconds = 60;
const int minimumEraSongs = 5;

const List<String> _remixPatterns = [
  'remix',
  'version by',
  'karaoke',
  'instrumental',
];

const List<String> _nonSongPatterns = [
  'track-by-track',
  'track by track',
  'commentary',
  'voice memo',
  'spoken word',
  'skit',
  'instrumental',
];

const Map<String, List<String>> _eraTitles = {
  'ts': [r"^taylor swift(\s*[(\[]taylor's version[)\]])?$"],
  'fearless': [r'^fearless\b', r'^the more fearless'],
  'speaknow': [r'^speak now'],
  'red': [r'^red\b', r'^the more red'],
  '1989': [r'^1989'],
  'rep': [r'^reputation'],
  'lover': [r'^lover\b', r'^the more lover'],
  'folklore': [r'^folklore'],
  'evermore': [r'^evermore'],
  'midnights': [r'^midnights'],
  'ttpd': [r'^the tortured poets department'],
  'showgirl': [r'^the life of a showgirl'],
};

final RegExp _mixWord = RegExp(r'\bmix\b');

bool isPlayableTitle(String title, String titleVersion, int duration) {
  final version = titleVersion.toLowerCase();
  final lowerTitle = title.toLowerCase();
  final remixed =
      (version.trim().isNotEmpty && _remixPatterns.any(version.contains)) ||
      _remixPatterns.take(3).any(lowerTitle.contains) ||
      _mixWord.hasMatch(lowerTitle) ||
      _mixWord.hasMatch(version);
  return !remixed &&
      duration >= minimumSongSeconds &&
      !_nonSongPatterns.any(lowerTitle.contains);
}

bool isTaylorLed(RawTrack track) => track.artistId == taylorArtistId;

bool isPlayableRecording(RawTrack track) =>
    isTaylorLed(track) &&
    track.hasPreview &&
    isPlayableTitle(track.title, track.titleVersion, track.duration);

String? eraKeyForTitle(String title) {
  final lower = title.toLowerCase().replaceAll('’', "'");
  for (final MapEntry(:key, :value) in _eraTitles.entries) {
    if (value.any((pattern) => RegExp(pattern).hasMatch(lower))) {
      return key;
    }
  }
  return null;
}

Catalogue buildCatalogue(Iterable<RawRelease> releases) {
  final ordered = releases.sortedBy<String>((release) => _order(release, 0));
  final byTitle = {
    for (final release in ordered) release.id: eraKeyForTitle(release.title),
  };
  final songEras = <String, String>{};
  final releaseEras = <int, String>{};
  final derivedEras = <Era>[];
  final derivedByName = <String, String>{};
  Set<String> songsOf(RawRelease release) => {
    for (final track in release.tracks.where(isPlayableRecording))
      normalizeTitle(track.title),
  };
  Set<String> titlesOf(RawRelease release) => {
    for (final track in release.tracks) normalizeTitle(track.title),
  };
  void claim(RawRelease release, Set<String> songs, String era) {
    releaseEras[release.id] = era;
    for (final song in songs) {
      songEras.putIfAbsent(song, () => era);
    }
  }

  for (final release in ordered) {
    final songs = songsOf(release);
    final shared = songs.where(songEras.containsKey).length;
    final titled =
        byTitle[release.id] ?? derivedByName[eraNameFromTitle(release.title)];
    if (titled != null) {
      claim(release, songs, titled);
    } else if (release.kind == ReleaseKind.album &&
        songs.length >= minimumEraSongs &&
        shared * 2 < songs.length &&
        shared < minimumEraSongs) {
      final era = Era(
        key: 'album-${release.id}',
        deezerAlbumId: release.id,
        eraName: eraNameFromTitle(release.title),
        subLabel: release.releaseDate.split('-').first,
        placeholderArgb: singlesEra.placeholderArgb,
      );
      derivedEras.add(era);
      derivedByName[era.eraName] = era.key;
      claim(release, songs, era.key);
    } else if (release.kind != ReleaseKind.single) {
      if (_eraBySongs(titlesOf(release), songEras) case final voted?) {
        claim(release, songs, voted);
      }
    }
  }
  for (final release in ordered) {
    if (!releaseEras.containsKey(release.id)) {
      releaseEras[release.id] =
          _eraBySongs(titlesOf(release), songEras) ?? singlesEra.key;
    }
  }
  final homes =
      <String, ({RawRelease release, RawTrack track, int position})>{};
  for (final release in ordered.sortedBy<String>(
    (release) => _order(release, release.kind == ReleaseKind.album ? 0 : 1),
  )) {
    for (final (index, track) in release.tracks.indexed) {
      if (!isPlayableRecording(track)) {
        continue;
      }
      homes.putIfAbsent(
        track.isrc.isEmpty ? 'deezer:${track.id}' : track.isrc,
        () => (release: release, track: track, position: index + 1),
      );
    }
  }
  return Catalogue(
    sources: ordered,
    derivedEras: derivedEras,
    releaseEras: releaseEras,
    recordings: [
      for (final MapEntry(key: isrc, value: home) in homes.entries)
        CatalogueRecording(
          isrc: isrc,
          eraKey: releaseEras[home.release.id]!,
          track: Track(
            id: home.track.id,
            title: home.track.title,
            titleShort: home.track.titleShort,
            duration: home.track.duration,
            preview: '',
            artist: const Artist(id: taylorArtistId, name: _taylorName),
            album: home.release.album,
            trackPosition: home.position,
            eraKey: releaseEras[home.release.id],
          ),
        ),
    ],
  );
}

final RegExp _editionSuffix = RegExp(r'\s*(\([^)]*\)|\[[^\]]*\]|:.*|\s-\s.*)$');

String eraNameFromTitle(String releaseTitle) {
  final name = releaseTitle.trim();
  final shorter = name.replaceAll(_editionSuffix, '').trim();
  return shorter.isEmpty || shorter == name ? name : eraNameFromTitle(shorter);
}

String? _eraBySongs(Set<String> songs, Map<String, String> songEras) {
  final votes = <String, int>{};
  for (final song in songs) {
    if (songEras[song] case final era?) {
      votes[era] = (votes[era] ?? 0) + 1;
    }
  }
  return votes.entries
      .fold<MapEntry<String, int>?>(
        null,
        (best, next) => best == null || next.value > best.value ? next : best,
      )
      ?.key;
}

String _order(RawRelease release, int rank) =>
    '$rank:${release.releaseDate}:${release.id.toString().padLeft(12, '0')}';
