import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/together/relay_connection.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/together/game_messages.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/together/room_controller.dart';
import 'package:swiftie_quiz/state/together/room_state.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/screens/together/join_room_screen.dart';
import 'package:swiftie_quiz/ui/screens/together/together_nav.dart';
import 'package:swiftie_quiz/ui/screens/together/together_shell.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:together_protocol/together_protocol.dart';

import '../../../state/together/fake_relay.dart';

final String _link = 'https://swiftie.satanshu.tech/#${'Ab0-_' * 8}xyz';

Future<ProviderContainer> pumpJoin(WidgetTester tester, FakeRelay relay) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer.test(
    overrides: [
      relayConnectorProvider.overrideWithValue(relay),
      editionProvider.overrideWithValue(Edition.open),
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
  container.read(togetherNavProvider.notifier).show(TogetherScreen.join);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Material(child: TogetherShell()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder codeField() => find.descendant(
  of: find.byType(JoinRoomScreen),
  matching: find.byType(TextField),
);

String typed(WidgetTester tester) =>
    tester.widget<TextField>(codeField()).controller!.text;

double joinOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(PillButton),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

List<JoinRoom> joins(FakeRelay relay) => [
  for (final message in relay.sent)
    if (message is JoinRoom) message,
];

void main() {
  testWidgets('the code field keeps four uppercase letters and joins', (
    tester,
  ) async {
    final relay = FakeRelay();
    final container = await pumpJoin(tester, relay);

    expect(find.text('Join a room'), findsOneWidget);
    expect(find.text('Ask the host for their 4-letter code.'), findsOneWidget);
    expect(find.text('ABCD'), findsOneWidget);
    expect(find.text('Join →'), findsOneWidget);
    expect(tester.widget<TextField>(codeField()).autofocus, isTrue);
    expect(joinOpacity(tester), 0.45);

    await tester.enterText(codeField(), 'ab1cde');
    await tester.pump();
    expect(typed(tester), 'ABCD');
    expect(joinOpacity(tester), 1);

    await tester.enterText(codeField(), 'w-x');
    await tester.pump();
    expect(typed(tester), 'WX');
    expect(joinOpacity(tester), 0.45);

    await tester.enterText(codeField(), 'qrst');
    await tester.pump();
    expect(typed(tester), 'QRST');
    await tester.tap(find.text('Join →'));
    await tester.pump();

    expect(find.text('Joining…'), findsOneWidget);
    expect(find.text('Join →'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(PillButton),
        matching: find.byType(RotationTransition),
      ),
      findsOneWidget,
    );
    expect(
      container.read(roomControllerProvider).status,
      RoomStatus.connecting,
    );
    expect(joins(relay), [
      const JoinRoom(code: 'QRST', name: 'Sam', game: gameProtocolVersion),
    ]);

    await tester.tap(find.text('Back'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(roomControllerProvider).status, RoomStatus.idle);
    expect(container.read(togetherNavProvider), TogetherScreen.hub);
    expect(find.byType(JoinRoomScreen), findsNothing);
    expect(find.text('Joining…'), findsNothing);

    final enterRelay = FakeRelay();
    await pumpJoin(tester, enterRelay);
    await tester.enterText(codeField(), 'mnop');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Joining…'), findsOneWidget);
    expect(joins(enterRelay), [
      const JoinRoom(code: 'MNOP', name: 'Sam', game: gameProtocolVersion),
    ]);
  });

  testWidgets('join failures show their lines', (tester) async {
    Future<void> expectLine(String line) async {
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text(line), findsOneWidget, reason: line);
      expect(
        tester.widget<Text>(find.text(line)).style?.color,
        AppTokens.dark.rose,
        reason: line,
      );
      expect(
        tester.getTopLeft(find.text(line)).dy,
        greaterThan(tester.getBottomLeft(codeField()).dy),
        reason: line,
      );
      expect(find.text('Join →'), findsOneWidget, reason: line);
    }

    final relay = FakeRelay();
    final container = await pumpJoin(tester, relay);

    await tester.enterText(codeField(), 'ab');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await expectLine('Room codes are 4 letters.');
    expect(relay.connections, 0);
    expect(container.read(roomControllerProvider).failure, RoomFailure.badCode);

    await tester.enterText(codeField(), 'abcd');
    await tester.pump();
    for (final (reason, line) in [
      (
        RelayErrorReason.notFound,
        "Couldn't reach that room. Check the code and your connection.",
      ),
      (RelayErrorReason.full, 'That room is full.'),
      (
        RelayErrorReason.inGame,
        "That game has already started. Try again when it's over.",
      ),
      (
        RelayErrorReason.gameMismatch,
        'Everyone in a room needs the same version of Project Swiftie.',
      ),
    ]) {
      await tester.tap(find.text('Join →'));
      await tester.pump();
      expect(find.text('Joining…'), findsOneWidget);
      relay.push(RelayError(reason));
      await expectLine(line);
    }
    expect(relay.connections, 4);

    for (final (refusal, line) in [
      (
        RelayFailure.badLink,
        "The server didn't accept your link. Check it in Settings.",
      ),
      (
        RelayFailure.unreachable,
        "Couldn't reach that room. Check the code and your connection.",
      ),
      (
        RelayFailure.needsUpdate,
        'That server needs a newer Project Swiftie. Update and try again.',
      ),
    ]) {
      await pumpJoin(tester, FakeRelay(refusal: refusal));
      await tester.enterText(codeField(), 'abcd');
      await tester.pump();
      await tester.tap(find.text('Join →'));
      await expectLine(line);
    }
  });
}
