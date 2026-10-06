import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/data/lyrics/lrclib_client.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/util/shuffle.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

const int minLyricsPoolSize = 5;
const int _initialBatchSize = 8;
const int _rollingBatchSize = 5;

const String noAlbumTracksMessage =
    'Could not load tracks for the selected albums. Please try again.';

final class LyricsSourceError implements Exception {
  const LyricsSourceError(this.message);

  final String message;

  @override
  String toString() => message;
}

final lyricsControllerProvider = Provider<LyricsController>(
  LyricsController.new,
);

class LyricsController {
  LyricsController(this._ref);

  final Ref _ref;
  int _sourceRequest = 0;
  int _initialRequest = 0;

  GameController get _game => _ref.read(gameControllerProvider.notifier);

  Future<List<Track>> loadSourceTracks() async {
    final request = ++_sourceRequest;
    final game = _ref.read(gameControllerProvider);
    final catalog = _ref.read(catalogControllerProvider.notifier);
    await catalog.loadCatalogue();
    final tracks = tracksForGame(
      _ref.read(catalogControllerProvider).catalogue,
      game,
      _ref.read(clockProvider)(),
    );
    if (tracks.isEmpty) {
      throw const LyricsSourceError(noAlbumTracksMessage);
    }
    if (request == _sourceRequest &&
        sameTrackSelection(game, _ref.read(gameControllerProvider))) {
      _game.setLyricsAvailableTracks(tracks);
    }
    return tracks;
  }

  Future<List<TrackWithLyrics>> preFetchInitial(
    List<Track> tracks, {
    void Function(int fetched, int total)? onProgress,
  }) async {
    final request = ++_initialRequest;
    final batch = tracks.take(_initialBatchSize).toList();
    final total = batch.length;
    _game.setLyricsFetchProgress((fetched: 0, total: total));

    final results = await (await _lrclib()).fetchLyricsBatch(batch);
    final pool = _withLyrics(batch, results);
    if (request != _initialRequest) {
      return pool;
    }
    _addToDecoyPool(pool);

    final fetched = results.length;
    _game.setLyricsFetchProgress((fetched: fetched, total: total));
    onProgress?.call(fetched, total);

    if (pool.length < minLyricsPoolSize) {
      _game.setLyricsFetchProgress(null);
      return pool;
    }

    final shuffledPool = shuffle(pool, random: _ref.read(randomProvider));
    _game
      ..setLyricsPool(shuffledPool)
      ..setLyricsFetchProgress(null);
    return shuffledPool;
  }

  Future<List<TrackWithLyrics>> preFetchMore(
    List<Track> tracks,
    Set<int> existingIds,
  ) async {
    final batch = tracks
        .where((track) => !existingIds.contains(track.id))
        .take(_rollingBatchSize)
        .toList();
    if (batch.isEmpty) {
      return const [];
    }
    try {
      final results = await (await _lrclib()).fetchLyricsBatch(batch);
      final fresh = _withLyrics(batch, results);
      _addToDecoyPool(fresh);
      return fresh;
    } on Object {
      return const [];
    }
  }

  Future<void> extendPool() async {
    final game = _ref.read(gameControllerProvider);
    final pool = game.lyricsPool;
    final source = game.lyricsAvailableTracks.isNotEmpty
        ? game.lyricsAvailableTracks
        : [for (final entry in pool) entry.track];
    final fresh = await preFetchMore(source, {
      for (final entry in pool) entry.track.id,
    });
    if (fresh.isNotEmpty) {
      _game.setLyricsPool([
        ..._ref.read(gameControllerProvider).lyricsPool,
        ...fresh,
      ]);
    }
  }

  void _addToDecoyPool(List<TrackWithLyrics> entries) {
    for (final entry in entries) {
      _game.addToDecoyPool(entry.track.id, entry.lyrics);
    }
  }

  static List<TrackWithLyrics> _withLyrics(
    List<Track> batch,
    Map<int, TrackLyrics?> results,
  ) => List.unmodifiable([
    for (final track in batch)
      if (results[track.id] case final lyrics?)
        TrackWithLyrics(track: track, lyrics: lyrics),
  ]);

  Future<LrclibClient> _lrclib() => _ref.read(lrclibClientProvider.future);
}
