import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/kit/text_link.dart';
import 'package:swiftie_quiz/ui/kit/vinyl.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/ui/widgets/back_link.dart';

enum _ErasView { loading, closed, ready }

typedef _EraAlbum = ({Era era, Album album});

class AlbumGrid extends ConsumerStatefulWidget {
  const AlbumGrid({super.key});

  static const String loadingLabel = 'Loading albums...';
  static const String title = 'Pick your eras';
  static const String subtitle = 'Tap as many as you like.';
  static const String closedTitle = 'The record store is closed.';
  static const String closedMessage =
      "We couldn't reach Deezer to load the albums. "
      'Check your connection and try again.';
  static const String retryLabel = 'Try again';
  static const String backToMenuLabel = 'Back to menu';
  static const String clearLabel = 'Clear';
  static const String continueLabel = 'Continue →';
  static const String emptySelectionLabel = 'Pick at least one era';

  static String selectionLabel(int eras, int tracks) {
    if (eras == 0) {
      return emptySelectionLabel;
    }
    return '$eras era${eras > 1 ? 's' : ''} · $tracks '
        'track${tracks == 1 ? '' : 's'}';
  }

  @override
  ConsumerState<AlbumGrid> createState() => _AlbumGridState();
}

class _AlbumGridState extends ConsumerState<AlbumGrid> {
  bool _loadRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestAlbums());
  }

  void _requestAlbums() {
    if (!mounted) {
      return;
    }
    if (ref.read(catalogControllerProvider).catalogue.isEmpty) {
      _reload();
    }
    setState(() => _loadRequested = true);
  }

  void _reload() =>
      unawaited(ref.read(catalogControllerProvider.notifier).loadCatalogue());

  void _toMenu() =>
      ref.read(gameControllerProvider.notifier).setPhase(GamePhase.menu);

  void _continue() =>
      ref.read(gameControllerProvider.notifier).beginSetup(GameMode.album);

  @override
  Widget build(BuildContext context) {
    final game = ref.read(gameControllerProvider.notifier);
    final catalogue = ref.watch(
      catalogControllerProvider.select((state) => state.catalogue),
    );
    final selectedKeys = ref.watch(
      gameControllerProvider.select((state) => state.selectedEraKeys),
    );
    final loading = ref.watch(
      catalogControllerProvider.select((state) => state.loading),
    );
    final view = !catalogue.isEmpty
        ? _ErasView.ready
        : !_loadRequested || loading
        ? _ErasView.loading
        : _ErasView.closed;
    final tiles = <_EraAlbum>[
      for (final era in eraGroups)
        if (catalogue.trackCount(era.key) > 0)
          (
            era: era,
            album: Album(
              id: era.deezerAlbumId,
              title: era.eraName,
              coverMedium: catalogue.coverFor(era.key),
            ),
          ),
    ];
    return ScreenEnter(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        bottomNavigationBar: view == _ErasView.ready
            ? _EraBar(
                label: AlbumGrid.selectionLabel(
                  selectedKeys.length,
                  catalogue.tracksFor(selectedKeys).length,
                ),
                hasSelection: selectedKeys.isNotEmpty,
                onClear: game.clearSelectedEras,
                onContinue: _continue,
              )
            : null,
        body: Builder(
          builder: (context) {
            final layout = AppLayout.of(context);
            final barInset = MediaQuery.paddingOf(context).bottom;
            return FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(
                requestFocusCallback:
                    (node, {alignment, alignmentPolicy, curve, duration}) =>
                        _revealAboveBar(
                          node,
                          barInset,
                          duration: duration,
                          curve: curve,
                        ),
              ),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _ErasHeader(onBack: _toMenu)),
                  switch (view) {
                    _ErasView.loading => const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ErasLoading(),
                    ),
                    _ErasView.closed => SliverFillRemaining(
                      hasScrollBody: false,
                      child: _RecordStoreClosed(
                        onRetry: _reload,
                        onBack: _toMenu,
                      ),
                    ),
                    _ErasView.ready => SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        layout.padX,
                        _EraGrid.padTop,
                        layout.padX,
                        _EraGrid.padBottom + barInset,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _EraGrid(
                          tiles: tiles,
                          columns: layout.eraColumns,
                          selectedKeys: selectedKeys,
                          onToggle: game.toggleEra,
                        ),
                      ),
                    ),
                  },
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static void _revealAboveBar(
    FocusNode node,
    double barInset, {
    Duration? duration,
    Curve? curve,
  }) {
    node.requestFocus();
    final box = node.context?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return;
    }
    const ring = Pressable.focusRingWidth + Pressable.focusRingGap;
    box.showOnScreen(
      rect: Rect.fromLTRB(
        -ring,
        -ring,
        box.size.width + ring,
        box.size.height + ring + barInset,
      ),
      duration: duration ?? Duration.zero,
      curve: curve ?? Curves.ease,
    );
  }
}

