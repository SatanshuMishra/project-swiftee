import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/together/room_controller.dart';
import 'package:swiftie_quiz/state/together/room_state.dart';
import 'package:swiftie_quiz/state/together/together_game_controller.dart';

enum TogetherScreen { hub, host, join, eras }

final togetherNavProvider = NotifierProvider<TogetherNav, TogetherScreen>(
  TogetherNav.new,
);

class TogetherNav extends Notifier<TogetherScreen> {
  @override
  TogetherScreen build() => TogetherScreen.hub;

  void show(TogetherScreen screen) => state = screen;
}

void backToHub(WidgetRef ref) {
  if (ref.read(roomControllerProvider).status == RoomStatus.connecting) {
    unawaited(ref.read(roomControllerProvider.notifier).leave());
  }
  ref.read(togetherNavProvider.notifier).show(TogetherScreen.hub);
}

VoidCallback leaveAction(WidgetRef ref) {
  final nav = ref.read(togetherNavProvider.notifier);
  final game = ref.read(gameControllerProvider.notifier);
  final together = ref.read(togetherGameControllerProvider.notifier);
  return () {
    nav.show(TogetherScreen.hub);
    game.setPhase(GamePhase.menu);
    unawaited(together.leaveTogether());
  };
}

void leavePlayTogether(WidgetRef ref) => leaveAction(ref)();
