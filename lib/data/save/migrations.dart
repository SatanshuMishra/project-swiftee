import 'package:swiftie_quiz/data/save/save_error.dart';

typedef SaveMigration = Map<String, Object?> Function(Map<String, Object?>);

const int currentSaveVersion = 4;

const Map<int, SaveMigration> _migrations = {
  1: _migrateV1ToV2,
  2: _migrateV2ToV3,
  3: _migrateV3ToV4,
};

int? declaredSaveVersion(Map<String, Object?> state) =>
    switch (state['version']) {
      final int version when version >= 0 => version,
      _ => null,
    };

Map<String, Object?> migrateToLatest(Map<String, Object?> state) =>
    _migrateFrom(declaredSaveVersion(state) ?? 1, state);

Map<String, Object?> _migrateFrom(int version, Map<String, Object?> state) {
  if (version >= currentSaveVersion) {
    return state;
  }
  final step = _migrations[version];
  if (step == null) {
    throw MissingMigrationError(version);
  }
  return _migrateFrom(version + 1, step(state));
}

Map<String, Object?> _migrateV1ToV2(Map<String, Object?> state) {
  final stats = switch (state['stats']) {
    final Map<String, Object?> object => object,
    _ => throw const SaveParseError('stats missing or not an object'),
  };
  return {
    ...state,
    'stats': {
      ...stats,
      for (final counter in const [
        'totalLyricsCorrect',
        'nameThaSongCorrect',
        'lyricsOrLieCorrect',
      ])
        if (!stats.containsKey(counter)) counter: 0,
    },
    'version': 2,
  };
}

Map<String, Object?> _migrateV2ToV3(Map<String, Object?> state) => {
  ...state,
  if (!state.containsKey('updater'))
    'updater': {
      'autoCheckEnabled': true,
      'lastCheckedAt': null,
      'skippedVersions': <Object?>[],
      'remindLaterUntil': null,
    },
  'version': 3,
};

Map<String, Object?> _migrateV3ToV4(Map<String, Object?> state) => {
  ...state,
  if (state['achievements'] case final Map<String, Object?> achievements)
    'achievements': {
      for (final MapEntry(:key, :value) in achievements.entries)
        key: switch (value) {
          final Map<String, Object?> record => {
            ...record,
            for (final field in const ['song', 'albumId', 'trackId'])
              if (!record.containsKey(field)) field: null,
          },
          _ => value,
        },
    },
  if (state['settings'] case final Map<String, Object?> settings)
    'settings': {
      ...settings,
      if (!settings.containsKey('misuVisits')) 'misuVisits': 'sometimes',
      if (!settings.containsKey('nickname')) 'nickname': null,
    },
  'version': 4,
};
