import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/lyric_processor.dart';
import 'package:swiftie_quiz/domain/engine/play_order.dart';
import 'package:swiftie_quiz/domain/models/play_history.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

final playHistoryProvider =
    NotifierProvider<PlayHistoryController, PlayHistory>(
      PlayHistoryController.new,
    );

class PlayHistoryController extends Notifier<PlayHistory> {
  @override
  PlayHistory build() => PlayHistory.empty;

  void heard(Track track) => state = state.hear(track);

  void read(Track track, Iterable<String> lines) =>
      state = state.readLyrics(songKey(track), lines.map(lyricLineKey));
}
