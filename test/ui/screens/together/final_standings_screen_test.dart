import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/domain/together/server_link.dart';
import 'package:swiftie_quiz/domain/together/standings.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/together/room_controller.dart';
import 'package:swiftie_quiz/state/together/together_game_controller.dart';
import 'package:swiftie_quiz/state/together/together_game_state.dart';
import 'package:swiftie_quiz/ui/screens/together/final_standings_screen.dart';
import 'package:swiftie_quiz/ui/screens/together/together_shell.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/together/standings_list.dart';
import 'package:together_protocol/together_protocol.dart';

import '../../../state/together/fake_relay.dart';

final String _linkText = 'https://swiftie.satanshu.tech/#${'Ab0-_' * 8}xyz';
final ServerLink _link = ServerLink.parse(_linkText)!;

const Player _ana = Player(id: 'p-ana', name: 'Ana', avatar: 'seedAna');
const Player _maya = Player(id: 'p-maya', name: 'Maya', avatar: 'seedMaya');
const Player _sam = Player(id: 'p-sam', name: 'Sam', avatar: 'seedSam');

class EndedTogether extends TogetherGameController {
  EndedTogether(this.initial);

  final TogetherGameState initial;
  int nexts = 0;

  @override
  TogetherGameState build() {
    super.build();
    return initial;
  }

  @override
  void next() {
    nexts += 1;
    super.next();
  }
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

TogetherGameState ended(Player viewer, List<PlayerScore> standings) =>
    TogetherGameState.initial.copyWith(
      stage: TogetherStage.ended,
      number: 10,
      total: 10,
      mode: TogetherMode.classic,
      difficulty: Difficulty.medium,
      roster: [_maya, viewer],
      standings: standings,
    );

typedef EndHarness = ({
  ProviderContainer container,
  EndedTogether together,
  FakeRelay relay,
});

Future<EndHarness> pumpEnd(
  WidgetTester tester, {
  required Edition edition,
  required Player viewer,
  required bool hosting,
  required List<PlayerScore> standings,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final relay = FakeRelay();
  final together = EndedTogether(ended(viewer, standings));
  final container = ProviderContainer.test(
    overrides: [
      relayConnectorProvider.overrideWithValue(relay),
      editionProvider.overrideWithValue(edition),
      togetherGameControllerProvider.overrideWith(() => together),
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
      ..push(RoomOpened(code: 'BCDF', you: viewer))
      ..push(const PeerJoined(_maya));
  } else {
    await room.join(_link, 'BCDF');
    relay.push(
      RoomJoined(
        code: 'BCDF',
        you: viewer,
        hostId: _maya.id,
        players: [_maya, viewer],
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
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return (container: container, together: together, relay: relay);
}

PlayerScore _score(
  String id,
  int score, {
  required int best,
  FastestAnswer? fastest,
}) => PlayerScore(
  id: id,
  score: score,
  streak: 0,
  best: best,
  wins: best,
  fastest: fastest,
  left: false,
);

void main() {
  testWidgets('the winner, highlights and buttons follow the prototype', (
    tester,
  ) async {
    final host = await pumpEnd(
      tester,
      edition: Edition.ana,
      viewer: _ana,
      hosting: true,
      standings: [
        _score(
          _maya.id,
          289,
          best: 1,
          fastest: const FastestAnswer(seconds: 2.34, song: 'Lover'),
        ),
        _score(
          _ana.id,
          375,
          best: 3,
          fastest: const FastestAnswer(seconds: 1.42, song: 'Daylight'),
        ),
      ],
    );

    expect(find.byType(FinalStandingsScreen), findsOneWidget);
    expect(find.text('Final standings · Classic'), findsOneWidget);
    expect(find.text('You take it, Ana.'), findsOneWidget);
    expect(find.text('375 points over 10 rounds.'), findsOneWidget);
    expect(find.text('Fastest answer'), findsOneWidget);
    expect(find.text('You · 1.4 s on Daylight'), findsOneWidget);
    expect(find.text('Longest streak'), findsOneWidget);
    expect(find.text('You · 3 in a row'), findsOneWidget);
    expect(find.byType(StandingsList), findsOneWidget);
    expect(find.text('Ana (you)'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Ana (you)')).dy,
      lessThan(tester.getTopLeft(find.text('Maya')).dy),
    );
    expect(find.text('Next →'), findsOneWidget);
    expect(find.text('Play again →'), findsNothing);
    expect(find.text('Back to menu'), findsNothing);
    await tester.tap(find.text('Next →'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(host.together.nexts, 1);
    expect(find.text('Start game →'), findsOneWidget);
    expect(find.text('Leave room'), findsOneWidget);

    final guest = await pumpEnd(
      tester,
      edition: Edition.open,
      viewer: _sam,
      hosting: false,
      standings: [
        _score(
          _maya.id,
          420,
          best: 4,
          fastest: const FastestAnswer(seconds: 0.96, song: 'Cruel Summer'),
        ),
        _score(_sam.id, 300, best: 2),
      ],
    );
    expect(find.text('Maya takes it.'), findsOneWidget);
    expect(find.text('420 points over 10 rounds.'), findsOneWidget);
    expect(find.text('Maya · 1.0 s on Cruel Summer'), findsOneWidget);
    expect(find.text('Maya · 4 in a row'), findsOneWidget);
    expect(find.text('Sam (you)'), findsOneWidget);
    expect(find.text('Next →'), findsOneWidget);
    expect(find.text('Back to menu'), findsNothing);

    await tester.tap(find.text('Next →'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(guest.together.nexts, 1);
    expect(
      guest.container.read(gameControllerProvider).phase,
      GamePhase.together,
    );
    expect(find.text('Waiting for Maya to start…'), findsOneWidget);
    expect(find.text('Leave room'), findsOneWidget);

    await pumpEnd(
      tester,
      edition: Edition.open,
      viewer: _sam,
      hosting: false,
      standings: [_score(_maya.id, 0, best: 0), _score(_sam.id, 0, best: 0)],
    );
    expect(find.text('You take it, Sam.'), findsOneWidget);
    expect(find.text('Fastest answer'), findsNothing);
    expect(find.text('Longest streak'), findsNothing);
  });

  testWidgets('a guest still on the results after the host closes the room '
      'sees the room closed after Next', (tester) async {
    final guest = await pumpEnd(
      tester,
      edition: Edition.open,
      viewer: _sam,
      hosting: false,
      standings: [
        _score(_maya.id, 420, best: 4),
        _score(_sam.id, 300, best: 2),
      ],
    );
    guest.relay.push(const RoomClosed());
    await guest.relay.end();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Next →'), findsOneWidget);

    await tester.tap(find.text('Next →'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Maya closed the room.'), findsOneWidget);
    expect(find.text('Back to menu'), findsOneWidget);
  });

  testWidgets('a host whose connection drops on the results sees it after '
      'Next', (tester) async {
    final host = await pumpEnd(
      tester,
      edition: Edition.open,
      viewer: _ana,
      hosting: true,
      standings: [
        _score(_ana.id, 420, best: 4),
        _score(_maya.id, 300, best: 2),
      ],
    );
    await host.relay.end();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Next →'), findsOneWidget);

    await tester.tap(find.text('Next →'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Lost the connection to the room.'), findsOneWidget);
    expect(find.text('Back to menu'), findsOneWidget);
  });
}
