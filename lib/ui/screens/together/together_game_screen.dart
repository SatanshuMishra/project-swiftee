import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/domain/together/scoring.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/together/room_controller.dart';
import 'package:swiftie_quiz/state/together/room_state.dart';
import 'package:swiftie_quiz/state/together/together_game_controller.dart';
import 'package:swiftie_quiz/state/together/together_game_state.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/game/answer_list.dart';
import 'package:swiftie_quiz/ui/game/game_top_bar.dart';
import 'package:swiftie_quiz/ui/game/lyric_paper.dart';
import 'package:swiftie_quiz/ui/game/record_player.dart';
import 'package:swiftie_quiz/ui/game/round_heading.dart';
import 'package:swiftie_quiz/ui/game/transport_bar.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/screens/game_screen.dart';
import 'package:swiftie_quiz/ui/screens/lyrics_game_screen.dart'
    show LyricsGameScreen;
import 'package:swiftie_quiz/ui/screens/together/lobby_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/ui/together/standings_list.dart';
import 'package:swiftie_quiz/ui/widgets/back_link.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';

class TogetherGameScreen extends ConsumerStatefulWidget {
  const TogetherGameScreen({super.key});

  static const String leaveLabel = 'Leave';
  static const String gettingReady = 'Getting ready…';
  static const String getReady = 'Get ready…';
  static const String soundQuestion = "What's playing?";
  static const String lieQuestion = 'Real, or a lie?';
  static const String kickerStart = 'Is this lyric from ';
  static const String kickerEnd = '?';
  static const String itWas = 'It was ';
  static const String realFrom = 'Real. From ';
  static const String lieWas = 'A lie. That was ';
  static const String songEnd = '.';
  static const String sittingOut = "Wrong guess. You're sitting this one out.";
  static const String lockedIn = 'Locked in. Waiting for the others…';
  static const String nobodyFirst = 'Nobody got it this time.';
  static const String you = 'You';
  static const String nextNowLabel = 'Next now';

  static String roundLabel(int number, int total, TogetherMode mode) =>
      'Round ${math.max(1, number)} of $total · ${mode.title}';

  static String roomLabel(String code) => 'Room $code';

  static String gotItFirst(String name) => '$name got it first.';

  static String nextIn(int seconds, {required bool last}) =>
      last ? 'Final standings in $seconds' : 'Next round in $seconds';

  static const double countdownSize = 160;
  static const double countdownFrom = 0.6;
  static const double countdownGap = 10;
  static const double countdownBottom = 60;
  static const double kickerSongSize = 22;
  static const double footerGap = 14;

  @override
  ConsumerState<TogetherGameScreen> createState() => _TogetherGameScreenState();
}

