import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:swiftie_quiz/data/covers/cover_store.dart';
import 'package:swiftie_quiz/data/save/save_location.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/persistence_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

final coversFolderProvider = Provider<Directory Function()>(
  (ref) =>
      () => Directory(
        p.join(p.dirname(defaultSaveFilePath()), savedCoversFolderName),
      ),
);

final coverStoreProvider = Provider<CoverStore>(
  (ref) => CoverStore(
    client: ref.watch(httpClientProvider),
    bundledKeys: () async => bundledCoverKeys(
      (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets(),
    ),
    loadAsset: (asset) async {
      final data = await rootBundle.load(asset);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    },
    folder: ref.watch(coversFolderProvider),
    save: () => ref.read(gameControllerProvider).progress.settings.saveCovers,
  ),
);

final coverCleanupProvider = Provider<void>((ref) {
  bool saving() =>
      ref.read(gameControllerProvider).progress.settings.saveCovers;
  void forget() => unawaited(ref.read(coverStoreProvider).forget());
  ref
    ..listen(
      gameControllerProvider.select(
        (game) => game.progress.settings.saveCovers,
      ),
      (previous, next) {
        if (previous == true && !next) {
          forget();
        }
      },
    )
    ..listen(persistenceControllerProvider, (previous, status) {
      if (previous != PersistenceStatus.loaded &&
          status == PersistenceStatus.loaded &&
          !saving()) {
        forget();
      }
    }, fireImmediately: true);
});
