import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/together/game_messages.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/together/room_controller.dart';
import 'package:swiftie_quiz/state/together/room_state.dart';
import 'package:swiftie_quiz/state/together/together_game_controller.dart';
import 'package:swiftie_quiz/state/together/together_game_state.dart';
import 'package:swiftie_quiz/ui/kit/confirm_dialog.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/screens/together/host_room_screen.dart';
import 'package:swiftie_quiz/ui/screens/together/lobby_screen.dart';
import 'package:swiftie_quiz/ui/screens/together/together_game_screen.dart';
import 'package:swiftie_quiz/ui/screens/together/together_nav.dart';
import 'package:swiftie_quiz/ui/screens/together/together_shell.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/together/player_avatar.dart';
import 'package:together_protocol/together_protocol.dart';

import '../../../state/together/fake_relay.dart';
import '../album_grid_test.dart' show FakeCatalog, bundled;

final String _link = 'https://swiftie.satanshu.tech/#${'Ab0-_' * 8}xyz';

const Player _sam = Player(id: 'p-sam', name: 'Sam', avatar: 'seedSam');
const Player _maya = Player(id: 'p-maya', name: 'Maya', avatar: 'seedMaya');
const Player _lee = Player(id: 'p-lee', name: 'Lee', avatar: 'seedLee');

class RecordingTogether extends TogetherGameController {
  RecordingTogether({this.startFailed = false});

  final bool startFailed;
  int starts = 0;
  int leaves = 0;

  @override
  TogetherGameState build() {
    super.build();
    return TogetherGameState.initial.copyWith(startFailed: startFailed);
  }

  @override
  Future<void> start() async => starts += 1;

