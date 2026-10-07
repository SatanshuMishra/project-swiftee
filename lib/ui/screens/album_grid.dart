import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/release_search.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/kit/section_label.dart';
import 'package:swiftie_quiz/ui/kit/segmented.dart';
import 'package:swiftie_quiz/ui/kit/selected_check.dart';
import 'package:swiftie_quiz/ui/kit/serif_input.dart';
import 'package:swiftie_quiz/ui/kit/text_link.dart';
import 'package:swiftie_quiz/ui/kit/vinyl.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/ui/widgets/back_link.dart';

enum _ErasView { loading, closed, ready }

enum PickTab { eras, releases }

enum ReleaseFilter {
  all('All', null),
  albums('Albums', ReleaseKind.album),
  eps('EPs', ReleaseKind.ep),
  singles('Singles', ReleaseKind.single);

  const ReleaseFilter(this.label, this.kind);

  final String label;
  final ReleaseKind? kind;

  bool allows(CatalogueRelease release) => kind == null || release.kind == kind;
}

typedef _Tile = ({
  Key key,
  String? cover,
  Color placeholder,
  String title,
  String meta,
  bool selected,
  VoidCallback onTap,
});

typedef _Section = ({String label, List<_Tile> tiles});

class AlbumGrid extends ConsumerStatefulWidget {
  const AlbumGrid({super.key});

  static const String loadingLabel = 'Loading albums...';
  static const String erasTitle = 'Pick your eras';
  static const String releasesTitle = 'Pick your releases';
  static const String erasSubtitle = 'Tap as many as you like.';
  static const String releasesSubtitle =
      'Albums, EPs and singles. Tap as many as you like.';
  static const String erasTab = 'Eras';
  static const String releasesTab = 'Releases';
  static const String searchHint = 'Search releases or songs';
  static const String clearSearchLabel = 'Clear search';
  static const String noResultsHint = 'Try an album, EP, single or song name.';
  static const String nothingYet = 'Nothing here yet.';
  static const String closedTitle = 'The record store is closed.';
  static const String closedMessage =
      "We couldn't reach Deezer to load the albums. "
      'Check your connection and try again.';
  static const String retryLabel = 'Try again';
  static const String backToMenuLabel = 'Back to menu';
  static const String clearLabel = 'Clear';
  static const String continueLabel = 'Continue →';
  static const String emptySelectionLabel = 'Pick at least one era or release';

  static String tabLabel(String label, int picked) =>
      picked == 0 ? label : '$label · $picked';

  static String kindLabel(ReleaseKind kind) => switch (kind) {
    ReleaseKind.album => 'Album',
    ReleaseKind.ep => 'EP',
    ReleaseKind.single => 'Single',
  };

  static String releaseMeta(CatalogueRelease release, {String? song}) =>
      song == null
      ? '${kindLabel(release.kind)} · ${release.year}'
      : 'with “$song”';

  static String noResultsTitle(String query) => switch (query.trim()) {
    '' => nothingYet,
    final shown => 'Nothing called “$shown”.',
  };

  static String selectionLabel(int eras, int releases, int tracks) {
    if (eras + releases == 0) {
      return emptySelectionLabel;
    }
    return [
      if (eras > 0) _count(eras, 'era'),
      if (releases > 0) _count(releases, 'release'),
      _count(tracks, 'track'),
    ].join(' · ');
  }

  static String _count(int count, String noun) =>
      '$count $noun${count == 1 ? '' : 's'}';

  @override
  ConsumerState<AlbumGrid> createState() => _AlbumGridState();
}

class _AlbumGridState extends ConsumerState<AlbumGrid> {
  bool _loadRequested = false;
  late PickTab _tab;
  ReleaseFilter _filter = ReleaseFilter.all;
  final TextEditingController _query = TextEditingController();
  ({Catalogue catalogue, ReleaseSearch search})? _search;

  @override
  void initState() {
    super.initState();
    final game = ref.read(gameControllerProvider);
    _tab = game.selectedEraKeys.isEmpty && game.selectedReleaseIds.isNotEmpty
        ? PickTab.releases
        : PickTab.eras;
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestAlbums());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
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

