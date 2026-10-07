import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/covers/cover_store.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/state/covers.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/persistence_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

const String _newRelease = 'ffffffffffffffffffffffffffffffff';
final Uint8List _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1]);

class _Persistence extends PersistenceController {
  @override
  PersistenceStatus build() => PersistenceStatus.idle;

  void finish() => state = PersistenceStatus.loaded;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory folder;
  late _Persistence persistence;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('covers_state');
    persistence = _Persistence();
  });
  tearDown(() {
    if (folder.existsSync()) {
      folder.deleteSync(recursive: true);
    }
  });

  Directory kept() => Directory('${folder.path}/covers');

  ProviderContainer container() => ProviderContainer.test(
    overrides: [
      coversFolderProvider.overrideWithValue(kept),
      httpClientProvider.overrideWithValue(
        MockClient((request) async => http.Response.bytes(_jpeg, 200)),
      ),
      persistenceControllerProvider.overrideWith(() => persistence),
    ],
  );

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

  Future<void> settle() async {
    for (var step = 0; step < 20; step++) {
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

  test('turning saving off removes the kept covers', () async {
    final scope = container()..read(coverCleanupProvider);
    persistence.finish();
    setSaving(scope, true);
    await scope.read(coverStoreProvider).load(deezerCoverUrl(_newRelease, 250));
    expect(kept().existsSync(), isTrue);

    setSaving(scope, false);
    await settle();
    expect(kept().existsSync(), isFalse);
  });

  test(
    'covers left behind are removed once a save with saving off loads',
    () async {
      kept().createSync(recursive: true);
      File('${kept().path}/$_newRelease.jpg').writeAsBytesSync(_jpeg);
      container().read(coverCleanupProvider);

      await settle();
      expect(kept().existsSync(), isTrue);
      persistence.finish();
      await settle();
      expect(kept().existsSync(), isFalse);
    },
  );

  test('a save that loads with saving on keeps its covers', () async {
    kept().createSync(recursive: true);
    final scope = container()..read(coverCleanupProvider);
    scope
        .read(gameControllerProvider.notifier)
        .setProgress(
          defaultProgress.copyWith(
            settings: defaultProgress.settings.copyWith(saveCovers: true),
          ),
        );

    persistence.finish();
    await settle();
    expect(kept().existsSync(), isTrue);
  });
}
