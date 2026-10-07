import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/data/catalog/catalog_error.dart';
import 'package:swiftie_quiz/domain/engine/answer_matcher.dart';
import 'package:swiftie_quiz/domain/engine/game_engine.dart';
import 'package:swiftie_quiz/domain/engine/option_generator.dart';
import 'package:swiftie_quiz/domain/engine/relisten_schedule.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/achievements_controller.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/misu_controller.dart';
import 'package:swiftie_quiz/state/play_history_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/game/answer_list.dart';
import 'package:swiftie_quiz/ui/game/game_top_bar.dart';
import 'package:swiftie_quiz/ui/game/next_prompt.dart';
import 'package:swiftie_quiz/ui/game/praise_lines.dart';
import 'package:swiftie_quiz/ui/game/quack_burst.dart';
import 'package:swiftie_quiz/ui/game/record_player.dart';
import 'package:swiftie_quiz/ui/game/round_heading.dart';
import 'package:swiftie_quiz/ui/game/transport_bar.dart';
import 'package:swiftie_quiz/ui/kit/modal_stack.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/kit/serif_input.dart';
import 'package:swiftie_quiz/ui/kit/text_link.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/domain/util/song_title.dart';

int roundTimerSeconds(Difficulty difficulty, int mediumTimer, int hardTimer) =>
    switch (difficulty) {
      Difficulty.easy => 0,
      Difficulty.medium => mediumTimer,
      Difficulty.hard => hardTimer,
    };

String songTitle(Track track) => displaySongTitle(
  track.titleShort.isNotEmpty ? track.titleShort : track.title,
);

String difficultyLabel(Difficulty difficulty) => switch (difficulty) {
  Difficulty.easy => 'Easy',
  Difficulty.medium => 'Medium',
  Difficulty.hard => 'Hard',
};

String eraNameOf(Catalogue catalogue, Track track) =>
    catalogue.eraOfTrack(track)?.eraName ?? track.album.title;

Color? eraPlaceholderOf(Catalogue catalogue, Track? track) =>
    switch (track == null ? null : catalogue.eraOfTrack(track)) {
      final era? => Color(era.placeholderArgb),
      null => null,
    };

String trackCaption(Catalogue catalogue, Track track) {
  final position = track.trackPosition;
  return [
    eraNameOf(catalogue, track),
    ?versionLabel(track.title, shown: songTitle(track)),
    if (position != null && catalogue.eraOfTrack(track)?.key != singlesEra.key)
      'track $position',
  ].join(' · ');
}

int? answerKeyIndex(LogicalKeyboardKey key) => switch (key) {
  LogicalKeyboardKey.digit1 || LogicalKeyboardKey.numpad1 => 0,
  LogicalKeyboardKey.digit2 || LogicalKeyboardKey.numpad2 => 1,
  LogicalKeyboardKey.digit3 || LogicalKeyboardKey.numpad3 => 2,
  LogicalKeyboardKey.digit4 || LogicalKeyboardKey.numpad4 => 3,
  _ => null,
};

bool isNextKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;

typedef RoundAnswer = ({
  Object? pick,
  bool correct,
  bool timedOut,
  bool close,
  String praise,
});

RoundAnswer songAnswer(
  Object? pick,
  Track track,
  Difficulty difficulty,
  QuizType quizType, {
  required bool timedOut,
}) {
  final correct =
      !timedOut && pick != null && checkAnswer(pick, track, difficulty);
  return (
    pick: pick,
    correct: correct,
    timedOut: timedOut,
    close:
        correct &&
        pick is String &&
        normalizeTitle(pick) != normalizeTitle(track.title),
    praise: correct ? drawNextMessage(quizType) : '',
  );
}

int? pickedIndexOf(List<Track> options, RoundAnswer? answer) {
  final pick = answer?.pick;
  if (pick is! int) {
    return null;
  }
  final index = options.indexWhere((option) => option.id == pick);
  return index < 0 ? null : index;
}

