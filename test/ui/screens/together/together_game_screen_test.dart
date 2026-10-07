import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/together/game_messages.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/domain/together/scoring.dart';
import 'package:swiftie_quiz/domain/together/server_link.dart';
import 'package:swiftie_quiz/domain/together/standings.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/together/room_controller.dart';
import 'package:swiftie_quiz/state/together/together_game_controller.dart';
import 'package:swiftie_quiz/state/together/together_game_state.dart';
import 'package:swiftie_quiz/ui/game/answer_list.dart';
import 'package:swiftie_quiz/ui/game/game_top_bar.dart';
import 'package:swiftie_quiz/ui/game/record_player.dart';
import 'package:swiftie_quiz/ui/game/transport_bar.dart';
import 'package:swiftie_quiz/ui/kit/confirm_dialog.dart';
import 'package:swiftie_quiz/ui/screens/game_screen.dart' show trackCaption;
import 'package:swiftie_quiz/ui/screens/together/together_game_screen.dart';
import 'package:swiftie_quiz/ui/screens/together/together_shell.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/together/standings_list.dart';
import 'package:together_protocol/together_protocol.dart';

import '../../../state/together/fake_relay.dart';
import '../album_grid_test.dart' show FakeCatalog, bundled;

final String _linkText = 'https://swiftie.satanshu.tech/#${'Ab0-_' * 8}xyz';
final ServerLink _link = ServerLink.parse(_linkText)!;

const Player _sam = Player(id: 'p-sam', name: 'Sam', avatar: 'seedSam');
const Player _maya = Player(id: 'p-maya', name: 'Maya', avatar: 'seedMaya');

Track _track(int id, String title) => Track(
  id: id,
  title: title,
  titleShort: title,
  duration: 200,
  preview: '',
  artist: const Artist(id: 12, name: 'Taylor Swift'),
  album: const Album(id: 99, title: 'Lover', coverMedium: null),
  trackPosition: id,
);

final List<Track> _options = [
  _track(1, 'Cruel Summer'),
  _track(2, 'The Archer'),
  _track(3, 'Daylight'),
  _track(4, 'Lover'),
];

class FakeTogether extends TogetherGameController {
  FakeTogether(this.initial);

  final TogetherGameState initial;
  List<({int? trackId, bool? real})> answers = const [];
  int nextNows = 0;
  int leaves = 0;

  @override
  TogetherGameState build() {
    super.build();
    return initial;
  }

  void show(TogetherGameState next) => state = next;

  @override
  void answer({int? trackId, bool? real}) {
    answers = [...answers, (trackId: trackId, real: real)];
    super.answer(trackId: trackId, real: real);
  }

  @override
  void nextNow() => nextNows += 1;

  @override
  Future<void> leaveTogether() {
    leaves += 1;
    return super.leaveTogether();
  }
}

class FakeAudio extends AudioController {
  int pauses = 0;
  int resumes = 0;
  int resets = 0;

  @override
  AudioState build() =>
      AudioState.idle.copyWith(playing: true, clipDuration: 10, progress: 0.3);

  @override
  void pause() {
    pauses += 1;
    state = state.copyWith(playing: false, paused: true);
  }

  @override
  void resume() {
    resumes += 1;
    state = state.copyWith(playing: true, paused: false);
  }

  @override
  void stop() {}

  @override
  void reset() => resets += 1;
}

class _PhaseScreen extends ConsumerWidget {
  const _PhaseScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(gameControllerProvider.select((game) => game.phase)) ==
          GamePhase.together
      ? const TogetherShell()
      : const Text('menu');
}

typedef GameHarness = ({
  ProviderContainer container,
  FakeTogether together,
  FakeAudio audio,
  FakeRelay relay,
});

TogetherGameState soundState({
  TogetherMode mode = TogetherMode.classic,
  TogetherStage stage = TogetherStage.round,
  int number = 1,
  int total = 10,
  Track? track,
}) => TogetherGameState.initial.copyWith(
  stage: stage,
  number: number,
  total: total,
  mode: mode,
  difficulty: Difficulty.medium,
  track: track ?? _options[2],
  options: _options,
  count: countdownFrom,
  roster: const [_maya, _sam],
  standings: [PlayerScore.start(_maya.id), PlayerScore.start(_sam.id)],
);

TogetherGameState lieState({TogetherStage stage = TogetherStage.round}) =>
    TogetherGameState.initial.copyWith(
      stage: stage,
      number: 2,
      total: 5,
      mode: TogetherMode.lyricsOrLie,
      difficulty: Difficulty.medium,
      track: _options[1],
      lines: const ['Combat, I’m ready for combat', 'I say I don’t want that'],
      roster: const [_maya, _sam],
      standings: [PlayerScore.start(_maya.id), PlayerScore.start(_sam.id)],
    );

