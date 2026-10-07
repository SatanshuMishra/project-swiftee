import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/app/app.dart';
import 'package:swiftie_quiz/domain/models/backup_entry.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/services/audio/audio_engine.dart';
import 'package:swiftie_quiz/services/updater/update_manifest_client.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/covers.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/lyrics_controller.dart';
import 'package:swiftie_quiz/state/persistence_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/toast_controller.dart';
import 'package:swiftie_quiz/state/updater_controller.dart';
import 'package:swiftie_quiz/ui/chrome/title_bar.dart';
import 'package:swiftie_quiz/ui/misu/misu_host.dart';
import 'package:swiftie_quiz/ui/overlays/achievement_toasts.dart';
import 'package:swiftie_quiz/ui/overlays/error_screen.dart';
import 'package:swiftie_quiz/ui/overlays/toast_host.dart';
import 'package:swiftie_quiz/ui/overlays/update_badge.dart';
import 'package:swiftie_quiz/ui/overlays/update_modal.dart';
import 'package:swiftie_quiz/ui/screens/album_grid.dart';
import 'package:swiftie_quiz/ui/screens/game_screen.dart';
import 'package:swiftie_quiz/ui/screens/lyrics_game_screen.dart';
import 'package:swiftie_quiz/ui/screens/lyrics_loading_screen.dart';
import 'package:swiftie_quiz/ui/screens/main_menu.dart';
import 'package:swiftie_quiz/ui/screens/nickname_screen.dart';
import 'package:swiftie_quiz/ui/screens/record_shelf_screen.dart';
import 'package:swiftie_quiz/ui/screens/round_summary_screen.dart';
import 'package:swiftie_quiz/ui/screens/settings_screen.dart';
import 'package:swiftie_quiz/ui/screens/setup_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

final DateTime _outsideBirthdayPeriod = DateTime(2026, 10, 5, 12);

const List<Type> _screenTypes = [
  NicknameScreen,
  MainMenu,
  AlbumGrid,
  SetupScreen,
  LyricsLoadingScreen,
  GameScreen,
  LyricsGameScreen,
  RoundSummaryScreen,
  RecordShelfScreen,
  SettingsScreen,
];

final class _RecordingPersistence extends PersistenceController {
  _RecordingPersistence({this.saved});

  final GameProgress? saved;
  int loads = 0;

  @override
  PersistenceStatus build() => PersistenceStatus.idle;

  @override
  Future<void> load() async {
    loads += 1;
    state = PersistenceStatus.loaded;
    if (saved case final progress?) {
      ref.read(gameControllerProvider.notifier).setProgress(progress);
    }
  }

  @override
  Future<List<BackupEntry>> listBackups() async => const [];
}

final class _RecordingUpdater extends UpdaterController {
  _RecordingUpdater(super.ref);

  List<bool> checks = const [];

  @override
  Future<void> check({bool manual = false}) async {
    checks = [...checks, manual];
  }
}

final class _CountingManifestClient implements UpdateManifestClient {
  List<String> checkedVersions = const [];

  @override
  Future<AvailableUpdate?> check(String runningVersion) async {
    checkedVersions = [...checkedVersions, runningVersion];
    return null;
  }
}

final class _IdleCatalog extends CatalogController {
  @override
  CatalogState build() => CatalogState.initial;

  @override
  Future<void> loadCatalogue() async {}

  @override
  Future<CatalogTracks> loadTrackPool() => Completer<CatalogTracks>().future;
}

final class _CountingCatalog extends _IdleCatalog {
  int releaseChecks = 0;

  @override
  Future<void> checkForNewReleases() async => releaseChecks += 1;
}

final class _BrokenCatalog extends CatalogController {
  @override
  CatalogState build() => throw StateError('catalog unavailable');

  @override
  Future<void> loadCatalogue() async {}
}

final class _HeldLyrics extends LyricsController {
  _HeldLyrics(super.ref);

  @override
  Future<List<Track>> loadSourceTracks() => Completer<List<Track>>().future;
}

final class _SilentEngine implements AudioEngine {
  int shutdowns = 0;

  @override
  Future<void> shutdown() async => shutdowns += 1;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} was not expected');
}

final class _ThrowsDuringLayout extends LeafRenderObjectWidget {
  const _ThrowsDuringLayout();

