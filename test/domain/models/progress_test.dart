import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';

const Map<String, Object?> defaultProgressJson = {
  'version': 3,
  'achievements': <String, Object?>{},
  'stats': {
    'totalCorrect': 0,
    'albumsPlayed': <Object?>[],
    'tracksGuessedPerAlbum': <String, Object?>{},
    'totalLyricsCorrect': 0,
    'nameThaSongCorrect': 0,
    'lyricsOrLieCorrect': 0,
  },
  'settings': {
    'theme': 'dark',
    'volume': 0.8,
    'mediumTimer': 30,
    'hardTimer': 20,
  },
  'updater': {
    'autoCheckEnabled': true,
    'lastCheckedAt': null,
    'skippedVersions': <Object?>[],
    'remindLaterUntil': null,
  },
};

const String tauriDefaultSaveJson = '''
{
  "version": 3,
  "achievements": {},
  "stats": {
    "totalCorrect": 0,
    "albumsPlayed": [],
    "tracksGuessedPerAlbum": {},
    "totalLyricsCorrect": 0,
    "nameThaSongCorrect": 0,
    "lyricsOrLieCorrect": 0
  },
  "settings": {
    "theme": "dark",
    "volume": 0.8,
    "mediumTimer": 30,
    "hardTimer": 20
  },
  "updater": {
    "autoCheckEnabled": true,
    "lastCheckedAt": null,
    "skippedVersions": [],
    "remindLaterUntil": null
  }
}''';

const String tauriPopulatedSaveJson = '''
{
  "version": 3,
  "achievements": {
    "first_meow": {
      "unlocked": true,
      "unlockedAt": "2026-02-15T14:30:00Z"
    }
  },
  "stats": {
    "totalCorrect": 0,
    "albumsPlayed": [
      "12345"
    ],
    "tracksGuessedPerAlbum": {
      "12345": [
        "111",
        "222"
      ]
    },
    "totalLyricsCorrect": 0,
    "nameThaSongCorrect": 0,
    "lyricsOrLieCorrect": 0
  },
  "settings": {
    "theme": "light",
    "volume": 1.0,
    "mediumTimer": 30,
    "hardTimer": 20
  },
  "updater": {
    "autoCheckEnabled": true,
    "lastCheckedAt": null,
    "skippedVersions": [
      "0.2.3"
    ],
    "remindLaterUntil": null
  }
}''';

const Map<String, Object?> loadRsV1Save = {
  'version': 1,
  'achievements': <String, Object?>{},
  'stats': {
    'totalCorrect': 7,
    'albumsPlayed': <Object?>[],
    'tracksGuessedPerAlbum': <String, Object?>{},
  },
  'settings': {'theme': 'dark', 'volume': 0.8},
};

const String progressRsSpecFormatSave = '''
{
    "version": 1,
    "achievements": {
        "first_meow": {"unlocked": true, "unlockedAt": "2026-02-15T14:30:00Z"},
        "purrfect_streak": {"unlocked": false, "unlockedAt": null}
    },
    "stats": {
        "totalCorrect": 42,
        "albumsPlayed": ["album_1"],
        "tracksGuessedPerAlbum": {"album_1": ["track_1"]}
    },
    "settings": {
        "theme": "dark",
        "volume": 0.8
    }
}''';

const JsonEncoder prettyEncoder = JsonEncoder.withIndent('  ');

Map<String, Object?> decodeObject(String source) =>
    jsonDecode(source) as Map<String, Object?>;

Map<String, Object?> withEntry(
  Map<String, Object?> source,
  String key,
  Object? value,
) => {...source, key: value};

Map<String, Object?> withoutKey(Map<String, Object?> source, String key) => {
  for (final MapEntry(key: entryKey, :value) in source.entries)
    if (entryKey != key) entryKey: value,
};

Map<String, Object?> objectAt(Map<String, Object?> source, String key) =>
    source[key]! as Map<String, Object?>;