  void _clearQuery() => setState(_query.clear);

  ReleaseSearch _searchOf(Catalogue catalogue) {
    if (_search case (catalogue: final indexed, :final search)
        when identical(indexed, catalogue)) {
      return search;
    }
    final search = ReleaseSearch(catalogue.releases);
    _search = (catalogue: catalogue, search: search);
    return search;
  }

  List<_Tile> _eraTiles(
    Catalogue catalogue,
    List<String> picked,
    ValueChanged<String> onToggle,
  ) => [
    for (final era in catalogue.eras)
      if (catalogue.trackCount(era.key) > 0)
        (
          key: ValueKey(era.key),
          cover: catalogue.coverFor(era.key),
          placeholder: Color(era.placeholderArgb),
          title: era.eraName,
          meta: era.subLabel,
          selected: picked.contains(era.key),
          onTap: () => onToggle(era.key),
        ),
  ];

  List<_Section> _releaseSections(
    Catalogue catalogue,
    List<int> picked,
    ValueChanged<int> onToggle,
  ) {
    final matches = [
      for (final match in _searchOf(catalogue).matches(_query.text))
        if (_filter.allows(match.release)) match,
    ];
    return [
      for (final era in catalogue.eras)
        if ([
              for (final match in matches)
                if (match.release.eraKey == era.key)
                  _releaseTile(match, era, picked, onToggle),
            ]
            case final tiles when tiles.isNotEmpty)
          (label: era.eraName, tiles: tiles),
    ];
  }

  _Tile _releaseTile(
    ReleaseMatch match,
    Era era,
    List<int> picked,
    ValueChanged<int> onToggle,
  ) => (
    key: ValueKey(match.release.id),
    cover: match.release.coverMedium,
    placeholder: Color(era.placeholderArgb),
    title: match.release.title,
    meta: AlbumGrid.releaseMeta(match.release, song: match.song),
    selected: picked.contains(match.release.id),
    onTap: () => onToggle(match.release.id),
  );