String? typedNoteOf(RoundAnswer? answer) => switch (answer?.pick) {
  final String typed when typed.isNotEmpty => GameScreen.youTyped(typed),
  _ => null,
};

typedef RoundTime = ({int total, int left, bool running});

const RoundTime untimedRound = (total: 0, left: 0, running: false);

extension RoundTimeView on RoundTime {
  bool get timed => total > 0;

  double? get fraction => timed ? left / total : null;

  int get secondsLeft => (left / RoundTimers.ticksPerSecond).ceil();

  bool get urgent => timed && GameTopBar.urgentAt(left / total);
}

String playingSubline(RoundTime time, {required bool coverHint}) {
  if (time.timed) {
    return GameScreen.secondsLeft(time.secondsLeft);
  }
  return coverHint ? GameScreen.coverHintLine : GameScreen.takeYourTimeLine;
}

String songAnsweredSubline(
  Catalogue catalogue,
  Track track,
  RoundAnswer answer,
) {
  if (!answer.correct) {
    return trackCaption(catalogue, track);
  }
  return answer.close
      ? GameScreen.closeEnough(songTitle(track))
      : answer.praise;
}

mixin RoundTimers<T extends StatefulWidget> on State<T> {
  static const Duration tick = Duration(milliseconds: 100);
  static const int ticksPerSecond = 10;
  static const Duration nextDelay = Duration(seconds: 2);

  final ValueNotifier<RoundTime> roundTime = ValueNotifier(untimedRound);
  Timer? _countdown;
  Timer? _nextDelay;
  bool _nextReady = false;

  bool get nextReady => _nextReady;

  void onTimeUp();

  void resetRound(int seconds) {
    _countdown?.cancel();
    _countdown = null;
    _nextDelay?.cancel();
    _nextDelay = null;
    _nextReady = false;
    final ticks = seconds * ticksPerSecond;
    roundTime.value = (total: ticks, left: ticks, running: false);
  }

  void startCountdown() {
    final time = roundTime.value;
    if (!time.timed || _countdown != null || time.left <= 0) {
      return;
    }
    roundTime.value = (total: time.total, left: time.left, running: true);
    _countdown = Timer.periodic(tick, (_) => _tick());
  }

  void stopCountdown() {
    _countdown?.cancel();
    _countdown = null;
    final time = roundTime.value;
    if (time.running) {
      roundTime.value = (total: time.total, left: time.left, running: false);
    }
  }

  void armNext() {
    _nextDelay?.cancel();
    _nextDelay = Timer(nextDelay, () {
      _nextDelay = null;
      if (mounted) {
        setState(() => _nextReady = true);
      }
    });
  }

  void _tick() {
    final time = roundTime.value;
    final left = time.left - 1;
    if (left > 0) {
      roundTime.value = (total: time.total, left: left, running: true);
      return;
    }
    _countdown?.cancel();
    _countdown = null;
    roundTime.value = (total: time.total, left: 0, running: false);
    onTimeUp();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _nextDelay?.cancel();
    roundTime.dispose();
    super.dispose();
  }
}

enum SoundStage { loading, playing, answered }

final class _ScopeLifetime {
  bool _ended = false;

  bool get ended => _ended;

  void end() => _ended = true;
}

final _scopeLifetimeProvider = Provider<_ScopeLifetime>((ref) {
  final lifetime = _ScopeLifetime();
  ref.onDispose(lifetime.end);
  return lifetime;
});

