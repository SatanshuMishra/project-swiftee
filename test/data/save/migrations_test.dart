import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/save/migrations.dart';
import 'package:swiftie_quiz/data/save/save_error.dart';

Map<String, Object?> v1Save() => {
  'version': 1,
  'achievements': <String, Object?>{},
  'stats': {
    'totalCorrect': 5,
    'albumsPlayed': <Object?>[],
    'tracksGuessedPerAlbum': <String, Object?>{},
  },
  'settings': {'theme': 'dark', 'volume': 0.8},
};

Map<String, Object?> v2Stats() => {
  'totalCorrect': 0,
  'albumsPlayed': <Object?>[],
  'tracksGuessedPerAlbum': <String, Object?>{},
  'totalLyricsCorrect': 0,
  'nameThaSongCorrect': 0,
  'lyricsOrLieCorrect': 0,
};

Map<String, Object?> v2Settings() => {
  'theme': 'dark',
  'volume': 0.8,
  'mediumTimer': 30,
  'hardTimer': 20,
};

Map<String, Object?> v3Save() => {
  'version': 3,
  'achievements': {
    'first_meow': {'unlocked': true, 'unlockedAt': '2026-02-15T14:30:00Z'},
    'purrfect_streak': {'unlocked': false, 'unlockedAt': null},
  },
  'stats': {
    'totalCorrect': 42,
    'albumsPlayed': ['12345', '67890'],
    'tracksGuessedPerAlbum': {
      '12345': ['111', '222'],
      '67890': ['333'],
    },
    'totalLyricsCorrect': 9,
    'nameThaSongCorrect': 5,
    'lyricsOrLieCorrect': 4,
  },
  'settings': {
    'theme': 'light',
    'volume': 0.35,
    'mediumTimer': 25,
    'hardTimer': 15,
  },
  'updater': {
    'autoCheckEnabled': false,
    'lastCheckedAt': '2026-10-05T08:00:00.000Z',
    'skippedVersions': ['0.2.3', '0.2.4'],
    'remindLaterUntil': '2026-10-06T08:00:00.000Z',
  },
};

Map<String, Object?> currentSave() => {
  'version': 5,
  'achievements': {
    'first_meow': {
      'unlocked': true,
      'unlockedAt': '2026-02-15T14:30:00Z',
      'song': 'Tim McGraw',
      'albumId': '12345',
      'trackId': '111',
    },
  },
  'stats': {
    'totalCorrect': 5,
    'albumsPlayed': <Object?>[],
    'tracksGuessedPerAlbum': <String, Object?>{},
    'totalLyricsCorrect': 0,
    'nameThaSongCorrect': 0,
    'lyricsOrLieCorrect': 0,
  },
  'settings': {
    'theme': 'dark',
    'volume': 0.8,
    'misuVisits': 'often',
    'nickname': 'Sam',
    'togetherLink': null,
  },
  'updater': {
    'autoCheckEnabled': true,
    'lastCheckedAt': null,
    'skippedVersions': <Object?>[],
    'remindLaterUntil': null,
  },
};

