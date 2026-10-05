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

Map<String, Object?> currentSave() => {
  'version': 3,
  'achievements': <String, Object?>{},
  'stats': {
    'totalCorrect': 5,
    'albumsPlayed': <Object?>[],
    'tracksGuessedPerAlbum': <String, Object?>{},
    'totalLyricsCorrect': 0,
    'nameThaSongCorrect': 0,
    'lyricsOrLieCorrect': 0,
  },
  'settings': {'theme': 'dark', 'volume': 0.8},
  'updater': {
    'autoCheckEnabled': true,
    'lastCheckedAt': null,
    'skippedVersions': <Object?>[],
    'remindLaterUntil': null,
  },
};

void main() {
  group('migrations parity', () {
    test('current save version is 3', () {
      expect(currentSaveVersion, 3);
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
      expect(result['version'], 3);
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

    test('migrate v1 through v3 chain', () {
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
      expect(result['version'], 3);
      expect(result['stats'], containsPair('totalCorrect', 99));
      expect(result['stats'], containsPair('totalLyricsCorrect', 0));
      expect(result['updater'], containsPair('autoCheckEnabled', true));
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