TransportStatus transportStatusOf(AudioState audio) {
  if (audio.loading) {
    return TransportStatus.loading;
  }
  if (audio.playing) {
    return TransportStatus.playing;
  }
  if (audio.paused) {
    return TransportStatus.paused;
  }
  return audio.progress > 0 ? TransportStatus.ended : TransportStatus.idle;
}

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  static const Duration roundLoaderMinimum = Duration(milliseconds: 450);
  static const int maxUnplayableSkips = 3;
  static const Duration roundLoaderTimeout = Duration(seconds: 8);
  static const String modeLabel = 'Name That Song';
  static const String loadingTracksLabel = 'Loading tracks...';
  static const String loadingNextTrackLabel = 'Loading next track...';
  static const String backToMenuLink = '← Back to menu';
  static const String soundQuestion = "What's playing?";
  static const String itWas = 'It was ';
  static const String timeUpItWas = "Time's up. It was ";
  static const String songEnd = '.';
  static const String takeYourTimeLine = 'Take your time.';
  static const String coverHintLine = 'Take your time. The cover is your hint.';

  static String secondsLeft(int seconds) => '$seconds seconds left.';

  static String closeEnough(String song) =>
      "Close enough. It's spelled “$song”.";

  static String youTyped(String typed) => 'You typed “$typed”.';

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with RoundTimers<GameScreen> {
  late final ProviderContainer _container;
  late final _ScopeLifetime _scope;
  final FocusNode _keys = FocusNode(
    debugLabel: 'GameScreen keys',
    skipTraversal: true,
  );
  final FocusNode _typedFocus = FocusNode(debugLabel: 'GameScreen answer');
  final TextEditingController _typed = TextEditingController();
  bool _tracksReady = false;
  bool _roundShown = false;
  bool _failed = false;
  bool _redraw = false;
  Track? _unheard;
  int _unplayableSkips = 0;
  String? _failure;
  List<Track> _allTracks = const [];
  SoundStage _stage = SoundStage.playing;
  RoundAnswer? _result;
  Track? _lastTrack;
  bool _clockStarted = false;
  DateTime _roundStart = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _loaderShownAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _loaderTimeout;
  Timer? _loaderMinimum;
  int _loadRequest = 0;
  int _playRequest = 0;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _scope = ref.read(_scopeLifetimeProvider);
    unawaited(_loadTracks());
  }

  @override
  void dispose() {
    _cancelLoaderTimers();
    _keys.dispose();
    _typedFocus.dispose();
    _typed.dispose();
    final container = _container;
    final scope = _scope;
    scheduleMicrotask(() {
      if (!scope.ended) {
        container.read(audioControllerProvider.notifier).reset();
      }
    });
    super.dispose();
  }

  DateTime _now() => ref.read(clockProvider)();

  Difficulty get _difficulty => ref.read(gameControllerProvider).difficulty;

  Future<void> _loadTracks() async {
    final request = ++_loadRequest;
    _loaderShownAt = _now();
    try {
      final tracks = await ref
          .read(catalogControllerProvider.notifier)
          .loadTrackPool();
      if (!mounted || request != _loadRequest) {
        return;
      }
      if (tracks.pool.isEmpty) {
        _fail(null);
        return;
      }
      setState(() {
        _allTracks = tracks.allTracks;
        _tracksReady = true;
      });
      _beginRound(tracks.pool);
    } on Object catch (error) {
      if (mounted && request == _loadRequest) {
        _fail(error is RateLimited ? error.message : null);
      }
    }
  }

  void _cancelLoaderTimers() {
    _loaderTimeout?.cancel();
    _loaderTimeout = null;
    _loaderMinimum?.cancel();
    _loaderMinimum = null;
  }

  void _beginRound(List<Track> pool) {
    final random = ref.read(randomProvider);
    final draw = drawNextTrack(
      pool,
      _allTracks,
      heard: ref.read(playHistoryProvider).heard,
      random: random,
    );
    _unheard = draw.track;
    final options = generateOptions(draw.track, _allTracks, random: random);
    final redraw = _redraw;
    _redraw = false;
    ref
        .read(gameControllerProvider.notifier)
        .startRound(draw.track, draw.remaining, options, redraw: redraw);
    final game = ref.read(gameControllerProvider);
    _cancelLoaderTimers();
    resetRound(
      roundTimerSeconds(
        game.difficulty,
        game.progress.settings.mediumTimer,
        game.progress.settings.hardTimer,
      ),
    );
    _typed.clear();
    _clockStarted = false;
    if (_roundShown) {
      _loaderShownAt = _now();
    }
    _loaderTimeout = Timer(GameScreen.roundLoaderTimeout, _revealRound);
    if (draw.track.album.coverMedium case final cover?) {
      unawaited(precacheImage(NetworkImage(cover), context));
    }
    setState(() {
      _result = null;
      _stage = SoundStage.loading;
    });
    unawaited(_play(draw.track));
  }

  Future<void> _play(Track track) async {
    final request = ++_playRequest;
    await ref.read(audioControllerProvider.notifier).play(track);
    if (mounted && request == _playRequest) {
      _handleAudioReady();
    }
  }

  void _handleAudioReady() {
    if (_failed) {
      return;
    }
    final audio = ref.read(audioControllerProvider);
    if (audio.error == null && !audio.unavailable) {
      _unplayableSkips = 0;
      if (_unheard case final track?) {
        _unheard = null;
        ref.read(playHistoryProvider.notifier).heard(track);
      }
      if (_upcoming() case final next?) {
        unawaited(
          ref.read(audioControllerProvider.notifier).prefetchPreview(next),
        );
      }
    }
    if (_stage == SoundStage.loading) {
      final remaining =
          GameScreen.roundLoaderMinimum - _now().difference(_loaderShownAt);
      if (remaining > Duration.zero) {
        _loaderMinimum?.cancel();
        _loaderMinimum = Timer(remaining, _revealRound);
      } else {
        _revealRound();
      }
    } else if (_stage == SoundStage.playing) {
      _startClock();
    }
  }

  Track? _upcoming() {
    final pool = ref.read(gameControllerProvider).trackPool;
    if (pool.isNotEmpty) {
      return pool.first;
    }
    final refill = createTrackPool(
      _allTracks,
      heard: ref.read(playHistoryProvider).heard,
      random: ref.read(randomProvider),
    );
    ref.read(gameControllerProvider.notifier).setTrackPool(refill);
    return refill.firstOrNull;
  }

  void _revealRound() {
    _cancelLoaderTimers();
    if (!mounted || _failed || _stage != SoundStage.loading) {
      return;
    }
    setState(() {
      _stage = SoundStage.playing;
      _roundShown = true;
    });
    if (!ref.read(audioControllerProvider).loading) {
      _startClock();
    }
    _focusInput();
  }

  void _startClock() {
    if (_clockStarted) {
      return;
    }
    _clockStarted = true;
    _roundStart = _now();
    startCountdown();
  }

  void _togglePlay() {
    final track = ref.read(gameControllerProvider).currentTrack;
    final audio = ref.read(audioControllerProvider.notifier);
    final state = ref.read(audioControllerProvider);
    if (state.loading || track == null) {
      return;
    }
    if (state.playing) {
      audio.pause();
    } else if (state.paused) {
      audio.resume();
    } else if (state.progress > 0) {
      audio.relisten();
    } else {
      unawaited(_play(track));
    }
  }

  void _answer(Object? pick, {bool timedOut = false}) {
    final game = ref.read(gameControllerProvider);
    final track = game.currentTrack;
    if (track == null || _stage != SoundStage.playing) {
      return;
    }
    final result = songAnswer(
      pick,
      track,
      game.difficulty,
      QuizType.sound,
      timedOut: timedOut,
    );
    final timeElapsed = _now().difference(_roundStart);
    final usedFullClip = game.relistenCount >= fullClipThreshold;
    stopCountdown();
    _cancelLoaderTimers();
    _playRequest += 1;
    final audio = ref.read(audioControllerProvider.notifier)..reset();
    final controller = ref.read(gameControllerProvider.notifier);
    if (result.correct) {
      controller.answerCorrect(track);
    } else {
      controller.answerIncorrect(track);
      audio.playQuack();
    }
    ref
        .read(achievementsControllerProvider)
        .checkAfterAnswer(
          correct: result.correct,
          timeElapsed: timeElapsed,
          usedFullClip: usedFullClip,
          track: track,
        );
    final after = ref.read(gameControllerProvider);
    ref
        .read(misuControllerProvider.notifier)
        .afterAnswer(
          correct: result.correct,
          streak: after.streak,
          missRun: after.quackCount,
          roundNumber: after.roundNumber,
        );
    setState(() {
      _stage = SoundStage.answered;
      _result = result;
      _lastTrack = track;
    });
    armNext();
    _focusKeys();
  }

  @override
  void onTimeUp() => _answer(null, timedOut: true);

  void _submitTyped() {
    final typed = _typed.text.trim();
    if (typed.isEmpty) {
      _typedFocus.requestFocus();
      return;
    }
    _answer(typed);
  }

  void _handleNext() {
    if (_stage != SoundStage.answered || !nextReady) {
      return;
    }
    final game = ref.read(gameControllerProvider);
    if (game.isLastQuickRound) {
      ref.read(gameControllerProvider.notifier).finishQuickRound();
      return;
    }
    _beginRound(game.trackPool);
  }

  bool _handleKey(LogicalKeyboardKey key) {
    if (_failed || !_tracksReady) {
      return false;
    }
    if (isNextKey(key)) {
      if (_stage != SoundStage.answered) {
        return false;
      }
      _handleNext();
      return true;
    }
    if (_stage != SoundStage.playing) {
      return false;
    }
    if (key == LogicalKeyboardKey.space) {
      _togglePlay();
      return true;
    }
    final index = answerKeyIndex(key);
    final options = ref.read(gameControllerProvider).options;
    if (index == null ||
        _difficulty == Difficulty.hard ||
        index >= options.length) {
      return false;
    }
    _answer(options[index].id);
    return true;
  }

  void _focusKeys() {
    if (mounted &&
        ref.read(modalStackProvider).isEmpty &&
        !_keys.hasPrimaryFocus) {
      _keys.requestFocus();
    }
  }

  void _focusInput() {
    if (_difficulty != Difficulty.hard) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _stage == SoundStage.playing &&
          ref.read(modalStackProvider).isEmpty) {
        _typedFocus.requestFocus();
      }
    });
  }

  void _fail(String? message) {
    _cancelLoaderTimers();
    stopCountdown();
    _playRequest += 1;
    setState(() {
      _failed = true;
      _failure = message;
    });
  }

  void _skipUnplayable() {
    final current = ref.read(gameControllerProvider).currentTrack;
    _unplayableSkips += 1;
    final remaining = List<Track>.unmodifiable([
      for (final track in _allTracks)
        if (track.id != current?.id) track,
    ]);
    if (current == null ||
        remaining.isEmpty ||
        _unplayableSkips > GameScreen.maxUnplayableSkips) {
      _fail(null);
      return;
    }
    _allTracks = remaining;
    _redraw = true;
    _beginRound(ref.read(gameControllerProvider).trackPool);
  }

  bool get _canSkip =>
      _tracksReady && !_failed && _stage != SoundStage.answered;

  void _retry() {
    _redraw = true;
    _unplayableSkips = 0;
    ref.read(audioControllerProvider.notifier).reset();
    setState(() {
      _failed = false;
      _failure = null;
      _tracksReady = false;
      _roundShown = false;
      _result = null;
    });
    unawaited(_loadTracks());
  }

  void _exit() => ref.read(gameControllerProvider.notifier).resetGame();

  @override
  Widget build(BuildContext context) {
    ref.listen(audioControllerProvider.select((audio) => audio.error), (
      _,
      error,
    ) {
      if (error != null && _canSkip) {
        _skipUnplayable();
      }
    });
    ref.listen(audioControllerProvider.select((audio) => audio.unavailable), (
      _,
      unavailable,
    ) {
      if (unavailable && _canSkip) {
        _skipUnplayable();
      }
    });
    final Widget body;
    if (_failed) {
      body = NeedleWontDrop(message: _failure, onRetry: _retry, onBack: _exit);
    } else if (!_tracksReady || !_roundShown) {
      body = GameFirstLoad(onBack: _exit);
    } else {
      body = _round(context);
    }
    return ScreenEnter(
      child: GameKeys(focusNode: _keys, onKey: _handleKey, child: body),
    );
  }

  Widget _round(BuildContext context) {
    final game = ref.watch(
      gameControllerProvider.select(
        (game) => (
          track: game.currentTrack,
          options: game.options,
          streak: game.streak,
          difficulty: game.difficulty,
          round: game.roundNumber,
          total: game.quickRoundTotal,
          misses: game.quackCount,
          last: game.isLastQuickRound,
        ),
      ),
    );
    final spinning = ref.watch(
      audioControllerProvider.select((audio) => audio.playing),
    );
    final catalogue = ref.watch(
      catalogControllerProvider.select((catalog) => catalog.catalogue),
    );
    final track = game.track;
    if (track == null) {
      return GameFirstLoad(onBack: _exit);
    }
    final tokens = AppTokens.of(context);
    final result = _result;
    final answered = result != null;
    final easy = game.difficulty == Difficulty.easy;
    final options = game.options;
    final rightIndex = options.indexWhere((option) => option.id == track.id);
    final note = typedNoteOf(result);
    return Stack(
      fit: StackFit.expand,
      children: [
        GameStage(
          topBar: RoundTopBar(
            modeLabel: GameScreen.modeLabel,
            difficulty: game.difficulty,
            streak: game.streak,
            round: game.round,
            totalRounds: game.total,
            time: roundTime,
            onExit: _exit,
          ),
          left: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: RecordPlayer(
                revealed: answered || easy,
                answered: answered,
                spinning: spinning,
                coverUrl: track.album.coverMedium,
                placeholder: eraPlaceholderOf(catalogue, track),
                previousCoverUrl: _lastTrack?.album.coverMedium,
                previousPlaceholder: eraPlaceholderOf(catalogue, _lastTrack),
              ),
            ),
            if (!answered) _SoundTransport(onToggle: _togglePlay),
            if (answered || easy)
              Text(
                trackCaption(catalogue, track),
                textAlign: TextAlign.center,
                style: AppType.small.copyWith(color: tokens.mut),
              ),
          ],
          right: [
            SongRoundHeading(
              catalogue: catalogue,
              question: GameScreen.soundQuestion,
              track: track,
              answer: result,
              time: roundTime,
              coverHint: easy,
            ),
            if (game.difficulty != Difficulty.hard)
              AnswerList(
                labels: [for (final option in options) songTitle(option)],
                onPick: (index) => _answer(options[index].id),
                answered: answered,
                rightIndex: rightIndex < 0 ? null : rightIndex,
                pickedIndex: pickedIndexOf(options, result),
              )
            else if (!answered)
              TypedAnswer(
                controller: _typed,
                focusNode: _typedFocus,
                onSubmit: _submitTyped,
              )
            else if (note != null)
              Text(note, style: AppType.body.copyWith(color: tokens.mut)),
            if (answered)
              NextPrompt(
                onNext: _handleNext,
                enabled: nextReady,
                label: game.last ? NextPrompt.seeRound : NextPrompt.nextSong,
              ),
          ],
          quack: result != null && !result.correct
              ? QuackBurst(key: ValueKey(game.round), level: game.misses)
              : null,
        ),
        if (_stage == SoundStage.loading) const BetweenSongsCover(),
      ],
    );
  }
}

