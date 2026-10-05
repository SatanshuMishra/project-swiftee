import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/backup_entry.dart';
import 'package:swiftie_quiz/domain/models/load_result.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/toast_controller.dart';

typedef ProgressSaver = Future<void> Function(GameProgress progress);

enum PersistenceStatus { idle, loading, loaded, failed }

const String loadFailedMessage =
    "Couldn't load your save. Open Settings → Backups to restore from a backup.";

const String _welcomeBackMessage =
    'Welcome back! Your progress has been preserved.';

String migratedMessage(int? fromVersion) => fromVersion == null
    ? _welcomeBackMessage
    : '$_welcomeBackMessage (Migrated from save format v$fromVersion.)';

final progressSaverProvider = Provider<ProgressSaver>(
  (ref) => ref.watch(saveStoreProvider).save,
);

final persistenceControllerProvider =
    NotifierProvider<PersistenceController, PersistenceStatus>(
      PersistenceController.new,
    );

class PersistenceController extends Notifier<PersistenceStatus> {
  static const Duration saveDelay = Duration(seconds: 1);

  Future<void>? _initialLoad;
  Future<void>? _inFlightSave;
  Timer? _pendingSave;
  String _lastSavedJson = '';

  @override
  PersistenceStatus build() {
    ref.onDispose(_cancelPendingSave);
    ref.listen(
      gameControllerProvider.select((game) => game.progress),
      (_, progress) => _scheduleSave(progress),
    );
    return PersistenceStatus.idle;
  }

  Future<void> load() => _initialLoad ??= _load();

  Future<List<BackupEntry>> listBackups() =>
      ref.read(saveStoreProvider).listBackups();

  Future<void> restoreBackup(int timestamp) async {
    final store = ref.read(saveStoreProvider);
    final statusBefore = state;
    state = PersistenceStatus.loading;
    _cancelPendingSave();
    await _inFlightSave;
    try {
      await store.restoreBackup(timestamp);
    } on Object {
      if (ref.mounted) {
        state = statusBefore;
        _scheduleSave(ref.read(gameControllerProvider).progress);
      }
      rethrow;
    }
    final LoadResult result;
    try {
      result = await store.load();
    } on Object {
      if (ref.mounted) {
        state = PersistenceStatus.failed;
      }
      rethrow;
    }
    if (!ref.mounted) {
      return;
    }
    state = PersistenceStatus.loaded;
    switch (result) {
      case LoadLoaded(:final progress) || LoadMigrated(:final progress):
        _apply(progress);
      case LoadFresh():
        break;
    }
  }

  Future<void> _load() async {
    state = PersistenceStatus.loading;
    final LoadResult result;
    try {
      result = await ref.read(saveStoreProvider).load();
    } on Object {
      if (ref.mounted) {
        state = PersistenceStatus.failed;
        _showToast(loadFailedMessage);
      }
      return;
    }
    if (!ref.mounted) {
      return;
    }
    state = PersistenceStatus.loaded;
    switch (result) {
      case LoadFresh():
        break;
      case LoadLoaded(:final progress):
        _apply(progress);
      case LoadMigrated(:final progress, :final fromVersion):
        _apply(progress);
        _showToast(migratedMessage(fromVersion));
    }
  }

  void _apply(GameProgress progress) =>
      ref.read(gameControllerProvider.notifier).setProgress(progress);

  void _showToast(String message) =>
      ref.read(toastControllerProvider.notifier).show(message);

  void _scheduleSave(GameProgress progress) {
    if (state != PersistenceStatus.loaded) {
      return;
    }
    _cancelPendingSave();
    _pendingSave = Timer(saveDelay, () => unawaited(_save(progress)));
  }

  Future<void> _save(GameProgress progress) {
    _pendingSave = null;
    final json = jsonEncode(progress.toJson());
    if (json == _lastSavedJson) {
      return Future<void>.value();
    }
    _lastSavedJson = json;
    return _inFlightSave = _write(progress);
  }

  Future<void> _write(GameProgress progress) async {
    try {
      await ref.read(progressSaverProvider)(progress);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to save progress',
        name: 'swiftie_quiz.persistence',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _cancelPendingSave() {
    _pendingSave?.cancel();
    _pendingSave = null;
  }
}
