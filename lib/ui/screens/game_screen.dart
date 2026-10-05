import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/data/catalog/catalog_error.dart';
import 'package:swiftie_quiz/domain/engine/answer_matcher.dart';
import 'package:swiftie_quiz/domain/engine/game_engine.dart';
import 'package:swiftie_quiz/domain/engine/option_generator.dart';
import 'package:swiftie_quiz/domain/engine/relisten_schedule.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/achievements_controller.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/cat/loading_gate.dart';
import 'package:swiftie_quiz/ui/game/audio_player.dart';
import 'package:swiftie_quiz/ui/game/game_header.dart';
import 'package:swiftie_quiz/ui/game/quiz_card.dart';
import 'package:swiftie_quiz/ui/game/result_feedback.dart';
import 'package:swiftie_quiz/ui/game/timer_bar.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/back_link.dart';
import 'package:swiftie_quiz/ui/widgets/screen_background.dart';
import 'package:swiftie_quiz/ui/widgets/above_app_chrome.dart';

enum SoundRoundState { idle, loading, playing, answered }

int roundTimerSeconds(Difficulty difficulty, int mediumTimer, int hardTimer) =>
    switch (difficulty) {
      Difficulty.easy => 0,
      Difficulty.medium => mediumTimer,
      Difficulty.hard => hardTimer,
    };

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  static const Duration roundLoaderMinimum = Duration(milliseconds: 400);
  static const Duration roundLoaderTimeout = Duration(seconds: 8);
  static const Duration overlayFade = Duration(milliseconds: 300);
  static const String loadingTracksLabel = 'Loading tracks...';
  static const String loadingNextTrackLabel = 'Loading next track...';
  static const String loadFailedMessage = 'Failed to load tracks.';
  static const String backToMenuLabel = 'Back to Menu';
  static const double padding = 32;
  static const double gap = 24;
  static const double errorGap = 16;
  static const Offset quizEntranceOffset = Offset(0, 10);
  static const Offset quizExitOffset = Offset(0, -10);
  static const double resultScale = 0.95;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  SoundRoundState _roundState = SoundRoundState.idle;
  bool? _lastResult;
  bool _timerActive = false;
  bool _tracksReady = false;
  String? _error;
  List<Track> _allTracks = const [];
  List<Track> _initialPool = const [];
  DateTime _roundStart = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _loaderShownAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _loaderTimeout;
  Timer? _loaderMinimum;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTracks());
  }

  @override
  void dispose() {
    _cancelLoaderTimers();
    super.dispose();
  }

  DateTime _now() => ref.read(clockProvider)();

  Future<void> _loadTracks() async {
    try {
      final tracks = await ref
          .read(catalogControllerProvider.notifier)
          .loadTrackPool();
      if (!mounted) {
        return;
      }
      if (tracks.pool.isEmpty) {
        setState(() => _error = GameScreen.loadFailedMessage);
        return;
      }
      setState(() {
        _allTracks = tracks.allTracks;
        _initialPool = tracks.pool;
        _tracksReady = true;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is RateLimited
              ? error.message
              : GameScreen.loadFailedMessage,
        );
      }
    }
  }

  void _cancelLoaderTimers() {
    _loaderTimeout?.cancel();
    _loaderTimeout = null;
    _loaderMinimum?.cancel();
    _loaderMinimum = null;
  }

  void _beginRound(List<Track> pool, {required bool immediate}) {
    final random = ref.read(randomProvider);
    final draw = drawNextTrack(pool, _allTracks, random: random);
    final options = generateOptions(draw.track, _allTracks, random: random);
    ref
        .read(gameControllerProvider.notifier)
        .startRound(draw.track, draw.remaining, options);
    _cancelLoaderTimers();
    if (!immediate) {
      _loaderShownAt = _now();
      _loaderTimeout = Timer(
        GameScreen.roundLoaderTimeout,
        _transitionToPlaying,
      );
    }
    setState(() {
      _lastResult = null;
      _roundState = immediate
          ? SoundRoundState.playing
          : SoundRoundState.loading;
    });
  }

  void _transitionToPlaying() {
    _cancelLoaderTimers();
    if (!mounted) {
      return;
    }
    setState(() {
      _roundState = SoundRoundState.playing;
      _timerActive = true;
      _roundStart = _now();
    });
  }

  void _handleLoadingComplete() => _beginRound(_initialPool, immediate: true);

  void _handleAudioReady() {
    if (_roundState == SoundRoundState.loading) {
      final remaining =
          GameScreen.roundLoaderMinimum - _now().difference(_loaderShownAt);
      if (remaining > Duration.zero) {
        _loaderMinimum?.cancel();
        _loaderMinimum = Timer(remaining, _transitionToPlaying);
      } else {
        _transitionToPlaying();
      }
    } else if (_roundState == SoundRoundState.playing && !_timerActive) {
      setState(() {
        _timerActive = true;
        _roundStart = _now();
      });
    }
  }

  void _handleAnswer(Object answer) {
    final game = ref.read(gameControllerProvider);
    final track = game.currentTrack;
    if (track == null || _roundState != SoundRoundState.playing) {
      return;
    }
    final correct = checkAnswer(answer, track, game.difficulty);
    final timeElapsed = _now().difference(_roundStart);
    final usedFullClip = game.relistenCount >= fullClipThreshold;
    setState(() {
      _timerActive = false;
      _lastResult = correct;
      _roundState = SoundRoundState.answered;
    });
    final controller = ref.read(gameControllerProvider.notifier);
    if (correct) {
      controller.answerCorrect(track);
    } else {
      controller.answerIncorrect();
      ref.read(audioControllerProvider.notifier).playQuack();
    }
    ref
        .read(achievementsControllerProvider)
        .checkAfterAnswer(
          correct: correct,
          timeElapsed: timeElapsed,
          usedFullClip: usedFullClip,
        );
  }

  void _handleTimerExpire() {
    if (_roundState == SoundRoundState.playing) {
      _handleAnswer(-1);
    }
  }

  void _handleNext() =>
      _beginRound(ref.read(gameControllerProvider).trackPool, immediate: false);

  void _exit() => ref.read(gameControllerProvider.notifier).resetGame();

  void _failRound(String message) {
    _cancelLoaderTimers();
    setState(() {
      _error = message;
      _timerActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(audioControllerProvider.select((audio) => audio.error), (
      _,
      error,
    ) {
      if (error != null && _error == null) {
        _failRound(error);
      }
    });
    final tokens = AppTokens.of(context);
    final labelStyle = CatLoader.defaultLabelStyle.copyWith(
      color: tokens.mutedForeground,
    );
    final error = _error;
    return Stack(
      fit: StackFit.expand,
      children: [
        ScreenBackground(
          child: error != null
              ? Center(
                  child: _ErrorView(message: error, onBack: _exit),
                )
              : LoadingGate(
                  loading: !_tracksReady,
                  label: GameScreen.loadingTracksLabel,
                  labelStyle: labelStyle,
                  onReady: _handleLoadingComplete,
                  child: _round(),
                ),
        ),
        _RoundLoaderOverlay(
          visible:
              _roundState == SoundRoundState.loading &&
              _tracksReady &&
              error == null,
          labelStyle: labelStyle,
        ),
      ],
    );
  }

  Widget _round() {
    final view = ref.watch(
      gameControllerProvider.select(
        (game) => (
          track: game.currentTrack,
          options: game.options,
          streak: game.streak,
          difficulty: game.difficulty,
          timer: roundTimerSeconds(
            game.difficulty,
            game.progress.settings.mediumTimer,
            game.progress.settings.hardTimer,
          ),
        ),
      ),
    );
    final track = view.track;
    return Padding(
      padding: const EdgeInsets.all(GameScreen.padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameHeader(streak: view.streak, onExit: _exit),
          if (track != null) ...[
            const SizedBox(height: GameScreen.gap),
            GameLane(
              key: const ValueKey('audio'),
              child: AudioPlayer(
                track: track,
                active: _roundState != SoundRoundState.answered,
                onLoaded: _handleAudioReady,
              ),
            ),
          ],
          if (view.timer > 0 && _roundState == SoundRoundState.playing) ...[
            const SizedBox(height: GameScreen.gap),
            GameLane(
              key: const ValueKey('timer'),
              child: TimerBar(
                duration: view.timer,
                onExpire: _handleTimerExpire,
                active: _timerActive,
              ),
            ),
          ],
          MotionPresence(
            spacing: GameScreen.gap,
            child: _roundMotion(track, view.difficulty, view.options),
          ),
        ],
      ),
    );
  }

  Motion? _roundMotion(Track? track, Difficulty difficulty, List<Track> opts) {
    final lastResult = _lastResult;
    if (track == null) {
      return null;
    }
    if (_roundState == SoundRoundState.playing) {
      return Motion(
        key: const ValueKey('quiz'),
        initial: const MotionPose(
          opacity: 0,
          offset: GameScreen.quizEntranceOffset,
        ),
        exit: const MotionPose(opacity: 0, offset: GameScreen.quizExitOffset),
        child: GameLane(
          child: QuizCard(
            difficulty: difficulty,
            options: opts,
            albumHint: difficulty == Difficulty.easy ? track.album.title : null,
            onAnswer: _handleAnswer,
            disabled: false,
          ),
        ),
      );
    }
    if (_roundState == SoundRoundState.answered && lastResult != null) {
      return Motion(
        key: const ValueKey('result'),
        initial: const MotionPose(opacity: 0, scale: GameScreen.resultScale),
        exit: const MotionPose(opacity: 0, scale: GameScreen.resultScale),
        child: ResultFeedback(
          correct: lastResult,
          correctTrack: track,
          onNext: _handleNext,
        ),
      );
    }
    return null;
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.lg.copyWith(color: AppPalette.red400),
        ),
        const SizedBox(height: GameScreen.errorGap),
        BackLink(
          label: GameScreen.backToMenuLabel,
          animateEntrance: false,
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _RoundLoaderOverlay extends StatefulWidget {
  const _RoundLoaderOverlay({required this.visible, required this.labelStyle});

  final bool visible;
  final TextStyle labelStyle;

  @override
  State<_RoundLoaderOverlay> createState() => _RoundLoaderOverlayState();
}

class _RoundLoaderOverlayState extends State<_RoundLoaderOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: GameScreen.overlayFade,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _fade,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      _fade.forward();
    }
  }

  @override
  void didUpdateWidget(_RoundLoaderOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) {
      return;
    }
    if (widget.visible) {
      _fade.forward();
    } else {
      _fade.reverse();
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return AboveAppChrome(
      child: AnimatedBuilder(
        animation: _fade,
        builder: (context, child) => _fade.isDismissed
            ? const SizedBox.shrink()
            : FadeTransition(opacity: _opacity, child: child),
        child: ColoredBox(
          color: tokens.background,
          child: Center(
            child: CatLoader(
              label: GameScreen.loadingNextTrackLabel,
              labelStyle: widget.labelStyle,
            ),
          ),
        ),
      ),
    );
  }
}