class _SoundTransport extends ConsumerWidget {
  const _SoundTransport({required this.onToggle});

  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioControllerProvider);
    final hasClip = audio.clipDuration > 0;
    return TransportBar(
      status: transportStatusOf(audio),
      stage: audio.relistenStage,
      elapsed: hasClip ? audio.progress * audio.clipDuration : 0,
      duration: hasClip ? audio.clipDuration : sliceDurationSeconds,
      onToggle: onToggle,
      spaceToggles:
          ref.watch(gameControllerProvider.select((game) => game.difficulty)) !=
          Difficulty.hard,
    );
  }
}

class GameKeys extends ConsumerStatefulWidget {
  const GameKeys({
    super.key,
    required this.focusNode,
    required this.onKey,
    required this.child,
  });

  final FocusNode focusNode;
  final bool Function(LogicalKeyboardKey key) onKey;
  final Widget child;

  static bool get typing =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorStateOfType<EditableTextState>() !=
      null;

  static bool activates(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.space || isNextKey(key);

  @override
  ConsumerState<GameKeys> createState() => _GameKeysState();
}

class _GameKeysState extends ConsumerState<GameKeys> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_reclaim);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reclaim());
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_reclaim);
    super.dispose();
  }

  void _reclaim() {
    if (!mounted || ref.read(modalStackProvider).isNotEmpty) {
      return;
    }
    final node = widget.focusNode;
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null ||
        (primary is FocusScopeNode && node.ancestors.contains(primary))) {
      node.requestFocus();
    }
  }

  KeyEventResult _handle(bool idle, KeyEvent event) {
    if (!idle || event is! KeyDownEvent || GameKeys.typing) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (GameKeys.activates(key) && !widget.focusNode.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }
    return widget.onKey(key) ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(modalStackProvider, (_, open) {
      if (open.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _reclaim());
      }
    });
    final idle = ref.watch(modalStackProvider).isEmpty;
    return Focus(
      focusNode: widget.focusNode,
      autofocus: true,
      onKeyEvent: (_, event) => _handle(idle, event),
      child: widget.child,
    );
  }
}

