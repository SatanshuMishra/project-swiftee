import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/achievements.dart';
import 'package:swiftie_quiz/domain/engine/misu_lines.dart';
import 'package:swiftie_quiz/domain/models/achievement_def.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/kit/vinyl.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/ui/widgets/back_link.dart';
import 'package:swiftie_quiz/domain/util/song_title.dart';

class RecordShelfScreen extends ConsumerStatefulWidget {
  const RecordShelfScreen({super.key});

  static const double topPad = 20;
  static const double bottomPad = 48;
  static const double headerGap = 14;
  static const double sectionGap = 30;
  static const double titleGap = 24;
  static const double titleRunGap = 12;
  static const double rowGap = 22;
  static const double columnGap = 26;
  static const String nameless = 'you';
  static const String hoverNote = 'hover a record to hear it';
  static const String separator = ' · ';

  static const List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const Map<String, String> hints = {
    'first_meow': 'Get 1 right',
    'getting_warmed_up': '10 right, all-time',
    'purrfect_streak': '10 in a row',
    'album_explorer': 'Songs from 5 eras',
    'album_completionist': 'Every song on one album',
    'hard_mode_hero': '5 right on Hard',
    'speed_demon': 'Right in under 3 s',
    'persistent_listener': 'Right after the full clip',
    'quack_collector': 'A secret',
    'all_ears': '50 songs, all-time',
    'lyric_lover': 'Any lyrics round',
    'poet_laureate': '20 in Name That Song',
    'lie_detector': '15 in Lyrics or Lie',
    'dual_threat': 'Sound and lyrics, one session',
    'lyric_streak': '10 in a row on lyrics',
  };

  static String title(String name) =>
      name == nameless ? 'Your record shelf' : "$name's record shelf";

  static String count(int earned) =>
      '$earned of ${achievementDefs.length}$separator$hoverNote';

  static String? shortDate(String? iso) {
    final moment = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    return moment == null ? null : '${months[moment.month - 1]} ${moment.day}';
  }

  static String detail(AchievementState record) {
    final song = record.song;
    final date = shortDate(record.unlockedAt);
    return [
      if (song != null) 'on ${displaySongTitle(song)}',
      ?date,
    ].join(separator);
  }

  @override
  ConsumerState<RecordShelfScreen> createState() => _RecordShelfScreenState();
}

