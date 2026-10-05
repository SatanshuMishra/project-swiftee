import 'package:swiftie_quiz/data/catalog/deezer_json.dart';

const int _minDurationSecs = 60;

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

bool isPlayableSong(DeezerTrack track) =>
    !_hasRemixVersion(track.titleVersion) &&
    track.track.duration >= _minDurationSecs &&
    !_hasNonSongKeyword(track.track.title);

bool _hasRemixVersion(String titleVersion) {
  final lower = titleVersion.toLowerCase();
  return lower.trim().isNotEmpty && _remixPatterns.any(lower.contains);
}

bool _hasNonSongKeyword(String title) {
  final lower = title.toLowerCase();
  return _nonSongPatterns.any(lower.contains);
}