class RoundTopBar extends StatelessWidget {
  const RoundTopBar({
    super.key,
    required this.modeLabel,
    required this.difficulty,
    required this.streak,
    required this.round,
    required this.totalRounds,
    required this.time,
    required this.onExit,
  });

  final String modeLabel;
  final Difficulty difficulty;
  final int streak;
  final int round;
  final int? totalRounds;
  final ValueListenable<RoundTime> time;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RoundTime>(
      valueListenable: time,
      builder: (context, time, _) => GameTopBar(
        modeLabel: modeLabel,
        difficultyLabel: difficultyLabel(difficulty),
        streak: streak,
        onExit: onExit,
        round: totalRounds == null ? null : round,
        totalRounds: totalRounds,
        timeFraction: time.fraction,
        timerRunning: time.running,
      ),
    );
  }
}

class SongRoundHeading extends StatelessWidget {
  const SongRoundHeading({
    super.key,
    required this.question,
    required this.catalogue,
    required this.track,
    required this.answer,
    required this.time,
    required this.coverHint,
  });

  final String question;
  final Catalogue catalogue;
  final Track track;
  final RoundAnswer? answer;
  final ValueListenable<RoundTime> time;
  final bool coverHint;

  @override
  Widget build(BuildContext context) {
    final answer = this.answer;
    if (answer == null) {
      return ValueListenableBuilder<RoundTime>(
        valueListenable: time,
        builder: (context, time, _) => RoundHeading(
          pre: question,
          subline: playingSubline(time, coverHint: coverHint),
          urgent: time.urgent,
        ),
      );
    }
    return RoundHeading(
      pre: answer.timedOut ? GameScreen.timeUpItWas : GameScreen.itWas,
      song: songTitle(track),
      post: GameScreen.songEnd,
      subline: songAnsweredSubline(catalogue, track, answer),
    );
  }
}

