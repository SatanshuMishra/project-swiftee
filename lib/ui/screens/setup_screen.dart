import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/play_order.dart';
import 'package:swiftie_quiz/domain/engine/version_filter.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/kit/choice_row.dart';
import 'package:swiftie_quiz/ui/kit/option_tile.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/kit/section_label.dart';
import 'package:swiftie_quiz/ui/kit/two_pane.dart';
import 'package:swiftie_quiz/ui/kit/vinyl.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/ui/widgets/back_link.dart';

typedef SetupChoice<T> = ({T value, String title, String description});

typedef _Cover = ({String? url, Color placeholder});

typedef _Source = ({int songs, Map<TrackVersions, int> versions});

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  static const String playingLabel = "You're playing";
  static const String shuffleTitle = 'Shuffle everything';
  static const String shuffleSublineUnknown = 'Every song, every era';
  static const String listenLabel = 'Listen or read';
  static const String lyricsGameLabel = 'Which lyrics game';
  static const String versionsLabel = 'Which versions';
  static const String difficultyLabel = 'Difficulty';
  static const String startLabel = 'Start →';
  static const String unknownSongs = '—';

  static const List<SetupChoice<QuizType>> quizTypes = [
    (
      value: QuizType.sound,
      title: 'Sound',
      description: 'Hear a clip, name the song.',
    ),
    (
      value: QuizType.lyrics,
      title: 'Lyrics',
      description: 'Read the words, test what you know.',
    ),
  ];

  static const List<SetupChoice<LyricsMode>> lyricsModes = [
    (
      value: LyricsMode.nameThatSong,
      title: 'Name That Song',
      description: 'Read the lyrics, guess the title.',
    ),
    (
      value: LyricsMode.lyricsOrLie,
      title: 'Lyrics or Lie',
      description: 'See a lyric, decide if it’s real.',
    ),
  ];

  static const List<SetupChoice<TrackVersions>> versionChoices = [
    (
      value: TrackVersions.every,
      title: 'Every version',
      description: 'Originals, re-recordings and live',
    ),
    (
      value: TrackVersions.taylorsVersion,
      title: 'Taylor’s Version',
      description: 'Her re-recordings replace the originals',
    ),
    (
      value: TrackVersions.noLive,
      title: 'No live takes',
      description: 'Studio recordings only',
    ),
  ];

  static const List<SetupChoice<Difficulty>> difficulties = [
    (value: Difficulty.easy, title: 'Easy', description: 'Quick warm-up'),
    (value: Difficulty.medium, title: 'Medium', description: 'The real thing'),
    (value: Difficulty.hard, title: 'Hard', description: 'For true Swifties'),
  ];

  static String sourceTitle(
    List<Era> eras, [
    List<CatalogueRelease> releases = const [],
  ]) => switch ((eras, releases)) {
    ([], []) => shuffleTitle,
    ([final era], []) => era.eraName,
    (_, []) => 'Your ${eras.length} eras',
    ([], [final release]) => release.title,
    ([], _) => 'Your ${releases.length} releases',
    _ => 'Your picks',
  };

  static String shuffleSubline(int? count, {QuizType quiz = QuizType.sound}) =>
      count == null
      ? shuffleSublineUnknown
      : '$count ${_unit(quiz)}, every era';

  static String erasSubline(int? count, {QuizType quiz = QuizType.sound}) =>
      '${count == null || count == 0 ? unknownSongs : count} ${_unit(quiz)}';

  static String _unit(QuizType quiz) => switch (quiz) {
    QuizType.sound => 'tracks',
    QuizType.lyrics => 'songs',
  };

  static List<String> features({
    required QuizType quizType,
    required LyricsMode lyricsMode,
    required Difficulty difficulty,
    required int mediumTimer,
    required int hardTimer,
  }) {
    final mediumTimed = '$mediumTimer-second timer';
    final hardTimed = '$hardTimer-second timer';
    return List.unmodifiable(switch ((quizType, lyricsMode, difficulty)) {
      (QuizType.sound, _, Difficulty.easy) => [
        'Multiple choice',
        'Album cover shown',
        'No time limit',
      ],
      (QuizType.sound, _, Difficulty.medium) => [
        'Multiple choice',
        'No album hint',
        mediumTimed,
      ],
      (QuizType.sound, _, Difficulty.hard) => [
        'Type your answer',
        'No hints',
        hardTimed,
      ],
      (QuizType.lyrics, LyricsMode.nameThatSong, Difficulty.easy) => [
        '4 lyric lines from the chorus',
        'Album hint',
        'Multiple choice',
      ],
      (QuizType.lyrics, LyricsMode.nameThatSong, Difficulty.medium) => [
        '3 lyric lines',
        'Multiple choice',
        mediumTimed,
      ],
      (QuizType.lyrics, LyricsMode.nameThatSong, Difficulty.hard) => [
        '2 lyric lines, no chorus',
        'Type your answer',
        hardTimed,
      ],
      (QuizType.lyrics, LyricsMode.lyricsOrLie, Difficulty.easy) => [
        '3 lyric lines',
        'Album cover shown',
        'Fakes from different eras',
        'No time limit',
      ],
      (QuizType.lyrics, LyricsMode.lyricsOrLie, Difficulty.medium) => [
        '2 lyric lines',
        'No hints',
        'Fakes from similar albums',
        mediumTimed,
      ],
      (QuizType.lyrics, LyricsMode.lyricsOrLie, Difficulty.hard) => [
        '1 lyric line',
        'No hints',
        'Fakes from the same album',
        hardTimed,
      ],
    });
  }

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  static const leftPadding = (top: 20.0, bottom: 40.0);
  static const rightPadding = (top: 32.0, bottom: 40.0);
  static const double leftGap = 28;
  static const double rightGap = 30;
  static const double sourceGap = 10;
  static const double fanTop = 8;
  static const double startTop = 4;

  late QuizType _quizType;
  late LyricsMode _lyricsMode;
  late Difficulty _difficulty;
  late TrackVersions _versions;
  ({GameState game, Catalogue catalogue, _Source source})? _source;

  @override
  void initState() {
    super.initState();
    final game = ref.read(gameControllerProvider);
    _quizType = game.quizType ?? QuizType.sound;
    _lyricsMode = game.lyricsMode ?? LyricsMode.nameThatSong;
    final remembered =
        game.quizType != null ||
        game.difficulty != GameState.initial.difficulty;
    _difficulty = remembered ? game.difficulty : Difficulty.medium;
    _versions = game.versions;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSource());
  }

  List<Era> _sourceEras(
    GameMode mode,
    Catalogue catalogue,
    List<String> selectedEraKeys,
  ) => switch (mode) {
    GameMode.random => const [],
    GameMode.album => List.unmodifiable(
      selectedEraKeys.map(catalogue.eraByKey).nonNulls,
    ),
    GameMode.tonight => List.unmodifiable([
      tonightsEra(ref.read(clockProvider)()),
    ]),
  };

  List<CatalogueRelease> _sourceReleases(
    GameMode mode,
    Catalogue catalogue,
    List<int> selectedIds,
  ) => mode == GameMode.album
      ? List.unmodifiable([
          for (final id in selectedIds)
            ?catalogue.releases.firstWhereOrNull((release) => release.id == id),
        ])
      : const [];

  _Source _sourceOf(Catalogue catalogue, GameState game) {
    if (_source
        case (game: final before, catalogue: final indexed, :final source)
        when identical(indexed, catalogue) &&
            sameTrackSelection(before, game)) {
      return source;
    }
    final tracks = tracksForGame(catalogue, game, ref.read(clockProvider)());
    final source = (
      songs: {for (final track in tracks) songKey(track)}.length,
      versions: Map<TrackVersions, int>.unmodifiable({
        for (final versions in TrackVersions.values)
          versions: keepVersions(tracks, versions).length,
      }),
    );
    _source = (game: game, catalogue: catalogue, source: source);
    return source;
  }

  bool _offers(_Source source, TrackVersions versions, {required bool known}) =>
      !known || (source.versions[versions] ?? 0) > 0;

  TrackVersions _versionsFor(_Source source, {required bool known}) =>
      _offers(source, _versions, known: known)
      ? _versions
      : TrackVersions.every;

  void _loadSource() {
    if (mounted) {
      unawaited(ref.read(catalogControllerProvider.notifier).loadCatalogue());
    }
  }

  void _back(GameMode mode) => ref
      .read(gameControllerProvider.notifier)
      .setPhase(
        mode == GameMode.album ? GamePhase.albumSelect : GamePhase.menu,
      );

  void _start() {
    final catalogue = ref.read(catalogControllerProvider).catalogue;
    final source = _sourceOf(catalogue, ref.read(gameControllerProvider));
    final game = ref.read(gameControllerProvider.notifier)
      ..setQuizType(_quizType)
      ..setDifficulty(_difficulty)
      ..setVersions(_versionsFor(source, known: !catalogue.isEmpty));
    switch (_quizType) {
      case QuizType.sound:
        game.setPhase(GamePhase.playing);
      case QuizType.lyrics:
        game
          ..setLyricsMode(_lyricsMode)
          ..setPhase(GamePhase.lyricsLoading);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    final mode = ref.watch(gameControllerProvider.select((game) => game.mode));
    final selectedKeys = ref.watch(
      gameControllerProvider.select((game) => game.selectedEraKeys),
    );
    final selectedIds = ref.watch(
      gameControllerProvider.select((game) => game.selectedReleaseIds),
    );
    final catalogue = ref.watch(
      catalogControllerProvider.select((catalog) => catalog.catalogue),
    );
    final timers = ref.watch(
      gameControllerProvider.select(
        (game) => (
          medium: game.progress.settings.mediumTimer,
          hard: game.progress.settings.hardTimer,
        ),
      ),
    );
    final eras = _sourceEras(mode, catalogue, selectedKeys);
    final releases = _sourceReleases(mode, catalogue, selectedIds);
    final known = !catalogue.isEmpty;
    final source = _sourceOf(catalogue, ref.read(gameControllerProvider));
    final versions = _versionsFor(source, known: known);
    final count = !known
        ? null
        : _quizType == QuizType.lyrics
        ? source.songs
        : source.versions[versions];
    final subline = eras.isEmpty && releases.isEmpty
        ? SetupScreen.shuffleSubline(count, quiz: _quizType)
        : SetupScreen.erasSubline(count, quiz: _quizType);
    final choiceColumns = layout.isNarrow ? 1 : 2;
    return ScreenEnter(
      child: TwoPane(
        left: Padding(
          padding: EdgeInsets.fromLTRB(
            layout.padX,
            leftPadding.top,
            layout.padX,
            leftPadding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: leftGap,
            children: [
              BackLink(onPressed: () => _back(mode), animateEntrance: false),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: sourceGap,
                children: [
                  const SectionLabel(SetupScreen.playingLabel),
                  Text(
                    SetupScreen.sourceTitle(eras, releases),
                    style: AppType.display(
                      layout.h1,
                      height: 1,
                      color: tokens.fg,
                    ),
                  ),
                  Text(
                    subline,
                    style: AppType.body.copyWith(color: tokens.mut),
                  ),
                ],
              ),
              if (!layout.isNarrow)
                Padding(
                  padding: const EdgeInsets.only(top: fanTop),
                  child: _CoverFan(
                    covers: [
                      for (final era
                          in eras.isEmpty && releases.isEmpty
                              ? catalogue.albumEras
                              : eras)
                        (
                          url: catalogue.coverFor(era.key),
                          placeholder: Color(era.placeholderArgb),
                        ),
                      for (final release in releases)
                        (
                          url: release.coverMedium,
                          placeholder: Color(
                            (catalogue.eraByKey(release.eraKey) ?? singlesEra)
                                .placeholderArgb,
                          ),
                        ),
                    ].take(_CoverFan.maxCovers).toList(),
                  ),
                ),
            ],
          ),
        ),
        right: Padding(
          padding: EdgeInsets.fromLTRB(
            layout.padX,
            rightPadding.top,
            layout.padX,
            rightPadding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: rightGap,
            children: [
              _Section(
                key: const ValueKey(SetupScreen.listenLabel),
                label: SetupScreen.listenLabel,
                children: [
                  _ChoiceGrid(
                    columns: choiceColumns,
                    children: [
                      for (final choice in SetupScreen.quizTypes)
                        ChoiceRow(
                          title: choice.title,
                          description: choice.description,
                          selected: _quizType == choice.value,
                          onTap: () => setState(() => _quizType = choice.value),
                        ),
                    ],
                  ),
                ],
              ),
              if (_quizType == QuizType.lyrics)
                _Rise(
                  key: const ValueKey(SetupScreen.lyricsGameLabel),
                  child: _Section(
                    label: SetupScreen.lyricsGameLabel,
                    children: [
                      _ChoiceGrid(
                        columns: choiceColumns,
                        children: [
                          for (final choice in SetupScreen.lyricsModes)
                            ChoiceRow(
                              title: choice.title,
                              description: choice.description,
                              selected: _lyricsMode == choice.value,
                              onTap: () =>
                                  setState(() => _lyricsMode = choice.value),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (_quizType == QuizType.sound)
                _Rise(
                  key: const ValueKey(SetupScreen.versionsLabel),
                  child: _Section(
                    label: SetupScreen.versionsLabel,
                    children: [
                      _ChoiceGrid(
                        columns: SetupScreen.versionChoices.length,
                        children: [
                          for (final choice in SetupScreen.versionChoices)
                            _Available(
                              available: _offers(
                                source,
                                choice.value,
                                known: known,
                              ),
                              child: OptionTile(
                                title: choice.title,
                                description: choice.description,
                                selected: versions == choice.value,
                                onTap:
                                    _offers(source, choice.value, known: known)
                                    ? () => setState(
                                        () => _versions = choice.value,
                                      )
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              _Section(
                key: const ValueKey(SetupScreen.difficultyLabel),
                label: SetupScreen.difficultyLabel,
                children: [
                  _ChoiceGrid(
                    columns: SetupScreen.difficulties.length,
                    children: [
                      for (final choice in SetupScreen.difficulties)
                        OptionTile(
                          title: choice.title,
                          description: choice.description,
                          selected: _difficulty == choice.value,
                          onTap: () =>
                              setState(() => _difficulty = choice.value),
                        ),
                    ],
                  ),
                  _FeatureList(
                    features: SetupScreen.features(
                      quizType: _quizType,
                      lyricsMode: _lyricsMode,
                      difficulty: _difficulty,
                      mediumTimer: timers.medium,
                      hardTimer: timers.hard,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: startTop),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PillButton(
                    label: SetupScreen.startLabel,
                    onPressed: _start,
                    size: PillSize.large,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({super.key, required this.label, required this.children});

  static const double gap = 10;

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: gap,
    children: [SectionLabel(label), ...children],
  );
}

class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({required this.columns, required this.children});

  static const double gap = 10;

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: gap,
    children: [
      for (final row in children.slices(columns))
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: gap,
            children: [for (final child in row) Expanded(child: child)],
          ),
        ),
    ],
  );
}

class _Rise extends StatelessWidget {
  const _Rise({super.key, required this.child});

  static const duration = Duration(milliseconds: 300);
  static const Curve curve = Curves.ease;
  static const double offset = 8;

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.duration(context, duration),
    curve: curve,
    builder: (context, shown, child) => Opacity(
      opacity: shown,
      child: Transform.translate(
        offset: Offset(0, offset * (1 - shown)),
        child: child,
      ),
    ),
    child: child,
  );
}

class _Available extends StatelessWidget {
  const _Available({required this.available, required this.child});

  static const double dimmed = 0.45;

  final bool available;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: available ? 1 : dimmed,
    duration: AppMotion.duration(context, AppMotion.selectionShift),
    curve: Curves.ease,
    child: child,
  );
}

class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.features});

  static const padding = EdgeInsets.fromLTRB(2, 6, 2, 0);
  static const double itemGap = 18;
  static const double runGap = 6;
  static const double dotSize = 5;
  static const double dotGap = 8;

  final List<String> features;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final style = AppType.sized(14, 20).copyWith(color: tokens.mut);
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: itemGap,
        runSpacing: runGap,
        children: [
          for (final feature in features)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: dotGap,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.coral,
                  ),
                  child: const SizedBox.square(dimension: dotSize),
                ),
                Flexible(child: Text(feature, style: style)),
              ],
            ),
        ],
      ),
    );
  }
}

class _CoverFan extends StatelessWidget {
  const _CoverFan({required this.covers});

  static const int maxCovers = 5;
  static const double size = 170;
  static const double step = 34;
  static const double degreesPerStep = 3;
  static const int uprightIndex = 2;

  final List<_Cover> covers;

  static double angleAt(int index) =>
      (index - uprightIndex) * degreesPerStep * math.pi / 180;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size + step * (covers.length - 1),
    height: size,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        for (final (index, cover) in covers.indexed.toList().reversed)
          Positioned(
            left: step * index,
            top: 0,
            child: Transform.rotate(
              angle: angleAt(index),
              child: AlbumSleeve(
                size: size,
                coverUrl: cover.url,
                placeholder: cover.placeholder,
              ),
            ),
          ),
      ],
    ),
  );
}