class _RecordShelfScreenState extends ConsumerState<RecordShelfScreen> {
  AudioController? _audio;
  String? _playing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final game = ref.read(gameControllerProvider);
      final needsCovers =
          game.albums.isEmpty &&
          game.progress.achievements.values.any(
            (record) => record.unlocked && record.albumId != null,
          );
      if (needsCovers) {
        unawaited(ref.read(catalogControllerProvider.notifier).loadCatalogue());
      }
    });
  }

  @override
  void dispose() {
    _audio?.stopSnippet();
    super.dispose();
  }

  AudioController _player() {
    final AudioController audio =
        _audio ?? ref.read(audioControllerProvider.notifier);
    _audio = audio;
    return audio;
  }

  void _play(String id, String? trackId) {
    _playing = id;
    if (trackId == null) {
      _player().stopSnippet();
    } else {
      unawaited(_player().previewSnippet(trackId));
    }
  }

  void _stop(String id) {
    if (_playing != id) {
      return;
    }
    _playing = null;
    _player().stopSnippet();
  }

  ShelfRecord _recordFor(
    AchievementDef definition,
    AchievementState? record,
    List<Album> albums,
  ) {
    final hint =
        RecordShelfScreen.hints[definition.id] ?? definition.description;
    if (record == null || !record.unlocked) {
      return ShelfRecord(definition: definition, hint: hint);
    }
    final albumId = int.tryParse(record.albumId ?? '');
    final placeholder = albumId == null
        ? null
        : ref
              .read(catalogControllerProvider)
              .catalogue
              .eraOf(albumId)
              ?.placeholderArgb;
    return ShelfRecord(
      definition: definition,
      hint: hint,
      record: record,
      coverUrl: albumId == null
          ? null
          : albums
                .firstWhereOrNull((album) => album.id == albumId)
                ?.coverMedium,
      placeholder: placeholder == null ? null : Color(placeholder),
      onPlay: () => _play(definition.id, record.trackId),
      onStop: () => _stop(definition.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    final edition = ref.watch(editionProvider);
    final nickname = ref.watch(
      gameControllerProvider.select((game) => game.progress.settings.nickname),
    );
    final achievements = ref.watch(
      gameControllerProvider.select((game) => game.progress.achievements),
    );
    final albums = ref.watch(
      gameControllerProvider.select((game) => game.albums),
    );
    final earned = achievementDefs
        .where((definition) => achievements[definition.id]?.unlocked ?? false)
        .length;
    return ScreenEnter(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          layout.padX,
          RecordShelfScreen.topPad,
          layout.padX,
          RecordShelfScreen.bottomPad,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BackLink(
                onPressed: () => ref
                    .read(gameControllerProvider.notifier)
                    .setPhase(GamePhase.menu),
              ),
            ),
            const SizedBox(height: RecordShelfScreen.headerGap),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: RecordShelfScreen.titleGap,
              runSpacing: RecordShelfScreen.titleRunGap,
              children: [
                Text(
                  RecordShelfScreen.title(displayName(edition, nickname)),
                  style: AppType.display(
                    layout.h1,
                    height: 1,
                    color: tokens.fg,
                  ),
                ),
                Text(
                  RecordShelfScreen.count(earned),
                  style: AppType.body.copyWith(color: tokens.mut),
                ),
              ],
            ),
            const SizedBox(height: RecordShelfScreen.sectionGap),
            _ShelfGrid(
              columns: layout.shelfColumns,
              children: [
                for (final definition in achievementDefs)
                  _recordFor(definition, achievements[definition.id], albums),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfGrid extends MultiChildRenderObjectWidget {
  const _ShelfGrid({required this.columns, required super.children});

  final int columns;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderShelfGrid(columns: columns);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderShelfGrid renderObject,
  ) => renderObject.columns = columns;
}

class _ShelfGridParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderShelfGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ShelfGridParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ShelfGridParentData> {
  _RenderShelfGrid({required this._columns});

  int _columns;
  double _lift = 0;

  set columns(int value) {
    if (value != _columns) {
      _columns = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ShelfGridParentData) {
      child.parentData = _ShelfGridParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final cellWidth =
        (width - (_columns - 1) * RecordShelfScreen.columnGap) / _columns;
    final lift = ShelfRecord.liftFor(cellWidth);
    final cell = BoxConstraints.tightFor(width: cellWidth);
    var rowTop = 0.0;
    var rowHeight = 0.0;
    var column = 0;
    var child = firstChild;
    while (child != null) {
      if (column == _columns) {
        rowTop += rowHeight + RecordShelfScreen.rowGap;
        rowHeight = 0;
        column = 0;
      }
      child.layout(cell, parentUsesSize: true);
      (child.parentData! as _ShelfGridParentData).offset = Offset(
        column * (cellWidth + RecordShelfScreen.columnGap),
        rowTop - lift,
      );
      rowHeight = math.max(rowHeight, child.size.height - lift);
      column += 1;
      child = childAfter(child);
    }
    _lift = lift;
    size = constraints.constrain(Size(width, rowTop + rowHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final reach = Rect.fromLTRB(0, -_lift, size.width, size.height);
    if (!reach.contains(position) ||
        !hitTestChildren(result, position: position)) {
      return false;
    }
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class ShelfRecord extends StatefulWidget {
  const ShelfRecord({
    super.key,
    required this.definition,
    required this.hint,
    this.record,
    this.coverUrl,
    this.placeholder,
    this.onPlay,
    this.onStop,
  });

  static const double sleeveTop = 46;
  static const double textGap = 12;
  static const double lineGap = 2;
  static const double discOverhang = 0.06;
  static const double discRestLeft = 0.22;
  static const double discRestRise = 0.30;
  static const double discOutLeft = 0.30;
  static const double discOutRise = 0.44;
  static const double discLabel = 0.34;
  static const Duration discSlide = Duration(milliseconds: 400);
  static const Curve discSlideCurve = Cubic(0.2, 0.8, 0.2, 1);
  static const Duration rise = Duration(milliseconds: 400);
  static const Curve riseCurve = Curves.ease;
  static const double riseOffset = 8;
  static const double nameSize = 21;
  static const double nameLineHeight = 24;
  static const double sleeveRadius = 3;
  static final TextStyle detailStyle = AppType.sized(12, 17);

  static double liftFor(double width) =>
      math.max(0, width * discOutRise - sleeveTop);

  final AchievementDef definition;
  final String hint;
  final AchievementState? record;
  final String? coverUrl;
  final Color? placeholder;
  final VoidCallback? onPlay;
  final VoidCallback? onStop;

  @override
  State<ShelfRecord> createState() => _ShelfRecordState();
}

class _ShelfRecordState extends State<ShelfRecord> {
  bool _hovered = false;
  bool _focused = false;

  bool get _out => _hovered || _focused;

  void _setHovered(bool hovered) {
    if (_hovered != hovered) {
      _change(() => _hovered = hovered, play: hovered);
    }
  }

  void _setFocused(bool focused) {
    if (_focused != focused) {
      _change(() => _focused = focused, play: false);
    }
  }

  void _change(VoidCallback update, {required bool play}) {
    final wasOut = _out;
    setState(update);
    if (play) {
      widget.onPlay?.call();
    } else if (wasOut && !_out) {
      widget.onStop?.call();
    }
  }

  Object? _replay(Intent intent) {
    widget.onPlay?.call();
    return null;
  }

  TextStyle _nameStyle(Color color) => AppType.display(
    ShelfRecord.nameSize,
    italic: true,
    height: ShelfRecord.nameLineHeight / ShelfRecord.nameSize,
    color: color,
  );

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    return _Rise(
      child: LayoutBuilder(
        builder: (context, constraints) => record == null
            ? _locked(context, constraints.maxWidth)
            : _earned(context, constraints.maxWidth, record),
      ),
    );
  }

  Widget _locked(BuildContext context, double width) {
    final tokens = AppTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(top: ShelfRecord.liftFor(width)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: ShelfRecord.sleeveTop),
          AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: DashedOutlinePainter(
                color: tokens.line2,
                radius: ShelfRecord.sleeveRadius,
              ),
            ),
          ),
          const SizedBox(height: ShelfRecord.textGap),
          Text(widget.definition.name, style: _nameStyle(tokens.faint)),
          const SizedBox(height: ShelfRecord.lineGap),
          Text(
            widget.hint,
            style: ShelfRecord.detailStyle.copyWith(color: tokens.faint),
          ),
        ],
      ),
    );
  }

  Widget _earned(BuildContext context, double width, AchievementState record) {
    final tokens = AppTokens.of(context);
    final detail = RecordShelfScreen.detail(record);
    final lift = ShelfRecord.liftFor(width);
    final left = _out ? ShelfRecord.discOutLeft : ShelfRecord.discRestLeft;
    final rise = _out ? ShelfRecord.discOutRise : ShelfRecord.discRestRise;
    final disc = width * (1 - left + ShelfRecord.discOverhang);
    final ring = _focused
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(ShelfRecord.sleeveRadius),
            border: Border.all(
              color: tokens.coral,
              width: Pressable.focusRingWidth,
              strokeAlign:
                  BorderSide.strokeAlignOutside +
                  2 * Pressable.focusRingGap / Pressable.focusRingWidth,
            ),
          )
        : const BoxDecoration();
    return Semantics(
      container: true,
      button: true,
      tooltip: widget.definition.description,
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.deferToChild,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedPositioned(
              duration: AppMotion.duration(context, ShelfRecord.discSlide),
              curve: ShelfRecord.discSlideCurve,
              left: width * left,
              top: lift + ShelfRecord.sleeveTop - width * rise,
              width: disc,
              height: disc,
              child: LayoutBuilder(
                builder: (context, box) => VinylDisc(
                  size: box.maxWidth,
                  labelUrl: widget.coverUrl,
                  labelColor: widget.placeholder ?? tokens.designCard,
                  labelFraction: ShelfRecord.discLabel,
                  style: VinylStyle.tile,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: lift),
              child: MetaData(
                behavior: HitTestBehavior.opaque,
                child: FocusableActionDetector(
                  onShowFocusHighlight: _setFocused,
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: _replay,
                    ),
                    ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
                      onInvoke: _replay,
                    ),
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: ShelfRecord.sleeveTop),
                      DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: ring,
                        child: AlbumSleeve(
                          size: width,
                          coverUrl: widget.coverUrl,
                          placeholder: widget.placeholder,
                          radius: ShelfRecord.sleeveRadius,
                        ),
                      ),
                      const SizedBox(height: ShelfRecord.textGap),
                      Text(
                        widget.definition.name,
                        style: _nameStyle(tokens.fg),
                      ),
                      if (detail.isNotEmpty) ...[
                        const SizedBox(height: ShelfRecord.lineGap),
                        Text(
                          detail,
                          style: ShelfRecord.detailStyle.copyWith(
                            color: tokens.mut,
                          ),
                        ),
                      ],
                    ],
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

class _Rise extends StatelessWidget {
  const _Rise({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.duration(context, ShelfRecord.rise),
    curve: ShelfRecord.riseCurve,
    builder: (context, shown, child) => Opacity(
      opacity: shown,
      child: Transform.translate(
        offset: Offset(0, ShelfRecord.riseOffset * (1 - shown)),
        child: child,
      ),
    ),
    child: child,
  );
}

class DashedOutlinePainter extends CustomPainter {
  const DashedOutlinePainter({
    required this.color,
    this.radius = 0,
    this.strokeWidth = 1,
    this.dash = 3,
    this.gap = 3,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            inset,
            inset,
            size.width - strokeWidth,
            size.height - strokeWidth,
          ),
          Radius.circular(radius),
        ),
      );
    final dashes = Path();
    for (final metric in outline.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += dash + gap) {
        dashes.addPath(metric.extractPath(start, start + dash), Offset.zero);
      }
    }
    canvas.drawPath(
      dashes,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(DashedOutlinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap;
}
