import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/lyric_processor.dart';
import 'package:swiftie_quiz/domain/engine/option_generator.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/achievements_controller.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/lyrics_controller.dart';
import 'package:swiftie_quiz/state/misu_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/game/answer_list.dart';
import 'package:swiftie_quiz/ui/game/lyric_paper.dart';
import 'package:swiftie_quiz/ui/game/next_prompt.dart';
import 'package:swiftie_quiz/ui/game/quack_burst.dart';
import 'package:swiftie_quiz/ui/game/record_player.dart';
import 'package:swiftie_quiz/ui/game/round_heading.dart';
import 'package:swiftie_quiz/ui/kit/modal_stack.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/screens/game_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/domain/util/song_title.dart';

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

String lyricsModeLabel(LyricsMode? mode) => switch (mode) {
  LyricsMode.lyricsOrLie => LyricsGameScreen.lyricsOrLieLabel,
  LyricsMode.nameThatSong || null => LyricsGameScreen.nameThatSongLabel,
};

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

class LyricsGameScreen extends ConsumerStatefulWidget {
  const LyricsGameScreen({super.key});

  static const String nameThatSongLabel = 'Lyrics · Name That Song';
  static const String lyricsOrLieLabel = 'Lyrics or Lie';
  static const String lyricsQuestion = 'Name that song.';
  static const String lieKicker = 'Is this lyric from';
  static const String rightVerdict = 'Right.';
  static const String wrongVerdict = 'Not this time.';
  static const String timeUpVerdict = "Time's up.";
  static const double lieGap = 18;

  static String realLine(String song) => "It's a real line from $song.";

  static String fakeLine(String? source) => switch (source) {
    final source? when source.isNotEmpty =>
      "It's a fake. That line is from ${displaySongTitle(source)}.",
    _ => "It's a fake.",
  };

  @override
  ConsumerState<LyricsGameScreen> createState() => _LyricsGameScreenState();
}