  @override
  Widget build(BuildContext context) {
    final game = ref.read(gameControllerProvider.notifier);
    final catalogue = ref.watch(
      catalogControllerProvider.select((state) => state.catalogue),
    );
    final eraKeys = ref.watch(
      gameControllerProvider.select((state) => state.selectedEraKeys),
    );
    final releaseIds = ref.watch(
      gameControllerProvider.select((state) => state.selectedReleaseIds),
    );
    final loading = ref.watch(
      catalogControllerProvider.select((state) => state.loading),
    );
    final view = !catalogue.isEmpty
        ? _ErasView.ready
        : !_loadRequested || loading
        ? _ErasView.loading
        : _ErasView.closed;
    final hasPicks = eraKeys.isNotEmpty || releaseIds.isNotEmpty;
    return ScreenEnter(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        bottomNavigationBar: view == _ErasView.ready
            ? _EraBar(
                label: AlbumGrid.selectionLabel(
                  eraKeys.length,
                  releaseIds.length,
                  hasPicks
                      ? catalogue
                            .tracksFor(eraKeys, releaseIds: releaseIds)
                            .length
                      : 0,
                ),
                hasSelection: hasPicks,
                onClear: game.clearSelection,
                onContinue: _continue,
              )
            : null,
        body: Builder(
          builder: (context) {
            final layout = AppLayout.of(context);
            final barInset = MediaQuery.paddingOf(context).bottom;
            final padding = EdgeInsets.fromLTRB(
              layout.padX,
              _TileGrid.padTop,
              layout.padX,
              _TileGrid.padBottom + barInset,
            );
            final onReleases = _tab == PickTab.releases;
            final sections = view == _ErasView.ready && onReleases
                ? _releaseSections(catalogue, releaseIds, game.toggleRelease)
                : const <_Section>[];
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
                  SliverToBoxAdapter(
                    child: _PickHeader(
                      tab: _tab,
                      eras: eraKeys.length,
                      releases: releaseIds.length,
                      onTab: (tab) => setState(() => _tab = tab),
                      onBack: _toMenu,
                      tools: onReleases && view == _ErasView.ready
                          ? _ReleaseTools(
                              filter: _filter,
                              onFilter: (filter) =>
                                  setState(() => _filter = filter),
                              query: _query,
                              onQuery: (_) => setState(() {}),
                              onClear: _clearQuery,
                            )
                          : null,
                    ),
                  ),
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
                    _ErasView.ready when !onReleases => SliverPadding(
                      padding: padding,
                      sliver: SliverToBoxAdapter(
                        child: _TileGrid(
                          tiles: _eraTiles(catalogue, eraKeys, game.toggleEra),
                          columns: layout.eraColumns,
                          style: _TileStyle.era,
                        ),
                      ),
                    ),
                    _ErasView.ready when sections.isEmpty => SliverPadding(
                      padding: padding,
                      sliver: SliverToBoxAdapter(
                        child: _NoReleases(
                          query: _query.text,
                          onClear: _clearQuery,
                        ),
                      ),
                    ),
                    _ErasView.ready => SliverPadding(
                      padding: padding,
                      sliver: SliverList.list(
                        children: [
                          for (final (index, section) in sections.indexed)
                            Padding(
                              key: ValueKey((PickTab.releases, section.label)),
                              padding: EdgeInsets.only(
                                top: index == 0 ? 0 : _ReleaseSection.gap,
                              ),
                              child: _ReleaseSection(
                                label: section.label,
                                tiles: section.tiles,
                                columns: layout.releaseColumns,
                              ),
                            ),
                        ],
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

class _PickHeader extends StatelessWidget {
  const _PickHeader({
    required this.tab,
    required this.eras,
    required this.releases,
    required this.onTab,
    required this.onBack,
    required this.tools,
  });

  static const double padTop = 20;
  static const double padBottom = 28;
  static const double gap = 14;
  static const double titleGapX = 24;
  static const double titleGapY = 12;
  static const double toolsTop = 8;

  final PickTab tab;
  final int eras;
  final int releases;
  final ValueChanged<PickTab> onTab;
  final VoidCallback onBack;
  final Widget? tools;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    final onReleases = tab == PickTab.releases;
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
                  onReleases ? AlbumGrid.releasesTitle : AlbumGrid.erasTitle,
                  style: AppType.display(
                    layout.h1,
                    height: 1,
                    color: tokens.fg,
                  ),
                ),
                Segmented<PickTab>(
                  options: [
                    (PickTab.eras, AlbumGrid.tabLabel(AlbumGrid.erasTab, eras)),
                    (
                      PickTab.releases,
                      AlbumGrid.tabLabel(AlbumGrid.releasesTab, releases),
                    ),
                  ],
                  value: tab,
                  onChanged: onTab,
                ),
              ],
            ),
          ),
          Text(
            onReleases ? AlbumGrid.releasesSubtitle : AlbumGrid.erasSubtitle,
            style: AppType.body.copyWith(color: tokens.mut),
          ),
          if (tools case final tools?)
            Padding(
              padding: const EdgeInsets.only(top: toolsTop),
              child: tools,
            ),
        ],
      ),
    );
  }
}

class _ReleaseTools extends StatelessWidget {
  const _ReleaseTools({
    required this.filter,
    required this.onFilter,
    required this.query,
    required this.onQuery,
    required this.onClear,
  });

  static const double filterGap = 24;
  static const double gapX = 32;
  static const double gapY = 14;
  static const double searchWidth = 320;
  static const double searchSize = 22;
  static const double searchLine = 28;

