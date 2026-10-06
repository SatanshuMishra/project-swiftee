import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/answer_matcher.dart';
import 'package:swiftie_quiz/domain/engine/lyric_processor.dart';
import 'package:swiftie_quiz/domain/engine/option_generator.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/achievements_controller.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/lyrics_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/game/game_header.dart';
import 'package:swiftie_quiz/ui/game/lyric_snippet_card.dart';
import 'package:swiftie_quiz/ui/game/lyrics_or_lie_card.dart';
import 'package:swiftie_quiz/ui/game/quiz_card.dart';
import 'package:swiftie_quiz/ui/game/result_feedback.dart';
import 'package:swiftie_quiz/ui/widgets/motion.dart';
import 'package:swiftie_quiz/ui/game/timer_bar.dart';
import 'package:swiftie_quiz/ui/screens/game_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/screen_background.dart';

int lyricsLineCount(LyricsMode? mode, Difficulty difficulty) =>
    switch ((mode, difficulty)) {
      (LyricsMode.nameThatSong, Difficulty.easy) => 4,
      (LyricsMode.nameThatSong, Difficulty.medium) => 3,
      (LyricsMode.nameThatSong, Difficulty.hard) => 2,
      (LyricsMode.lyricsOrLie, Difficulty.easy) => 3,
      (LyricsMode.lyricsOrLie, Difficulty.medium) => 2,
      (LyricsMode.lyricsOrLie, Difficulty.hard) => 1,
      (null, _) => 1,
    };

enum LyricsRoundState { playing, answered }

final class _LyricsRound {
  const _LyricsRound({
    required this.entry,
    required this.snippetLines,
    required this.decoy,
  });

  final TrackWithLyrics entry;
  final List<String> snippetLines;
  final DecoyResult? decoy;
}

final class _TimedOut {
  const _TimedOut();
}

class LyricsGameScreen extends ConsumerStatefulWidget {
  const LyricsGameScreen({super.key});

  static const String preparingLabel = 'Preparing round...';
  static const double gap = 24;

  @override
  ConsumerState<LyricsGameScreen> createState() => _LyricsGameScreenState();
}

class _LyricsGameScreenState extends ConsumerState<LyricsGameScreen> {
  LyricsRoundState _roundState = LyricsRoundState.playing;
  _LyricsRound? _round;
  bool? _lastResult;
  bool _timerActive = false;
  List<Track> _options = const [];
  List<Track> _allTracks = const [];
  DateTime _roundStart = DateTime.fromMillisecondsSinceEpoch(0);
  int _poolIndex = 0;
  bool _started = false;
  Timer? _firstRound;

  @override
  void initState() {
    super.initState();
    _scheduleFirstRound();
  }

  @override
  void dispose() {
    _firstRound?.cancel();
    super.dispose();
  }

  DateTime _now() => ref.read(clockProvider)();

  void _scheduleFirstRound() {
    if (_started ||
        _firstRound != null ||
        ref.read(gameControllerProvider).lyricsPool.isEmpty) {
      return;
    }
    _firstRound = Timer(Duration.zero, () {
      _firstRound = null;
      _started = true;
      final game = ref.read(gameControllerProvider);
      _allTracks = game.lyricsAvailableTracks.isNotEmpty
          ? game.lyricsAvailableTracks
          : [for (final entry in game.lyricsPool) entry.track];
      _beginRound();
    });
  }

  void _beginRound() {
    final entry = ref.read(gameControllerProvider.notifier).nextLyricsTrack();
    if (entry == null) {
      return;
    }
    final game = ref.read(gameControllerProvider);
    final mode = game.lyricsMode;
    final difficulty = game.difficulty;
    final random = ref.read(randomProvider);
    final lineCount = lyricsLineCount(mode, difficulty);
    var snippetLines = const <String>[];
    var options = _options;
    DecoyResult? decoy;
    switch (mode) {
      case LyricsMode.nameThatSong:
        final snippet = extractSnippet(
          entry.lyrics.lines,
          lineCount,
          difficulty == Difficulty.easy,
          difficulty == Difficulty.hard,
          random: random,
        );
        snippetLines = sanitiseSnippet(snippet.lines, entry.track.title);
        if (difficulty != Difficulty.hard) {
          options = generateOptions(
            entry.track,
            _allTracks.isNotEmpty
                ? _allTracks
                : [for (final pooled in game.lyricsPool) pooled.track],
            random: random,
          );
        }
      case LyricsMode.lyricsOrLie:
        decoy = selectDecoyOrReal(
          entry.lyrics.lines,
          game.decoyPool,
          difficulty,
          currentTrackAlbum: entry.lyrics.sourceAlbum,
          lineCount: lineCount,
          currentTrackTitle: entry.track.title,
          random: random,
        );
      case null:
        break;
    }
    final startedAt = _now();
    setState(() {
      _round = _LyricsRound(
        entry: entry,
        snippetLines: snippetLines,
        decoy: decoy,
      );
      _options = options;
      _roundState = LyricsRoundState.playing;
      _lastResult = null;
      _timerActive = true;
      _roundStart = startedAt;
      _poolIndex += 1;
    });
  }

