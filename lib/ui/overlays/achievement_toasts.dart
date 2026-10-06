import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/achievements.dart';
import 'package:swiftie_quiz/domain/models/achievement_def.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/ui/kit/vinyl.dart';
import 'package:swiftie_quiz/ui/overlays/toast_host.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/domain/util/song_title.dart';

final Map<String, AchievementDef> _definitionsById = Map.unmodifiable({
  for (final definition in achievementDefs) definition.id: definition,
});

@immutable
final class _ToastContent {
  const _ToastContent({
    required this.title,
    this.song,
    this.albumId,
    this.coverUrl,
    this.placeholder,
  });

  factory _ToastContent.of(AchievementDef definition, GameState game) {
    final record = game.progress.achievements[definition.id];
    final albumId = int.tryParse(record?.albumId ?? '');
    final album = albumId == null
        ? null
        : [
            ...game.albums,
            ?game.currentTrack?.album,
          ].firstWhereOrNull((album) => album.id == albumId);
    final era = albumId == null ? null : eraForAlbumId(albumId);
    return _ToastContent(
      title: definition.name,
      song: record?.song,
      albumId: albumId,
      coverUrl: album?.coverMedium,
      placeholder: era == null ? null : Color(era.placeholderArgb),
    );
  }

  final String title;
  final String? song;
  final int? albumId;
  final String? coverUrl;
  final Color? placeholder;
}

@immutable
final class _ShownToast {
  const _ShownToast({
    required this.slot,
    required this.id,
    required this.content,
    this.leaving = false,
  });

  final Object slot;
  final String id;
  final _ToastContent content;
  final bool leaving;

  _ShownToast leave() =>
      _ShownToast(slot: slot, id: id, content: content, leaving: true);
}

class AchievementToasts extends ConsumerStatefulWidget {
  const AchievementToasts({super.key});

  static const String kicker = 'New on your shelf';
  static const Duration stagger = Duration(milliseconds: 350);
  static const Size artSize = Size(52, 44);
  static const double sleeveSize = 44;
  static const double sleeveRadius = 3;
  static const double discSize = 40;
  static const Offset discOffset = Offset(14, 2);
  static const VinylStyle discStyle = VinylStyle(
    groove: 1,
    gap: 1.4,
    ringAlpha: 0,
    shadowOffset: 0,
    shadowBlur: 0,
    hole: false,
  );

  static String songLine(String song) => 'on ${displaySongTitle(song)}';

  @override
  ConsumerState<AchievementToasts> createState() => _AchievementToastsState();
}

class _AchievementToastsState extends ConsumerState<AchievementToasts> {
  late final ToastStack _stack;
  List<String> _pending = const [];
  List<({String id, _ToastContent content})> _queue = const [];
  List<_ShownToast> _shown = const [];
  Map<Object, Timer> _expiries = const {};
  Map<Object, Timer> _removals = const {};
  Map<String, Timer> _orphans = const {};
  Timer? _stagger;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _stack = ref.read(toastStackProvider.notifier);
    ref.listenManual(
      gameControllerProvider.select((game) => game.pendingToasts),
      (_, ids) => _sync(ids),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _sync(ref.read(gameControllerProvider).pendingToasts);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = AppMotion.reduced(context);
  }

