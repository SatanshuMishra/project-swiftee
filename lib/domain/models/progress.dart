import 'package:collection/collection.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';

const Object _unchanged = Object();

const int _defaultMediumTimer = 30;
const int _defaultHardTimer = 20;

const GameProgress defaultProgress = GameProgress(
  version: 4,
  achievements: {},
  stats: GameStats(
    totalCorrect: 0,
    albumsPlayed: [],
    tracksGuessedPerAlbum: {},
    totalLyricsCorrect: 0,
    nameThaSongCorrect: 0,
    lyricsOrLieCorrect: 0,
  ),
  settings: GameSettings(
    theme: ThemeSetting.dark,
    volume: 0.8,
    mediumTimer: _defaultMediumTimer,
    hardTimer: _defaultHardTimer,
    misuVisits: MisuVisits.sometimes,
    nickname: null,
  ),
  updater: UpdaterState(
    autoCheckEnabled: true,
    lastCheckedAt: null,
    skippedVersions: [],
    remindLaterUntil: null,
  ),
);

enum MisuVisits {
  often('often'),
  sometimes('sometimes'),
  off('off');

  const MisuVisits(this.wireName);

  final String wireName;

  static MisuVisits? fromWireName(String wireName) =>
      values.firstWhereOrNull((value) => value.wireName == wireName);
}

final class AchievementState {
  const AchievementState({
    required this.unlocked,
    required this.unlockedAt,
    this.song,
    this.albumId,
    this.trackId,
  });

  factory AchievementState.fromJson(Map<String, Object?> json) =>
      AchievementState(
        unlocked: _readBool(json, 'unlocked'),
        unlockedAt: _readOptionalString(json, 'unlockedAt'),
        song: _readOptionalString(json, 'song'),
        albumId: _readOptionalString(json, 'albumId'),
        trackId: _readOptionalString(json, 'trackId'),
      );

  final bool unlocked;
  final String? unlockedAt;
  final String? song;
  final String? albumId;
  final String? trackId;

  Map<String, Object?> toJson() => {
    'unlocked': unlocked,
    'unlockedAt': unlockedAt,
    'song': song,
    'albumId': albumId,
    'trackId': trackId,
  };

  AchievementState copyWith({
    bool? unlocked,
    Object? unlockedAt = _unchanged,
    Object? song = _unchanged,
    Object? albumId = _unchanged,
    Object? trackId = _unchanged,
  }) => AchievementState(
    unlocked: unlocked ?? this.unlocked,
    unlockedAt: identical(unlockedAt, _unchanged)
        ? this.unlockedAt
        : unlockedAt as String?,
    song: identical(song, _unchanged) ? this.song : song as String?,
    albumId: identical(albumId, _unchanged) ? this.albumId : albumId as String?,
    trackId: identical(trackId, _unchanged) ? this.trackId : trackId as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is AchievementState &&
      other.unlocked == unlocked &&
      other.unlockedAt == unlockedAt &&
      other.song == song &&
      other.albumId == albumId &&
      other.trackId == trackId;

  @override
  int get hashCode => Object.hash(unlocked, unlockedAt, song, albumId, trackId);

  @override
  String toString() =>
      'AchievementState(unlocked: $unlocked, unlockedAt: $unlockedAt, '
      'song: $song, albumId: $albumId, trackId: $trackId)';
}

final class GameStats {
  const GameStats({
    required this.totalCorrect,
    required this._albumsPlayed,
    required this._tracksGuessedPerAlbum,
    required this.totalLyricsCorrect,
    required this.nameThaSongCorrect,
    required this.lyricsOrLieCorrect,
  });

  factory GameStats.fromJson(Map<String, Object?> json) => GameStats(
    totalCorrect: _readCount(json, 'totalCorrect'),
    albumsPlayed: _readStringList(json, 'albumsPlayed'),
    tracksGuessedPerAlbum: _readStringListMap(json, 'tracksGuessedPerAlbum'),
    totalLyricsCorrect: _readCountOr(json, 'totalLyricsCorrect', 0),
    nameThaSongCorrect: _readCountOr(json, 'nameThaSongCorrect', 0),
    lyricsOrLieCorrect: _readCountOr(json, 'lyricsOrLieCorrect', 0),
  );

  final int totalCorrect;
  final List<String> _albumsPlayed;
  final Map<String, List<String>> _tracksGuessedPerAlbum;
  final int totalLyricsCorrect;
  final int nameThaSongCorrect;
  final int lyricsOrLieCorrect;

  List<String> get albumsPlayed => UnmodifiableListView(_albumsPlayed);