  void _handleAnswer(Object answer) {
    final round = _round;
    if (round == null || _roundState != LyricsRoundState.playing) {
      return;
    }
    final game = ref.read(gameControllerProvider);
    final mode = game.lyricsMode;
    final track = round.entry.track;
    final decoy = round.decoy;
    final timeElapsed = _now().difference(_roundStart);
    final correct = switch (mode) {
      LyricsMode.nameThatSong => checkAnswer(answer, track, game.difficulty),
      LyricsMode.lyricsOrLie =>
        decoy != null && answer is bool && answer == decoy.isReal,
      null => false,
    };
    setState(() {
      _timerActive = false;
      _lastResult = correct;
      _roundState = LyricsRoundState.answered;
    });
    final controller = ref.read(gameControllerProvider.notifier);
    if (correct) {
      controller.answerCorrect(track);
      if (mode != null) {
        controller.incrementLyricsStat(mode);
      }
    } else {
      controller.answerIncorrect();
      ref.read(audioControllerProvider.notifier).playQuack();
    }
    ref
        .read(achievementsControllerProvider)
        .checkAfterAnswer(
          correct: correct,
          timeElapsed: timeElapsed,
          usedFullClip: false,
        );
    unawaited(ref.read(lyricsControllerProvider).extendPool());
  }

  void _handleTimerExpire() {
    if (_roundState != LyricsRoundState.playing) {
      return;
    }
    _handleAnswer(
      ref.read(gameControllerProvider).lyricsMode == LyricsMode.lyricsOrLie
          ? const _TimedOut()
          : -1,
    );
  }

  void _exit() => ref.read(gameControllerProvider.notifier).resetGame();

  @override
  Widget build(BuildContext context) {
    ref.listen(
      gameControllerProvider.select((game) => game.lyricsPool.isNotEmpty),
      (_, hasPool) {
        if (hasPool) {
          _scheduleFirstRound();
        }
      },
    );
    final tokens = AppTokens.of(context);
    final view = ref.watch(
      gameControllerProvider.select(
        (game) => (
          streak: game.streak,
          mode: game.lyricsMode,
          difficulty: game.difficulty,
          timer: roundTimerSeconds(
            game.difficulty,
            game.progress.settings.mediumTimer,
            game.progress.settings.hardTimer,
          ),
        ),
      ),
    );
    final round = _round;
    if (round == null) {
      return ScreenBackground(
        child: Center(
          child: Text(
            LyricsGameScreen.preparingLabel,
            style: AppText.base.copyWith(color: tokens.mutedForeground),
          ),
        ),
      );
    }
    return ScreenBackground(
      child: Padding(
        padding: const EdgeInsets.all(GameScreen.padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameHeader(streak: view.streak, onExit: _exit),
            if (view.timer > 0 && _roundState == LyricsRoundState.playing) ...[
              const SizedBox(height: LyricsGameScreen.gap),
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
              spacing: LyricsGameScreen.gap,
              child: _roundMotion(tokens, round, view.mode, view.difficulty),
            ),
          ],
        ),
      ),
    );
  }

  Motion? _roundMotion(
    AppTokens tokens,
    _LyricsRound round,
    LyricsMode? mode,
    Difficulty difficulty,
  ) {
    final lastResult = _lastResult;
    final track = round.entry.track;
    if (_roundState == LyricsRoundState.playing) {
      return Motion(
        key: ValueKey('quiz-$_poolIndex'),
        initial: const MotionPose(
          opacity: 0,
          offset: GameScreen.quizEntranceOffset,
        ),
        exit: const MotionPose(opacity: 0, offset: GameScreen.quizExitOffset),
        child: GameLane(child: _question(tokens, round, mode, difficulty)),
      );
    }
    if (lastResult == null) {
      return null;
    }
    return Motion(
      key: const ValueKey('result'),
      initial: const MotionPose(opacity: 0, scale: GameScreen.resultScale),
      exit: const MotionPose(opacity: 0, scale: GameScreen.resultScale),
      child: ResultFeedback(
        correct: lastResult,
        correctTrack: track,
        onNext: _beginRound,
        quizType: QuizType.lyrics,
        lyricsMode: mode,
        decoySourceSong: round.decoy?.sourceSong,
      ),
    );
  }

  Widget _question(
    AppTokens tokens,
    _LyricsRound round,
    LyricsMode? mode,
    Difficulty difficulty,
  ) {
    final track = round.entry.track;
    final decoy = round.decoy;
    switch (mode) {
      case LyricsMode.nameThatSong:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (difficulty == Difficulty.easy) ...[
              Text(
                'Album: ${track.album.title}',
                style: AppText.sm.copyWith(color: tokens.mutedForeground),
              ),
              const SizedBox(height: LyricsGameScreen.gap),
            ],
            LyricSnippetCard(lines: round.snippetLines),
            const SizedBox(height: LyricsGameScreen.gap),
            QuizCard(
              difficulty: difficulty,
              options: _options,
              albumHint: null,
              onAnswer: _handleAnswer,
              disabled: false,
            ),
          ],
        );
      case LyricsMode.lyricsOrLie when decoy != null:
        return LyricsOrLieCard(
          songTitle: track.titleShort.isNotEmpty
              ? track.titleShort
              : track.title,
          albumCover: track.album.coverMedium,
          showAlbumCover: difficulty == Difficulty.easy,
          lyricLines: decoy.lines,
          onAnswer: _handleAnswer,
          disabled: false,
        );
      case LyricsMode.lyricsOrLie || null:
        return const SizedBox.shrink();
    }
  }
}