  @override
  Future<void> leaveTogether() {
    leaves += 1;
    return super.leaveTogether();
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

typedef LobbyHarness = ({
  ProviderContainer container,
  RecordingTogether together,
});

Future<LobbyHarness> pumpTogether(
  WidgetTester tester,
  FakeRelay relay, {
  required TogetherScreen screen,
  bool startFailed = false,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final together = RecordingTogether(startFailed: startFailed);
  final container = ProviderContainer.test(
    overrides: [
      relayConnectorProvider.overrideWithValue(relay),
      editionProvider.overrideWithValue(Edition.open),
      togetherGameControllerProvider.overrideWith(() => together),
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
          togetherLink: _link,
        ),
      ),
    )
    ..setPhase(GamePhase.together);
  container.read(togetherNavProvider.notifier).show(screen);
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
  return (container: container, together: together);
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> disconnect(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await settle(tester);
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
  await settle(tester);
}

Future<LobbyHarness> hostLobby(
  WidgetTester tester,
  FakeRelay relay, {
  bool startFailed = false,
}) async {
  final harness = await pumpTogether(
    tester,
    relay,
    screen: TogetherScreen.host,
    startFailed: startFailed,
  );
  await tapAndSettle(tester, find.text('Open room →'));
  relay.push(const RoomOpened(code: 'BCDF', you: _sam));
  await settle(tester);
  return harness;
}

Future<LobbyHarness> guestLobby(WidgetTester tester, FakeRelay relay) async {
  final harness = await pumpTogether(
    tester,
    relay,
    screen: TogetherScreen.join,
  );
  await tester.enterText(find.byType(TextField), 'abcd');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await settle(tester);
  relay.push(
    RoomJoined(
      code: 'ABCD',
      you: _sam,
      hostId: _maya.id,
      players: const [_maya, _lee, _sam],
    ),
  );
  await settle(tester);
  return harness;
}

double startOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.descendant(
        of: find.widgetWithText(PillButton, 'Start game →'),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

Finder inDialog(String text) =>
    find.descendant(of: find.byType(ConfirmDialog), matching: find.text(text));

Finder rowOf(String name) => find.ancestor(
  of: find.text(name),
  matching: find.byWidgetPredicate(
    (widget) => widget is Row && widget.children.length >= 2,
  ),
);

GamePhase phaseOf(ProviderContainer container) =>
    container.read(gameControllerProvider).phase;

void main() {
  testWidgets('the host changes the game without closing the room', (
    tester,
  ) async {
    final relay = FakeRelay();
    final (:container, together: _) = await hostLobby(tester, relay);
    relay.push(const PeerJoined(_maya));
    await settle(tester);
    expect(find.byType(LobbyScreen), findsOneWidget);
    expect(find.text('Classic'), findsOneWidget);
    expect(
      find.text('10 rounds · Medium · Shuffle everything'),
      findsOneWidget,
    );

    await tapAndSettle(tester, find.text('Change game'));

    expect(find.byType(HostRoomScreen), findsOneWidget);
    expect(
      find.text('Room BCDF stays open while you change things.'),
      findsOneWidget,
    );
    expect(find.text('Back to room →'), findsOneWidget);
    expect(find.text('Open room →'), findsNothing);

    await tapAndSettle(tester, find.text('Quick draw'));
    await tapAndSettle(tester, find.text('5'));
    final broadcasts = [
      for (final body in relay.bodies)
        if (body.to == null) body.message,
    ];
    expect(broadcasts, [
      const SettingsChanged(
        settings: RoomSettings(mode: TogetherMode.quickDraw),
        scopeLabel: 'Shuffle everything',
      ),
      const SettingsChanged(
        settings: RoomSettings(mode: TogetherMode.quickDraw, rounds: 5),
        scopeLabel: 'Shuffle everything',
      ),
    ]);

    await tapAndSettle(tester, find.text('Back to room →'));

    expect(find.byType(LobbyScreen), findsOneWidget);
    for (final letter in ['B', 'C', 'D', 'F']) {
      expect(find.text(letter), findsOneWidget, reason: letter);
    }
    expect(find.text('Quick draw'), findsOneWidget);
    expect(
      find.text(
        'First right answer takes the round. Guess wrong and you sit out '
        'until the next song.',
      ),
      findsOneWidget,
    );
    expect(find.text('5 rounds · Medium · Shuffle everything'), findsOneWidget);
    expect(find.text('2 of 8 players'), findsOneWidget);

    await tapAndSettle(tester, find.text('Change game'));
    await tapAndSettle(tester, find.text('Back'));
    expect(find.byType(LobbyScreen), findsOneWidget);
    expect(container.read(roomControllerProvider).code, 'BCDF');
    expect(relay.connections, 1);
    expect(relay.connected, isTrue);
    expect(relay.sent.whereType<OpenRoom>(), hasLength(1));

    await tapAndSettle(tester, find.text('Change game'));
    expect(find.byType(HostRoomScreen), findsOneWidget);
    await relay.end();
    await settle(tester);
    expect(find.byType(HostRoomScreen), findsNothing);
    expect(find.text('Lost the connection to the room.'), findsOneWidget);
    expect(find.text('Open room →'), findsNothing);
  });

  testWidgets('the host lobby shows the code, players and a start gate', (
    tester,
  ) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final relay = FakeRelay();
    final (:container, :together) = await hostLobby(tester, relay);

    expect(find.text('← '), findsOneWidget);
    expect(find.text('Leave room'), findsOneWidget);
    expect(find.text('Room code'), findsOneWidget);
    final tiles = [
      for (final letter in ['B', 'C', 'D', 'F'])
        tester.getTopLeft(find.text(letter)),
    ];
    for (final (index, tile) in tiles.indexed.skip(1)) {
      expect(tile.dx, greaterThan(tiles[index - 1].dx));
      expect(tile.dy, tiles[index - 1].dy);
    }
    expect(find.text('Classic'), findsOneWidget);
    expect(
      find.text(
        'Everyone hears the same clip and answers. Faster right answers score '
        'more.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('10 rounds · Medium · Shuffle everything'),
      findsOneWidget,
    );
    expect(find.text('Change game'), findsOneWidget);
    expect(find.text('Players'), findsOneWidget);
    expect(find.text('1 of 8 players'), findsOneWidget);
    expect(find.text('Sam (you)'), findsOneWidget);
    expect(
      find.descendant(of: rowOf('Sam (you)'), matching: find.text('Host')),
      findsOneWidget,
    );
    expect(find.byType(PlayerAvatar), findsOneWidget);
    expect(find.text('Waiting for friends to join…'), findsOneWidget);
    expect(find.text('Needs at least 2 players'), findsOneWidget);
    expect(find.text("Couldn't get the songs ready. Try again."), findsNothing);

    expect(startOpacity(tester), 0.45);
    await tester.tap(find.text('Start game →'));
    await settle(tester);
    expect(together.starts, 0);

    await tester.tap(find.text('Copy code'));
    await tester.pump();
    expect(clipboard, 'BCDF');
    expect(find.text('Copied'), findsOneWidget);
    expect(find.text('Copy code'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Copied'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Copy code'), findsOneWidget);
    expect(find.text('Copied'), findsNothing);

    relay.push(const PeerJoined(_maya));
    await settle(tester);

    expect(find.text('2 of 8 players'), findsOneWidget);
    expect(find.text('Maya'), findsOneWidget);
    expect(
      find.descendant(of: rowOf('Maya'), matching: find.text('Host')),
      findsNothing,
    );
    final avatars = tester.widgetList<PlayerAvatar>(find.byType(PlayerAvatar));
    expect(
      [for (final avatar in avatars) avatar.seed],
      ['seedSam', 'seedMaya'],
    );
    expect([for (final avatar in avatars) avatar.size], [32, 32]);
    expect(
      tester.getTopLeft(find.text('Maya')).dy,
      greaterThan(tester.getTopLeft(find.text('Sam (you)')).dy),
    );
    expect(startOpacity(tester), 1);
    await tester.tap(find.text('Start game →'));
    await settle(tester);
    expect(together.starts, 1);
    expect(container.read(roomControllerProvider).status, RoomStatus.open);

    final failedRelay = FakeRelay();
    await hostLobby(tester, failedRelay, startFailed: true);
    expect(
      find.text("Couldn't get the songs ready. Try again."),
      findsOneWidget,
    );
  });

  testWidgets('a guest waits for the host and leaving asks first', (
    tester,
  ) async {
    final relay = FakeRelay();
    final (:container, :together) = await guestLobby(tester, relay);

    expect(find.byType(LobbyScreen), findsOneWidget);
    expect(find.text('Room ABCD'), findsOneWidget);
    expect(find.text("Maya's room"), findsOneWidget);
    expect(find.text('Room code'), findsNothing);
    expect(find.text('Copy code'), findsNothing);
    expect(find.text('Change game'), findsNothing);
    expect(find.text('Start game →'), findsNothing);
    expect(find.text('3 of 8 players'), findsOneWidget);
    expect(find.text('Sam (you)'), findsOneWidget);
    expect(
      find.descendant(of: rowOf('Maya'), matching: find.text('Host')),
      findsOneWidget,
    );
    expect(find.text('Waiting for Maya to start…'), findsOneWidget);
    expect(find.text('Waiting for friends to join…'), findsNothing);
    expect(
      find.text('10 rounds · Medium · Shuffle everything'),
      findsOneWidget,
    );

    relay.pushGame(
      _maya.id,
      const SettingsChanged(
        settings: RoomSettings(
          mode: TogetherMode.lyricsOrLie,
          difficulty: Difficulty.hard,
        ),
        scopeLabel: '2 eras · 26 tracks',
      ),
    );
    await settle(tester);
    expect(find.text('Lyrics or Lie'), findsOneWidget);
    expect(find.text('10 rounds · Hard · 2 eras · 26 tracks'), findsOneWidget);

    relay.pushGame(
      _maya.id,
      const SettingsChanged(
        settings: RoomSettings(
          versions: VersionChoice(
            live: false,
            rerecorded: Rerecorded.taylorsVersion,
          ),
        ),
        scopeLabel: 'Shuffle everything',
      ),
    );
    await settle(tester);
    expect(
      find.text(
        '10 rounds · Medium · Shuffle everything · Studio, Acoustic & remixes '
        '· Taylor’s Version',
      ),
      findsOneWidget,
    );

    await tapAndSettle(tester, find.text('Leave room'));
    expect(inDialog('Leave the room?'), findsOneWidget);
    expect(
      inDialog('You can join again with the same code while the room is open.'),
      findsOneWidget,
    );
    expect(inDialog('Leave'), findsOneWidget);
    await tapAndSettle(tester, inDialog('Cancel'));
    expect(find.byType(ConfirmDialog), findsNothing);
    expect(find.byType(LobbyScreen), findsOneWidget);
    expect(together.leaves, 0);

    await tapAndSettle(tester, find.text('Leave room'));
    relay.pushGame(_maya.id, const GameStarting(settings: RoomSettings()));
    await settle(tester);
    expect(find.byType(TogetherGameScreen), findsOneWidget);
    expect(inDialog('Leave'), findsOneWidget);
    await tapAndSettle(tester, inDialog('Leave'));
    await disconnect(tester);
    expect(together.leaves, 1);
    expect(phaseOf(container), GamePhase.menu);
    expect(find.text('menu'), findsOneWidget);
    expect(relay.connected, isFalse);

    final hostRelay = FakeRelay();
    final host = await hostLobby(tester, hostRelay);
    await tapAndSettle(tester, find.text('Leave room'));
    expect(inDialog('Close the room?'), findsOneWidget);
    expect(inDialog('Everyone in it goes back to the menu.'), findsOneWidget);
    expect(inDialog('Close room'), findsOneWidget);
    expect(inDialog('Leave the room?'), findsNothing);
    await tapAndSettle(tester, inDialog('Close room'));
    await disconnect(tester);
    expect(host.together.leaves, 1);
    expect(phaseOf(host.container), GamePhase.menu);
    expect(host.container.read(togetherNavProvider), TogetherScreen.hub);
    expect(hostRelay.connected, isFalse);
  });

  testWidgets('a closed room says so and offers the menu', (tester) async {
    for (final (closed, line) in [
      (true, 'Maya closed the room.'),
      (false, 'Lost the connection to the room.'),
    ]) {
      final relay = FakeRelay();
      final (:container, :together) = await guestLobby(tester, relay);
      if (closed) {
        relay.push(const RoomClosed());
      }
      await relay.end();
      await settle(tester);

      expect(
        container.read(roomControllerProvider).failure,
        closed ? RoomFailure.hostClosed : RoomFailure.connectionLost,
      );
      expect(find.text(line), findsOneWidget, reason: line);
      expect(find.text('Back to menu'), findsOneWidget, reason: line);
      expect(find.text('Players'), findsNothing, reason: line);

      await tapAndSettle(tester, find.text('Back to menu'));

      expect(together.leaves, 1, reason: line);
      expect(phaseOf(container), GamePhase.menu, reason: line);
      expect(find.text('menu'), findsOneWidget, reason: line);
      expect(container.read(togetherNavProvider), TogetherScreen.hub);
      expect(container.read(roomControllerProvider), RoomState.initial);
    }
  });
}