void main() {
  group('migrations parity', () {
    test('current save version is 5', () {
      expect(currentSaveVersion, 5);
    });

    test('migrates v1 to current', () {
      final input = v1Save();
      final result = migrateToLatest(input);
      expect(result['version'], currentSaveVersion);
      expect(result['stats'], containsPair('totalLyricsCorrect', 0));
      expect(result['stats'], containsPair('nameThaSongCorrect', 0));
      expect(result['stats'], containsPair('lyricsOrLieCorrect', 0));
      expect(result['stats'], containsPair('totalCorrect', 5));
      expect(input, equals(v1Save()));
    });

    test('no-op when already current', () {
      expect(migrateToLatest(currentSave()), equals(currentSave()));
    });

    test('migrate v2 to v3 adds the updater field', () {
      final result = migrateToLatest({
        'version': 2,
        'achievements': <String, Object?>{},
        'stats': v2Stats(),
        'settings': v2Settings(),
      });
      expect(result['version'], 5);
      expect(
        result['updater'],
        equals({
          'autoCheckEnabled': true,
          'lastCheckedAt': null,
          'skippedVersions': <Object?>[],
          'remindLaterUntil': null,
        }),
      );
    });

    test('migrate v1 through v5 chain', () {
      final result = migrateToLatest({
        'version': 1,
        'achievements': <String, Object?>{},
        'stats': {
          'totalCorrect': 99,
          'albumsPlayed': <Object?>[],
          'tracksGuessedPerAlbum': <String, Object?>{},
        },
        'settings': v2Settings(),
      });
      expect(result['version'], 5);
      expect(result['stats'], containsPair('totalCorrect', 99));
      expect(result['stats'], containsPair('totalLyricsCorrect', 0));
      expect(result['updater'], containsPair('autoCheckEnabled', true));
      expect(result['settings'], containsPair('misuVisits', 'sometimes'));
      expect(result['settings'], containsPair('nickname', null));
      expect(result['settings'], containsPair('togetherLink', null));
    });

    test('migrate v2 to v3 preserves an existing updater field', () {
      final result = migrateToLatest({
        'version': 2,
        'achievements': <String, Object?>{},
        'stats': v2Stats(),
        'settings': v2Settings(),
        'updater': {
          'autoCheckEnabled': false,
          'lastCheckedAt': '2026-01-01T00:00:00Z',
          'skippedVersions': ['0.3.0'],
          'remindLaterUntil': null,
        },
      });
      expect(result['updater'], containsPair('autoCheckEnabled', false));
      expect(result['updater'], containsPair('skippedVersions', ['0.3.0']));
    });

    test('a version 3 save migrates to version 5 unchanged', () {
      final input = v3Save();

      final result = migrateToLatest(input);

      expect(result, {
        'version': 5,
        'achievements': {
          'first_meow': {
            'unlocked': true,
            'unlockedAt': '2026-02-15T14:30:00Z',
            'song': null,
            'albumId': null,
            'trackId': null,
          },
          'purrfect_streak': {
            'unlocked': false,
            'unlockedAt': null,
            'song': null,
            'albumId': null,
            'trackId': null,
          },
        },
        'stats': v3Save()['stats'],
        'settings': {
          'theme': 'light',
          'volume': 0.35,
          'mediumTimer': 25,
          'hardTimer': 15,
          'misuVisits': 'sometimes',
          'nickname': null,
          'togetherLink': null,
        },
        'updater': v3Save()['updater'],
      });
      expect(input, equals(v3Save()));
    });

    test('migrate v3 to v4 keeps values a v3 save already carries', () {
      final result = migrateToLatest({
        ...v3Save(),
        'achievements': {
          'first_meow': {
            'unlocked': true,
            'unlockedAt': null,
            'song': 'Tim McGraw',
          },
        },
        'settings': {...v2Settings(), 'misuVisits': 'off', 'nickname': 'Sam'},
      });

      expect(result['achievements'], {
        'first_meow': {
          'unlocked': true,
          'unlockedAt': null,
          'song': 'Tim McGraw',
          'albumId': null,
          'trackId': null,
        },
      });
      expect(result['settings'], containsPair('misuVisits', 'off'));
      expect(result['settings'], containsPair('nickname', 'Sam'));
    });

    test('migrate v3 to v4 leaves malformed parts for the parser', () {
      final result = migrateToLatest({
        ...v3Save(),
        'achievements': {'first_meow': true},
        'settings': 'dark',
      });

      expect(result['version'], 5);
      expect(result['achievements'], {'first_meow': true});
      expect(result['settings'], 'dark');
    });

    test('idempotent double run', () {
      final once = migrateToLatest(v1Save());
      expect(migrateToLatest(once), equals(once));
    });

    test('missing version treated as v1', () {
      final result = migrateToLatest({...v1Save()}..remove('version'));
      expect(result['version'], currentSaveVersion);
      expect(result['stats'], containsPair('totalLyricsCorrect', 0));
    });

    test('a non-numeric version is treated as v1', () {
      final result = migrateToLatest({...v1Save(), 'version': '2'});
      expect(result['version'], currentSaveVersion);
      expect(result['stats'], containsPair('totalLyricsCorrect', 0));
    });

    test('v1 without stats is a parse error', () {
      expect(
        () => migrateToLatest({...v1Save()}..remove('stats')),
        throwsA(
          isA<SaveParseError>().having(
            (error) => error.message,
            'message',
            'Parse error: stats missing or not an object',
          ),
        ),
      );
    });

    test('a version with no migration step is reported', () {
      expect(
        () => migrateToLatest({...v1Save(), 'version': 0}),
        throwsA(
          isA<MissingMigrationError>()
              .having((error) => error.fromVersion, 'fromVersion', 0)
              .having(
                (error) => error.message,
                'message',
                'Missing migration step from version 0',
              ),
        ),
      );
    });
  });
}
