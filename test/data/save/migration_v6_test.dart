import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/save/migrations.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';

Map<String, Object?> v5Save() => {
  'version': 5,
  'achievements': {
    'first_meow': {
      'unlocked': true,
      'unlockedAt': '2026-02-15T14:30:00Z',
      'song': 'Tim McGraw',
      'albumId': '12345',
      'trackId': '111',
    },
    'purrfect_streak': {
      'unlocked': false,
      'unlockedAt': null,
      'song': null,
      'albumId': null,
      'trackId': null,
    },
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
    'misuVisits': 'often',
    'nickname': 'Sam',
    'togetherLink': 'https://swiftie.satanshu.tech/#key',
  },
  'updater': {
    'autoCheckEnabled': false,
    'lastCheckedAt': '2026-10-05T08:00:00.000Z',
    'skippedVersions': ['0.2.3', '0.2.4'],
    'remindLaterUntil': '2026-10-06T08:00:00.000Z',
  },
};

void main() {
  test('a version 5 save loads unchanged with album covers not saved', () {
    final input = v5Save();

    final result = migrateToLatest(input);

    expect(result.keys, v5Save().keys);
    expect(result['version'], 6);
    for (final key in ['achievements', 'stats', 'updater']) {
      expect(result[key], v5Save()[key], reason: key);
    }
    final settings = result['settings']! as Map<String, Object?>;
    final before = v5Save()['settings']! as Map<String, Object?>;
    expect(settings.keys, [...before.keys, 'saveCovers']);
    for (final MapEntry(:key, :value) in before.entries) {
      expect(settings[key], value, reason: key);
    }
    expect(settings['saveCovers'], isFalse);
    expect(input, v5Save());

    final progress = GameProgress.fromJson(result);
    expect(progress.version, 6);
    expect(
      progress.settings.togetherLink,
      'https://swiftie.satanshu.tech/#key',
    );
    expect(progress.settings.saveCovers, isFalse);
    expect(GameProgress.fromJson(progress.toJson()), progress);
  });

  test('saving covers is off for a new player and is kept once on', () {
    expect(defaultProgress.settings.saveCovers, isFalse);
    final on = defaultProgress.copyWith(
      settings: defaultProgress.settings.copyWith(saveCovers: true),
    );

    expect(GameProgress.fromJson(on.toJson()).settings.saveCovers, isTrue);
  });
}