Future<GameHarness> pumpGame(
  WidgetTester tester,
  TogetherGameState initial, {
  bool hosting = false,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final relay = FakeRelay();
  final together = FakeTogether(initial);
  final audio = FakeAudio();
  final container = ProviderContainer.test(
    overrides: [
      relayConnectorProvider.overrideWithValue(relay),
      editionProvider.overrideWithValue(Edition.open),
      togetherGameControllerProvider.overrideWith(() => together),
      audioControllerProvider.overrideWith(() => audio),
      catalogControllerProvider.overrideWith(
        () => FakeCatalog(CatalogState.initial.copyWith(catalogue: bundled)),
      ),
    ],
  );
  container.read(gameControllerProvider.notifier)
    ..setProgress(
      defaultProgress.copyWith(
        settings: defaultProgress.settings.copyWith(
          nickname: 'Sam',
          togetherLink: _linkText,
        ),
      ),
    )
    ..setPhase(GamePhase.together);
  final room = container.read(roomControllerProvider.notifier);
  if (hosting) {
    await room.open(_link);
    relay
      ..push(const RoomOpened(code: 'BCDF', you: _sam))
      ..push(const PeerJoined(_maya));
  } else {
    await room.join(_link, 'BCDF');
    relay.push(
      RoomJoined(
        code: 'BCDF',
        you: _sam,
        hostId: _maya.id,
        players: const [_maya, _sam],
      ),
    );
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Material(child: _PhaseScreen()),
      ),
    ),
  );
  await settle(tester);
  return (container: container, together: together, audio: audio, relay: relay);
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> show(
  WidgetTester tester,
  GameHarness harness,
  TogetherGameState state,
) async {
  harness.together.show(state);
  await settle(tester);
}

TogetherGameState current(GameHarness harness) =>
    harness.container.read(togetherGameControllerProvider);

AnswerButton answerButton(WidgetTester tester, String label) =>
    tester.widget<AnswerButton>(
      find.ancestor(of: find.text(label), matching: find.byType(AnswerButton)),
    );

List<AnswerState> answerStates(WidgetTester tester) => [
  for (final button in tester.widgetList<AnswerButton>(
    find.byType(AnswerButton),
  ))
    button.state,
];

AnswerState verdict(WidgetTester tester, String label) => tester
    .widget<RealFakeButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(RealFakeButton),
      ),
    )
    .state;

double timerFraction(WidgetTester tester) =>
    tester.widget<TimerFill>(find.byType(TimerFill)).fraction;

Finder rowOf(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(StandingsRow));