class GameStage extends StatelessWidget {
  const GameStage({
    super.key,
    required this.topBar,
    required this.left,
    required this.right,
    this.quack,
  });

  static const double padTop = 24;
  static const double padBottom = 40;
  static const double leftGap = 22;
  static const double rightGap = 24;

  final Widget topBar;
  final List<Widget> left;
  final List<Widget> right;
  final Widget? quack;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        topBar,
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                layout.padX,
                padTop,
                layout.padX,
                padBottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(
                    0,
                    constraints.maxHeight - padTop - padBottom,
                  ),
                ),
                child: Center(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: leftGap,
                          children: left,
                        ),
                      ),
                      SizedBox(width: layout.gap),
                      Expanded(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: rightGap,
                              children: right,
                            ),
                            if (quack case final quack?)
                              Positioned.fill(child: quack),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TypedAnswer extends StatelessWidget {
  const TypedAnswer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  static const String placeholder = 'Type the song title';
  static const String hint = 'Small typos are fine. Press Enter to submit.';
  static const String submitLabel = 'Submit';
  static const double fontSize = 34;
  static const double lineHeight = 42;
  static const double gap = 14;
  static const double hintGap = 12;
  static const double minInputWidth = 200;
  static const double submitWidth = 96;
  static const double waitingOpacity = 0.45;
  static const submitPadding = EdgeInsets.symmetric(
    vertical: 12,
    horizontal: 22,
  );

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final input = SerifInput(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      fontSize: fontSize,
      lineHeight: lineHeight,
      onSubmitted: (_) => onSubmit(),
    );
    final submit = ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final ready = controller.text.trim().isNotEmpty;
        return AnimatedOpacity(
          opacity: ready ? 1 : waitingOpacity,
          duration: AppMotion.duration(context, AppMotion.selectionShift),
          curve: Curves.ease,
          child: Pressable(
            onPressed: onSubmit,
            enabled: ready,
            focusRadius: PillButton.radius,
            builder: (context, _) => DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.btn,
                borderRadius: PillButton.radius,
              ),
              child: Padding(
                padding: submitPadding,
                child: Text(
                  submitLabel,
                  style: AppType.sized(
                    15,
                    20,
                    weight: FontWeight.w600,
                  ).copyWith(color: tokens.onBtn),
                ),
              ),
            ),
          ),
        );
      },
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: hintGap,
      children: [
        LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth >= minInputWidth + gap + submitWidth
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: gap,
                  children: [
                    Expanded(child: input),
                    submit,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: gap,
                  children: [input, submit],
                ),
        ),
        Text(hint, style: AppType.caption.copyWith(color: tokens.faint)),
      ],
    );
  }
}