class _LyricsGameScreenState extends ConsumerState<LyricsGameScreen>
    with RoundTimers<LyricsGameScreen> {
  final FocusNode _keys = FocusNode(
    debugLabel: 'LyricsGameScreen keys',
    skipTraversal: true,
  );
  final FocusNode _typedFocus = FocusNode(
    debugLabel: 'LyricsGameScreen answer',
  );
  final TextEditingController _typed = TextEditingController();
  _LyricsRound? _round;
  RoundAnswer? _result;
  List<Track> _options = const [];
  List<Track> _allTracks = const [];
  Track? _lastTrack;
  DateTime _roundStart = DateTime.fromMillisecondsSinceEpoch(0);
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
    _keys.dispose();
    _typedFocus.dispose();
    _typed.dispose();
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
    resetRound(
      roundTimerSeconds(
        difficulty,
        game.progress.settings.mediumTimer,
        game.progress.settings.hardTimer,
      ),
    );
    _typed.clear();
    final startedAt = _now();
    setState(() {
      _round = _LyricsRound(
        entry: entry,
        snippetLines: snippetLines,
        decoy: decoy,
      );
      _options = options;
      _result = null;
      _roundStart = startedAt;
    });
    startCountdown();
    _focusInput();
  }

  void _answer(Object? pick, {bool timedOut = false}) {
    final round = _round;
    if (round == null || _result != null) {
      return;
    }
    final game = ref.read(gameControllerProvider);
    final mode = game.lyricsMode;
    final track = round.entry.track;
    final decoy = round.decoy;
    final timeElapsed = _now().difference(_roundStart);
    final RoundAnswer result = switch (mode) {
      LyricsMode.lyricsOrLie => (
        pick: pick,
        correct: !timedOut && decoy != null && pick == decoy.isReal,
        timedOut: timedOut,
        close: false,
        praise: '',
      ),
      LyricsMode.nameThatSong || null => songAnswer(
        pick,
        track,
        game.difficulty,
        QuizType.lyrics,
        timedOut: timedOut || mode == null,
      ),
    };
    stopCountdown();
    final controller = ref.read(gameControllerProvider.notifier);
    if (result.correct) {
      controller.answerCorrect(track);
      if (mode != null) {
        controller.incrementLyricsStat(mode);
      }
    } else {
      controller.answerIncorrect(track);
      ref.read(audioControllerProvider.notifier).playQuack();
    }
    ref
        .read(achievementsControllerProvider)
        .checkAfterAnswer(
          correct: result.correct,
          timeElapsed: timeElapsed,
          usedFullClip: false,
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
      _result = result;
      _lastTrack = track;
    });
    armNext();
    _focusKeys();
    unawaited(ref.read(lyricsControllerProvider).extendPool());
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
    if (_result == null || !nextReady) {
      return;
    }
    if (ref.read(gameControllerProvider).isLastQuickRound) {
      ref.read(gameControllerProvider.notifier).finishQuickRound();
      return;
    }
    _beginRound();
  }

  bool _handleKey(LogicalKeyboardKey key) {
    if (_round == null) {
      return false;
    }
    if (isNextKey(key)) {
      if (_result == null) {
        return false;
      }
      _handleNext();
      return true;
    }
    if (_result != null) {
      return false;
    }
    final game = ref.read(gameControllerProvider);
    if (game.lyricsMode == LyricsMode.lyricsOrLie) {
      final verdict = switch (key) {
        LogicalKeyboardKey.keyR => true,
        LogicalKeyboardKey.keyF => false,
        _ => null,
      };
      if (verdict == null) {
        return false;
      }
      _answer(verdict);
      return true;
    }
    final index = answerKeyIndex(key);
    if (index == null ||
        game.difficulty == Difficulty.hard ||
        index >= _options.length) {
      return false;
    }
    _answer(_options[index].id);
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
    final game = ref.read(gameControllerProvider);
    if (game.difficulty != Difficulty.hard ||
        game.lyricsMode != LyricsMode.nameThatSong) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _result == null && ref.read(modalStackProvider).isEmpty) {
        _typedFocus.requestFocus();
      }
    });
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
    final round = _round;
    return ScreenEnter(
      child: GameKeys(
        focusNode: _keys,
        onKey: _handleKey,
        child: round == null
            ? GameFirstLoad(onBack: _exit)
            : _roundView(context, round),
      ),
    );
  }

  Widget _roundView(BuildContext context, _LyricsRound round) {
    final game = ref.watch(
      gameControllerProvider.select(
        (game) => (
          mode: game.lyricsMode,
          streak: game.streak,
          difficulty: game.difficulty,
          round: game.roundNumber,
          total: game.quickRoundTotal,
          misses: game.quackCount,
          last: game.isLastQuickRound,
        ),
      ),
    );
    final result = _result;
    final answered = result != null;
    final track = round.entry.track;
    final lie = game.mode == LyricsMode.lyricsOrLie;
    return GameStage(
      topBar: RoundTopBar(
        modeLabel: lyricsModeLabel(game.mode),
        difficulty: game.difficulty,
        streak: game.streak,
        round: game.round,
        totalRounds: game.total,
        time: roundTime,
        onExit: _exit,
      ),
      left: [
        if (lie)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RecordPlayer(
              revealed: answered || game.difficulty == Difficulty.easy,
              answered: answered,
              spinning: false,
              coverUrl: track.album.coverMedium,
              placeholder: eraPlaceholderOf(track),
              previousCoverUrl: _lastTrack?.album.coverMedium,
              previousPlaceholder: eraPlaceholderOf(_lastTrack),
            ),
          )
        else
          LyricPaper(
            lines: round.snippetLines,
            song: songTitle(track),
            era: eraNameOf(track),
            coverUrl: track.album.coverMedium,
            placeholder: eraPlaceholderOf(track),
            revealed: answered,
            showHint: game.difficulty == Difficulty.easy,
          ),
      ],
      right: [
        if (lie)
          ..._lieColumn(round, track, result)
        else
          ..._songColumn(context, track, game.difficulty, result),
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
    );
  }

  List<Widget> _songColumn(
    BuildContext context,
    Track track,
    Difficulty difficulty,
    RoundAnswer? result,
  ) {
    final tokens = AppTokens.of(context);
    final answered = result != null;
    final options = _options;
    final rightIndex = options.indexWhere((option) => option.id == track.id);
    final note = typedNoteOf(result);
    return [
      SongRoundHeading(
        question: LyricsGameScreen.lyricsQuestion,
        track: track,
        answer: result,
        time: roundTime,
        coverHint: false,
      ),
      if (difficulty != Difficulty.hard)
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
    ];
  }

  List<Widget> _lieColumn(
    _LyricsRound round,
    Track track,
    RoundAnswer? result,
  ) {
    final decoy = round.decoy;
    final title = songTitle(track);
    final pick = result?.pick;
    return [
      if (result == null)
        ValueListenableBuilder<RoundTime>(
          valueListenable: roundTime,
          builder: (context, time, _) => RoundHeading.question(
            kicker: LyricsGameScreen.lieKicker,
            song: title,
            subline: playingSubline(time, coverHint: false),
            urgent: time.urgent,
          ),
        )
      else
        RoundHeading(
          pre: result.correct
              ? LyricsGameScreen.rightVerdict
              : result.timedOut
              ? LyricsGameScreen.timeUpVerdict
              : LyricsGameScreen.wrongVerdict,
          subline: decoy == null || decoy.isReal
              ? LyricsGameScreen.realLine(title)
              : LyricsGameScreen.fakeLine(decoy.sourceSong),
        ),
      if (decoy != null)
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: LyricsGameScreen.lieGap,
          children: [
            LyricPaper.quote(lines: decoy.lines),
            RealFakeButtons(
              onPick: _answer,
              answered: result != null,
              isReal: decoy.isReal,
              picked: pick is bool ? pick : null,
            ),
          ],
        ),
    ];
  }
}
