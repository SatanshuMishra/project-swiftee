import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/together/relay_connection.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/together/game_messages.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/domain/together/server_link.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/together/room_controller.dart';
import 'package:swiftie_quiz/state/together/room_state.dart';
import 'package:together_protocol/together_protocol.dart';

import 'fake_relay.dart';

final ServerLink _link = ServerLink.parse(
  'https://swiftie.satanshu.tech/#${'Ab0-_' * 8}xyz',
)!;

const Player _ana = Player(id: 'host1', name: 'Ana', avatar: 'seedAna');
const Player _maya = Player(id: 'guest1', name: 'Maya', avatar: 'seedMaya');
const Player _lee = Player(id: 'guest2', name: 'Lee', avatar: 'seedLee');
const Player _sam = Player(id: 'guest3', name: 'Sam', avatar: 'seedSam');

ProviderContainer _container(
  FakeRelay relay, {
  Edition edition = Edition.open,
  String nickname = 'Sam',
}) {
  final container = ProviderContainer.test(
    overrides: [
      relayConnectorProvider.overrideWithValue(relay),
      editionProvider.overrideWithValue(edition),
    ],
  );
  container
      .read(gameControllerProvider.notifier)
      .setProgress(
        defaultProgress.copyWith(
          settings: defaultProgress.settings.copyWith(nickname: nickname),
        ),
      );
  return container;
}