GameProgress populatedProgress() => const GameProgress(
  version: 3,
  achievements: {
    'first_meow': AchievementState(
      unlocked: true,
      unlockedAt: '2026-02-15T14:30:00Z',
    ),
    'purrfect_streak': AchievementState(unlocked: false, unlockedAt: null),
  },
  stats: GameStats(
    totalCorrect: 42,
    albumsPlayed: ['12345', '67890'],
    tracksGuessedPerAlbum: {
      '12345': ['111', '222'],
      '67890': ['333'],
    },
    totalLyricsCorrect: 9,
    nameThaSongCorrect: 5,
    lyricsOrLieCorrect: 4,
  ),
  settings: GameSettings(
    theme: ThemeSetting.light,
    volume: 0.35,
    mediumTimer: 25,
    hardTimer: 15,
  ),
  updater: UpdaterState(
    autoCheckEnabled: false,
    lastCheckedAt: '2026-10-05T08:00:00.000Z',
    skippedVersions: ['0.2.3', '0.2.4'],
    remindLaterUntil: '2026-10-06T08:00:00.000Z',
  ),
);

void main() {
  group('progress json matches the Tauri save format', () {
    test('toJson of defaultProgress equals the DEFAULT_PROGRESS json', () {
      expect(defaultProgress.toJson(), defaultProgressJson);
    });

    test('pretty-printed defaultProgress is byte-identical to Tauri', () {
      expect(
        prettyEncoder.convert(defaultProgress.toJson()),
        tauriDefaultSaveJson,
      );
    });

    test('pretty-printed populated progress is byte-identical to Tauri', () {
      final progress = defaultProgress.copyWith(
        achievements: {
          'first_meow': const AchievementState(
            unlocked: true,
            unlockedAt: '2026-02-15T14:30:00Z',
          ),
        },
        stats: defaultProgress.stats.copyWith(
          albumsPlayed: ['12345'],
          tracksGuessedPerAlbum: {
            '12345': ['111', '222'],
          },
        ),
        settings: defaultProgress.settings.copyWith(
          theme: ThemeSetting.light,
          volume: 1,
        ),
        updater: defaultProgress.updater.copyWith(skippedVersions: ['0.2.3']),
      );

      expect(prettyEncoder.convert(progress.toJson()), tauriPopulatedSaveJson);
      expect(
        GameProgress.fromJson(decodeObject(tauriPopulatedSaveJson)),
        progress,
      );
    });

    test('fromJson of the load.rs v1 save applies the serde defaults', () {
      final progress = GameProgress.fromJson(loadRsV1Save);

      expect(progress.version, 1);
      expect(progress.achievements, isEmpty);
      expect(progress.stats.totalCorrect, 7);
      expect(progress.stats.albumsPlayed, isEmpty);
      expect(progress.stats.tracksGuessedPerAlbum, isEmpty);
      expect(progress.stats.totalLyricsCorrect, 0);
      expect(progress.stats.nameThaSongCorrect, 0);
      expect(progress.stats.lyricsOrLieCorrect, 0);
      expect(progress.settings.theme, ThemeSetting.dark);
      expect(progress.settings.volume, 0.8);
      expect(progress.settings.mediumTimer, 30);
      expect(progress.settings.hardTimer, 20);
      expect(progress.updater.autoCheckEnabled, isTrue);
      expect(progress.updater.lastCheckedAt, isNull);
      expect(progress.updater.skippedVersions, isEmpty);
      expect(progress.updater.remindLaterUntil, isNull);
      expect(
        progress,
        defaultProgress.copyWith(
          version: 1,
          stats: defaultProgress.stats.copyWith(totalCorrect: 7),
        ),
      );
    });

    test('fromJson of a v2 save without updater uses the default updater', () {
      final v2Save = {
        'version': 2,
        'achievements': <String, Object?>{},
        'stats': {
          'totalCorrect': 12,
          'albumsPlayed': ['12345'],
          'tracksGuessedPerAlbum': {
            '12345': ['111'],
          },
          'totalLyricsCorrect': 3,
          'nameThaSongCorrect': 2,
          'lyricsOrLieCorrect': 1,
        },
        'settings': {
          'theme': 'system',
          'volume': 0.5,
          'mediumTimer': 35,
          'hardTimer': 15,
        },
      };

      final progress = GameProgress.fromJson(v2Save);

      expect(progress.version, 2);
      expect(progress.updater, defaultProgress.updater);
      expect(progress.stats.totalLyricsCorrect, 3);
      expect(progress.stats.nameThaSongCorrect, 2);
      expect(progress.stats.lyricsOrLieCorrect, 1);
      expect(progress.settings.theme, ThemeSetting.system);
      expect(progress.settings.mediumTimer, 35);
      expect(progress.settings.hardTimer, 15);
    });

    test('fromJson(toJson(x)) == x for a populated progress', () {
      final progress = populatedProgress();

      final direct = GameProgress.fromJson(progress.toJson());
      final throughText = GameProgress.fromJson(
        decodeObject(prettyEncoder.convert(progress.toJson())),
      );

      expect(direct, progress);
      expect(direct.hashCode, progress.hashCode);
      expect(throughText, progress);
      expect(throughText.toJson(), progress.toJson());
    });

    test('a round trip drops unknown keys and keeps only save.json keys', () {
      final source = populatedProgress().toJson();
      final stats = objectAt(source, 'stats');
      final settings = objectAt(source, 'settings');
      final updater = objectAt(source, 'updater');
      final achievements = objectAt(source, 'achievements');
      final withUnknowns = {
        ...source,
        'futureField': 'x',
        'stats': withEntry(stats, 'futureCounter', 1),
        'settings': withEntry(settings, 'futureSetting', true),
        'updater': withEntry(updater, 'futureFlag', false),
        'achievements': {
          for (final MapEntry(:key, :value) in achievements.entries)
            key: withEntry(value! as Map<String, Object?>, 'futureNote', 'y'),
        },
      };

      final output = GameProgress.fromJson(withUnknowns).toJson();

      expect(output, source);
      expect(output.keys, [
        'version',
        'achievements',
        'stats',
        'settings',
        'updater',
      ]);
      expect(objectAt(output, 'stats').keys, [
        'totalCorrect',
        'albumsPlayed',
        'tracksGuessedPerAlbum',
        'totalLyricsCorrect',
        'nameThaSongCorrect',
        'lyricsOrLieCorrect',
      ]);
      expect(objectAt(output, 'settings').keys, [
        'theme',
        'volume',
        'mediumTimer',
        'hardTimer',
      ]);
      expect(objectAt(output, 'updater').keys, [
        'autoCheckEnabled',
        'lastCheckedAt',
        'skippedVersions',
        'remindLaterUntil',
      ]);
      expect(objectAt(objectAt(output, 'achievements'), 'first_meow').keys, [
        'unlocked',
        'unlockedAt',
      ]);
    });

    test('an unknown theme string becomes dark', () {
      final save = withEntry(loadRsV1Save, 'settings', {
        'theme': 'sepia',
        'volume': 0.8,
      });

      expect(GameProgress.fromJson(save).settings.theme, ThemeSetting.dark);
    });

    test('an integer volume reads as a double and writes as 1.0', () {
      final save = withEntry(loadRsV1Save, 'settings', {
        'theme': 'dark',
        'volume': 1,
      });

      final progress = GameProgress.fromJson(save);

      expect(progress.settings.volume, 1.0);
      expect(jsonEncode(progress.settings.toJson()), contains('"volume":1.0'));
    });

    test('optional fields missing inside present objects read as null', () {
      final save = {
        ...loadRsV1Save,
        'version': 3,
        'achievements': {
          'first_meow': {'unlocked': true},
        },
        'updater': {'autoCheckEnabled': false, 'skippedVersions': <Object?>[]},
      };

      final progress = GameProgress.fromJson(save);

      expect(progress.achievements['first_meow']!.unlockedAt, isNull);
      expect(progress.updater.lastCheckedAt, isNull);
      expect(progress.updater.remindLaterUntil, isNull);
      expect(progress.updater.autoCheckEnabled, isFalse);
    });

    test('fields serde requires are rejected when missing or mistyped', () {
      final stats = objectAt(loadRsV1Save, 'stats');
      final invalidSaves = <String, Map<String, Object?>>{
        'missing stats': withoutKey(loadRsV1Save, 'stats'),
        'missing settings': withoutKey(loadRsV1Save, 'settings'),
        'missing achievements': withoutKey(loadRsV1Save, 'achievements'),
        'missing version': withoutKey(loadRsV1Save, 'version'),
        'missing totalCorrect': withEntry(
          loadRsV1Save,
          'stats',
          withoutKey(stats, 'totalCorrect'),
        ),
        'missing theme': withEntry(loadRsV1Save, 'settings', {'volume': 0.8}),
        'missing volume': withEntry(loadRsV1Save, 'settings', {
          'theme': 'dark',
        }),
        'null updater': withEntry(loadRsV1Save, 'updater', null),
        'updater without skippedVersions': withEntry(loadRsV1Save, 'updater', {
          'autoCheckEnabled': true,
        }),
        'float totalCorrect': withEntry(
          loadRsV1Save,
          'stats',
          withEntry(stats, 'totalCorrect', 7.0),
        ),
        'negative totalCorrect': withEntry(
          loadRsV1Save,
          'stats',
          withEntry(stats, 'totalCorrect', -1),
        ),
        'null totalLyricsCorrect': withEntry(
          loadRsV1Save,
          'stats',
          withEntry(stats, 'totalLyricsCorrect', null),
        ),
        'non-string album id': withEntry(
          loadRsV1Save,
          'stats',
          withEntry(stats, 'albumsPlayed', [12345]),
        ),
        'non-string theme': withEntry(loadRsV1Save, 'settings', {
          'theme': 3,
          'volume': 0.8,
        }),
        'achievement without unlocked': withEntry(
          loadRsV1Save,
          'achievements',
          {'first_meow': <String, Object?>{}},
        ),
      };

      for (final MapEntry(key: label, value: save) in invalidSaves.entries) {
        expect(
          () => GameProgress.fromJson(save),
          throwsFormatException,
          reason: label,
        );
      }
    });

    test('progress.rs test_default_progress', () {
      const progress = defaultProgress;

      expect(progress.version, 3);
      expect(progress.stats.totalCorrect, 0);
      expect(progress.stats.totalLyricsCorrect, 0);
      expect(progress.stats.nameThaSongCorrect, 0);
      expect(progress.stats.lyricsOrLieCorrect, 0);
      expect(progress.settings.theme, ThemeSetting.dark);
      expect(progress.settings.volume, closeTo(0.8, 1e-15));
      expect(progress.achievements, isEmpty);
    });

    test('progress.rs test_default_progress_includes_updater_state', () {
      const p = defaultProgress;

      expect(p.updater.autoCheckEnabled, isTrue);
      expect(p.updater.lastCheckedAt, isNull);
      expect(p.updater.skippedVersions, isEmpty);
      expect(p.updater.remindLaterUntil, isNull);
    });

    test('progress.rs test_updater_state_serializes_with_camel_case', () {
      final json = defaultProgress.toJson();
      final updater = objectAt(json, 'updater');

      expect(updater.containsKey('autoCheckEnabled'), isTrue);
      expect(updater.containsKey('lastCheckedAt'), isTrue);
      expect(updater.containsKey('skippedVersions'), isTrue);
      expect(updater.containsKey('remindLaterUntil'), isTrue);
    });

    test('progress.rs test_progress_serde_round_trip', () {
      final progress = defaultProgress.copyWith(
        stats: defaultProgress.stats.copyWith(
          totalCorrect: 42,
          albumsPlayed: ['12345'],
          tracksGuessedPerAlbum: {
            '12345': ['111', '222'],
          },
        ),
        achievements: {
          'first_meow': const AchievementState(
            unlocked: true,
            unlockedAt: '2026-02-15T14:30:00Z',
          ),
        },
      );

      final json = jsonEncode(progress.toJson());
      final deserialized = GameProgress.fromJson(decodeObject(json));

      expect(deserialized.stats.totalCorrect, 42);
      expect(deserialized.achievements['first_meow']!.unlocked, isTrue);
      expect(deserialized.stats.albumsPlayed, ['12345']);
      expect(deserialized.stats.tracksGuessedPerAlbum['12345'], ['111', '222']);
    });

    test('progress.rs test_progress_deserializes_from_spec_format', () {
      final progress = GameProgress.fromJson(
        decodeObject(progressRsSpecFormatSave),
      );

      expect(progress.version, 1);
      expect(progress.stats.totalCorrect, 42);
      expect(progress.achievements['first_meow']!.unlocked, isTrue);
      expect(progress.achievements['purrfect_streak']!.unlocked, isFalse);
    });

    test('progress.rs test_persistence_round_trip_with_tempfile', () {
      const progress = defaultProgress;
      final dir = Directory.systemTemp.createTempSync('progress_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = p.join(dir.path, 'save.json');

      File(path).writeAsStringSync(prettyEncoder.convert(progress.toJson()));

      final contents = File(path).readAsStringSync();
      final loaded = GameProgress.fromJson(decodeObject(contents));
      expect(loaded.version, progress.version);
      expect(loaded.settings.theme, progress.settings.theme);
    });

    test('progress.rs test_default_includes_timer_fields', () {
      const progress = defaultProgress;

      expect(progress.settings.mediumTimer, 30);
      expect(progress.settings.hardTimer, 20);
    });

    test('progress.rs test_settings_serde_round_trip_preserves_timers', () {
      final json = jsonEncode(defaultProgress.toJson());
      final back = GameProgress.fromJson(decodeObject(json));

      expect(back.settings.mediumTimer, 30);
      expect(back.settings.hardTimer, 20);
    });

    test('every enum value round trips through its wire name', () {
      final enumRoundTrips = <String, List<(Object, Object?)>>{
        'GamePhase': [
          for (final value in GamePhase.values)
            (value, GamePhase.fromWireName(value.wireName)),
        ],
        'GameMode': [
          for (final value in GameMode.values)
            (value, GameMode.fromWireName(value.wireName)),
        ],
        'QuizType': [
          for (final value in QuizType.values)
            (value, QuizType.fromWireName(value.wireName)),
        ],
        'LyricsMode': [
          for (final value in LyricsMode.values)
            (value, LyricsMode.fromWireName(value.wireName)),
        ],
        'Difficulty': [
          for (final value in Difficulty.values)
            (value, Difficulty.fromWireName(value.wireName)),
        ],
        'ThemeSetting': [
          for (final value in ThemeSetting.values)
            (value, ThemeSetting.fromWireName(value.wireName)),
        ],
      };

      for (final MapEntry(key: name, value: pairs) in enumRoundTrips.entries) {
        for (final (original, parsed) in pairs) {
          expect(parsed, original, reason: '$name.$original');
        }
      }
    });

    test('wire names match the TypeScript string unions', () {
      expect(GamePhase.values.map((value) => value.wireName), [
        'nickname',
        'menu',
        'album-select',
        'setup',
        'lyrics-loading',
        'playing',
        'round-summary',
        'record-shelf',
        'settings',
      ]);
      expect(GameMode.values.map((value) => value.wireName), [
        'random',
        'album',
        'tonight',
      ]);
      expect(QuizType.values.map((value) => value.wireName), [
        'sound',
        'lyrics',
      ]);
      expect(LyricsMode.values.map((value) => value.wireName), [
        'name-that-song',
        'lyrics-or-lie',
      ]);
      expect(Difficulty.values.map((value) => value.wireName), [
        'easy',
        'medium',
        'hard',
      ]);
      expect(ThemeSetting.values.map((value) => value.wireName), [
        'dark',
        'light',
        'system',
      ]);
    });

    test('unknown wire names give null', () {
      for (final unknown in ['', 'Menu', 'albumSelect', 'album_select', ' ']) {
        expect(GamePhase.fromWireName(unknown), isNull, reason: unknown);
        expect(GameMode.fromWireName(unknown), isNull, reason: unknown);
        expect(QuizType.fromWireName(unknown), isNull, reason: unknown);
        expect(LyricsMode.fromWireName(unknown), isNull, reason: unknown);
        expect(Difficulty.fromWireName(unknown), isNull, reason: unknown);
        expect(ThemeSetting.fromWireName(unknown), isNull, reason: unknown);
      }
      expect(LyricsMode.fromWireName('nameThatSong'), isNull);
      expect(ThemeSetting.fromWireName('Dark'), isNull);
    });
  });

  group('progress models are immutable values', () {
    test('collections read from json cannot be modified', () {
      final progress = GameProgress.fromJson(populatedProgress().toJson());

      expect(
        () => progress.stats.albumsPlayed.add('1'),
        throwsUnsupportedError,
      );
      expect(
        () => progress.stats.tracksGuessedPerAlbum['12345']!.add('1'),
        throwsUnsupportedError,
      );
      expect(
        () => progress.stats.tracksGuessedPerAlbum['1'] = const [],
        throwsUnsupportedError,
      );
      expect(
        () => progress.achievements['x'] = const AchievementState(
          unlocked: false,
          unlockedAt: null,
        ),
        throwsUnsupportedError,
      );
      expect(
        () => progress.updater.skippedVersions.add('1'),
        throwsUnsupportedError,
      );
    });

    test('collections passed as growable lists are exposed unmodifiable', () {
      final albums = List<String>.of(const ['12345']);
      final tracks = List<String>.of(const ['111']);
      final stats = defaultProgress.stats.copyWith(
        albumsPlayed: albums,
        tracksGuessedPerAlbum: {'12345': tracks},
      );
      final constructed = GameStats(
        totalCorrect: 0,
        albumsPlayed: albums,
        tracksGuessedPerAlbum: {'12345': tracks},
        totalLyricsCorrect: 0,
        nameThaSongCorrect: 0,
        lyricsOrLieCorrect: 0,
      );

      albums.add('67890');
      tracks.add('222');

      expect(stats.albumsPlayed, ['12345']);
      expect(stats.tracksGuessedPerAlbum['12345'], ['111']);
      expect(() => constructed.albumsPlayed.add('1'), throwsUnsupportedError);
      expect(
        () => constructed.tracksGuessedPerAlbum['12345']!.add('1'),
        throwsUnsupportedError,
      );
    });

    test('toJson returns collections independent of the model', () {
      final progress = populatedProgress();
      final json = progress.toJson();

      (objectAt(json, 'stats')['albumsPlayed']! as List<Object?>).add('x');

      expect(progress.stats.albumsPlayed, ['12345', '67890']);
    });

    test('copyWith clears nullable fields only when given null', () {
      final updater = populatedProgress().updater;

      expect(updater.copyWith().lastCheckedAt, '2026-10-05T08:00:00.000Z');
      expect(updater.copyWith(lastCheckedAt: null).lastCheckedAt, isNull);
      expect(updater.copyWith(remindLaterUntil: null).remindLaterUntil, isNull);
      expect(
        updater.copyWith(remindLaterUntil: null).lastCheckedAt,
        '2026-10-05T08:00:00.000Z',
      );
      expect(
        const AchievementState(
          unlocked: true,
          unlockedAt: '2026-02-15T14:30:00Z',
        ).copyWith(unlockedAt: null).unlockedAt,
        isNull,
      );
    });

    test('equal content gives equal values and hash codes', () {
      final a = populatedProgress();
      final b = GameProgress.fromJson(decodeObject(jsonEncode(a.toJson())));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == a.copyWith(version: 2), isFalse);
      expect(
        a ==
            a.copyWith(
              stats: a.stats.copyWith(albumsPlayed: ['67890', '12345']),
            ),
        isFalse,
      );
      expect(
        a ==
            a.copyWith(updater: a.updater.copyWith(skippedVersions: ['0.2.3'])),
        isFalse,
      );
    });
  });
}