  Map<String, List<String>> get tracksGuessedPerAlbum => UnmodifiableMapView({
    for (final MapEntry(:key, :value) in _tracksGuessedPerAlbum.entries)
      key: UnmodifiableListView(value),
  });

  Map<String, Object?> toJson() => {
    'totalCorrect': totalCorrect,
    'albumsPlayed': [..._albumsPlayed],
    'tracksGuessedPerAlbum': {
      for (final MapEntry(:key, :value) in _tracksGuessedPerAlbum.entries)
        key: [...value],
    },
    'totalLyricsCorrect': totalLyricsCorrect,
    'nameThaSongCorrect': nameThaSongCorrect,
    'lyricsOrLieCorrect': lyricsOrLieCorrect,
  };

  GameStats copyWith({
    int? totalCorrect,
    List<String>? albumsPlayed,
    Map<String, List<String>>? tracksGuessedPerAlbum,
    int? totalLyricsCorrect,
    int? nameThaSongCorrect,
    int? lyricsOrLieCorrect,
  }) => GameStats(
    totalCorrect: totalCorrect ?? this.totalCorrect,
    albumsPlayed: albumsPlayed == null
        ? _albumsPlayed
        : List<String>.unmodifiable(albumsPlayed),
    tracksGuessedPerAlbum: tracksGuessedPerAlbum == null
        ? _tracksGuessedPerAlbum
        : _freezeStringListMap(tracksGuessedPerAlbum),
    totalLyricsCorrect: totalLyricsCorrect ?? this.totalLyricsCorrect,
    nameThaSongCorrect: nameThaSongCorrect ?? this.nameThaSongCorrect,
    lyricsOrLieCorrect: lyricsOrLieCorrect ?? this.lyricsOrLieCorrect,
  );

  @override
  bool operator ==(Object other) =>
      other is GameStats &&
      other.totalCorrect == totalCorrect &&
      const ListEquality<String>().equals(other._albumsPlayed, _albumsPlayed) &&
      _stringListMapEquality.equals(
        other._tracksGuessedPerAlbum,
        _tracksGuessedPerAlbum,
      ) &&
      other.totalLyricsCorrect == totalLyricsCorrect &&
      other.nameThaSongCorrect == nameThaSongCorrect &&
      other.lyricsOrLieCorrect == lyricsOrLieCorrect;

  @override
  int get hashCode => Object.hash(
    totalCorrect,
    const ListEquality<String>().hash(_albumsPlayed),
    _stringListMapEquality.hash(_tracksGuessedPerAlbum),
    totalLyricsCorrect,
    nameThaSongCorrect,
    lyricsOrLieCorrect,
  );

  @override
  String toString() =>
      'GameStats(totalCorrect: $totalCorrect, albumsPlayed: $_albumsPlayed, '
      'tracksGuessedPerAlbum: $_tracksGuessedPerAlbum, '
      'totalLyricsCorrect: $totalLyricsCorrect, '
      'nameThaSongCorrect: $nameThaSongCorrect, '
      'lyricsOrLieCorrect: $lyricsOrLieCorrect)';
}

final class GameSettings {
  const GameSettings({
    required this.theme,
    required this.volume,
    required this.mediumTimer,
    required this.hardTimer,
    this.misuVisits = MisuVisits.sometimes,
    this.nickname,
  });

  factory GameSettings.fromJson(Map<String, Object?> json) => GameSettings(
    theme:
        ThemeSetting.fromWireName(_readString(json, 'theme')) ??
        ThemeSetting.dark,
    volume: _readNumber(json, 'volume'),
    mediumTimer: _readCountOr(json, 'mediumTimer', _defaultMediumTimer),
    hardTimer: _readCountOr(json, 'hardTimer', _defaultHardTimer),
    misuVisits: switch (_readOptionalString(json, 'misuVisits')) {
      final String wireName =>
        MisuVisits.fromWireName(wireName) ?? MisuVisits.sometimes,
      null => MisuVisits.sometimes,
    },
    nickname: _readOptionalString(json, 'nickname'),
  );

  final ThemeSetting theme;
  final double volume;
  final int mediumTimer;
  final int hardTimer;
  final MisuVisits misuVisits;
  final String? nickname;

  Map<String, Object?> toJson() => {
    'theme': theme.wireName,
    'volume': volume,
    'mediumTimer': mediumTimer,
    'hardTimer': hardTimer,
    'misuVisits': misuVisits.wireName,
    'nickname': nickname,
  };

