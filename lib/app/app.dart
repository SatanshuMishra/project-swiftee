import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/app/window_setup.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/persistence_controller.dart';
import 'package:swiftie_quiz/state/updater_controller.dart';
import 'package:swiftie_quiz/ui/overlays/achievement_toasts.dart';
import 'package:swiftie_quiz/ui/overlays/error_screen.dart';
import 'package:swiftie_quiz/ui/overlays/toast_host.dart';
import 'package:swiftie_quiz/ui/overlays/update_badge.dart';
import 'package:swiftie_quiz/ui/chrome/title_bar.dart';
import 'package:swiftie_quiz/ui/misu/misu_host.dart';
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
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

const Duration firstUpdateCheckDelay = Duration(milliseconds: 1500);
const Duration updateCheckInterval = Duration(hours: 6);

final platformBrightnessProvider = Provider<Brightness Function()>(
  (ref) =>
      () => PlatformDispatcher.instance.platformBrightness,
);

final themeBrightnessProvider = Provider<Brightness>((ref) {
  final setting = ref.watch(
    gameControllerProvider.select((game) => game.progress.settings.theme),
  );
  return switch (setting) {
    ThemeSetting.dark => Brightness.dark,
    ThemeSetting.light => Brightness.light,
    ThemeSetting.system => ref.watch(platformBrightnessProvider)(),
  };
});

final themeModeProvider = Provider<ThemeMode>(
  (ref) => switch (ref.watch(themeBrightnessProvider)) {
    Brightness.dark => ThemeMode.dark,
    Brightness.light => ThemeMode.light,
  },
);

final windowChromeProvider = Provider<WindowChrome>(
  (ref) => matchMacWindowChrome,
);

class RenderFailures extends ValueNotifier<Object?> {
  RenderFailures({this.restartApp = restartAppWidgetTree}) : super(null);

  static const Set<String> _layoutContexts = {
    'during performLayout()',
    'during performResize()',
  };

  final VoidCallback restartApp;

  static bool isRenderFailure(FlutterErrorDetails details) => switch ((
    details.library,
    '${details.context}',
  )) {
    ('widgets library', 'building' || 'while rebuilding dirty elements') =>
      true,
    ('widgets library', final context) => context.startsWith('building '),
    ('rendering library', final context) => _layoutContexts.contains(context),
    _ => false,
  };

  void report(FlutterErrorDetails details) {
    if (!isRenderFailure(details)) {
      return;
    }
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => value ??= details.exception)
      ..ensureVisualUpdate();
  }

  void restart() {
    value = null;
    restartApp();
  }
}

final RenderFailures renderFailures = RenderFailures();

final renderFailuresProvider = Provider<RenderFailures>(
  (ref) => renderFailures,
);

void installErrorHandlers(RenderFailures failures) {
  ErrorWidget.builder = (details) =>
      ErrorScreen(error: details.exception, onRestart: failures.restart);
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    failures.report(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    developer.log(
      'Unhandled error',
      name: 'swiftie_quiz.app',
      error: error,
      stackTrace: stackTrace,
    );
    return true;
  };
}

class SwiftieQuizApp extends ConsumerStatefulWidget {
  const SwiftieQuizApp({super.key});

  static const String title = 'Project Swiftie';

  @override
  ConsumerState<SwiftieQuizApp> createState() => _SwiftieQuizAppState();
}

class _SwiftieQuizAppState extends ConsumerState<SwiftieQuizApp> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<Brightness>(
      themeBrightnessProvider,
      (_, brightness) => unawaited(
        applyWindowChrome(ref.read(windowChromeProvider), brightness),
      ),
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final failures = ref.watch(renderFailuresProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: SwiftieQuizApp.title,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      themeAnimationDuration: switch (ref.watch(
        persistenceControllerProvider,
      )) {
        PersistenceStatus.loaded || PersistenceStatus.failed =>
          AppMotion.duration(context, AppMotion.themeFade),
        PersistenceStatus.idle || PersistenceStatus.loading => Duration.zero,
      },
      builder: (context, navigator) => Material(
        color: AppTokens.of(context).bg,
        animationDuration: Duration.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppTitleBar(),
            Expanded(child: navigator ?? const SizedBox.shrink()),
          ],
        ),
      ),
      home: ValueListenableBuilder<Object?>(
        valueListenable: failures,
        builder: (context, failure, shell) => failure == null
            ? shell!
            : ErrorScreen(error: failure, onRestart: failures.restart),
        child: const _GameShell(),
      ),
    );
  }
}

class _GameShell extends ConsumerStatefulWidget {
  const _GameShell();

  @override
  ConsumerState<_GameShell> createState() => _GameShellState();
}

class _GameShellState extends ConsumerState<_GameShell> {
  late final Timer _firstUpdateCheck;
  late final Timer _periodicUpdateCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(persistenceControllerProvider.notifier).load());
      }
    });
    _firstUpdateCheck = Timer(firstUpdateCheckDelay, _checkForUpdates);
    _periodicUpdateCheck = Timer.periodic(
      updateCheckInterval,
      (_) => _checkForUpdates(),
    );
  }

  @override
  void dispose() {
    _firstUpdateCheck.cancel();
    _periodicUpdateCheck.cancel();
    super.dispose();
  }

  void _checkForUpdates() {
    unawaited(ref.read(updaterControllerProvider).check());
    unawaited(_checkForNewReleases());
  }

  Future<void> _checkForNewReleases() async {
    try {
      await ref.read(catalogControllerProvider.notifier).checkForNewReleases();
    } on Object {
      return;
    }
  }

  static Widget _screenFor(GamePhase phase, QuizType? quizType) =>
      switch (phase) {
        GamePhase.nickname => const NicknameScreen(),
        GamePhase.menu => const MainMenu(),
        GamePhase.albumSelect => const AlbumGrid(),
        GamePhase.setup => const SetupScreen(),
        GamePhase.lyricsLoading => const LyricsLoadingScreen(),
        GamePhase.playing =>
          quizType == QuizType.lyrics
              ? const LyricsGameScreen()
              : const GameScreen(),
        GamePhase.roundSummary => const RoundSummaryScreen(),
        GamePhase.recordShelf => const RecordShelfScreen(),
        GamePhase.settings => const SettingsScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final screen = ref.watch(
      gameControllerProvider.select(
        (game) => (phase: game.phase, quizType: game.quizType),
      ),
    );
    return Material(
      color: AppTokens.of(context).bg,
      animationDuration: Duration.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          UpdateOverlay(
            screen: _screenFor(screen.phase, screen.quizType),
            belowDialog: const AchievementToasts(),
          ),
          const MisuHost(),
          const ToastHost(),
        ],
      ),
    );
  }
}
