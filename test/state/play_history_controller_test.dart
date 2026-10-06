import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/play_history_controller.dart';

Track _track(int id, String title) => Track(
  id: id,
  title: title,
  titleShort: title,
  duration: 200,
  preview: '',
  artist: const Artist(id: 12246, name: 'Taylor Swift'),
  album: const Album(id: 1, title: 'Red', coverMedium: null),
);

void main() {
  group('PlayHistoryController', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer.test());

    test('starts each session with nothing heard or read', () {
      final history = container.read(playHistoryProvider);

      expect(history.heard, isEmpty);
      expect(history.read, isEmpty);
      expect(history.lines, isEmpty);
    });

    test('remembers each recording heard, in order', () {
      final red = _track(1, 'Red');
      final redTv = _track(2, "Red (Taylor's Version)");
      container.read(playHistoryProvider.notifier)
        ..heard(red)
        ..heard(redTv);

      expect(container.read(playHistoryProvider).heard, [red, redTv]);
    });

    test('remembers lyrics by song and lines by their words', () {
      container.read(playHistoryProvider.notifier).read(
        _track(2, "Red (Taylor's Version)"),
        [
          'Loving him is like driving a new Maserati',
          'Down a DEAD-END street!',
        ],
      );
      final history = container.read(playHistoryProvider);

      expect(history.read, ['red']);
      expect(history.lines, [
        'loving him is like driving a new maserati',
        'down a deadend street',
      ]);
    });
  });
}
