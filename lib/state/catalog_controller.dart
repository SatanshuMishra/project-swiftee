import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/data/catalog/deezer_client.dart';
import 'package:swiftie_quiz/domain/engine/game_engine.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/providers.dart';

const Object _unchanged = Object();

typedef CatalogTracks = ({List<Track> allTracks, List<Track> pool});

final class CatalogState {
  const CatalogState._({
    required this.albumsLoading,
    required this.albumsError,
    required this.albumTrackTotals,
  });

  static const CatalogState initial = CatalogState._(
    albumsLoading: false,
    albumsError: null,
    albumTrackTotals: {},
  );

  final bool albumsLoading;
  final String? albumsError;
  final Map<int, int> albumTrackTotals;

  CatalogState copyWith({
    bool? albumsLoading,
    Object? albumsError = _unchanged,
    Map<int, int>? albumTrackTotals,
  }) => CatalogState._(
    albumsLoading: albumsLoading ?? this.albumsLoading,
    albumsError: identical(albumsError, _unchanged)
        ? this.albumsError
        : albumsError as String?,
    albumTrackTotals: albumTrackTotals == null
        ? this.albumTrackTotals
        : Map.unmodifiable(albumTrackTotals),
  );

  @override
  bool operator ==(Object other) =>
      other is CatalogState &&
      other.albumsLoading == albumsLoading &&
      other.albumsError == albumsError &&
      const MapEquality<int, int>().equals(
        other.albumTrackTotals,
        albumTrackTotals,
      );

  @override
  int get hashCode => Object.hash(
    albumsLoading,
    albumsError,
    const MapEquality<int, int>().hash(albumTrackTotals),
  );

  @override
  String toString() =>
      'CatalogState(albumsLoading: $albumsLoading, albumsError: $albumsError, '
      'albumTrackTotals: $albumTrackTotals)';
}

bool sameTrackSelection(GameState before, GameState now) =>
    before.mode == now.mode &&
    const ListEquality<int>().equals(
      before.selectedAlbumIds,
      now.selectedAlbumIds,
    );

final catalogControllerProvider =
    NotifierProvider<CatalogController, CatalogState>(CatalogController.new);

class CatalogController extends Notifier<CatalogState> {
  int _trackPoolRequest = 0;

  @override
  CatalogState build() => CatalogState.initial;

  Future<void> loadAlbums() async {
    if (state.albumsLoading ||
        ref.read(gameControllerProvider).albums.isNotEmpty) {
      return;
    }
    state = state.copyWith(albumsLoading: true, albumsError: null);
    try {
      final albums = await (await _client()).fetchAlbums();
      if (!ref.mounted) {
        return;
      }
      ref.read(gameControllerProvider.notifier).setAlbums(albums);
      state = state.copyWith(albumsLoading: false);
    } on Object catch (error) {
      if (ref.mounted) {
        state = state.copyWith(albumsLoading: false, albumsError: '$error');
      }
    }
  }

  Future<List<Track>> fetchTopTracks() async =>
      (await _client()).fetchTopTracks();

  Future<AlbumTracks> fetchAlbumTracks(int albumId) async {
    final albumTracks = await (await _client()).fetchAlbumTracks(albumId);
    if (ref.mounted) {
      state = state.copyWith(
        albumTrackTotals: {
          ...state.albumTrackTotals,
          albumId: albumTracks.totalTracks,
        },
      );
    }
    return albumTracks;
  }

  Future<CatalogTracks> loadTrackPool() async {
    final request = ++_trackPoolRequest;
    final game = ref.read(gameControllerProvider);
    final random = ref.read(randomProvider);
    final tracks = switch (game.mode) {
      GameMode.random => await fetchTopTracks(),
      GameMode.album => await _selectedAlbumTracks(game.selectedAlbumIds),
      GameMode.tonight => await _selectedAlbumTracks([
        tonightsEra(ref.read(clockProvider)()).deezerAlbumId,
      ]),
    };
    final pool = createTrackPool(tracks, random: random);
    if (ref.mounted &&
        request == _trackPoolRequest &&
        sameTrackSelection(game, ref.read(gameControllerProvider))) {
      ref.read(gameControllerProvider.notifier).setTrackPool(pool);
    }
    return (allTracks: List<Track>.unmodifiable(tracks), pool: pool);
  }

  Future<List<Track>> _selectedAlbumTracks(List<int> albumIds) async {
    var tracks = const <Track>[];
    for (final albumId in albumIds) {
      tracks = [...tracks, ...(await fetchAlbumTracks(albumId)).tracks];
    }
    return tracks;
  }

  Future<DeezerClient> _client() => ref.read(deezerClientProvider.future);
}
