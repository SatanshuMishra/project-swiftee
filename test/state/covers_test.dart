import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:swiftie_quiz/data/covers/cover_store.dart';
import 'package:swiftie_quiz/data/save/save_store.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/state/covers.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/persistence_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

const String _newRelease = 'ffffffffffffffffffffffffffffffff';
const int _backupAt = 1759800000;
final Uint8List _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory folder;

  setUp(() => folder = Directory.systemTemp.createTempSync('covers_state'));
  tearDown(() {
    if (folder.existsSync()) {
      folder.deleteSync(recursive: true);
    }
  });

  Directory kept() => Directory('${folder.path}/covers');
  File saveFile() => File(p.join(folder.path, 'save.json'));

  String saveWith({required bool saveCovers}) => jsonEncode({
    ...defaultProgress.toJson(),
    'settings': {
      ...defaultProgress.settings.toJson(),
      'saveCovers': saveCovers,
    },
  });

  void keepACover() {
    kept().createSync(recursive: true);
    File('${kept().path}/$_newRelease.jpg').writeAsBytesSync(_jpeg);
  }

  ProviderContainer container() {
    final scope = ProviderContainer.test(
      overrides: [
        coversFolderProvider.overrideWithValue(kept),
        httpClientProvider.overrideWithValue(
          MockClient((request) async => http.Response.bytes(_jpeg, 200)),
        ),
        saveStoreProvider.overrideWithValue(
          SaveStore(saveFile(), () => DateTime.utc(2026, 10, 7)),
        ),
        progressSaverProvider.overrideWithValue((progress) async {}),
      ],
    );
    scope.listen(coverCleanupProvider, (_, _) {});
    return scope;
  }

  void setSaving(ProviderContainer scope, bool saving) {
    final progress = scope.read(gameControllerProvider).progress;
    scope
        .read(gameControllerProvider.notifier)
        .setProgress(
          progress.copyWith(
            settings: progress.settings.copyWith(saveCovers: saving),
          ),
        );
  }

  Future<void> idle() async {
    for (var step = 0; step < 20; step++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<void> untilRemoved() async {
    for (var step = 0; step < 200 && kept().existsSync(); step++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test(
    'one store serves every cover and keeps them only while saving is on',
    () async {
      final scope = container();
      final store = scope.read(coverStoreProvider);

      await store.load(deezerCoverUrl(_newRelease, 250));
      expect(kept().existsSync(), isFalse);

      setSaving(scope, true);
      expect(identical(scope.read(coverStoreProvider), store), isTrue);
      await store.load(deezerCoverUrl(_newRelease, 250));
      expect(File('${kept().path}/$_newRelease.jpg').existsSync(), isTrue);
    },
  );

  test('a launch whose save has saving on keeps its covers', () async {
    saveFile().writeAsStringSync(saveWith(saveCovers: true));
    keepACover();
    final scope = container();

    await scope.read(persistenceControllerProvider.notifier).load();
    await idle();

    expect(
      scope.read(gameControllerProvider).progress.settings.saveCovers,
      isTrue,
    );
    expect(kept().existsSync(), isTrue);
  });

  test(
    'a launch whose save has saving off removes covers left behind',
    () async {
      saveFile().writeAsStringSync(saveWith(saveCovers: false));
      keepACover();
      final scope = container();

      await idle();
      expect(kept().existsSync(), isTrue);
      await scope.read(persistenceControllerProvider.notifier).load();
      await untilRemoved();
      expect(kept().existsSync(), isFalse);
    },
  );

  test('turning saving off removes the kept covers', () async {
    saveFile().writeAsStringSync(saveWith(saveCovers: true));
    final scope = container();
    await scope.read(persistenceControllerProvider.notifier).load();
    await scope.read(coverStoreProvider).load(deezerCoverUrl(_newRelease, 250));
    expect(kept().existsSync(), isTrue);

    setSaving(scope, false);
    await untilRemoved();
    expect(kept().existsSync(), isFalse);
  });

  test('restoring a backup keeps covers when it has saving on and removes '
      'them when it has it off', () async {
    saveFile().writeAsStringSync('{not json');
    keepACover();
    final scope = container();
    final persistence = scope.read(persistenceControllerProvider.notifier);
    await persistence.load();
    await idle();
    expect(scope.read(persistenceControllerProvider), PersistenceStatus.failed);
    expect(kept().existsSync(), isTrue);

    File(p.join(folder.path, 'save.backup.$_backupAt.json'))
        .writeAsStringSync(saveWith(saveCovers: true));
    await persistence.restoreBackup(_backupAt);
    await idle();
    expect(kept().existsSync(), isTrue);

    File(p.join(folder.path, 'save.backup.${_backupAt + 1}.json'))
        .writeAsStringSync(saveWith(saveCovers: false));
    await persistence.restoreBackup(_backupAt + 1);
    await untilRemoved();
    expect(kept().existsSync(), isFalse);
  });
}
