import 'package:collection/collection.dart';
import 'package:swiftie_quiz/domain/engine/answer_matcher.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

const int taylorArtistId = 12246;
const String _taylorName = 'Taylor Swift';
const int minimumSongSeconds = 60;

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
  'ts': [r'^taylor swift$'],
  'fearless': [r'^fearless', r'^the more fearless'],
  'speaknow': [r'^speak now'],
  'red': [r'^red\b', r'^the more red'],
  '1989': [r'^1989'],
  'rep': [r'^reputation'],
  'lover': [r'^lover', r'^the more lover'],
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
  final eraSongs = <String, Set<String>>{};
  for (final release in ordered) {
    final era = byTitle[release.id];
    if (era == null) {
      continue;
    }
    for (final track in release.tracks.where(isPlayableRecording)) {
      (eraSongs[era] ??= {}).add(normalizeTitle(track.title));
    }
  }
  final releaseEras = {
    for (final release in ordered)
      release.id: byTitle[release.id] ?? _eraBySongs(release, eraSongs),
  };
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

String _eraBySongs(RawRelease release, Map<String, Set<String>> eraSongs) {
  final votes = <String, int>{};
  for (final track in release.tracks) {
    final song = normalizeTitle(track.title);
    for (final MapEntry(key: era, value: songs) in eraSongs.entries) {
      if (songs.contains(song)) {
        votes[era] = (votes[era] ?? 0) + 1;
      }
    }
  }
  return votes.entries
          .fold<MapEntry<String, int>?>(
            null,
            (best, next) =>
                best == null || next.value > best.value ? next : best,
          )
          ?.key ??
      singlesEra.key;
}

String _order(RawRelease release, int rank) =>
    '$rank:${release.releaseDate}:${release.id.toString().padLeft(12, '0')}';
