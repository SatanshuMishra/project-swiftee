import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/app/app.dart';
import 'package:swiftie_quiz/domain/models/backup_entry.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/services/audio/audio_engine.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/lyrics_controller.dart';
import 'package:swiftie_quiz/state/persistence_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/updater_controller.dart';
import 'package:swiftie_quiz/ui/chrome/title_bar.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

final class _LoadedPersistence extends PersistenceController {
  @override
  PersistenceStatus build() => PersistenceStatus.idle;

  @override
  Future<void> load() async {
    state = PersistenceStatus.loaded;
  }

  @override
  Future<List<BackupEntry>> listBackups() async => const [];
}

final class _IdleUpdater extends UpdaterController {
  _IdleUpdater(super.ref);

  @override
  Future<void> check({bool manual = false}) async {}
}

final class _IdleCatalog extends CatalogController {
  @override
  CatalogState build() => CatalogState.initial;

  @override
  Future<void> loadAlbums() async {}

  @override
  Future<CatalogTracks> loadTrackPool() => Completer<CatalogTracks>().future;
}

final class _HeldLyrics extends LyricsController {
  _HeldLyrics(super.ref);

  @override
  Future<List<Track>> loadSourceTracks() => Completer<List<Track>>().future;
}

final class _SilentEngine implements AudioEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} was not expected');
}

Future<void> launchShell(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 5, 12)),
        editionProvider.overrideWithValue(Edition.ana),
        randomProvider.overrideWithValue(Random(5)),
        appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
        httpClientProvider.overrideWithValue(
          MockClient((request) async => http.Response('', 404)),
        ),
        audioEngineProvider.overrideWithValue(_SilentEngine()),
        persistenceControllerProvider.overrideWith(_LoadedPersistence.new),
        catalogControllerProvider.overrideWith(_IdleCatalog.new),
        lyricsControllerProvider.overrideWith(_HeldLyrics.new),
        platformBrightnessProvider.overrideWithValue(() => Brightness.dark),
        windowChromeProvider.overrideWithValue((_, _) async {}),
        renderFailuresProvider.overrideWithValue(RenderFailures()),
        updaterControllerProvider.overrideWith(_IdleUpdater.new),
      ],
      child: const SwiftieQuizApp(),
    ),
  );
}

Color shellColor(WidgetTester tester) => tester
    .widget<ColoredBox>(
      find
          .ancestor(
            of: find.byType(AppTitleBar),
            matching: find.byType(ColoredBox),
          )
          .first,
    )
    .color;

void main() {
  testWidgets('the theme cross-fades over 300 ms', (tester) async {
    await launchShell(tester);
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(AppMotion.themeFade, const Duration(milliseconds: 300));
    expect(app.themeAnimationDuration, const Duration(milliseconds: 300));
    expect(shellColor(tester), AppTokens.dark.bg);

    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(gameControllerProvider.notifier)
        .setTheme(ThemeSetting.light);
    await tester.pump();
    expect(shellColor(tester), AppTokens.dark.bg);

    await tester.pump(AppMotion.themeFade ~/ 2);
    final halfway = shellColor(tester);
    expect(halfway, isNot(AppTokens.dark.bg));
    expect(halfway, isNot(AppTokens.light.bg));

    await tester.pump(AppMotion.themeFade ~/ 2);
    expect(shellColor(tester), AppTokens.light.bg);
  });

  testWidgets('the theme switches at once when motion is reduced', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await launchShell(tester);
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeAnimationDuration, Duration.zero);
    expect(shellColor(tester), AppTokens.dark.bg);

    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(gameControllerProvider.notifier)
        .setTheme(ThemeSetting.light);
    await tester.pump();
    expect(shellColor(tester), AppTokens.light.bg);
  });
}
