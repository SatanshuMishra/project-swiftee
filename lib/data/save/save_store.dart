import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:swiftie_quiz/data/save/migrations.dart';
import 'package:swiftie_quiz/data/save/save_error.dart';
import 'package:swiftie_quiz/domain/models/backup_entry.dart';
import 'package:swiftie_quiz/domain/models/load_result.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';

const int maxSaveBackups = 3;

const JsonEncoder _prettyJson = JsonEncoder.withIndent('  ');

final RegExp _backupFileName = RegExp(r'^save\.backup\.(\d+)\.json$');

final class SaveStore {
  const SaveStore(this.saveFile, this._now);

  final File saveFile;
  final DateTime Function() _now;

  Directory get _folder => saveFile.parent;

  File get _tempFile => File(p.setExtension(saveFile.path, '.json.tmp'));

  File _backupFile(int timestamp) =>
      File(p.join(_folder.path, 'save.backup.$timestamp.json'));

  Future<LoadResult> load() => _guard(() async {
    final saveType = await FileSystemEntity.type(saveFile.path);
    if (saveType == FileSystemEntityType.notFound) {
      return const LoadFresh();
    }
    final state = _decodeObject(await saveFile.readAsString());
    final declaredVersion = declaredSaveVersion(state);
    final version = declaredVersion ?? 1;
    if (version > currentSaveVersion) {
      throw FutureSaveVersionError(version);
    }
    if (version == currentSaveVersion) {
      return LoadLoaded(progress: GameProgress.fromJson(state));
    }
    await createBackup();
    final progress = GameProgress.fromJson(migrateToLatest(state));
    await save(progress);
    return LoadMigrated(progress: progress, fromVersion: declaredVersion);
  });

  Future<void> save(GameProgress progress) => _guard(() async {
    await _folder.create(recursive: true);
    final temp = _tempFile;
    await temp.writeAsString(
      _prettyJson.convert(progress.toJson()),
      flush: true,
    );
    await temp.rename(saveFile.path);
  });

  Future<File> createBackup() => _guard(() async {
    if (!await saveFile.exists()) {
      throw const SaveFileError('save file does not exist');
    }
    final backup = await saveFile.copy(_backupFile(_unixSeconds()).path);
    await pruneBackups();
    return backup;
  });

  Future<List<BackupEntry>> listBackups() => _guard(() async {
    if (!await _folder.exists()) {
      return const <BackupEntry>[];
    }
    final entities = await _folder.list().toList();
    final entries = [
      for (final entity in entities)
        if (_backupTimestamp(p.basename(entity.path)) case final timestamp?)
          BackupEntry(
            timestamp: timestamp,
            path: entity.path,
            sizeBytes: (await entity.stat()).size,
          ),
    ];
    return List<BackupEntry>.unmodifiable(
      entries.sorted((a, b) => b.timestamp.compareTo(a.timestamp)),
    );
  });

  Future<void> pruneBackups() => _guard(() async {
    final stale = (await listBackups()).skip(maxSaveBackups);
    await Future.wait([
      for (final entry in stale) _deleteIgnoringFailure(File(entry.path)),
    ]);
  });

  Future<void> restoreBackup(int timestamp) => _guard(() async {
    final backup = _backupFile(timestamp);
    if (!await backup.exists()) {
      throw const SaveFileError('backup file does not exist');
    }
    final temp = _tempFile;
    await backup.copy(temp.path);
    await temp.rename(saveFile.path);
  });

  int _unixSeconds() {
    final milliseconds = _now().millisecondsSinceEpoch;
    if (milliseconds < 0) {
      throw const SaveFileError('second time provided was later than self');
    }
    return milliseconds ~/ Duration.millisecondsPerSecond;
  }
}

int? _backupTimestamp(String fileName) =>
    switch (_backupFileName.firstMatch(fileName)) {
      final RegExpMatch match => int.tryParse(match.group(1)!),
      null => null,
    };

Map<String, Object?> _decodeObject(String raw) => switch (jsonDecode(raw)) {
  final Map<String, Object?> object => object,
  _ => throw const FormatException('save file is not a JSON object'),
};

Future<void> _deleteIgnoringFailure(File file) =>
    file.delete().then<void>((_) {}).onError<FileSystemException>((_, _) {});

Future<T> _guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on FileSystemException catch (error, stackTrace) {
    Error.throwWithStackTrace(SaveFileError(_describe(error)), stackTrace);
  } on FormatException catch (error, stackTrace) {
    Error.throwWithStackTrace(SaveParseError(error.message), stackTrace);
  }
}

String _describe(FileSystemException error) => switch (error.osError) {
  final OSError osError => '${osError.message} (os error ${osError.errorCode})',
  null => error.message,
};