  final ReleaseFilter filter;
  final ValueChanged<ReleaseFilter> onFilter;
  final TextEditingController query;
  final ValueChanged<String> onQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: gapX,
          runSpacing: gapY,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: filterGap,
              children: [
                for (final option in ReleaseFilter.values)
                  _FilterTab(
                    label: option.label,
                    selected: option == filter,
                    onTap: () => onFilter(option),
                  ),
              ],
            ),
            SizedBox(
              width: layout.isNarrow ? constraints.maxWidth : searchWidth,
              child: SerifInput(
                controller: query,
                placeholder: AlbumGrid.searchHint,
                fontSize: searchSize,
                lineHeight: searchLine,
                onChanged: onQuery,
                trailing: query.text.trim().isEmpty
                    ? null
                    : SizedBox(
                        height: searchLine,
                        child: OverflowBox(
                          fit: OverflowBoxFit.deferToChild,
                          maxHeight: TextLink.minHeight,
                          child: TextLink(
                            label: AlbumGrid.clearLabel,
                            onTap: onClear,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const padding = EdgeInsets.only(top: 10, bottom: 6);
  static const double underline = 2;
  static const focusRadius = BorderRadius.all(Radius.circular(4));

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final shift = AppMotion.duration(context, AppMotion.selectionShift);
    return Pressable(
      onPressed: onTap,
      selected: selected,
      focusRadius: focusRadius,
      builder: (context, state) => AnimatedContainer(
        duration: shift,
        curve: Curves.ease,
        padding: padding,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? tokens.coral
                  : tokens.coral.withValues(alpha: 0),
              width: underline,
            ),
          ),
        ),
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(
            end: selected || state.hovered ? tokens.fg : tokens.mut,
          ),
          duration: shift,
          curve: Curves.ease,
          builder: (context, color, _) =>
              Text(label, style: AppType.sized(14, 20).copyWith(color: color)),
        ),
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

class _NoReleases extends StatelessWidget {
  const _NoReleases({required this.query, required this.onClear});

  static const padding = EdgeInsets.only(top: 32);
  static const double gap = 12;
  static const double messageMaxWidth = 420;

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: gap,
          children: [
            Text(
              AlbumGrid.noResultsTitle(query),
              textAlign: TextAlign.center,
              style: AppType.display(36, height: 40 / 36, color: tokens.fg),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: messageMaxWidth),
              child: Text(
                AlbumGrid.noResultsHint,
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: tokens.mut),
              ),
            ),
            if (query.trim().isNotEmpty)
              TextLink(label: AlbumGrid.clearSearchLabel, onTap: onClear),
          ],
        ),
      ),
    );
  }
}

class _ReleaseSection extends StatelessWidget {
  const _ReleaseSection({
    required this.label,
    required this.tiles,
    required this.columns,
  });

  static const double gap = 40;
  static const double labelGap = 14;

  final String label;
  final List<_Tile> tiles;
  final int columns;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    explicitChildNodes: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: labelGap,
      children: [
        SectionLabel(label),
        _TileGrid(tiles: tiles, columns: columns, style: _TileStyle.release),
      ],
    ),
  );
}

enum _TileStyle {
  era(size: 21, line: 24, lines: 1),
  release(size: 18, line: 22, lines: 2);

  const _TileStyle({
    required this.size,
    required this.line,
    required this.lines,
  });

  final double size;
  final double line;
  final int lines;
}

class _TileGrid extends StatelessWidget {
  const _TileGrid({
    required this.tiles,
    required this.columns,
    required this.style,
  });

  static const double padTop = 24;
  static const double padBottom = 40;
  static const double rowGap = 30;
  static const double columnGap = 24;
  static const double subpixels = 64;

  final List<_Tile> tiles;
  final int columns;
  final _TileStyle style;

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
              key: tile.key,
              width: width,
              child: _PickTile(tile: tile, style: style),
            ),
        ],
      );
    },
  );
}

class _PickTile extends StatelessWidget {
  const _PickTile({required this.tile, required this.style});

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

  final _Tile tile;
  final _TileStyle style;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final selected = tile.selected;
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
      builder: (context, shown, child) => Opacity(
        opacity: shown,
        child: Transform.translate(
          offset: Offset(0, riseOffset * (1 - shown)),
          child: child,
        ),
      ),
      child: Pressable(
        onPressed: tile.onTap,
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
                            labelUrl: tile.cover,
                            labelColor: tile.placeholder,
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
                              coverUrl: tile.cover,
                              placeholder: tile.placeholder,
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
                              child: SelectedCheck(size: _PickTile.checkSize),
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
                  tile.title,
                  maxLines: style.lines,
                  softWrap: style.lines > 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.display(
                    style.size,
                    italic: true,
                    height: style.line / style.size,
                    color: tokens.fg,
                  ),
                ),
                Text(
                  tile.meta,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
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
