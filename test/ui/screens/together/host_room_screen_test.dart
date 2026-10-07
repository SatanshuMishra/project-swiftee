import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/together/relay_connection.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/together/game_messages.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/together/room_controller.dart';
import 'package:swiftie_quiz/state/together/room_state.dart';
import 'package:swiftie_quiz/ui/kit/choice_row.dart';
import 'package:swiftie_quiz/ui/kit/segmented.dart';
import 'package:swiftie_quiz/ui/screens/album_grid.dart';
import 'package:swiftie_quiz/ui/screens/together/host_room_screen.dart';
import 'package:swiftie_quiz/ui/screens/together/together_nav.dart';
import 'package:swiftie_quiz/ui/screens/together/together_shell.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:together_protocol/together_protocol.dart';

import '../../../state/together/fake_relay.dart';
import '../album_grid_test.dart' show FakeCatalog, bundled;

final String _link = 'https://swiftie.satanshu.tech/#${'Ab0-_' * 8}xyz';

const Player _sam = Player(id: 'host1', name: 'Sam', avatar: 'seedSam');

Future<ProviderContainer> pumpHost(WidgetTester tester, FakeRelay relay) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer.test(
    overrides: [
      relayConnectorProvider.overrideWithValue(relay),
      editionProvider.overrideWithValue(Edition.open),
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
  container.read(togetherNavProvider.notifier).show(TogetherScreen.host);
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

ChoiceRow choice(WidgetTester tester, String title) => tester.widget<ChoiceRow>(
  find.ancestor(of: find.text(title), matching: find.byType(ChoiceRow)),
);

RoomState roomOf(ProviderContainer container) =>
    container.read(roomControllerProvider);

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the host screen offers the prototype choices with their defaults',
    (tester) async {
      final container = await pumpHost(tester, FakeRelay());

      for (final text in [
        'Host a room',
        'Everyone plays the same songs at the same time. Up to 8 players.',
        'Game',
        'Songs',
        'Rounds',
        'Difficulty',
        'Classic',
        'Everyone hears the same clip and answers. Faster right answers score '
            'more.',
        'Quick draw',
        'First right answer takes the round. Guess wrong and you sit out until '
            'the next song.',
        'Lyrics or Lie',
        'Everyone sees the same line and votes Real or Fake. Every right call '
            'scores.',
        'Shuffle everything',
        'Every song, every era.',
        'Pick your eras',
        'Stick to the albums you love most.',
        '5',
        '10',
        '15',
        'Easy',
        'Medium',
        'Hard',
        'No hints · 20 seconds a round',
        'Open room →',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.textContaining('stays open'), findsNothing);
      expect(find.text('Back to room →'), findsNothing);

      expect(choice(tester, 'Classic').selected, isTrue);
      expect(choice(tester, 'Quick draw').selected, isFalse);
      expect(choice(tester, 'Lyrics or Lie').selected, isFalse);
      expect(choice(tester, 'Shuffle everything').selected, isTrue);
      expect(choice(tester, 'Pick your eras').selected, isFalse);
      expect(
        tester.widget<Segmented<int>>(find.byType(Segmented<int>)).value,
        10,
      );
      expect(
        tester
            .widget<Segmented<Difficulty>>(find.byType(Segmented<Difficulty>))
            .value,
        Difficulty.medium,
      );
      expect(roomOf(container).settings, const RoomSettings());
      expect(roomOf(container).scopeLabel, 'Shuffle everything');

      await tapAndSettle(tester, find.text('Hard'));
      expect(find.text('No hints · 12 seconds a round'), findsOneWidget);
      await tapAndSettle(tester, find.text('Easy'));
      expect(
        find.text('Album cover shown · 30 seconds a round'),
        findsOneWidget,
      );
      await tapAndSettle(tester, find.text('15'));
      await tapAndSettle(tester, find.text('Lyrics or Lie'));
      expect(choice(tester, 'Lyrics or Lie').selected, isTrue);
      expect(choice(tester, 'Classic').selected, isFalse);
      expect(
        roomOf(container).settings,
        const RoomSettings(
          mode: TogetherMode.lyricsOrLie,
          rounds: 15,
          difficulty: Difficulty.easy,
        ),
      );
    },
  );

  testWidgets('a failed open shows its line under the button', (tester) async {
    for (final (refusal, line) in [
      (
        RelayFailure.unreachable,
        "Couldn't open a room. Check your connection and try again.",
      ),
      (
        RelayFailure.badLink,
        "The server didn't accept your link. Check it in Settings.",
      ),
      (
        RelayFailure.needsUpdate,
        'That server needs a newer Project Swiftie. Update and try again.',
      ),
      (RelayFailure.busy, 'The server is busy. Try again in a minute.'),
    ]) {
      final relay = FakeRelay(refusal: refusal);
      final container = await pumpHost(tester, relay);
      expect(find.text(line), findsNothing);

      await tapAndSettle(tester, find.text('Open room →'));

      expect(find.text(line), findsOneWidget, reason: line);
      expect(
        tester.widget<Text>(find.text(line)).style?.color,
        AppTokens.dark.rose,
      );
      expect(
        tester.getTopLeft(find.text(line)).dy,
        greaterThan(tester.getBottomLeft(find.text('Open room →')).dy),
      );
      expect(roomOf(container).status, RoomStatus.idle);
      expect(relay.connections, 0);
      expect(find.text('Host a room'), findsOneWidget);
    }

    final relay = FakeRelay();
    final container = await pumpHost(tester, relay);
    await tester.tap(find.text('Open room →'));
    await tester.pump();
    expect(find.text('Opening…'), findsOneWidget);
    expect(find.text('Open room →'), findsNothing);
    expect(relay.sent, [
      const OpenRoom(name: 'Sam', game: gameProtocolVersion),
    ]);

    relay.push(const RoomOpened(code: 'BCDF', you: _sam));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(roomOf(container).status, RoomStatus.open);
    expect(container.read(togetherNavProvider), TogetherScreen.hub);
    expect(find.byType(HostRoomScreen), findsNothing);
    expect(find.text('Room code'), findsOneWidget);
  });

  testWidgets('picking eras returns to the host screen with the summary', (
    tester,
  ) async {
    final container = await pumpHost(tester, FakeRelay());
    final label = AlbumGrid.selectionLabel(
      1,
      0,
      bundled.tracksFor(['lover']).length,
    );
    expect(label, startsWith('1 era · '));

    await tapAndSettle(tester, find.text('Pick your eras'));
    expect(find.byType(AlbumGrid), findsOneWidget);
    expect(find.byType(HostRoomScreen), findsNothing);
    expect(container.read(gameControllerProvider).selectedEraKeys, isEmpty);

    await tapAndSettle(tester, find.byKey(const ValueKey('lover')));
    await tapAndSettle(tester, find.text('Continue →'));

    expect(find.byType(AlbumGrid), findsNothing);
    expect(find.text('Host a room'), findsOneWidget);
    expect(choice(tester, 'Pick your eras').selected, isTrue);
    expect(choice(tester, 'Pick your eras').description, label);
    expect(choice(tester, 'Shuffle everything').selected, isFalse);
    expect(find.text(label), findsOneWidget);
    expect(
      roomOf(container).settings.scope,
      RoomScope.picked(eraKeys: ['lover'], releaseIds: []),
    );
    expect(roomOf(container).scopeLabel, label);
    expect(container.read(gameControllerProvider).phase, GamePhase.together);

    container.read(gameControllerProvider.notifier).clearSelection();
    await tapAndSettle(tester, find.text('Pick your eras'));
    expect(container.read(gameControllerProvider).selectedEraKeys, ['lover']);
    await tapAndSettle(tester, find.byKey(const ValueKey('fearless')));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Back'));

    expect(find.text('Host a room'), findsOneWidget);
    expect(choice(tester, 'Pick your eras').description, label);
    expect(
      roomOf(container).settings.scope,
      RoomScope.picked(eraKeys: ['lover'], releaseIds: []),
    );

    await tapAndSettle(tester, find.text('Shuffle everything'));
    expect(choice(tester, 'Shuffle everything').selected, isTrue);
    expect(
      choice(tester, 'Pick your eras').description,
      'Stick to the albums you love most.',
    );
    expect(roomOf(container).settings.scope, const RoomScope.everything());
    expect(roomOf(container).scopeLabel, 'Shuffle everything');
  });
}
