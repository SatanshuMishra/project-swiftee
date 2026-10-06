import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/catalogue_rules.dart';
import 'package:swiftie_quiz/domain/engine/game_engine.dart';
import 'package:swiftie_quiz/domain/engine/version_filter.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/play_history_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

const Object _unchanged = Object();

typedef CatalogTracks = ({List<Track> allTracks, List<Track> pool});

final class CatalogState {
  const CatalogState._({
    required this.catalogue,
    required this.loading,
    required this.error,
  });

  static final CatalogState initial = CatalogState._(
    catalogue: Catalogue.empty,
    loading: false,
    error: null,
  );

  final Catalogue catalogue;
  final bool loading;
  final String? error;

  CatalogState copyWith({
    Catalogue? catalogue,
    bool? loading,
    Object? error = _unchanged,
  }) => CatalogState._(
    catalogue: catalogue ?? this.catalogue,
    loading: loading ?? this.loading,
    error: identical(error, _unchanged) ? this.error : error as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is CatalogState &&
      other.catalogue == catalogue &&
      other.loading == loading &&
      other.error == error;

  @override
  int get hashCode => Object.hash(catalogue, loading, error);

  @override
  String toString() =>
      'CatalogState(recordings: ${catalogue.recordings.length}, '
      'loading: $loading, error: $error)';
}

bool sameTrackSelection(GameState before, GameState now) =>
    before.mode == now.mode &&
    const ListEquality<String>().equals(
      before.selectedEraKeys,
      now.selectedEraKeys,
    ) &&
    const ListEquality<int>().equals(
      before.selectedReleaseIds,
      now.selectedReleaseIds,
    );

List<Track> tracksForGame(Catalogue catalogue, GameState game, DateTime now) =>
    switch (game.mode) {
      GameMode.random => catalogue.allTracks,
      GameMode.album => catalogue.tracksFor(
        game.selectedEraKeys,
        releaseIds: game.selectedReleaseIds,
      ),
      GameMode.tonight => catalogue.tracksFor([tonightsEra(now).key]),
    };

final catalogControllerProvider =
    NotifierProvider<CatalogController, CatalogState>(CatalogController.new);

class CatalogController extends Notifier<CatalogState> {
  Future<void>? _loading;
  Future<void>? _releaseCheck;

  @override
  CatalogState build() {
    _loading = null;
    _releaseCheck = null;
    return CatalogState.initial;
  }

  Future<void> loadCatalogue() => _loading ??= _load();

  Future<CatalogTracks> loadTrackPool() async {
    await loadCatalogue();
    final game = ref.read(gameControllerProvider);
    final tracks = keepVersions(
      tracksForGame(state.catalogue, game, ref.read(clockProvider)()),
      game.versions,
    );
    final pool = createTrackPool(
      tracks,
      heard: ref.read(playHistoryProvider).heard,
      random: ref.read(randomProvider),
    );
    if (ref.mounted) {
      ref.read(gameControllerProvider.notifier).setTrackPool(pool);
    }
    return (allTracks: tracks, pool: pool);
  }

  Future<void> _load() async {
    await Future<void>.value();
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(loading: true, error: null);
    try {
      final releases = await ref.read(catalogueStoreProvider).load();
      if (!ref.mounted) {
        return;
      }
      _apply(buildCatalogue(releases));
      state = state.copyWith(loading: false);
    } on Object catch (error) {
      _loading = null;
      if (ref.mounted) {
        state = state.copyWith(loading: false, error: '$error');
      }
      return;
    }
  }

  Future<void> checkForNewReleases() =>
      _releaseCheck ??= _checkForNewReleases();

  Future<void> _checkForNewReleases() async {
    await loadCatalogue();
    if (!ref.mounted) {
      return;
    }
    if (state.catalogue.isEmpty) {
      _releaseCheck = null;
      return;
    }
    try {
      final client = await ref.read(deezerClientProvider.future);
      final current = state.catalogue;
      final added = await ref
          .read(catalogueStoreProvider)
          .addNewReleases(client, current.releaseIds);
      if (added.isNotEmpty && ref.mounted) {
        _apply(buildCatalogue([...current.sources, ...added]));
      }
    } on Object {
      _releaseCheck = null;
    }
  }

  void _apply(Catalogue catalogue) {
    state = state.copyWith(catalogue: catalogue);
    ref.read(gameControllerProvider.notifier).setAlbums(catalogue.albums);
  }
}