  @override
  void dispose() {
    _stagger?.cancel();
    for (final timer in [
      ..._expiries.values,
      ..._removals.values,
      ..._orphans.values,
    ]) {
      timer.cancel();
    }
    final stack = _stack;
    final slots = [for (final toast in _shown) toast.slot];
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        for (final slot in slots) {
          stack.remove(slot);
        }
      })
      ..ensureVisualUpdate();
    super.dispose();
  }

  void _sync(List<String> ids) {
    final previous = _pending.toSet();
    final current = ids.toSet();
    _pending = List.unmodifiable(ids);
    final game = ref.read(gameControllerProvider);
    for (final id in current.where((id) => !previous.contains(id))) {
      _arrive(id, game);
    }
    for (final id in previous.where((id) => !current.contains(id))) {
      _depart(id);
    }
    _revealNext();
  }

  void _arrive(String id, GameState game) {
    final definition = _definitionsById[id];
    if (definition == null) {
      _orphans = Map.unmodifiable({
        ..._orphans,
        id: Timer(AppMotion.toastStay, () => _dismiss(id)),
      });
      return;
    }
    _queue = List.unmodifiable([
      ..._queue,
      (id: id, content: _ToastContent.of(definition, game)),
    ]);
  }

  void _depart(String id) {
    _orphans[id]?.cancel();
    _orphans = Map.unmodifiable({
      for (final MapEntry(:key, :value) in _orphans.entries)
        if (key != id) key: value,
    });
    _queue = List.unmodifiable(_queue.where((queued) => queued.id != id));
    for (final toast in _shown.where(
      (toast) => toast.id == id && !toast.leaving,
    )) {
      _leave(toast);
    }
  }

  void _revealNext() {
    if (_stagger != null || _queue.isEmpty) {
      return;
    }
    final next = _queue.first;
    _queue = List.unmodifiable(_queue.skip(1));
    final toast = _ShownToast(
      slot: Object(),
      id: next.id,
      content: next.content,
    );
    _stack.add(toast.slot);
    setState(() => _shown = List.unmodifiable([..._shown, toast]));
    _expiries = Map.unmodifiable({
      ..._expiries,
      toast.slot: Timer(AppMotion.toastStay, () => _dismiss(toast.id)),
    });
    if (_reduced) {
      _revealNext();
      return;
    }
    _stagger = Timer(AchievementToasts.stagger, () {
      _stagger = null;
      _revealNext();
    });
  }

  void _leave(_ShownToast toast) {
    _expiries[toast.slot]?.cancel();
    _expiries = _without(_expiries, toast.slot);
    if (_reduced) {
      _remove(toast.slot);
      return;
    }
    setState(
      () => _shown = List.unmodifiable([
        for (final shown in _shown)
          shown.slot == toast.slot ? shown.leave() : shown,
      ]),
    );
    _removals = Map.unmodifiable({
      ..._removals,
      toast.slot: Timer(ToastMotion.fade, () => _remove(toast.slot)),
    });
  }

  void _remove(Object slot) {
    _removals = _without(_removals, slot);
    _stack.remove(slot);
    setState(
      () => _shown = List.unmodifiable(
        _shown.where((toast) => toast.slot != slot),
      ),
    );
  }

  static Map<Object, Timer> _without(Map<Object, Timer> timers, Object slot) =>
      Map.unmodifiable({
        for (final MapEntry(:key, :value) in timers.entries)
          if (key != slot) key: value,
      });

  void _dismiss(String id) =>
      ref.read(gameControllerProvider.notifier).dismissToast(id);

  @override
  Widget build(BuildContext context) {
    if (_shown.isEmpty) {
      return const SizedBox.shrink();
    }
    final order = ref.watch(toastStackProvider);
    return Stack(
      children: [
        for (final toast in _shown)
          ToastSlot(
            key: ObjectKey(toast.slot),
            index: order.indexOf(toast.slot),
            child: ToastMotion(
              shown: !toast.leaving,
              child: _AchievementToast(
                content: toast.content,
                onDismiss: () => _dismiss(toast.id),
              ),
            ),
          ),
      ],
    );
  }
}

class _AchievementToast extends StatelessWidget {
  const _AchievementToast({required this.content, required this.onDismiss});

  final _ToastContent content;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final song = content.song;
    return ToastCard(
      kicker: AchievementToasts.kicker,
      title: content.title,
      sub: song == null ? null : AchievementToasts.songLine(song),
      leading: content.albumId == null
          ? null
          : _FlatAlbumArt(
              coverUrl: content.coverUrl,
              placeholder: content.placeholder,
            ),
      onDismiss: onDismiss,
    );
  }
}

class _FlatAlbumArt extends StatelessWidget {
  const _FlatAlbumArt({required this.coverUrl, required this.placeholder});

  final String? coverUrl;
  final Color? placeholder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    return Theme(
      data: theme.copyWith(
        extensions: [
          ...theme.extensions.values.whereNot(
            (extension) => extension is AppTokens,
          ),
          tokens.copyWith(shadow: Colors.transparent),
        ],
      ),
      child: SizedBox.fromSize(
        size: AchievementToasts.artSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: AchievementToasts.discOffset.dx,
              top: AchievementToasts.discOffset.dy,
              child: const VinylDisc(
                size: AchievementToasts.discSize,
                labelFraction: 0,
                style: AchievementToasts.discStyle,
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: AlbumSleeve(
                size: AchievementToasts.sleeveSize,
                radius: AchievementToasts.sleeveRadius,
                coverUrl: coverUrl,
                placeholder: placeholder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