class GameFirstLoad extends StatelessWidget {
  const GameFirstLoad({super.key, required this.onBack});

  static const double loaderSize = 220;
  static const double gap = 20;
  static const double padBottom = 40;

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: padBottom),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: gap,
          children: [
            CatLoader(
              px: loaderSize,
              label: GameScreen.loadingTracksLabel,
              labelStyle: CatLoader.defaultLabelStyle.copyWith(
                color: tokens.mut,
              ),
            ),
            TextLink(label: GameScreen.backToMenuLink, onTap: onBack),
          ],
        ),
      ),
    );
  }
}

class NeedleWontDrop extends StatelessWidget {
  const NeedleWontDrop({
    super.key,
    required this.onRetry,
    required this.onBack,
    this.message,
  });

  static const String title = "The needle won't drop.";
  static const String defaultMessage =
      "We couldn't load the tracks from Deezer. "
      'Check your connection and try again.';
  static const String retryLabel = 'Try again';
  static const String backToMenuLabel = 'Back to menu';
  static const double padBottom = 60;
  static const double gap = 12;
  static const double actionsPadTop = 8;
  static const double messageMaxWidth = 420;

  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(layout.padX, 0, layout.padX, padBottom),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: gap,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppType.display(36, height: 40 / 36, color: tokens.fg),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: messageMaxWidth),
              child: Text(
                message ?? defaultMessage,
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: tokens.mut),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: actionsPadTop),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: gap,
                runSpacing: gap,
                children: [
                  PillButton(
                    label: retryLabel,
                    onPressed: onRetry,
                    size: PillSize.large,
                  ),
                  PillButton(
                    label: backToMenuLabel,
                    onPressed: onBack,
                    kind: PillKind.outline,
                    size: PillSize.large,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BetweenSongsCover extends StatelessWidget {
  const BetweenSongsCover({super.key});

  static const double loaderSize = 200;
  static const rise = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return RiseIn(
      duration: rise,
      child: ColoredBox(
        color: tokens.bg,
        child: Center(
          child: CatLoader(
            px: loaderSize,
            label: GameScreen.loadingNextTrackLabel,
            labelStyle: CatLoader.defaultLabelStyle.copyWith(color: tokens.mut),
          ),
        ),
      ),
    );
  }
}
