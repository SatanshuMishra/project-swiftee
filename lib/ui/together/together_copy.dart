import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/state/together/room_state.dart';
import 'package:swiftie_quiz/ui/screens/game_screen.dart' show difficultyLabel;

String roomMeta(RoomSettings settings, String scopeLabel) =>
    '${settings.rounds} rounds · ${difficultyLabel(settings.difficulty)} · '
    '$scopeLabel';

String failureLine(
  RoomFailure failure, {
  bool hosting = false,
  String host = '',
}) => switch (failure) {
  RoomFailure.badLink =>
    "The server didn't accept your link. Check it in Settings.",
  RoomFailure.needsUpdate =>
    'That server needs a newer Project Swiftie. Update and try again.',
  RoomFailure.busy => 'The server is busy. Try again in a minute.',
  RoomFailure.unreachable when hosting =>
    "Couldn't open a room. Check your connection and try again.",
  RoomFailure.unreachable || RoomFailure.notFound =>
    "Couldn't reach that room. Check the code and your connection.",
  RoomFailure.badCode => 'Room codes are 4 letters.',
  RoomFailure.full => 'That room is full.',
  RoomFailure.inGame =>
    "That game has already started. Try again when it's over.",
  RoomFailure.gameMismatch =>
    'Everyone in a room needs the same version of Project Swiftie.',
  RoomFailure.hostClosed => '$host closed the room.',
  RoomFailure.connectionLost => 'Lost the connection to the room.',
};