  @override
  RenderObject createRenderObject(BuildContext context) => _ThrowingBox();
}

final class _ThrowingBox extends RenderBox {
  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() => throw StateError('layout failed');
}

final class _ThrowsWhileBuilding extends StatelessWidget {
  const _ThrowsWhileBuilding();

  @override
  Widget build(BuildContext context) => throw StateError('build failed');
}

final class _ThrowsOnRightToLeft extends StatefulWidget {
  const _ThrowsOnRightToLeft();

  @override
  State<_ThrowsOnRightToLeft> createState() => _ThrowsOnRightToLeftState();
}

final class _ThrowsOnRightToLeftState extends State<_ThrowsOnRightToLeft> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Directionality.of(context) == TextDirection.rtl) {
      throw StateError('dependency failed');
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

Widget _throwingItem(BuildContext context, int index) =>
    throw StateError('item failed');

final class _Harness {
  _Harness(
    this.tester, {
    this.saved,
    this.realUpdater = false,
    this.catalog = _IdleCatalog.new,
  });

  final WidgetTester tester;
  final GameProgress? saved;
  final bool realUpdater;
  final CatalogController Function() catalog;
  late final _RecordingPersistence persistence = _RecordingPersistence(
    saved: saved,
  );
  late final RenderFailures failures = RenderFailures(
    restartApp: () => restarts += 1,
  );
  final _CountingManifestClient manifest = _CountingManifestClient();
  final _SilentEngine engine = _SilentEngine();
  _RecordingUpdater? _updater;
  Brightness platformBrightness = Brightness.dark;
  List<(Brightness, Color)> chrome = const [];
  int restarts = 0;
  List<Uri> requests = const [];

  _RecordingUpdater get updater => _updater!;

  List<Override> get _overrides => [
    clockProvider.overrideWithValue(() => _outsideBirthdayPeriod),
    editionProvider.overrideWithValue(Edition.ana),
    randomProvider.overrideWithValue(Random(5)),
    appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
    httpClientProvider.overrideWithValue(
      MockClient((request) async {
        requests = [...requests, request.url];
        return http.Response('', 404);
      }),
    ),
    audioEngineProvider.overrideWithValue(engine),
    persistenceControllerProvider.overrideWith(() => persistence),
    coversFolderProvider.overrideWithValue(
      () => Directory('${Directory.systemTemp.path}/swiftie-test-no-covers'),
    ),
    catalogControllerProvider.overrideWith(catalog),
    lyricsControllerProvider.overrideWith(_HeldLyrics.new),
    platformBrightnessProvider.overrideWithValue(() => platformBrightness),
    windowChromeProvider.overrideWithValue((brightness, background) async {
      chrome = [...chrome, (brightness, background)];
    }),
    renderFailuresProvider.overrideWithValue(failures),
    if (realUpdater)
      updateManifestClientProvider.overrideWithValue(AsyncData(manifest))
    else
      updaterControllerProvider.overrideWith(
        (ref) => _updater = _RecordingUpdater(ref),
      ),
  ];

  Future<void> launch() async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(overrides: _overrides, child: const SwiftieQuizApp()),
    );
    if (!realUpdater) {
      container.read(updaterControllerProvider);
    }
  }

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  GameController get game => container.read(gameControllerProvider.notifier);

  Future<void> show(GamePhase phase, {QuizType? quizType}) async {
    if (quizType != null) {
      game.setQuizType(quizType);
    }
    game.setPhase(phase);
    await tester.pump();
  }

  void expectOnlyScreen(Type screen) {
    for (final type in _screenTypes) {
      expect(
        find.byType(type),
        type == screen ? findsOneWidget : findsNothing,
        reason: '$type while expecting $screen',
      );
    }
  }

  void expectOverlaysAbove(Type screen) {
    expect(find.byType(AchievementToasts), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppTitleBar),
        matching: find.byType(UpdateBadge),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(UpdateOverlay),
        matching: find.byType(UpdateBadge),
      ),
      findsNothing,
    );
    expect(find.byType(UpdateModal), findsOneWidget);
    expect(find.byType(ToastHost), findsOneWidget);
    final layers = tester
        .widget<Stack>(
          find
              .ancestor(
                of: find.byType(ToastHost),
                matching: find.byType(Stack),
              )
              .first,
        )
        .children;
    expect(layers, hasLength(3));
    expect(layers.first, isA<UpdateOverlay>());
    final shell = layers.first as UpdateOverlay;
    expect(shell.screen.runtimeType, screen);
    expect(shell.belowDialog, isA<AchievementToasts>());
    expect(layers[1], isA<MisuHost>());
    expect(layers.last, isA<ToastHost>());
    expect(find.byType(AppTitleBar), findsOneWidget);
  }

  Future<void> expectTheme(Brightness brightness) async {
    await tester.pump(AppMotion.themeFade);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.themeMode,
      brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    );
    final context = tester.element(find.byType(ToastHost));
    final tokens = brightness == Brightness.dark
        ? AppTokens.dark
        : AppTokens.light;
    expect(Theme.of(context).brightness, brightness);
    expect(AppTokens.of(context).bg, tokens.bg);
    expect(AppTokens.of(context).fg, tokens.fg);
  }
}

