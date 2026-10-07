import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/data/lyrics/lrclib_client.dart';
import 'package:swiftie_quiz/data/lyrics/lyrics_error.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/engine/play_order.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/play_history_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

const int minLyricsPoolSize = 5;
const int _initialBatchSize = 8;
const int _maxInitialBatches = 3;
const int _rollingBatchSize = 5;

const String noAlbumTracksMessage =
    'Could not load tracks for the selected eras. Please try again.';

const String catalogueUnavailableMessage =
    'Could not load the song list. Please try again.';

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
  int _initialRequest = 0;
  ({int request, Future<void> done})? _extending;
  Set<int> _tried = const {};

  GameController get _game => _ref.read(gameControllerProvider.notifier);

  Future<List<Track>> loadSourceTracks() async {
    final game = _ref.read(gameControllerProvider);
    final catalog = _ref.read(catalogControllerProvider.notifier);
    await catalog.loadCatalogue();
    if (_ref.read(catalogControllerProvider).error != null) {
      throw const LyricsSourceError(catalogueUnavailableMessage);
    }
    final tracks = lyricsOrder(
      tracksForGame(
        _ref.read(catalogControllerProvider).catalogue,
        game,
        _ref.read(clockProvider)(),
      ),
      read: _ref.read(playHistoryProvider).read,
      random: _ref.read(randomProvider),
    );
    if (tracks.isEmpty) {
      throw const LyricsSourceError(noAlbumTracksMessage);
    }
    if (sameTrackSelection(game, _ref.read(gameControllerProvider))) {
      _game.setLyricsAvailableTracks(tracks);
    }
    return tracks;
  }

  Future<List<TrackWithLyrics>> preFetchInitial(
    List<Track> tracks, {
    void Function(int fetched, int total)? onProgress,
  }) async {
    final request = ++_initialRequest;
    final batches = tracks
        .slices(_initialBatchSize)
        .take(_maxInitialBatches)
        .toList();
    var pool = const <TrackWithLyrics>[];
    var fetched = 0;
    var total = batches.firstOrNull?.length ?? 0;
    var unchecked = 0;
    var tried = const <int>{};
    _game.setLyricsFetchProgress((fetched: 0, total: total));

    final lrclib = await _lrclib();
    for (final (index, batch) in batches.indexed) {
      if (index > 0) {
        total += batch.length;
        _game.setLyricsFetchProgress((fetched: fetched, total: total));
      }
      final results = await lrclib.fetchLyricsBatch(batch);
      final found = _withLyrics(batch, results);
      pool = List.unmodifiable([...pool, ...found]);
      if (request != _initialRequest) {
        return pool;
      }
      tried = Set.unmodifiable({...tried, for (final track in batch) track.id});
      _tried = tried;
      _addToDecoyPool(found);
      fetched += results.length;
      unchecked += batch.length - results.length;
      _game.setLyricsFetchProgress((fetched: fetched, total: total));
      onProgress?.call(fetched, total);
      if (results.isEmpty || pool.length >= minLyricsPoolSize) {
        break;
      }
    }

    if (pool.length < minLyricsPoolSize) {
      _game.setLyricsFetchProgress(null);
      return unchecked > 0 ? throw const LyricsUnavailable() : pool;
    }

    _game
      ..setLyricsPool(pool)
      ..setLyricsFetchProgress(null);
    return pool;
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

  Future<void> extendPool() {
    final request = _initialRequest;
    if (_extending case (request: final pending, :final done)
        when pending == request) {
      return done;
    }
    late final Future<void> done;
    done = _extendPool(request).whenComplete(() {
      if (identical(_extending?.done, done)) {
        _extending = null;
      }
    });
    _extending = (request: request, done: done);
    return done;
  }

  Future<void> _extendPool(int request) async {
    final game = _ref.read(gameControllerProvider);
    final pool = game.lyricsPool;
    final source = game.lyricsAvailableTracks.isNotEmpty
        ? game.lyricsAvailableTracks
        : [for (final entry in pool) entry.track];
    final skip = {..._tried, for (final entry in pool) entry.track.id};
    final batch = [
      for (final track in source)
        if (!skip.contains(track.id)) track.id,
    ].take(_rollingBatchSize).toList();
    final fresh = await preFetchMore(source, skip);
    if (request != _initialRequest) {
      return;
    }
    _tried = Set.unmodifiable({..._tried, ...batch});
    _game.appendLyricsPool(fresh);
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