void main() {
  group('play together room', () {
    test(
      "opening a room uses the edition's name and lists joiners in order",
      () async {
        final openRelay = FakeRelay();
        await _container(openRelay)
            .read(roomControllerProvider.notifier)
            .open(_link);
        expect(openRelay.sent, [
          const OpenRoom(name: 'Sam', game: gameProtocolVersion),
        ]);

        final relay = FakeRelay();
        final container = _container(relay, edition: Edition.ana);
        final room = container.read(roomControllerProvider.notifier);
        RoomState state() => container.read(roomControllerProvider);
        final presence = room.presence.take(3).toList();

        await room.open(_link);
        expect(relay.sent, [
          const OpenRoom(name: 'Ana', game: gameProtocolVersion),
        ]);
        expect(state().status, RoomStatus.connecting);

        relay.push(const RoomOpened(code: 'BCDF', you: _ana));
        await pumpEventQueue();
        expect(state().role, RoomRole.host);
        expect(state().status, RoomStatus.open);
        expect(state().code, 'BCDF');
        expect(state().you, _ana);
        expect(state().hostId, _ana.id);
        expect(state().hostName, 'Ana');
        expect(state().players, [_ana]);

        relay
          ..push(const PeerJoined(_maya))
          ..push(const PeerJoined(_lee));
        await pumpEventQueue();
        expect(state().players, [_ana, _maya, _lee]);

        relay.push(PeerLeft(_maya.id));
        await pumpEventQueue();
        expect(state().players, [_ana, _lee]);
        expect(await presence, [
          const PeerJoined(_maya),
          const PeerJoined(_lee),
          PeerLeft(_maya.id),
        ]);
        expect(relay.connections, 1);
      },
    );

    test('changing settings while the room is open reaches every guest on the same connection', () async {
      final relay = FakeRelay();
      final container = _container(relay);
      final room = container.read(roomControllerProvider.notifier);
      RoomState state() => container.read(roomControllerProvider);
      const picked = RoomSettings(
        mode: TogetherMode.lyricsOrLie,
        rounds: 5,
        difficulty: Difficulty.easy,
      );
      const pickedChange = SettingsChanged(
        settings: picked,
        scopeLabel: 'Shuffle everything',
      );
      final changed = RoomSettings(
        mode: TogetherMode.quickDraw,
        rounds: 15,
        difficulty: Difficulty.hard,
        scope: RoomScope.picked(
          eraKeys: const ['speak-now', 'evermore'],
          releaseIds: const [],
        ),
      );

      room.setSettings(picked, 'Shuffle everything');
      await Future.wait([room.open(_link), room.open(_link)]);
      relay.push(const RoomOpened(code: 'BCDF', you: _sam));
      await pumpEventQueue();
      await room.open(_link);
      expect(relay.sent, [
        const OpenRoom(name: 'Sam', game: gameProtocolVersion),
      ]);

      relay.push(const PeerJoined(_maya));
      await pumpEventQueue();
      expect(relay.bodies, [(to: _maya.id, message: pickedChange)]);

      room.setSettings(changed, '2 eras · 26 tracks');
      expect(relay.bodies, [
        (to: _maya.id, message: pickedChange),
        (
          to: null,
          message: SettingsChanged(
            settings: changed,
            scopeLabel: '2 eras · 26 tracks',
          ),
        ),
      ]);
      expect(state().settings, changed);
      expect(state().scopeLabel, '2 eras · 26 tracks');
      expect(state().code, 'BCDF');
      expect(state().players, [_sam, _maya]);
      expect(relay.connections, 1);

      await room.leave();
      expect(
        state(),
        RoomState.initial.copyWith(
          settings: changed,
          scopeLabel: '2 eras · 26 tracks',
        ),
      );
      expect(relay.connected, isFalse);
    });

    test('join codes are checked and relay refusals become failures', () async {
      final relay = FakeRelay();
      final container = _container(relay);
      final room = container.read(roomControllerProvider.notifier);
      RoomState state() => container.read(roomControllerProvider);

      await room.join(_link, 'ab1');
      expect(state().failure, RoomFailure.badCode);
      expect(state().status, RoomStatus.idle);
      expect(relay.connections, 0);

      await room.join(_link, 'abcd');
      expect(relay.sent, [
        const JoinRoom(code: 'ABCD', name: 'Sam', game: gameProtocolVersion),
      ]);
      expect(state().status, RoomStatus.connecting);
      expect(state().failure, isNull);
      await room.leave();

      const reasons = {
        RelayErrorReason.notFound: RoomFailure.notFound,
        RelayErrorReason.full: RoomFailure.full,
        RelayErrorReason.inGame: RoomFailure.inGame,
        RelayErrorReason.gameMismatch: RoomFailure.gameMismatch,
      };
      for (final MapEntry(key: reason, value: failure) in reasons.entries) {
        await room.join(_link, 'wxyz');
        relay.push(RelayError(reason));
        await pumpEventQueue();
        expect(state().failure, failure, reason: reason.wireName);
        expect(state().status, RoomStatus.idle);
        expect(relay.connected, isFalse);
      }
      expect(relay.connections, 5);

      await room.join(_link, 'wxyz');
      await relay.end();
      await pumpEventQueue();
      expect(state().failure, RoomFailure.unreachable);
      expect(state().status, RoomStatus.idle);

      const refusals = {
        RelayFailure.badLink: RoomFailure.badLink,
        RelayFailure.needsUpdate: RoomFailure.needsUpdate,
        RelayFailure.busy: RoomFailure.busy,
        RelayFailure.unreachable: RoomFailure.unreachable,
      };
      for (final MapEntry(key: refusal, value: failure) in refusals.entries) {
        final refusing = FakeRelay(refusal: refusal);
        final refused = _container(refusing);
        await refused.read(roomControllerProvider.notifier).join(_link, 'abcd');
        expect(
          refused.read(roomControllerProvider).failure,
          failure,
          reason: refusal.name,
        );
        expect(refused.read(roomControllerProvider).status, RoomStatus.idle);
        expect(refusing.sent, isEmpty);
      }
    });

    test(
      "a guest follows the host's settings and notices the room closing",
      () async {
        final relay = FakeRelay();
        final container = _container(relay);
        final room = container.read(roomControllerProvider.notifier);
        RoomState state() => container.read(roomControllerProvider);
        final hostSettings = RoomSettings(
          mode: TogetherMode.quickDraw,
          rounds: 5,
          difficulty: Difficulty.hard,
          scope: RoomScope.picked(
            eraKeys: const ['evermore'],
            releaseIds: const [],
          ),
        );
        final hostChange = SettingsChanged(
          settings: hostSettings,
          scopeLabel: '1 era · 13 tracks',
        );
        const strayChange = SettingsChanged(
          settings: RoomSettings(),
          scopeLabel: 'Shuffle everything',
        );
        final received = room.messages.take(2).toList();
        final joined = RoomJoined(
          code: 'ABCD',
          you: _sam,
          hostId: _maya.id,
          players: const [_maya, _sam],
        );

        await room.join(_link, 'ABCD');
        relay.push(joined);
        await pumpEventQueue();
        expect(state().role, RoomRole.guest);
        expect(state().status, RoomStatus.open);
        expect(state().code, 'ABCD');
        expect(state().you, _sam);
        expect(state().hostName, 'Maya');
        expect(state().players, [_maya, _sam]);

        relay
          ..pushGame(_maya.id, hostChange)
          ..pushGame(_lee.id, strayChange);
        await pumpEventQueue();
        expect(state().settings, hostSettings);
        expect(state().scopeLabel, '1 era · 13 tracks');
        expect(await received, [
          (from: _maya.id, message: hostChange),
          (from: _lee.id, message: strayChange),
        ]);

        relay.push(const RoomClosed());
        await relay.end();
        await pumpEventQueue();
        expect(state().status, RoomStatus.closed);
        expect(state().failure, RoomFailure.hostClosed);
        expect(state().closedBy, 'Maya');

        room.clearFailure();
        expect(state().failure, isNull);
        expect(state().closedBy, isNull);

        await room.leave();
        expect(state(), RoomState.initial);

        await room.join(_link, 'ABCD');
        relay.push(const RelayError(RelayErrorReason.full));
        await relay.end();
        await pumpEventQueue();
        expect(state().failure, RoomFailure.full);
        expect(state().status, RoomStatus.idle);

        await room.join(_link, 'ABCD');
        relay.push(joined);
        await pumpEventQueue();
        expect(state().status, RoomStatus.open);
        await relay.end();
        await pumpEventQueue();
        expect(state().status, RoomStatus.closed);
        expect(state().failure, RoomFailure.connectionLost);
      },
    );
  });
}