class _TogetherGameScreenState extends ConsumerState<TogetherGameScreen>
    with RoundTimers<TogetherGameScreen> {
  final FocusNode _keys = FocusNode(
    debugLabel: 'TogetherGameScreen keys',
    skipTraversal: true,
  );
  Track? _lastTrack;

  @override
  void initState() {
    super.initState();
    _syncClock(ref.read(togetherGameControllerProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(catalogControllerProvider).catalogue.isEmpty) {
        unawaited(ref.read(catalogControllerProvider.notifier).loadCatalogue());
      }
    });
  }

  @override
  void dispose() {
    _keys.dispose();
    super.dispose();
  }

  @override
  void onTimeUp() {}

  void _syncClock(TogetherGameState game) {
    final seconds = roundSeconds(game.difficulty);
    switch (game.stage) {
      case TogetherStage.round:
        resetRound(seconds);
        startCountdown();
      case TogetherStage.reveal:
        stopCountdown();
        final time = roundTime.value;
        roundTime.value = (total: time.total, left: 0, running: false);
        _lastTrack = game.track;
      case TogetherStage.starting ||
          TogetherStage.countdown ||
          TogetherStage.loading:
        resetRound(seconds);
      case TogetherStage.idle || TogetherStage.ended || TogetherStage.lost:
        stopCountdown();
    }
  }

  bool _handleKey(LogicalKeyboardKey key) {
    final game = ref.read(togetherGameControllerProvider);
    if (game.stage != TogetherStage.round || game.myStatus != null) {
      return false;
    }
    final together = ref.read(togetherGameControllerProvider.notifier);
    if (game.mode == TogetherMode.lyricsOrLie) {
      final real = switch (key) {
        LogicalKeyboardKey.keyR => true,
        LogicalKeyboardKey.keyF => false,
        _ => null,
      };
      if (real == null) {
        return false;
      }
      together.answer(real: real);
      return true;
    }
    if (key == LogicalKeyboardKey.space) {
      together.togglePause();
      return true;
    }
    final index = answerKeyIndex(key);
    if (index == null || index >= game.options.length) {
      return false;
    }
    together.answer(trackId: game.options[index].id);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      togetherGameControllerProvider.select((game) => game.stage),
      (_, _) =>
          setState(() => _syncClock(ref.read(togetherGameControllerProvider))),
    );
    final game = ref.watch(togetherGameControllerProvider);
    final room = ref.watch(roomControllerProvider);
    final header = _Header(
      label: TogetherGameScreen.roundLabel(game.number, game.total, game.mode),
      code: room.code ?? '',
      time: roundTime,
      onLeave: () => unawaited(confirmLeaveRoom(context, ref)),
    );
    final Widget body = switch (game.stage) {
      TogetherStage.round ||
      TogetherStage.reveal when game.track != null => _Round(
        game: game,
        room: room,
        header: header,
        time: roundTime,
        lastTrack: _lastTrack,
      ),
      TogetherStage.countdown => _Staged(
        header: header,
        child: _Countdown(
          label: TogetherGameScreen.roundLabel(
            game.number,
            game.total,
            game.mode,
          ),
          count: game.count,
        ),
      ),
      TogetherStage.loading => _Staged(
        header: header,
        child: const BetweenSongsCover(),
      ),
      TogetherStage.lost => _Staged(
        header: header,
        child: RoomClosedPanel(
          failure: room.failure ?? RoomFailure.connectionLost,
          host: room.closedBy ?? room.hostName ?? '',
        ),
      ),
      _ => _Staged(header: header, child: const _GettingReady()),
    };
    return ScreenEnter(
      child: GameKeys(focusNode: _keys, onKey: _handleKey, child: body),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.label,
    required this.code,
    required this.time,
    required this.onLeave,
  });

  final String label;
  final String code;
  final ValueListenable<RoundTime> time;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final style = AppType.sized(14, 20).copyWith(color: tokens.mut);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: GameTopBar.padding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BackLink(
                label: TogetherGameScreen.leaveLabel,
                onPressed: onLeave,
                animateEntrance: false,
              ),
              const SizedBox(width: GameTopBar.gap),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              const SizedBox(width: GameTopBar.gap),
              Text(TogetherGameScreen.roomLabel(code), style: style),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: GameTopBar.timerInset,
          ),
          child: SizedBox(
            height: GameTopBar.timerHeight,
            child: ColoredBox(
              color: tokens.line,
              child: ValueListenableBuilder<RoundTime>(
                valueListenable: time,
                builder: (context, time, _) => TimerFill(
                  fraction: (time.fraction ?? 1).clamp(0.0, 1.0),
                  running: time.running,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Staged extends StatelessWidget {
  const _Staged({required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      header,
      Expanded(child: child),
    ],
  );
}

class _GettingReady extends StatelessWidget {
  const _GettingReady();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: GameFirstLoad.padBottom),
    child: Center(
      child: CatLoader(
        px: GameFirstLoad.loaderSize,
        label: TogetherGameScreen.gettingReady,
        labelStyle: CatLoader.defaultLabelStyle.copyWith(
          color: AppTokens.of(context).mut,
        ),
      ),
    ),
  );
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final digit = Text(
      '$count',
      style: AppType.display(
        TogetherGameScreen.countdownSize,
        height: 1,
        color: tokens.coralT,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(
        bottom: TogetherGameScreen.countdownBottom,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: TogetherGameScreen.countdownGap,
          children: [
            Text(label, style: AppType.body.copyWith(color: tokens.mut)),
            SizedBox(
              height: TogetherGameScreen.countdownSize,
              child: Center(
                child: AppMotion.reduced(context)
                    ? digit
                    : Entrance(
                        key: ValueKey(count),
                        fromScale: TogetherGameScreen.countdownFrom,
                        child: digit,
                      ),
              ),
            ),
            Text(
              TogetherGameScreen.getReady,
              style: AppType.body.copyWith(color: tokens.mut),
            ),
          ],
        ),
      ),
    );
  }
}

class _Round extends ConsumerWidget {
  const _Round({
    required this.game,
    required this.room,
    required this.header,
    required this.time,
    required this.lastTrack,
  });

  final TogetherGameState game;
  final RoomState room;
  final Widget header;
  final ValueListenable<RoundTime> time;
  final Track? lastTrack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final together = ref.read(togetherGameControllerProvider.notifier);
    final audio = ref.watch(audioControllerProvider);
    final catalogue = ref.watch(
      catalogControllerProvider.select((catalog) => catalog.catalogue),
    );
    final track = game.track!;
    final revealed = game.stage == TogetherStage.reveal;
    final lie = game.mode == TogetherMode.lyricsOrLie;
    final hosting = room.role == RoomRole.host;
    final youId = room.you?.id ?? '';
    final open = !revealed && game.myStatus == null;
    return GameStage(
      topBar: header,
      left: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: RecordPlayer(
            revealed: revealed || game.difficulty == Difficulty.easy,
            answered: revealed,
            spinning: !lie && audio.playing,
            coverUrl: track.album.coverMedium,
            placeholder: eraPlaceholderOf(catalogue, track),
            previousCoverUrl: lastTrack?.album.coverMedium,
            previousPlaceholder: eraPlaceholderOf(catalogue, lastTrack),
          ),
        ),
        if (!lie && !revealed)
          TransportBar(
            status: transportStatusOf(audio),
            stage: audio.relistenStage,
            elapsed: audio.clipDuration > 0
                ? audio.progress * audio.clipDuration
                : 0,
            duration: audio.clipDuration > 0
                ? audio.clipDuration
                : sliceDurationSeconds,
            onToggle: together.togglePause,
          ),
      ],
      right: [
        _Heading(game: game, catalogue: catalogue, youId: youId, time: time),
        if (lie)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: LyricsGameScreen.lieGap,
            children: [
              LyricPaper.quote(lines: game.lines),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: RealFakeButtons.gap,
                children: [
                  for (final (real, label, keyHint) in const [
                    (true, RealFakeButtons.realLabel, RealFakeButtons.realKey),
                    (false, RealFakeButtons.fakeLabel, RealFakeButtons.fakeKey),
                  ])
                    Expanded(
                      child: RealFakeButton(
                        label: label,
                        keyHint: keyHint,
                        state: _stateOf(
                          revealed: revealed,
                          answered: game.myStatus != null,
                          right: game.isReal == real,
                          picked: game.myRealPick == real,
                        ),
                        onPressed: open
                            ? () => together.answer(real: real)
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          )
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AnswerList.gap,
            children: [
              for (final (index, option) in game.options.indexed)
                AnswerButton(
                  number: index + 1,
                  label: songTitle(option),
                  state: _stateOf(
                    revealed: revealed,
                    answered: game.myStatus != null,
                    right: game.answerTrackId == option.id,
                    picked: game.myTrackPick == option.id,
                  ),
                  onPressed: open
                      ? () => together.answer(trackId: option.id)
                      : null,
                ),
            ],
          ),
        StandingsList(game: game, viewerId: youId),
        if (revealed)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: TogetherGameScreen.footerGap,
            runSpacing: TogetherGameScreen.footerGap,
            children: [
              Text(
                TogetherGameScreen.nextIn(
                  game.revealLeft,
                  last: game.number >= game.total,
                ),
                style: AppType.sized(14, 20).copyWith(
                  color: tokens.mut,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (hosting)
                PillButton(
                  label: TogetherGameScreen.nextNowLabel,
                  kind: PillKind.outline,
                  onPressed: together.nextNow,
                ),
            ],
          ),
      ],
    );
  }
}

AnswerState _stateOf({
  required bool revealed,
  required bool answered,
  required bool right,
  required bool picked,
}) {
  if (revealed) {
    return right
        ? AnswerState.right
        : picked
        ? AnswerState.wrong
        : AnswerState.dim;
  }
  if (picked) {
    return AnswerState.mine;
  }
  return answered ? AnswerState.dim : AnswerState.idle;
}

class _Heading extends StatelessWidget {
  const _Heading({
    required this.game,
    required this.catalogue,
    required this.youId,
    required this.time,
  });

  final TogetherGameState game;
  final Catalogue catalogue;
  final String youId;
  final ValueListenable<RoundTime> time;

  String _revealSubline(Track track) {
    if (game.mode != TogetherMode.quickDraw) {
      return trackCaption(catalogue, track);
    }
    final winnerId = game.winnerId;
    if (winnerId == null) {
      return TogetherGameScreen.nobodyFirst;
    }
    if (winnerId == youId) {
      return TogetherGameScreen.gotItFirst(TogetherGameScreen.you);
    }
    final name = game.roster
        .where((player) => player.id == winnerId)
        .map((player) => player.name)
        .firstOrNull;
    return name == null
        ? TogetherGameScreen.nobodyFirst
        : TogetherGameScreen.gotItFirst(name);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final track = game.track!;
    final lie = game.mode == TogetherMode.lyricsOrLie;
    final Widget heading;
    if (game.stage == TogetherStage.reveal) {
      final real = game.isReal ?? true;
      heading = RoundHeading(
        pre: !lie
            ? TogetherGameScreen.itWas
            : real
            ? TogetherGameScreen.realFrom
            : TogetherGameScreen.lieWas,
        song: lie && !real ? game.sourceSong ?? '' : songTitle(track),
        post: TogetherGameScreen.songEnd,
        subline: _revealSubline(track),
      );
    } else {
      heading = ValueListenableBuilder<RoundTime>(
        valueListenable: time,
        builder: (context, time, _) => RoundHeading(
          pre: lie
              ? TogetherGameScreen.lieQuestion
              : TogetherGameScreen.soundQuestion,
          subline: switch (game.myStatus) {
            AnswerStatus.out => TogetherGameScreen.sittingOut,
            AnswerStatus.answered => TogetherGameScreen.lockedIn,
            null => GameScreen.secondsLeft(time.secondsLeft),
          },
          urgent: game.myStatus == null && time.urgent,
        ),
      );
    }
    if (!lie) {
      return heading;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RoundHeading.gap,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: TogetherGameScreen.kickerStart),
              TextSpan(
                text: songTitle(track),
                style: AppType.display(
                  TogetherGameScreen.kickerSongSize,
                  italic: true,
                  color: tokens.coralT,
                ),
              ),
              const TextSpan(text: TogetherGameScreen.kickerEnd),
            ],
          ),
          style: AppType.body.copyWith(color: tokens.mut),
        ),
        heading,
      ],
    );
  }
}
