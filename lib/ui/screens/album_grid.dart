import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/cat/loading_gate.dart';
import 'package:swiftie_quiz/ui/screens/main_menu.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';
import 'package:swiftie_quiz/ui/widgets/primary_button.dart';

class AlbumGrid extends ConsumerStatefulWidget {
  const AlbumGrid({super.key});

  static const String loadingLabel = 'Loading albums...';
  static const EdgeInsets padding = EdgeInsets.fromLTRB(32, 32, 32, 80);
  static const double gap = 32;
  static const double gridGap = 16;

  static String startLabel(int count) =>
      'Start Quiz ($count album${count > 1 ? 's' : ''})';

  @override
  ConsumerState<AlbumGrid> createState() => _AlbumGridState();
}

class _AlbumGridState extends ConsumerState<AlbumGrid> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(gameControllerProvider).albums.isEmpty) {
        unawaited(ref.read(catalogControllerProvider.notifier).loadAlbums());
      }
    });
  }

  void _start() {
    if (ref.read(gameControllerProvider).selectedAlbumIds.isNotEmpty) {
      ref
          .read(gameControllerProvider.notifier)
          .setPhase(GamePhase.quizTypeSelect);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final game = ref.read(gameControllerProvider.notifier);
    final albums = ref.watch(
      gameControllerProvider.select((state) => state.albums),
    );
    final selectedIds = ref.watch(
      gameControllerProvider.select((state) => state.selectedAlbumIds),
    );
    final catalog = ref.watch(catalogControllerProvider);
    final error = catalog.albumsError;
    return ScreenScaffold(
      overlays: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _StartFooter(
            visible: selectedIds.isNotEmpty && !catalog.albumsLoading,
            count: selectedIds.length,
            onClear: game.clearSelectedAlbums,
            onStart: _start,
          ),
        ),
      ],
      body: Padding(
        padding: AlbumGrid.padding,
        child: IntrinsicHeight(
          child: Column(
            children: spacedVertically([
              BackHeader(
                maxWidth: TailwindContainers.xl5,
                onBack: () => game.setPhase(GamePhase.menu),
              ),
              const ScreenHeading(
                title: 'Pick Albums',
                subtitle: 'Tap one or more albums, then start your quiz',
              ),
              if (error != null && error.isNotEmpty)
                Text(
                  error,
                  style: AppText.base.copyWith(color: tokens.incorrect),
                ),
              Expanded(
                child: LoadingGate(
                  loading: catalog.albumsLoading && albums.isEmpty,
                  label: AlbumGrid.loadingLabel,
                  labelStyle: CatLoader.defaultLabelStyle.copyWith(
                    color: tokens.mutedForeground,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ResponsiveGrid(
                      columns: const GridColumns(2, sm: 3, md: 4, lg: 5),
                      gap: AlbumGrid.gridGap,
                      maxWidth: TailwindContainers.xl5,
                      children: [
                        for (final (index, album) in albums.indexed)
                          AlbumTile(
                            key: ValueKey(album.id),
                            album: album,
                            selected: selectedIds.contains(album.id),
                            delay: Duration(
                              milliseconds: math.min(index * 30, 500),
                            ),
                            onTap: () => game.toggleAlbum(album.id),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ], AlbumGrid.gap),
          ),
        ),
      ),
    );
  }
}

class AlbumTile extends StatelessWidget {
  const AlbumTile({
    super.key,
    required this.album,
    required this.selected,
    required this.delay,
    required this.onTap,
  });

  static const Offset entranceOffset = Offset(0, 20);
  static const double hoverScale = 1.05;
  static const double tapScale = 0.97;
  static const double radius = AppRadii.xl2;
  static const double ringWidth = 2;
  static const int ringPercent = 20;
  static const double captionPadding = 12;
  static const String placeholder = '♫';
  static final CssLinearGradient coverShade = CssLinearGradient(
    direction: const CssGradientDirection.angle(0),
    colors: const [
      Color.from(alpha: 0.8, red: 0, green: 0, blue: 0),
      Color.from(alpha: 0.2, red: 0, green: 0, blue: 0),
      Color(0x00000000),
    ],
    interpolation: ColorInterpolation.oklab,
  );

  final Album album;
  final bool selected;
  final Duration delay;
  final VoidCallback onTap;

  BoxDecoration _decoration(AppTokens tokens, double hover, double selection) {
    final ring = tokens.primary.slashOpacity(ringPercent);
    return BoxDecoration(
      color: tokens.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Oklab.mix(tokens.border, tokens.primary, selection),
      ),
      boxShadow: [
        ...BoxShadow.lerpList(
          AppShadows.hidden(AppShadows.xl),
          AppShadows.xl,
          hover,
        )!,
        BoxShadow(
          color: ring.withValues(alpha: ring.a * selection),
          spreadRadius: ringWidth * selection,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Entrance(
      fromOffset: entranceOffset,
      delay: delay,
      hoverScale: hoverScale,
      tapScale: tapScale,
      child: Semantics(
        label: album.title,
        selected: selected,
        child: PlainButton(
          onPressed: onTap,
          duration: AppMotion.cardTransitionDuration,
          builder: (context, hover) => TweenAnimationBuilder<double>(
            tween: Tween(end: selected ? 1 : 0),
            duration: AppMotion.cardTransitionDuration,
            curve: AppMotion.cssTransitionCurve,
            builder: (context, selection, cover) => Container(
              decoration: _decoration(tokens, hover, selection),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius - 1),
                child: cover,
              ),
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: switch (album.coverMedium) {
                final cover? => _Cover(url: cover, title: album.title),
                null => ColoredBox(
                  color: tokens.muted,
                  child: Center(
                    child: Text(
                      placeholder,
                      style: AppText.xl2.copyWith(
                        color: tokens.mutedForeground,
                      ),
                    ),
                  ),
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.title});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.network(
        url,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) => const SizedBox.expand(),
      ),
      DecoratedBox(decoration: BoxDecoration(gradient: AlbumTile.coverShade)),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Padding(
          padding: const EdgeInsets.all(AlbumTile.captionPadding),
          child: Text(
            title,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: AppText.sm.copyWith(
              fontWeight: FontWeight.w600,
              color: AppPalette.white,
            ),
          ),
        ),
      ),
    ],
  );
}

class _StartFooter extends StatefulWidget {
  const _StartFooter({
    required this.visible,
    required this.count,
    required this.onClear,
    required this.onStart,
  });

  static const double offset = 20;
  static const double blur = 8;
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 16,
  );
  static const EdgeInsets clearPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );
  static const Color background = Color.from(
    alpha: 0.6,
    red: 0,
    green: 0,
    blue: 0,
  );
  static const Color clearColor = Color.from(
    alpha: 0.7,
    red: 1,
    green: 1,
    blue: 1,
  );

  final bool visible;
  final int count;
  final VoidCallback onClear;
  final VoidCallback onStart;

  @override
  State<_StartFooter> createState() => _StartFooterState();
}

class _StartFooterState extends State<_StartFooter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _presence = AnimationController.unbounded(
    vsync: this,
  );
  late bool _present = widget.visible;
  late int _shownCount = widget.count;

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      unawaited(_presence.springTo(1));
    }
  }

  @override
  void didUpdateWidget(_StartFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible) {
      _shownCount = widget.count;
    }
    if (widget.visible == oldWidget.visible) {
      return;
    }
    if (widget.visible) {
      _present = true;
      unawaited(_presence.springTo(1));
    } else {
      unawaited(
        _presence.springTo(0).orCancel.then((_) {
          if (mounted && !widget.visible) {
            setState(() => _present = false);
          }
        }, onError: (Object _) {}),
      );
    }
  }

  @override
  void dispose() {
    _presence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_present) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _presence,
      builder: (context, child) => Opacity(
        opacity: _presence.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, _StartFooter.offset * (1 - _presence.value)),
          child: child,
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: _StartFooter.blur,
            sigmaY: _StartFooter.blur,
          ),
          child: ColoredBox(
            color: _StartFooter.background,
            child: Padding(
              padding: _StartFooter.padding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PlainButton(
                    onPressed: widget.onClear,
                    builder: (context, hover) => Padding(
                      padding: _StartFooter.clearPadding,
                      child: Text(
                        'Clear all',
                        style: AppText.sm.copyWith(
                          color: Color.lerp(
                            _StartFooter.clearColor,
                            AppPalette.white,
                            hover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  PrimaryButton(
                    label: AlbumGrid.startLabel(_shownCount),
                    variant: PrimaryButtonVariant.start,
                    onPressed: widget.onStart,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