Future<FlutterErrorDetails> _firstErrorWhilePumping(
  WidgetTester tester,
  List<Widget> widgets,
) async {
  var reported = const <FlutterErrorDetails>[];
  final original = FlutterError.onError;
  FlutterError.onError = (details) => reported = [...reported, details];
  try {
    for (final widget in widgets) {
      await tester.pumpWidget(widget);
    }
    await tester.pumpWidget(const SizedBox());
  } finally {
    FlutterError.onError = original;
  }
  expect(reported, isNotEmpty);
  return reported.first;
}

void main() {
  group('phase routing', () {
    final cases = <({GamePhase phase, QuizType? quizType, Type screen})>[
      (phase: GamePhase.nickname, quizType: null, screen: NicknameScreen),
      (phase: GamePhase.menu, quizType: null, screen: MainMenu),
      (phase: GamePhase.albumSelect, quizType: null, screen: AlbumGrid),
      (phase: GamePhase.setup, quizType: null, screen: SetupScreen),
      (
        phase: GamePhase.lyricsLoading,
        quizType: QuizType.lyrics,
        screen: LyricsLoadingScreen,
      ),
      (phase: GamePhase.playing, quizType: QuizType.sound, screen: GameScreen),
      (
        phase: GamePhase.playing,
        quizType: QuizType.lyrics,
        screen: LyricsGameScreen,
      ),
      (
        phase: GamePhase.roundSummary,
        quizType: null,
        screen: RoundSummaryScreen,
      ),
      (phase: GamePhase.recordShelf, quizType: null, screen: RecordShelfScreen),
      (phase: GamePhase.settings, quizType: null, screen: SettingsScreen),
    ];

    for (final (:phase, :quizType, :screen) in cases) {
      testWidgets(
        '${phase.wireName}${quizType == null ? '' : ' (${quizType.wireName})'} '
        'shows $screen under the toasts, update badge and update dialog',
        (tester) async {
          final harness = _Harness(tester);
          await harness.launch();

          await harness.show(phase, quizType: quizType);

          harness
            ..expectOnlyScreen(screen)
            ..expectOverlaysAbove(screen);
        },
      );
    }

    testWidgets('the app opens on the main menu with the overlays', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await harness.launch();

      harness
        ..expectOnlyScreen(MainMenu)
        ..expectOverlaysAbove(MainMenu);
    });

    testWidgets('playing without a quiz type shows the sound game', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await harness.launch();

      await harness.show(GamePhase.playing);

      harness.expectOnlyScreen(GameScreen);
    });

    testWidgets(
      'each phase change swaps the screen on the next frame with no transition',
      (tester) async {
        final harness = _Harness(tester);
        await harness.launch();

        for (final (:phase, :quizType, :screen) in [...cases, cases.first]) {
          await harness.show(phase, quizType: quizType);

          harness.expectOnlyScreen(screen);
        }
      },
    );

    testWidgets('the save is loaded once, when the app starts', (tester) async {
      final harness = _Harness(tester);
      await harness.launch();

      expect(harness.persistence.loads, 1);

      await harness.show(GamePhase.settings);
      harness.game.setTheme(ThemeSetting.light);
      await tester.pump();
      await harness.show(GamePhase.menu);

      expect(harness.persistence.loads, 1);
    });

    testWidgets('the overlays work over a screen', (tester) async {
      final harness = _Harness(tester);
      await harness.launch();
      await harness.show(GamePhase.recordShelf);

      harness.game
        ..setUpdaterState(
          const UpdaterAvailable(
            manifest: UpdateManifest(
              version: '0.3.1',
              notes: '',
              pubDate: '2026-10-05T12:00:00Z',
            ),
          ),
        )
        ..addToast('first_meow');
      harness.container
          .read(toastControllerProvider.notifier)
          .show('Welcome back! Your progress has been preserved.');
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(AchievementToasts),
          matching: find.text('First Meow'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Welcome back! Your progress has been preserved.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Update available · 0.3.1'));
      await tester.pumpAndSettle();

      expect(find.text('Version 0.3.1 is here'), findsOneWidget);
      expect(find.byType(RecordShelfScreen), findsOneWidget);

      await tester.tap(
        find.text('Welcome back! Your progress has been preserved.'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Welcome back! Your progress has been preserved.'),
        findsNothing,
      );
      expect(find.text('Version 0.3.1 is here'), findsOneWidget);
    });

    testWidgets('dark and light settings choose the theme directly', (
      tester,
    ) async {
      final harness = _Harness(tester)..platformBrightness = Brightness.light;
      await harness.launch();

      await harness.expectTheme(Brightness.dark);

      harness.game.setTheme(ThemeSetting.light);
      await tester.pump();
      await harness.expectTheme(Brightness.light);

      harness.platformBrightness = Brightness.dark;
      harness.game.setTheme(ThemeSetting.light);
      await tester.pump();
      await harness.expectTheme(Brightness.light);

      harness.game.setTheme(ThemeSetting.dark);
      await tester.pump();
      await harness.expectTheme(Brightness.dark);
    });

    testWidgets('the window chrome follows the resolved theme', (tester) async {
      final harness = _Harness(tester)..platformBrightness = Brightness.light;
      await harness.launch();

      expect(harness.chrome, [(Brightness.dark, AppTokens.dark.bg)]);

      harness.game.setTheme(ThemeSetting.light);
      await tester.pump();
      expect(harness.chrome.last, (Brightness.light, AppTokens.light.bg));

      harness.platformBrightness = Brightness.dark;
      harness.game.setTheme(ThemeSetting.system);
      await tester.pump();
      expect(harness.chrome.last, (Brightness.dark, AppTokens.dark.bg));

      harness.game.setVolume(0.4);
      await tester.pump();
      expect(harness.chrome, hasLength(3));
    });

    testWidgets('a saved system theme resolves from the platform at launch', (
      tester,
    ) async {
      final harness = _Harness(
        tester,
        saved: defaultProgress.copyWith(
          settings: defaultProgress.settings.copyWith(
            theme: ThemeSetting.system,
          ),
        ),
      )..platformBrightness = Brightness.light;
      await harness.launch();
      await tester.pump();

      await harness.expectTheme(Brightness.light);
    });

    testWidgets(
      'the system theme resolves when the setting changes and not again while it stays system',
      (tester) async {
        final harness = _Harness(tester)..platformBrightness = Brightness.light;
        await harness.launch();

        harness.game.setTheme(ThemeSetting.system);
        await tester.pump();
        await harness.expectTheme(Brightness.light);

        harness.platformBrightness = Brightness.dark;
        harness.game
          ..setVolume(0.4)
          ..setTheme(ThemeSetting.system);
        await harness.show(GamePhase.settings);
        await harness.expectTheme(Brightness.light);

        harness.game.setTheme(ThemeSetting.light);
        await tester.pump();
        await harness.expectTheme(Brightness.light);

        harness.game.setTheme(ThemeSetting.system);
        await tester.pump();
        await harness.expectTheme(Brightness.dark);
      },
    );
  });

  group('update checks run once at launch and every six hours', () {
    testWidgets(
      'one automatic check at 1.5 s, none more during 30 s of progress changes, one more at 6 h',
      (tester) async {
        final harness = _Harness(tester);
        await harness.launch();

        await tester.pump(const Duration(milliseconds: 1499));
        expect(harness.updater.checks, isEmpty);

        await tester.pump(const Duration(milliseconds: 1));
        expect(harness.updater.checks, [false]);

        for (var second = 1; second <= 30; second++) {
          final progress = harness.container
              .read(gameControllerProvider)
              .progress;
          harness.game
            ..setProgress(
              progress.copyWith(
                updater: progress.updater.copyWith(
                  lastCheckedAt: DateTime.utc(
                    2026,
                    10,
                    5,
                    12,
                    0,
                    second,
                  ).toIso8601String(),
                ),
              ),
            )
            ..setVolume(second / 100)
            ..setTheme(second.isEven ? ThemeSetting.light : ThemeSetting.dark);
          await tester.pump(const Duration(seconds: 1));
        }
        expect(harness.updater.checks, [false]);

        await tester.pump(
          updateCheckInterval - const Duration(milliseconds: 31501),
        );
        expect(harness.updater.checks, [false]);

        await tester.pump(const Duration(milliseconds: 1));
        expect(harness.updater.checks, [false, false]);
      },
    );

    testWidgets('checks once at launch, then again only after six hours', (
      tester,
    ) async {
      final harness = _Harness(tester, realUpdater: true);
      await harness.launch();

      await tester.pump(const Duration(seconds: 60));
      expect(harness.manifest.checkedVersions, ['0.3.0']);
      expect(
        harness.container
            .read(gameControllerProvider)
            .progress
            .updater
            .lastCheckedAt,
        isNotNull,
      );

      await tester.pump(updateCheckInterval);
      expect(harness.manifest.checkedVersions, ['0.3.0', '0.3.0']);
    });

    testWidgets('every update check also looks for new releases', (
      tester,
    ) async {
      final catalog = _CountingCatalog();
      final harness = _Harness(tester, catalog: () => catalog);
      await harness.launch();

      await tester.pump(const Duration(seconds: 60));
      expect(catalog.releaseChecks, 1);

      await tester.pump(updateCheckInterval);
      expect(catalog.releaseChecks, 2);
    });

    testWidgets('the timers stop when the app is disposed', (tester) async {
      final harness = _Harness(tester);
      await harness.launch();
      final updater = harness.updater;

      await tester.pumpWidget(const SizedBox());
      await tester.pump(updateCheckInterval * 2);

      expect(updater.checks, isEmpty);
    });
  });

  group('render errors show the error screen', () {
    testWidgets('only build and layout errors count as render failures', (
      tester,
    ) async {
      final buildError = await _firstErrorWhilePumping(tester, [
        const _ThrowsWhileBuilding(),
      ]);
      final itemBuildError = await _firstErrorWhilePumping(tester, [
        Directionality(
          textDirection: TextDirection.ltr,
          child: ListView.builder(itemCount: 1, itemBuilder: _throwingItem),
        ),
      ]);
      final rebuildError = await _firstErrorWhilePumping(tester, [
        const Directionality(
          textDirection: TextDirection.ltr,
          child: _ThrowsOnRightToLeft(),
        ),
        const Directionality(
          textDirection: TextDirection.rtl,
          child: _ThrowsOnRightToLeft(),
        ),
      ]);
      final layoutError = await _firstErrorWhilePumping(tester, [
        const Center(child: _ThrowsDuringLayout()),
      ]);
      final overflow = await _firstErrorWhilePumping(tester, [
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 100,
              child: Row(children: [SizedBox(width: 200, height: 20)]),
            ),
          ),
        ),
      ]);

      for (final (name, details, message) in [
        ('build', buildError, 'Bad state: build failed'),
        ('list item build', itemBuildError, 'Bad state: item failed'),
        ('rebuild', rebuildError, 'Bad state: dependency failed'),
        ('layout', layoutError, 'Bad state: layout failed'),
      ]) {
        expect('${details.exception}', message, reason: name);
        expect(RenderFailures.isRenderFailure(details), isTrue, reason: name);
      }
      expect(RenderFailures.isRenderFailure(overflow), isFalse);
      for (final library in [
        'gesture library',
        'image resource service',
        'services library',
        'scheduler library',
        null,
      ]) {
        expect(
          RenderFailures.isRenderFailure(
            FlutterErrorDetails(
              exception: StateError('elsewhere'),
              library: library,
            ),
          ),
          isFalse,
          reason: '$library',
        );
      }
    });

    testWidgets(
      'the installed handlers send a build error to the error screen and swallow uncaught async errors',
      (tester) async {
        final harness = _Harness(tester, catalog: _BrokenCatalog.new);
        await harness.launch();
        final errorWidgetBuilder = ErrorWidget.builder;
        final flutterErrorHandler = FlutterError.onError;
        final platformErrorHandler = PlatformDispatcher.instance.onError;
        late final bool asyncErrorHandled;
        try {
          installErrorHandlers(harness.failures);

          asyncErrorHandled = PlatformDispatcher.instance.onError!(
            StateError('lost future'),
            StackTrace.empty,
          );
          await tester.pump();
          await tester.pump();
          expect(harness.failures.value, isNull);
          harness.expectOnlyScreen(MainMenu);

          harness.game.setPhase(GamePhase.albumSelect);
          await tester.pump();
          expect(
            find.descendant(
              of: find.byType(AlbumGrid),
              matching: find.byType(ErrorScreen),
            ),
            findsOneWidget,
          );

          await tester.pump();
        } finally {
          ErrorWidget.builder = errorWidgetBuilder;
          FlutterError.onError = flutterErrorHandler;
          PlatformDispatcher.instance.onError = platformErrorHandler;
        }

        expect(asyncErrorHandled, isTrue);
        expect(harness.failures.value, isA<Object>());
        expect(find.byType(ErrorScreen), findsOneWidget);
        expect(find.text('Bad state: catalog unavailable'), findsOneWidget);
        expect(find.byType(AlbumGrid), findsNothing);
        expect(find.byType(UpdateOverlay), findsNothing);
        expect(find.byType(AppTitleBar), findsOneWidget);
      },
    );

    testWidgets(
      'a build error replaces the whole app, which stops its timers, until Restart',
      (tester) async {
        final harness = _Harness(tester, catalog: _BrokenCatalog.new);
        await harness.launch();
        final updater = harness.updater;

        final original = FlutterError.onError;
        FlutterError.onError = harness.failures.report;
        try {
          harness.game.setPhase(GamePhase.albumSelect);
          await tester.pump();
          await tester.pump();
        } finally {
          FlutterError.onError = original;
        }

        expect(find.byType(ErrorScreen), findsOneWidget);
        expect(find.text('Something went wrong'), findsOneWidget);
        expect(find.text('Bad state: catalog unavailable'), findsOneWidget);
        expect(find.byType(AlbumGrid), findsNothing);
        expect(find.byType(UpdateOverlay), findsNothing);
        expect(find.byType(AppTitleBar), findsOneWidget);
        expect(find.byType(ToastHost), findsNothing);

        await tester.pump(firstUpdateCheckDelay * 2);
        expect(updater.checks, isEmpty);

        harness.game.setPhase(GamePhase.menu);
        await tester.tap(find.text('Restart'));
        await tester.pump();

        expect(harness.restarts, 1);
        expect(harness.failures.value, isNull);
        harness.expectOnlyScreen(MainMenu);

        await tester.pump(firstUpdateCheckDelay);
        expect(updater.checks, [false]);
      },
    );

    testWidgets('errors outside build and layout leave the screen alone', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await harness.launch();

      harness.failures.report(
        FlutterErrorDetails(
          exception: StateError('cover failed'),
          library: 'image resource service',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(ErrorScreen), findsNothing);
      harness.expectOnlyScreen(MainMenu);
    });
  });

  testWidgets('the title bar text takes the theme, not the fallback style', (
    tester,
  ) async {
    final harness = _Harness(tester);
    await harness.launch();

    final title = tester.widget<RichText>(
      find
          .descendant(
            of: find.byType(AppTitleBar),
            matching: find.byType(RichText),
          )
          .first,
    );
    expect(title.text.style?.decoration, isNot(TextDecoration.underline));
    expect(title.text.style?.fontFamily, isNot('monospace'));
  });

  testWidgets('a request to quit shuts the audio engine down, then lets the '
      'app exit', (tester) async {
    final harness = _Harness(tester);
    await harness.launch();

    final response = await tester.binding.handleRequestAppExit();

    expect(response, AppExitResponse.exit);
    expect(harness.engine.shutdowns, 1);
  });
}
