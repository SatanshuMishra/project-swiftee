import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/play_history.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

Track _track(int id) => Track(
  id: id,
  title: 'Song $id',
  titleShort: 'Song $id',
  duration: 200,
  preview: '',
  artist: const Artist(id: 12246, name: 'Taylor Swift'),
  album: const Album(id: 1, title: 'Album', coverMedium: null),
);

void main() {
  group('PlayHistory', () {
    test('keeps the latest plays and forgets the oldest past the limit', () {
      var history = PlayHistory.empty;
      for (var id = 0; id < PlayHistory.limit + 5; id++) {
        history = history.hear(_track(id)).readLyrics('song $id', ['line $id']);
      }

      expect(history.heard, hasLength(PlayHistory.limit));
      expect(history.heard.first.id, 5);
      expect(history.heard.last.id, PlayHistory.limit + 4);
      expect(history.read.first, 'song 5');
      expect(history.lines.first, 'line 5');
    });

    test('adding a play returns a new history and leaves the old one', () {
      final before = PlayHistory.empty.hear(_track(1));
      final after = before.hear(_track(2)).readLyrics('red', ['a', 'b']);

      expect(before.heard.map((track) => track.id), [1]);
      expect(before.read, isEmpty);
      expect(after.heard.map((track) => track.id), [1, 2]);
      expect(after.read, ['red']);
      expect(after.lines, ['a', 'b']);
    });

    test('its lists cannot be changed from outside', () {
      final history = PlayHistory.empty.hear(_track(1)).readLyrics('red', [
        'a',
      ]);

      expect(() => history.heard.add(_track(2)), throwsUnsupportedError);
      expect(() => history.read.add('22'), throwsUnsupportedError);
      expect(() => history.lines.clear(), throwsUnsupportedError);
    });

    test('two histories with the same plays are equal', () {
      expect(
        PlayHistory.empty.hear(_track(1)).readLyrics('red', ['a']),
        PlayHistory.empty.hear(_track(1)).readLyrics('red', ['a']),
      );
      expect(
        PlayHistory.empty.hear(_track(1)),
        isNot(PlayHistory.empty.hear(_track(2))),
      );
    });
  });
}
