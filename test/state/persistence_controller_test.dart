import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swiftie_quiz/data/save/save_error.dart';
import 'package:swiftie_quiz/data/save/save_store.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/load_result.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/persistence_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/toast_controller.dart';

final DateTime _now = DateTime.utc(2026, 10, 5, 12);

Map<String, Object?> _currentSave({required int totalCorrect}) => {
  ...defaultProgress.toJson(),
  'stats': {...defaultProgress.stats.toJson(), 'totalCorrect': totalCorrect},
};

Map<String, Object?> _v1Save({required int totalCorrect}) => {
  'version': 1,
  'achievements': <String, Object?>{},
  'stats': {
    'totalCorrect': totalCorrect,
    'albumsPlayed': <Object?>[],
    'tracksGuessedPerAlbum': <String, Object?>{},
  },
  'settings': {'theme': 'dark', 'volume': 0.8},
};

void main() {
  late Directory saveFolder;
  late File saveFile;
  late SaveStore store;
  late List<GameProgress> saved;
  late ProviderContainer container;

  void writeSave(Map<String, Object?> json) =>
      saveFile.writeAsStringSync(jsonEncode(json));

  GameProgress progress() => container.read(gameControllerProvider).progress;

  String? toast() => container.read(toastControllerProvider);

  PersistenceController persistence() =>
      container.read(persistenceControllerProvider.notifier);

  GameController game() => container.read(gameControllerProvider.notifier);

  setUp(() {
    saveFolder = Directory.systemTemp.createTempSync('swiftie_persistence_');
    saveFile = File(p.join(saveFolder.path, 'save.json'));
    store = SaveStore(saveFile, () => _now);
    saved = [];
    container = ProviderContainer.test(
      overrides: [
        clockProvider.overrideWithValue(() => _now),
        saveStoreProvider.overrideWithValue(store),
        progressSaverProvider.overrideWithValue((progress) async {
          saved = [...saved, progress];
        }),
      ],
    );
  });

  tearDown(() => saveFolder.deleteSync(recursive: true));

  group('persistence parity', () {
    test('does nothing on Fresh result (no toast, no setProgress)', () async {
      await persistence().load();

      expect(toast(), isNull);
      expect(progress(), defaultProgress);
      expect(
        container.read(persistenceControllerProvider),
        PersistenceStatus.loaded,
      );
    });

    test(
      'setProgress (with merged settings) on Loaded result; no toast',
      () async {
        writeSave({
          ..._currentSave(totalCorrect: 42),
          'settings': {'theme': 'light', 'volume': 0.5},
        });

        await persistence().load();

        expect(progress().stats.totalCorrect, 42);
        expect(progress().settings.theme, ThemeSetting.light);
        expect(progress().settings.volume, 0.5);
        expect(progress().settings.mediumTimer, 30);
        expect(progress().settings.hardTimer, 20);
        expect(toast(), isNull);
      },
    );

    test('setProgress + toast with version on Migrated result with known fromVersion', () async {
      writeSave(_v1Save(totalCorrect: 7));

      await persistence().load();

      expect(progress().stats.totalCorrect, 7);
      expect(
        toast(),
        'Welcome back! Your progress has been preserved. '
        '(Migrated from save format v1.)',
      );
    });

    test('toast omits version when fromVersion is null', () async {
      writeSave({..._v1Save(totalCorrect: 0)}..remove('version'));

      await persistence().load();

      expect(toast(), 'Welcome back! Your progress has been preserved.');
      expect(toast(), isNot(matches(RegExp(r'v\d'))));
    });

    test('does not overwrite store on invoke error (preserves seeded data for backup recovery)', () async {
      writeSave({..._currentSave(totalCorrect: 1), 'version': 99});
      final seeded = defaultProgress.copyWith(
        stats: defaultProgress.stats.copyWith(totalCorrect: 99),
      );
      game().setProgress(seeded);

      await persistence().load();

      expect(progress().stats.totalCorrect, 99);
      expect(
        toast(),
        "Couldn't load your save. Open Settings → Backups to restore from a backup.",
      );
      expect(
        container.read(persistenceControllerProvider),
        PersistenceStatus.failed,
      );
    });

    test(
      'the open edition without a nickname starts on the nickname screen',
      () async {
        Future<GamePhase> phaseAfterLoad(
          Edition edition, {
          String? nickname,
        }) async {
          writeSave({
            ..._currentSave(totalCorrect: 3),
            'settings': {
              ...defaultProgress.settings.toJson(),
              'nickname': nickname,
            },
          });
          final launch = ProviderContainer.test(
            overrides: [
              clockProvider.overrideWithValue(() => _now),
              saveStoreProvider.overrideWithValue(store),
              progressSaverProvider.overrideWithValue((_) async {}),
              editionProvider.overrideWithValue(edition),
            ],
          );
          expect(launch.read(gameControllerProvider).phase, GamePhase.menu);
          await launch.read(persistenceControllerProvider.notifier).load();
          expect(
            launch.read(gameControllerProvider).progress.stats.totalCorrect,
            3,
          );
          return launch.read(gameControllerProvider).phase;
        }

        expect(await phaseAfterLoad(Edition.open), GamePhase.nickname);
        expect(await phaseAfterLoad(Edition.ana), GamePhase.menu);
        expect(
          await phaseAfterLoad(Edition.open, nickname: 'Sam'),
          GamePhase.menu,
        );
      },
    );

    test('a fresh, migrated or failed load routes the open edition', () async {
      Future<GamePhase> phaseAfterLoad(Edition edition) async {
        final launch = ProviderContainer.test(
          overrides: [
            clockProvider.overrideWithValue(() => _now),
            saveStoreProvider.overrideWithValue(store),
            progressSaverProvider.overrideWithValue((_) async {}),
            editionProvider.overrideWithValue(edition),
          ],
        );
        await launch.read(persistenceControllerProvider.notifier).load();
        return launch.read(gameControllerProvider).phase;
      }

      expect(await phaseAfterLoad(Edition.open), GamePhase.nickname);
      expect(await phaseAfterLoad(Edition.ana), GamePhase.menu);

      writeSave(_v1Save(totalCorrect: 7));
      expect(await phaseAfterLoad(Edition.open), GamePhase.nickname);

      writeSave({..._currentSave(totalCorrect: 1), 'version': 99});
      expect(await phaseAfterLoad(Edition.open), GamePhase.nickname);
      expect(await phaseAfterLoad(Edition.ana), GamePhase.menu);
    });

    test('loads only once', () async {
      writeSave(_currentSave(totalCorrect: 42));
      final first = persistence().load();
      final second = persistence().load();
      await first;
      writeSave(_currentSave(totalCorrect: 1));

      await persistence().load();

      expect(identical(first, second), isTrue);
      expect(progress().stats.totalCorrect, 42);
    });

    test('never saves before a load', () {
      persistence();
      expect(
        container.read(persistenceControllerProvider),
        PersistenceStatus.idle,
      );

      fakeAsync((async) {
        game().setVolume(0.5);
        async.elapse(const Duration(seconds: 5));
      });

      expect(saved, isEmpty);
    });

    test('never saves after a failed load', () async {
      writeSave({..._currentSave(totalCorrect: 1), 'version': 6});
      await persistence().load();

      fakeAsync((async) {
        game()
          ..setVolume(0.5)
          ..answerIncorrect()
          ..setTheme(ThemeSetting.light);
        async.elapse(const Duration(seconds: 5));
      });

      expect(saved, isEmpty);
      expect(
        jsonDecode(saveFile.readAsStringSync()),
        containsPair('version', 6),
      );
    });

    test('saves 1 s after the last progress change', () async {
      await persistence().load();

      fakeAsync((async) {
        game().setVolume(0.5);
        async.elapse(const Duration(milliseconds: 999));
        expect(saved, isEmpty);

        game().setVolume(0.6);
        async.elapse(const Duration(milliseconds: 999));
        expect(saved, isEmpty);

        async.elapse(const Duration(milliseconds: 1));
        expect(saved, hasLength(1));
        expect(saved.single.settings.volume, 0.6);

        async.elapse(const Duration(seconds: 5));
        expect(saved, hasLength(1));
      });
    });

    test('skips a progress whose JSON equals the last saved one', () async {
      await persistence().load();

      fakeAsync((async) {
        game().setVolume(0.6);
        async.elapse(const Duration(seconds: 1));
        expect(saved, hasLength(1));

        game().setVolume(0.7);
        async.elapse(const Duration(milliseconds: 500));
        game().setVolume(0.6);
        async.elapse(const Duration(seconds: 1));
        expect(saved, hasLength(1));

        game().setVolume(0.7);
        async.elapse(const Duration(seconds: 1));
        expect(saved, hasLength(2));
        expect(saved.last.settings.volume, 0.7);
      });
    });

    test('saves through the save store by default', () async {
      final defaultSaver = ProviderContainer.test(
        overrides: [saveStoreProvider.overrideWithValue(store)],
      );
      final progress = defaultProgress.copyWith(
        stats: defaultProgress.stats.copyWith(totalCorrect: 3),
      );

      await defaultSaver.read(progressSaverProvider)(progress);

      expect(await store.load(), LoadLoaded(progress: progress));
    });

    test('lists backups and restores one, then reloads it', () async {
      writeSave(_currentSave(totalCorrect: 5));
      await store.createBackup();
      writeSave(_currentSave(totalCorrect: 9));
      await persistence().load();
      expect(progress().stats.totalCorrect, 9);

      final backups = await persistence().listBackups();
      expect(backups, hasLength(1));
      expect(backups.single.timestamp, _now.millisecondsSinceEpoch ~/ 1000);

      await persistence().restoreBackup(backups.single.timestamp);

      expect(progress().stats.totalCorrect, 5);
      expect(
        (jsonDecode(saveFile.readAsStringSync())
            as Map<String, Object?>)['stats'],
        containsPair('totalCorrect', 5),
      );
      expect(
        container.read(persistenceControllerProvider),
        PersistenceStatus.loaded,
      );
    });

    test('a restore pauses saving until the backup is loaded', () async {
      writeSave(_currentSave(totalCorrect: 5));
      await store.createBackup();
      writeSave(_currentSave(totalCorrect: 9));
      await persistence().load();
      final timestamp = (await persistence().listBackups()).single.timestamp;

      final restoring = persistence().restoreBackup(timestamp);
      expect(
        container.read(persistenceControllerProvider),
        PersistenceStatus.loading,
      );
      await restoring;

      expect(
        container.read(persistenceControllerProvider),
        PersistenceStatus.loaded,
      );
      expect(progress().stats.totalCorrect, 5);
    });

    test('a restore after a failed load re-enables saving', () async {
      writeSave(_currentSave(totalCorrect: 5));
      await store.createBackup();
      writeSave({..._currentSave(totalCorrect: 1), 'version': 99});
      await persistence().load();
      expect(
        container.read(persistenceControllerProvider),
        PersistenceStatus.failed,
      );

      final timestamp = (await persistence().listBackups()).single.timestamp;
      await persistence().restoreBackup(timestamp);

      expect(progress().stats.totalCorrect, 5);
      expect(
        container.read(persistenceControllerProvider),
        PersistenceStatus.loaded,
      );
    });

    test('restoring a missing backup fails and keeps progress', () async {
      writeSave(_currentSave(totalCorrect: 9));
      await persistence().load();

      await expectLater(
        persistence().restoreBackup(1),
        throwsA(isA<SaveFileError>()),
      );

      expect(progress().stats.totalCorrect, 9);
      expect(
        container.read(persistenceControllerProvider),
        PersistenceStatus.loaded,
      );
    });
  });

  group('message toast', () {
    test('show replaces the message, which clears itself after 5 s', () {
      fakeAsync((async) {
        final toasts = container.read(toastControllerProvider.notifier);
        toasts.show('First');
        expect(toast(), 'First');

        async.elapse(const Duration(seconds: 3));
        toasts.show('Second');
        expect(toast(), 'Second');

        async.elapse(const Duration(milliseconds: 4999));
        expect(toast(), 'Second');

        async.elapse(const Duration(milliseconds: 1));
        expect(toast(), isNull);
      });
    });

    test('dismiss clears the message at once', () {
      fakeAsync((async) {
        final toasts = container.read(toastControllerProvider.notifier)
          ..show('Hello');
        toasts.dismiss();
        expect(toast(), isNull);
        async.elapse(const Duration(seconds: 10));
        expect(toast(), isNull);
      });
    });
  });
}