class _ErasHeader extends StatelessWidget {
  const _ErasHeader({required this.onBack});

  static const double padTop = 20;
  static const double padBottom = 28;
  static const double gap = 14;
  static const double titleGapX = 24;
  static const double titleGapY = 12;

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(layout.padX, padTop, layout.padX, padBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: gap,
        children: [
          BackLink(onPressed: onBack, animateEntrance: false),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: titleGapX,
              runSpacing: titleGapY,
              children: [
                Text(
                  AlbumGrid.title,
                  style: AppType.display(
                    layout.h1,
                    height: 1,
                    color: tokens.fg,
                  ),
                ),
                Text(
                  AlbumGrid.subtitle,
                  style: AppType.body.copyWith(color: tokens.mut),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErasLoading extends StatelessWidget {
  const _ErasLoading();

  static const double loaderSize = 220;
  static const double padBottom = 80;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: padBottom),
    child: Center(
      child: CatLoader(
        px: loaderSize,
        label: AlbumGrid.loadingLabel,
        labelStyle: CatLoader.defaultLabelStyle.copyWith(
          color: AppTokens.of(context).mut,
        ),
      ),
    ),
  );
}

class _RecordStoreClosed extends StatelessWidget {
  const _RecordStoreClosed({required this.onRetry, required this.onBack});

  static const double padBottom = 80;
  static const double gap = 12;
  static const double actionsGap = 12;
  static const double actionsPadTop = 8;
  static const double messageMaxWidth = 420;

  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(layout.padX, 0, layout.padX, padBottom),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: gap,
          children: [
            Text(
              AlbumGrid.closedTitle,
              textAlign: TextAlign.center,
              style: AppType.display(36, height: 40 / 36, color: tokens.fg),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: messageMaxWidth),
              child: Text(
                AlbumGrid.closedMessage,
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: tokens.mut),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: actionsPadTop),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: actionsGap,
                runSpacing: actionsGap,
                children: [
                  PillButton(
                    label: AlbumGrid.retryLabel,
                    onPressed: onRetry,
                    size: PillSize.large,
                  ),
                  PillButton(
                    label: AlbumGrid.backToMenuLabel,
                    onPressed: onBack,
                    kind: PillKind.outline,
                    size: PillSize.large,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EraGrid extends StatelessWidget {
  const _EraGrid({
    required this.tiles,
    required this.columns,
    required this.selectedKeys,
    required this.onToggle,
  });

  static const double padTop = 24;
  static const double padBottom = 40;
  static const double rowGap = 30;
  static const double columnGap = 24;
  static const double subpixels = 64;

  final List<_EraAlbum> tiles;
  final int columns;
  final List<String> selectedKeys;
  final ValueChanged<String> onToggle;

  static double tileWidth(double width, int columns) =>
      ((width - columnGap * (columns - 1)) / columns * subpixels)
          .floorToDouble() /
      subpixels;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = tileWidth(constraints.maxWidth, columns);
      return Wrap(
        spacing: columnGap,
        runSpacing: rowGap,
        children: [
          for (final tile in tiles)
            SizedBox(
              key: ValueKey(tile.era.key),
              width: width,
              child: _EraTile(
                era: tile.era,
                album: tile.album,
                selected: selectedKeys.contains(tile.era.key),
                onTap: () => onToggle(tile.era.key),
              ),
            ),
        ],
      );
    },
  );
}

class _EraTile extends StatelessWidget {
  const _EraTile({
    required this.era,
    required this.album,
    required this.selected,
    required this.onTap,
  });

  static const double labelGap = 12;
  static const double captionGap = 2;
  static const double discInset = 0.04;
  static const double discFraction = 0.92;
  static const double discLabelFraction = 0.34;
  static const double discSlide = 0.34;
  static const double ringWidth = 2;
  static const double checkInset = 8;
  static const double checkSize = 24;
  static const double riseOffset = 8;
  static const rise = Duration(milliseconds: 400);
  static const Curve riseCurve = Curves.ease;
  static const discMove = Duration(milliseconds: 450);
  static const Curve discMoveCurve = Cubic(0.2, 0.8, 0.2, 1);
  static const ringShift = Duration(milliseconds: 250);
  static const Curve ringShiftCurve = Curves.ease;
  static const checkFade = Duration(milliseconds: 200);
  static const Curve checkFadeCurve = Curves.ease;
  static const checkPop = Duration(milliseconds: 250);
  static const Curve checkPopCurve = Cubic(0.34, 1.56, 0.64, 1);
  static const radius = BorderRadius.all(Radius.circular(3));
  static const focusRadius = BorderRadius.all(Radius.circular(4));

  final Era era;
  final Album album;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final placeholder = Color(era.placeholderArgb);
    final cover = album.coverMedium;
    final ring = selected
        ? BorderSide(
            color: tokens.coral,
            width: ringWidth,
            strokeAlign: BorderSide.strokeAlignOutside,
          )
        : BorderSide(
            color: tokens.coral.withValues(alpha: 0),
            width: 0,
            style: BorderStyle.none,
            strokeAlign: BorderSide.strokeAlignOutside,
          );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.duration(context, rise),
      curve: riseCurve,
      builder: (context, shown, tile) => Opacity(
        opacity: shown,
        child: Transform.translate(
          offset: Offset(0, riseOffset * (1 - shown)),
          child: tile,
        ),
      ),
      child: Pressable(
        onPressed: onTap,
        selected: selected,
        focusRadius: focusRadius,
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: labelGap,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.maxWidth;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: size * discInset,
                        top: size * discInset,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: selected ? discSlide : 0),
                          duration: AppMotion.duration(context, discMove),
                          curve: discMoveCurve,
                          builder: (context, slide, disc) =>
                              FractionalTranslation(
                                translation: Offset(slide, 0),
                                child: disc,
                              ),
                          child: VinylDisc(
                            size: size * discFraction,
                            labelUrl: cover,
                            labelColor: placeholder,
                            labelFraction: discLabelFraction,
                            style: VinylStyle.tile,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: _LiftOnHover(
                          child: AnimatedContainer(
                            duration: AppMotion.duration(context, ringShift),
                            curve: ringShiftCurve,
                            foregroundDecoration: BoxDecoration(
                              borderRadius: radius,
                              border: Border.fromBorderSide(ring),
                            ),
                            child: AlbumSleeve(
                              size: size,
                              coverUrl: cover,
                              placeholder: placeholder,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: checkInset,
                        top: checkInset,
                        child: AnimatedOpacity(
                          opacity: selected ? 1 : 0,
                          duration: AppMotion.duration(context, checkFade),
                          curve: checkFadeCurve,
                          child: AnimatedScale(
                            scale: selected ? 1 : 0,
                            duration: AppMotion.duration(context, checkPop),
                            curve: checkPopCurve,
                            child: const ExcludeSemantics(
                              child: _SelectedCheck(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: captionGap,
              children: [
                Text(
                  era.eraName,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.display(
                    21,
                    italic: true,
                    height: 24 / 21,
                    color: tokens.fg,
                  ),
                ),
                Text(
                  era.subLabel,
                  style: AppType.caption.copyWith(color: tokens.mut),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiftOnHover extends StatefulWidget {
  const _LiftOnHover({required this.child});

  static const double offset = 3;
  static const lift = Duration(milliseconds: 250);
  static const Curve liftCurve = Cubic(0.2, 0.8, 0.2, 1);

  final Widget child;

  @override
  State<_LiftOnHover> createState() => _LiftOnHoverState();
}

class _LiftOnHoverState extends State<_LiftOnHover> {
  bool _hovered = false;

  void _setHovered(bool hovered) {
    if (_hovered != hovered) {
      setState(() => _hovered = hovered);
    }
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => _setHovered(true),
    onExit: (_) => _setHovered(false),
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: _hovered ? -_LiftOnHover.offset : 0),
      duration: AppMotion.duration(context, _LiftOnHover.lift),
      curve: _LiftOnHover.liftCurve,
      builder: (context, dy, child) =>
          Transform.translate(offset: Offset(0, dy), child: child),
      child: widget.child,
    ),
  );
}

class _SelectedCheck extends StatelessWidget {
  const _SelectedCheck();

  static const String glyph = '✓';

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return SizedBox.square(
      dimension: _EraTile.checkSize,
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: tokens.coral),
        child: Center(
          child: Text(
            glyph,
            style: AppType.sized(
              13,
              13,
              weight: FontWeight.w700,
            ).copyWith(color: tokens.onCoral),
          ),
        ),
      ),
    );
  }
}

class _EraBar extends StatelessWidget {
  const _EraBar({
    required this.label,
    required this.hasSelection,
    required this.onClear,
    required this.onContinue,
  });

  static const double blur = 12;
  static const double padY = 14;
  static const double gap = 16;

  final String label;
  final bool hasSelection;
  final VoidCallback onClear;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: layout.padX,
            vertical: padY,
          ),
          decoration: BoxDecoration(
            color: tokens.bar,
            border: Border(top: BorderSide(color: tokens.line)),
          ),
          child: Row(
            spacing: gap,
            children: [
              Expanded(
                child: Row(
                  spacing: gap,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.sized(14, 20).copyWith(color: tokens.fg),
                      ),
                    ),
                    if (hasSelection)
                      TextLink(label: AlbumGrid.clearLabel, onTap: onClear),
                  ],
                ),
              ),
              PillButton(
                label: AlbumGrid.continueLabel,
                onPressed: onContinue,
                enabled: hasSelection,
                size: PillSize.large,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