void main() {
  testWidgets('a sound round counts down, locks a pick and reveals', (
    tester,
  ) async {
    final countdown = soundState(stage: TogetherStage.countdown);
    final harness = await pumpGame(tester, countdown);

    expect(find.byType(TogetherGameScreen), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
    expect(find.text('Room BCDF'), findsOneWidget);
    expect(find.text('Round 1 of 10 · Classic'), findsNWidgets(2));
    expect(find.text('Get ready…'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(timerFraction(tester), 1);
    await show(tester, harness, countdown.copyWith(count: 2));
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsNothing);
    await show(tester, harness, countdown.copyWith(count: 1));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Get ready…'), findsOneWidget);

    final round = countdown.copyWith(stage: TogetherStage.round);
    await show(tester, harness, round);
    expect(find.text('Get ready…'), findsNothing);
    expect(find.text('Round 1 of 10 · Classic'), findsOneWidget);
    expect(find.text("What's playing?"), findsOneWidget);
    expect(find.text('20 seconds left.'), findsOneWidget);
    expect(find.byType(RecordPlayer), findsOneWidget);
    expect(find.byType(TransportBar), findsOneWidget);
    expect(answerStates(tester), List.filled(4, AnswerState.idle));
    expect(
      [
        for (final button in tester.widgetList<AnswerButton>(
          find.byType(AnswerButton),
        ))
          (button.number, button.label),
      ],
      [(1, 'Cruel Summer'), (2, 'The Archer'), (3, 'Daylight'), (4, 'Lover')],
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('18 seconds left.'), findsOneWidget);
    expect(timerFraction(tester), lessThan(1));

    await tester.tap(find.text('The Archer'));
    await settle(tester);
    expect(harness.together.answers, [(trackId: 2, real: null)]);
    expect(current(harness).myTrackPick, 2);
    expect(answerStates(tester), [
      AnswerState.dim,
      AnswerState.mine,
      AnswerState.dim,
      AnswerState.dim,
    ]);
    expect(answerButton(tester, 'The Archer').chipText, '•');
    expect(
      find.descendant(
        of: find.widgetWithText(AnswerButton, 'The Archer'),
        matching: find.text('•'),
      ),
      findsOneWidget,
    );
    expect(find.text('Locked in. Waiting for the others…'), findsOneWidget);
    expect(find.textContaining('seconds left.'), findsNothing);
    expect(
      harness.relay.bodies.map((body) => body.message).whereType<AnswerSent>(),
      hasLength(1),
    );

    await show(
      tester,
      harness,
      current(harness).copyWith(
        stage: TogetherStage.reveal,
        answerTrackId: 3,
        results: {
          _maya.id: const RoundResult(
            playerId: 'p-maya',
            pickTrackId: 3,
            pickReal: null,
            right: true,
            at: 2.3,
            gain: 189,
          ),
          _sam.id: const RoundResult(
            playerId: 'p-sam',
            pickTrackId: 2,
            pickReal: null,
            right: false,
            at: 4.1,
            gain: 0,
          ),
        },
        standings: [
          const PlayerScore(
            id: 'p-maya',
            score: 189,
            streak: 1,
            best: 1,
            wins: 1,
            fastest: FastestAnswer(seconds: 2.3, song: 'Daylight'),
            left: false,
          ),
          PlayerScore.start(_sam.id),
        ],
        revealLeft: revealSeconds,
      ),
    );

    expect(find.text('It was Daylight.'), findsOneWidget);
    expect(find.text(trackCaption(bundled, _options[2])), findsOneWidget);
    expect(answerStates(tester), [
      AnswerState.dim,
      AnswerState.wrong,
      AnswerState.right,
      AnswerState.dim,
    ]);
    expect(find.text('Next round in 6'), findsOneWidget);
    expect(find.text('Next now'), findsNothing);
    expect(timerFraction(tester), 0);
    expect(find.byType(TransportBar), findsNothing);
    expect(
      find.descendant(of: rowOf('Maya'), matching: find.text('Right · 2.3 s')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rowOf('Maya'), matching: find.text('+189')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rowOf('Sam (you)'), matching: find.text('Wrong')),
      findsOneWidget,
    );

    await show(tester, harness, current(harness).copyWith(revealLeft: 5));
    expect(find.text('Next round in 5'), findsOneWidget);
    await show(
      tester,
      harness,
      current(harness).copyWith(number: 10, revealLeft: 6),
    );
    expect(find.text('Final standings in 6'), findsOneWidget);
  });

  testWidgets('lyrics or lie asks about the song and reveals the source', (
    tester,
  ) async {
    final harness = await pumpGame(tester, lieState());

    expect(find.text('Round 2 of 5 · Lyrics or Lie'), findsOneWidget);
    expect(find.text('Is this lyric from The Archer?'), findsOneWidget);
    expect(find.text('Real, or a lie?'), findsOneWidget);
    expect(find.text('“Combat, I’m ready for combat”'), findsOneWidget);
    expect(find.text('“I say I don’t want that”'), findsOneWidget);
    expect(find.text('20 seconds left.'), findsOneWidget);
    expect(find.byType(TransportBar), findsNothing);
    expect(find.byType(AnswerButton), findsNothing);
    expect(verdict(tester, 'Real'), AnswerState.idle);
    expect(verdict(tester, 'Fake'), AnswerState.idle);

    await tester.tap(find.text('Fake'));
    await settle(tester);
    expect(harness.together.answers, [(trackId: null, real: false)]);
    expect(verdict(tester, 'Fake'), AnswerState.mine);
    expect(verdict(tester, 'Real'), AnswerState.dim);
    expect(find.text('Locked in. Waiting for the others…'), findsOneWidget);

    await show(
      tester,
      harness,
      current(harness).copyWith(
        stage: TogetherStage.reveal,
        isReal: false,
        sourceSong: 'Cruel Summer',
        revealLeft: revealSeconds,
      ),
    );
    expect(find.text('A lie. That was Cruel Summer.'), findsOneWidget);
    expect(find.text('Is this lyric from The Archer?'), findsOneWidget);
    expect(verdict(tester, 'Fake'), AnswerState.right);
    expect(verdict(tester, 'Real'), AnswerState.dim);
    expect(find.text('Next round in 6'), findsOneWidget);

    await show(
      tester,
      harness,
      current(harness).copyWith(isReal: true, sourceSong: null),
    );
    expect(find.text('Real. From The Archer.'), findsOneWidget);
    expect(verdict(tester, 'Real'), AnswerState.right);
    expect(verdict(tester, 'Fake'), AnswerState.wrong);
  });

  testWidgets('quick draw sits out a wrong guess and names the winner', (
    tester,
  ) async {
    final harness = await pumpGame(
      tester,
      soundState(mode: TogetherMode.quickDraw),
    );
    expect(find.text('Round 1 of 10 · Quick draw'), findsOneWidget);

    await tester.tap(find.text('Cruel Summer'));
    await settle(tester);
    expect(current(harness).myStatus, AnswerStatus.out);
    expect(
      find.text("Wrong guess. You're sitting this one out."),
      findsOneWidget,
    );
    expect(answerStates(tester).first, AnswerState.mine);
    expect(
      find.descendant(
        of: rowOf('Sam (you)'),
        matching: find.text('Sitting out'),
      ),
      findsOneWidget,
    );

    final reveal = current(harness).copyWith(
      stage: TogetherStage.reveal,
      answerTrackId: 3,
      winnerId: _maya.id,
      revealLeft: revealSeconds,
    );
    await show(tester, harness, reveal);
    expect(find.text('It was Daylight.'), findsOneWidget);
    expect(find.text('Maya got it first.'), findsOneWidget);
    expect(find.text('Next now'), findsNothing);
    expect(
      find.descendant(of: rowOf('Maya'), matching: find.text('Got it first')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: rowOf('Sam (you)'),
        matching: find.text('Wrong guess'),
      ),
      findsOneWidget,
    );

    await show(tester, harness, reveal.copyWith(winnerId: null));
    expect(find.text('Nobody got it this time.'), findsOneWidget);
    await show(tester, harness, reveal.copyWith(winnerId: _sam.id));
    expect(find.text('You got it first.'), findsOneWidget);

    final host = await pumpGame(tester, reveal, hosting: true);
    expect(find.text('Next now'), findsOneWidget);
    await tester.tap(find.text('Next now'));
    await settle(tester);
    expect(host.together.nextNows, 1);
  });

  testWidgets('a lost room stops the game and offers the menu', (tester) async {
    for (final (closed, line) in [
      (false, 'Lost the connection to the room.'),
      (true, 'Maya closed the room.'),
    ]) {
      final harness = await pumpGame(tester, soundState());
      expect(find.text("What's playing?"), findsOneWidget);

      if (closed) {
        harness.relay.push(const RoomClosed());
      }
      await harness.relay.end();
      await settle(tester);

      expect(current(harness).stage, TogetherStage.lost, reason: line);
      expect(harness.audio.resets, greaterThan(0), reason: line);
      expect(find.text(line), findsOneWidget, reason: line);
      expect(find.text('Back to menu'), findsOneWidget, reason: line);
      expect(find.byType(AnswerButton), findsNothing, reason: line);

      await tester.tap(find.text('Back to menu'));
      await settle(tester);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await settle(tester);

      expect(harness.together.leaves, 1, reason: line);
      expect(
        harness.container.read(gameControllerProvider).phase,
        GamePhase.menu,
        reason: line,
      );
      expect(find.text('menu'), findsOneWidget, reason: line);
    }

    final harness = await pumpGame(tester, soundState());
    await harness.relay.end();
    await settle(tester);
    expect(current(harness).stage, TogetherStage.lost);
    await tester.tap(find.text('Leave'));
    await settle(tester);
    expect(find.byType(ConfirmDialog), findsNothing);
    expect(harness.together.leaves, 1);
    expect(
      harness.container.read(gameControllerProvider).phase,
      GamePhase.menu,
    );
  });

  testWidgets('number keys, R, F and space work in rounds', (tester) async {
    final harness = await pumpGame(tester, soundState());

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect(harness.audio.pauses, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect(harness.audio.resumes, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await settle(tester);
    expect(harness.together.answers, [(trackId: 3, real: null)]);
    expect(answerStates(tester)[2], AnswerState.mine);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect(harness.together.answers, hasLength(1));
    expect(current(harness).myTrackPick, 3);
    expect(answerStates(tester)[2], AnswerState.mine);
    expect(answerStates(tester)[0], AnswerState.dim);
    expect(harness.audio.pauses, 1);

    final lie = await pumpGame(tester, lieState());
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await settle(tester);
    expect(lie.together.answers, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await settle(tester);
    expect(lie.together.answers, [(trackId: null, real: true)]);
    expect(verdict(tester, 'Real'), AnswerState.mine);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await settle(tester);
    expect(lie.together.answers, hasLength(1));
    expect(current(lie).myRealPick, isTrue);

    final fake = await pumpGame(tester, lieState());
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await settle(tester);
    expect(fake.together.answers, [(trackId: null, real: false)]);
    expect(verdict(tester, 'Fake'), AnswerState.mine);
  });
}
