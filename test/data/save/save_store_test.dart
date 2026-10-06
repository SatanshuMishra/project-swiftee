import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swiftie_quiz/data/save/save_error.dart';
import 'package:swiftie_quiz/data/save/save_store.dart';
import 'package:swiftie_quiz/domain/models/backup_entry.dart';
import 'package:swiftie_quiz/domain/models/load_result.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';

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

const String defaultSaveJson = '''
{
  "version": 4,
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
    "hardTimer": 20,
    "misuVisits": "sometimes",
    "nickname": null
  },
  "updater": {
    "autoCheckEnabled": true,
    "lastCheckedAt": null,
    "skippedVersions": [],
    "remindLaterUntil": null
  }
}''';

DateTime fixedNow() =>
    DateTime.fromMillisecondsSinceEpoch(1700000000500, isUtc: true);

const String fixedBackupName = 'save.backup.1700000000.json';

GameProgress progressWithTotalCorrect(int totalCorrect) =>
    defaultProgress.copyWith(
      stats: defaultProgress.stats.copyWith(totalCorrect: totalCorrect),
    );

void main() {
  group('save store parity', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('save_store_test_');
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    File fileIn(String name) => File(p.join(dir.path, name));

    SaveStore storeFor(String name) => SaveStore(fileIn(name), fixedNow);

    Future<File> writeSaveJson(Map<String, Object?> value) async {
      final file = fileIn('save.json');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(value),
      );
      return file;
    }

    Future<Object?> readJson(File file) async =>
        jsonDecode(await file.readAsString());

    Future<List<int>> backupTimestamps() async => [
      for (final entry in await storeFor('save.json').listBackups())
        entry.timestamp,
    ];

    group('load', () {
      test('returns fresh when there is no save file', () async {
        expect(await storeFor('save.json').load(), const LoadFresh());
      });

      test('returns loaded when already current', () async {
        await writeSaveJson(defaultProgress.toJson());
        expect(
          await storeFor('save.json').load(),
          const LoadLoaded(progress: defaultProgress),
        );
        expect(await backupTimestamps(), isEmpty);
      });

      test('returns migrated and persists when the version is old', () async {
        final v1State = {
          'version': 1,
          'achievements': <String, Object?>{},
          'stats': {
            'totalCorrect': 7,
            'albumsPlayed': <Object?>[],
            'tracksGuessedPerAlbum': <String, Object?>{},
          },
          'settings': {'theme': 'dark', 'volume': 0.8},
        };
        final file = await writeSaveJson(v1State);
        final original = await file.readAsString();
        final store = storeFor('save.json');

        expect(
          await store.load(),
          LoadMigrated(progress: progressWithTotalCorrect(7), fromVersion: 1),
        );

        final backups = await store.listBackups();
        expect(backups, hasLength(1));
        expect(p.basename(backups.single.path), fixedBackupName);
        expect(await File(backups.single.path).readAsString(), original);

        expect(await readJson(file), containsPair('version', 4));
        expect(
          await store.load(),
          LoadLoaded(progress: progressWithTotalCorrect(7)),
        );
        expect(await backupTimestamps(), hasLength(1));
      });

      test('a Tauri version 3 save loads migrated with its values', () async {
        await fileIn('save.json').writeAsString(tauriDefaultSaveJson);
        final store = storeFor('save.json');

        expect(
          await store.load(),
          const LoadMigrated(progress: defaultProgress, fromVersion: 3),
        );
        expect(await backupTimestamps(), hasLength(1));
        expect(await fileIn('save.json').readAsString(), defaultSaveJson);
      });

      test('reports no from-version when the version is missing', () async {
        await writeSaveJson({
          'achievements': <String, Object?>{},
          'stats': {
            'totalCorrect': 3,
            'albumsPlayed': <Object?>[],
            'tracksGuessedPerAlbum': <String, Object?>{},
          },
          'settings': {'theme': 'dark', 'volume': 0.8},
        });

        expect(
          await storeFor('save.json').load(),
          LoadMigrated(
            progress: progressWithTotalCorrect(3),
            fromVersion: null,
          ),
        );
      });

      test(
        'reports no from-version when the version is not a number',
        () async {
          await writeSaveJson({
            'version': 'two',
            'achievements': <String, Object?>{},
            'stats': {
              'totalCorrect': 4,
              'albumsPlayed': <Object?>[],
              'tracksGuessedPerAlbum': <String, Object?>{},
            },
            'settings': {'theme': 'dark', 'volume': 0.8},
          });

          expect(
            await storeFor('save.json').load(),
            LoadMigrated(
              progress: progressWithTotalCorrect(4),
              fromVersion: null,
            ),
          );
        },
      );

      test('throws the newer-version error when the save is newer', () async {
        final file = await writeSaveJson({
          'version': 8,
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
        });

        await expectLater(
          storeFor('save.json').load(),
          throwsA(
            isA<FutureSaveVersionError>()
                .having((error) => error.version, 'version', 8)
                .having(
                  (error) => error.message,
                  'message',
                  'Save file is from a newer version (v8) than this app '
                      'supports',
                ),
          ),
        );
        expect(await readJson(file), containsPair('version', 8));
        expect(await backupTimestamps(), isEmpty);
      });

      test(
        'a failed migration leaves the backup and the save intact',
        () async {
          final file = await writeSaveJson({
            'version': 1,
            'achievements': <String, Object?>{},
            'settings': {'theme': 'dark', 'volume': 0.8},
          });

          await expectLater(
            storeFor('save.json').load(),
            throwsA(isA<SaveParseError>()),
          );
          expect(await backupTimestamps(), hasLength(1));
          expect(await readJson(file), containsPair('version', 1));
        },
      );

      test('malformed JSON is a parse error', () async {
        await fileIn('save.json').writeAsString('{"version": 3,');

        await expectLater(
          storeFor('save.json').load(),
          throwsA(
            isA<SaveParseError>().having(
              (error) => error.message,
              'message',
              startsWith('Parse error: '),
            ),
          ),
        );
      });
    });

    group('save', () {
      test('writes then renames atomically', () async {
        await storeFor('data.json').save(progressWithTotalCorrect(1));

        expect(
          await fileIn('data.json').readAsString(),
          contains('"totalCorrect": 1'),
        );
        expect(fileIn('data.json.tmp').existsSync(), isFalse);
      });

      test('creates the parent folder if missing', () async {
        final nested = File(p.join(dir.path, 'nested', 'sub', 'data.json'));
        await SaveStore(nested, fixedNow).save(defaultProgress);

        expect(nested.existsSync(), isTrue);
      });

      test('overwrites an existing file', () async {
        await fileIn('data.json').writeAsString('old');
        await storeFor('data.json').save(progressWithTotalCorrect(2));

        expect(
          await fileIn('data.json').readAsString(),
          contains('"totalCorrect": 2'),
        );
      });

      test('writes the pretty-printed version 4 save shape', () async {
        await storeFor('save.json').save(defaultProgress);

        expect(await fileIn('save.json').readAsString(), defaultSaveJson);
      });
    });

    group('backups', () {
      test('createBackup makes a copy named with unix seconds', () async {
        await fileIn('save.json').writeAsString('hello');

        final backup = await storeFor('save.json').createBackup();

        expect(backup.path, p.join(dir.path, fixedBackupName));
        expect(await backup.readAsString(), 'hello');
      });

      test('createBackup errors when the save is missing', () async {
        await expectLater(
          storeFor('nonexistent.json').createBackup(),
          throwsA(
            isA<SaveFileError>().having(
              (error) => error.message,
              'message',
              'File error: save file does not exist',
            ),
          ),
        );
      });

      test('listBackups returns newest first', () async {
        await fileIn('save.json').writeAsString('x');
        for (final ts in [100, 200, 300]) {
          await fileIn('save.backup.$ts.json').writeAsString('ts=$ts');
        }

        final entries = await storeFor('save.json').listBackups();

        expect([for (final entry in entries) entry.timestamp], [300, 200, 100]);
        expect(
          entries.first,
          BackupEntry(
            timestamp: 300,
            path: p.join(dir.path, 'save.backup.300.json'),
            sizeBytes: 6,
          ),
        );
      });

      test('listBackups ignores non-backup files', () async {
        await fileIn('save.json').writeAsString('x');
        await fileIn('random.txt').writeAsString('y');
        await fileIn('save.backup.500.json').writeAsString('z');

        expect(await backupTimestamps(), [500]);
      });

      test('listBackups is empty when the save folder is missing', () async {
        final store = SaveStore(
          File(p.join(dir.path, 'missing', 'save.json')),
          fixedNow,
        );

        expect(await store.listBackups(), isEmpty);
      });

      test('prune keeps only the three newest backups', () async {
        for (var ts = 1; ts <= 5; ts++) {
          await fileIn('save.backup.$ts.json').writeAsString('x');
        }

        await storeFor('save.json').pruneBackups();

        expect(await backupTimestamps(), [5, 4, 3]);
      });

      test('createBackup ignores a backup it cannot delete', () async {
        await fileIn('save.json').writeAsString('x');
        await Directory(p.join(dir.path, 'save.backup.1.json')).create();
        for (final ts in [2, 3, 4]) {
          await fileIn('save.backup.$ts.json').writeAsString('x');
        }

        await storeFor('save.json').createBackup();

        expect(await backupTimestamps(), [1700000000, 4, 3, 1]);
      });

      test('restore overwrites the save file', () async {
        await fileIn('save.json').writeAsString('current');
        await fileIn('save.backup.100.json').writeAsString('restored');

        await storeFor('save.json').restoreBackup(100);

        expect(await fileIn('save.json').readAsString(), 'restored');
        expect(fileIn('save.json.tmp').existsSync(), isFalse);
      });

      test('restore fails when the backup is missing', () async {
        await fileIn('save.json').writeAsString('current');

        await expectLater(
          storeFor('save.json').restoreBackup(100),
          throwsA(
            isA<SaveFileError>().having(
              (error) => error.message,
              'message',
              'File error: backup file does not exist',
            ),
          ),
        );
        expect(await fileIn('save.json').readAsString(), 'current');
      });
    });
  });
}