  GameSettings copyWith({
    ThemeSetting? theme,
    double? volume,
    int? mediumTimer,
    int? hardTimer,
    MisuVisits? misuVisits,
    Object? nickname = _unchanged,
  }) => GameSettings(
    theme: theme ?? this.theme,
    volume: volume ?? this.volume,
    mediumTimer: mediumTimer ?? this.mediumTimer,
    hardTimer: hardTimer ?? this.hardTimer,
    misuVisits: misuVisits ?? this.misuVisits,
    nickname: identical(nickname, _unchanged)
        ? this.nickname
        : nickname as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is GameSettings &&
      other.theme == theme &&
      other.volume == volume &&
      other.mediumTimer == mediumTimer &&
      other.hardTimer == hardTimer &&
      other.misuVisits == misuVisits &&
      other.nickname == nickname;

  @override
  int get hashCode =>
      Object.hash(theme, volume, mediumTimer, hardTimer, misuVisits, nickname);

  @override
  String toString() =>
      'GameSettings(theme: $theme, volume: $volume, '
      'mediumTimer: $mediumTimer, hardTimer: $hardTimer, '
      'misuVisits: $misuVisits, nickname: $nickname)';
}

final class UpdaterState {
  const UpdaterState({
    required this.autoCheckEnabled,
    required this.lastCheckedAt,
    required this._skippedVersions,
    required this.remindLaterUntil,
  });

  factory UpdaterState.fromJson(Map<String, Object?> json) => UpdaterState(
    autoCheckEnabled: _readBool(json, 'autoCheckEnabled'),
    lastCheckedAt: _readOptionalString(json, 'lastCheckedAt'),
    skippedVersions: _readStringList(json, 'skippedVersions'),
    remindLaterUntil: _readOptionalString(json, 'remindLaterUntil'),
  );

  final bool autoCheckEnabled;
  final String? lastCheckedAt;
  final List<String> _skippedVersions;
  final String? remindLaterUntil;

  List<String> get skippedVersions => UnmodifiableListView(_skippedVersions);

  Map<String, Object?> toJson() => {
    'autoCheckEnabled': autoCheckEnabled,
    'lastCheckedAt': lastCheckedAt,
    'skippedVersions': [..._skippedVersions],
    'remindLaterUntil': remindLaterUntil,
  };

  UpdaterState copyWith({
    bool? autoCheckEnabled,
    Object? lastCheckedAt = _unchanged,
    List<String>? skippedVersions,
    Object? remindLaterUntil = _unchanged,
  }) => UpdaterState(
    autoCheckEnabled: autoCheckEnabled ?? this.autoCheckEnabled,
    lastCheckedAt: identical(lastCheckedAt, _unchanged)
        ? this.lastCheckedAt
        : lastCheckedAt as String?,
    skippedVersions: skippedVersions == null
        ? _skippedVersions
        : List<String>.unmodifiable(skippedVersions),
    remindLaterUntil: identical(remindLaterUntil, _unchanged)
        ? this.remindLaterUntil
        : remindLaterUntil as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is UpdaterState &&
      other.autoCheckEnabled == autoCheckEnabled &&
      other.lastCheckedAt == lastCheckedAt &&
      const ListEquality<String>().equals(
        other._skippedVersions,
        _skippedVersions,
      ) &&
      other.remindLaterUntil == remindLaterUntil;

  @override
  int get hashCode => Object.hash(
    autoCheckEnabled,
    lastCheckedAt,
    const ListEquality<String>().hash(_skippedVersions),
    remindLaterUntil,
  );

  @override
  String toString() =>
      'UpdaterState(autoCheckEnabled: $autoCheckEnabled, '
      'lastCheckedAt: $lastCheckedAt, skippedVersions: $_skippedVersions, '
      'remindLaterUntil: $remindLaterUntil)';
}

final class GameProgress {
  const GameProgress({
    required this.version,
    required this._achievements,
    required this.stats,
    required this.settings,
    required this.updater,
  });

  factory GameProgress.fromJson(Map<String, Object?> json) => GameProgress(
    version: _readCount(json, 'version'),
    achievements: _readAchievements(json, 'achievements'),
    stats: GameStats.fromJson(_readObject(json, 'stats')),
    settings: GameSettings.fromJson(_readObject(json, 'settings')),
    updater: json.containsKey('updater')
        ? UpdaterState.fromJson(_readObject(json, 'updater'))
        : defaultProgress.updater,
  );

  final int version;
  final Map<String, AchievementState> _achievements;
  final GameStats stats;
  final GameSettings settings;
  final UpdaterState updater;

