import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/game_engine.dart';
import 'package:swiftie_quiz/domain/models/track.dart';

Track makeTrack(int id, [String preview = 'https://example.com/p.mp3']) =>
    Track(
      id: id,
      title: 'Track $id',
      titleShort: 'Track $id',
      duration: 30,
      preview: preview,
      artist: const Artist(id: 12246, name: 'Taylor Swift'),
      album: const Album(id: 1, title: 'Album', coverMedium: null),
    );

void main() {
  group('game engine parity', () {
    group('createTrackPool', () {
      test('keeps tracks whose preview is fetched when they play', () {
        final tracks = [makeTrack(1), makeTrack(2, ''), makeTrack(3)];
        final pool = createTrackPool(tracks, random: Random(1));
        expect(pool.map((track) => track.id), unorderedEquals([1, 2, 3]));
      });

      test('shuffles the pool', () {
        final tracks = List.generate(20, makeTrack);
        final pool = createTrackPool(tracks, random: Random(2));
        expect(pool.length, 20);
        final ids = pool.map((track) => track.id).toList()..sort();
        expect(ids, List.generate(20, (i) => i));
      });
    });

    group('drawNextTrack', () {
      test('draws from pool and returns remainder', () {
        final tracks = [makeTrack(1), makeTrack(2), makeTrack(3)];
        final draw = drawNextTrack(tracks, tracks, random: Random(3));
        expect(draw.track.id, 1);
        expect(draw.remaining.length, 2);
      });

      test('reshuffles when pool is empty', () {
        final allTracks = [makeTrack(1), makeTrack(2)];
        final draw = drawNextTrack([], allTracks, random: Random(4));
        expect(draw.track, isA<Track>());
        expect(draw.remaining.length, 1);
      });
    });
  });
}
