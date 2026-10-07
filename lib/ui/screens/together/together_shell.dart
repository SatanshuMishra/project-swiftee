import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/state/together/room_controller.dart';
import 'package:swiftie_quiz/state/together/room_state.dart';
import 'package:swiftie_quiz/state/together/together_game_controller.dart';
import 'package:swiftie_quiz/state/together/together_game_state.dart';
import 'package:swiftie_quiz/ui/screens/album_grid.dart';
import 'package:swiftie_quiz/ui/screens/together/final_standings_screen.dart';
import 'package:swiftie_quiz/ui/screens/together/host_room_screen.dart';
import 'package:swiftie_quiz/ui/screens/together/join_room_screen.dart';
import 'package:swiftie_quiz/ui/screens/together/lobby_screen.dart';
import 'package:swiftie_quiz/ui/screens/together/together_game_screen.dart';
import 'package:swiftie_quiz/ui/screens/together/together_hub_screen.dart';
import 'package:swiftie_quiz/ui/screens/together/together_nav.dart';

class TogetherShell extends ConsumerWidget {
  const TogetherShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(
      togetherGameControllerProvider.select((game) => game.stage),
    );
    switch (stage) {
      case TogetherStage.starting ||
          TogetherStage.countdown ||
          TogetherStage.loading ||
          TogetherStage.round ||
          TogetherStage.reveal ||
          TogetherStage.lost:
        return const TogetherGameScreen();
      case TogetherStage.ended:
        return const FinalStandingsScreen();
      case TogetherStage.idle:
        break;
    }
    final nav = ref.watch(togetherNavProvider);
    final (status, failure, role) = ref.watch(
      roomControllerProvider.select(
        (room) => (room.status, room.failure, room.role),
      ),
    );
    final inRoom = switch (status) {
      RoomStatus.open => true,
      RoomStatus.closed =>
        failure == RoomFailure.hostClosed ||
            failure == RoomFailure.connectionLost,
      RoomStatus.idle || RoomStatus.connecting => false,
    };
    final editing =
        role == RoomRole.host &&
        status == RoomStatus.open &&
        (nav == TogetherScreen.host || nav == TogetherScreen.eras);
    if (inRoom && !editing) {
      return const LobbyScreen();
    }
    return switch (nav) {
      TogetherScreen.hub => const TogetherHubScreen(),
      TogetherScreen.host => const HostRoomScreen(),
      TogetherScreen.join => const JoinRoomScreen(),
      TogetherScreen.eras => AlbumGrid(
        onBack: () =>
            ref.read(togetherNavProvider.notifier).show(TogetherScreen.host),
        onContinue: () => storePickedScope(ref),
      ),
    };
  }
}