  Map<String, AchievementState> get achievements =>
      UnmodifiableMapView(_achievements);

  Map<String, Object?> toJson() => {
    'version': version,
    'achievements': {
      for (final MapEntry(:key, :value) in _achievements.entries)
        key: value.toJson(),
    },
    'stats': stats.toJson(),
    'settings': settings.toJson(),
    'updater': updater.toJson(),
  };

  GameProgress copyWith({
    int? version,
    Map<String, AchievementState>? achievements,
    GameStats? stats,
    GameSettings? settings,
    UpdaterState? updater,
  }) => GameProgress(
    version: version ?? this.version,
    achievements: achievements == null
        ? _achievements
        : Map<String, AchievementState>.unmodifiable(achievements),
    stats: stats ?? this.stats,
    settings: settings ?? this.settings,
    updater: updater ?? this.updater,
  );

  @override
  bool operator ==(Object other) =>
      other is GameProgress &&
      other.version == version &&
      const MapEquality<String, AchievementState>().equals(
        other._achievements,
        _achievements,
      ) &&
      other.stats == stats &&
      other.settings == settings &&
      other.updater == updater;

  @override
  int get hashCode => Object.hash(
    version,
    const MapEquality<String, AchievementState>().hash(_achievements),
    stats,
    settings,
    updater,
  );

  @override
  String toString() =>
      'GameProgress(version: $version, achievements: $_achievements, '
      'stats: $stats, settings: $settings, updater: $updater)';
}

const MapEquality<String, List<String>> _stringListMapEquality = MapEquality(
  values: ListEquality<String>(),
);

Map<String, List<String>> _freezeStringListMap(
  Map<String, List<String>> source,
) => Map<String, List<String>>.unmodifiable({
  for (final MapEntry(:key, :value) in source.entries)
    key: List<String>.unmodifiable(value),
});

FormatException _missingField(String key) =>
    FormatException('missing field "$key"');

FormatException _invalidType(String key, String expected) =>
    FormatException('invalid type for "$key", expected $expected');

Object? _readPresent(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    throw _missingField(key);
  }
  return json[key];
}

bool _readBool(Map<String, Object?> json, String key) =>
    switch (_readPresent(json, key)) {
      final bool value => value,
      _ => throw _invalidType(key, 'a boolean'),
    };

int _readCount(Map<String, Object?> json, String key) =>
    switch (_readPresent(json, key)) {
      final int value when value >= 0 => value,
      _ => throw _invalidType(key, 'a non-negative integer'),
    };

int _readCountOr(Map<String, Object?> json, String key, int fallback) =>
    json.containsKey(key) ? _readCount(json, key) : fallback;

double _readNumber(Map<String, Object?> json, String key) =>
    switch (_readPresent(json, key)) {
      final num value => value.toDouble(),
      _ => throw _invalidType(key, 'a number'),
    };

String _readString(Map<String, Object?> json, String key) =>
    switch (_readPresent(json, key)) {
      final String value => value,
      _ => throw _invalidType(key, 'a string'),
    };

String? _readOptionalString(Map<String, Object?> json, String key) =>
    switch (json[key]) {
      null => null,
      final String value => value,
      _ => throw _invalidType(key, 'a string or null'),
    };

Map<String, Object?> _asObject(Object? value, String key) => switch (value) {
  final Map<String, Object?> object => object,
  _ => throw _invalidType(key, 'an object'),
};

Map<String, Object?> _readObject(Map<String, Object?> json, String key) =>
    _asObject(_readPresent(json, key), key);

List<String> _asStringList(Object? value, String key) => switch (value) {
  final List<Object?> items => List<String>.unmodifiable([
    for (final item in items)
      item is String ? item : throw _invalidType(key, 'a list of strings'),
  ]),
  _ => throw _invalidType(key, 'a list of strings'),
};

List<String> _readStringList(Map<String, Object?> json, String key) =>
    _asStringList(_readPresent(json, key), key);

Map<String, List<String>> _readStringListMap(
  Map<String, Object?> json,
  String key,
) => Map<String, List<String>>.unmodifiable({
  for (final MapEntry(key: entryKey, :value) in _readObject(json, key).entries)
    entryKey: _asStringList(value, '$key.$entryKey'),
});

Map<String, AchievementState> _readAchievements(
  Map<String, Object?> json,
  String key,
) => Map<String, AchievementState>.unmodifiable({
  for (final MapEntry(key: entryKey, :value) in _readObject(json, key).entries)
    entryKey: AchievementState.fromJson(_asObject(value, '$key.$entryKey')),
});
