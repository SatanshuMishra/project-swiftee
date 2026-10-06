import 'package:collection/collection.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

final class Era {
  const Era({
    required this.key,
    required this.deezerAlbumId,
    required this.eraName,
    required this.subLabel,
    required this.placeholderArgb,
  });

  final String key;
  final int deezerAlbumId;
  final String eraName;
  final String subLabel;
  final int placeholderArgb;

  @override
  bool operator ==(Object other) =>
      other is Era &&
      other.key == key &&
      other.deezerAlbumId == deezerAlbumId &&
      other.eraName == eraName &&
      other.subLabel == subLabel &&
      other.placeholderArgb == placeholderArgb;

  @override
  int get hashCode =>
      Object.hash(key, deezerAlbumId, eraName, subLabel, placeholderArgb);

  @override
  String toString() =>
      'Era(key: $key, deezerAlbumId: $deezerAlbumId, eraName: $eraName, '
      'subLabel: $subLabel, placeholderArgb: $placeholderArgb)';
}

const List<Era> curatedEras = [
  Era(
    key: 'ts',
    deezerAlbumId: 321177137,
    eraName: 'Taylor Swift',
    subLabel: '2006',
    placeholderArgb: 0xFF3A6343,
  ),
  Era(
    key: 'fearless',
    deezerAlbumId: 221543452,
    eraName: 'Fearless',
    subLabel: "Taylor's Version",
    placeholderArgb: 0xFF6A5526,
  ),
  Era(
    key: 'speaknow',
    deezerAlbumId: 461146065,
    eraName: 'Speak Now',
    subLabel: "Taylor's Version",
    placeholderArgb: 0xFF694B70,
  ),
  Era(
    key: 'red',
    deezerAlbumId: 272247412,
    eraName: 'Red',
    subLabel: "Taylor's Version",
    placeholderArgb: 0xFF7B4844,
  ),
  Era(
    key: '1989',
    deezerAlbumId: 504180521,
    eraName: '1989',
    subLabel: "Taylor's Version",
    placeholderArgb: 0xFF285F78,
  ),
  Era(
    key: 'rep',
    deezerAlbumId: 52612062,
    eraName: 'reputation',
    subLabel: '2017',
    placeholderArgb: 0xFF45577F,
  ),
  Era(
    key: 'lover',
    deezerAlbumId: 108447472,
    eraName: 'Lover',
    subLabel: '2019',
    placeholderArgb: 0xFF76475D,
  ),
  Era(
    key: 'folklore',
    deezerAlbumId: 162683632,
    eraName: 'folklore',
    subLabel: '2020',
    placeholderArgb: 0xFF196467,
  ),
  Era(
    key: 'evermore',
    deezerAlbumId: 192580112,
    eraName: 'evermore',
    subLabel: '2020',
    placeholderArgb: 0xFF764D30,
  ),
  Era(
    key: 'midnights',
    deezerAlbumId: 368474187,
    eraName: 'Midnights',
    subLabel: '2022',
    placeholderArgb: 0xFF50537F,
  ),
  Era(
    key: 'ttpd',
    deezerAlbumId: 574109801,
    eraName: 'The Tortured Poets Department',
    subLabel: '2024',
    placeholderArgb: 0xFF715129,
  ),
  Era(
    key: 'showgirl',
    deezerAlbumId: 829966251,
    eraName: 'The Life of a Showgirl',
    subLabel: '2025',
    placeholderArgb: 0xFF794A3A,
  ),
];

int dayOfYear(DateTime moment) {
  final day = DateTime.utc(moment.year, moment.month, moment.day);
  final yearStart = DateTime.utc(moment.year);
  return day.difference(yearStart).inDays + 1;
}

const Era singlesEra = Era(
  key: 'singles',
  deezerAlbumId: 0,
  eraName: 'Singles & soundtracks',
  subLabel: 'Beyond the albums',
  placeholderArgb: 0xFF5C5450,
);

const List<Era> eraGroups = [...curatedEras, singlesEra];

Era? eraByKey(String key) =>
    eraGroups.firstWhereOrNull((era) => era.key == key);

Era tonightsEra(DateTime now) =>
    curatedEras[dayOfYear(now) % curatedEras.length];

Era? eraOfTrack(Track track) => switch (track.eraKey) {
  final key? => eraByKey(key),
  null => eraForAlbumId(track.album.id),
};

Era? eraForAlbumId(int albumId) =>
    curatedEras.firstWhereOrNull((era) => era.deezerAlbumId == albumId);
