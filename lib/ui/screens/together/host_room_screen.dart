import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/version_filter.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/domain/together/server_link.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/together/room_controller.dart';
import 'package:swiftie_quiz/state/together/room_state.dart';
import 'package:swiftie_quiz/ui/kit/choice_row.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/kit/section_label.dart';
import 'package:swiftie_quiz/ui/kit/segmented.dart';
import 'package:swiftie_quiz/ui/kit/two_pane.dart';
import 'package:swiftie_quiz/ui/kit/whole_word_text.dart';
import 'package:swiftie_quiz/ui/screens/album_grid.dart';
import 'package:swiftie_quiz/ui/screens/game_screen.dart' show difficultyLabel;
import 'package:swiftie_quiz/ui/screens/main_menu.dart';
import 'package:swiftie_quiz/ui/screens/settings_screen.dart' show Spinner;
import 'package:swiftie_quiz/ui/screens/together/together_nav.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/ui/together/together_copy.dart';
import 'package:swiftie_quiz/ui/widgets/back_link.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';
import 'package:swiftie_quiz/ui/widgets/version_choices.dart';

void storePickedScope(WidgetRef ref) {
  final game = ref.read(gameControllerProvider);
  final eraKeys = game.selectedEraKeys;
  final releaseIds = game.selectedReleaseIds;
  final everything = eraKeys.isEmpty && releaseIds.isEmpty;
  final tracks = ref
      .read(catalogControllerProvider)
      .catalogue
      .tracksFor(eraKeys, releaseIds: releaseIds)
      .length;
  final room = ref.read(roomControllerProvider);
  ref
      .read(roomControllerProvider.notifier)
      .setSettings(
        room.settings.copyWith(
          scope: everything
              ? const RoomScope.everything()
              : RoomScope.picked(eraKeys: eraKeys, releaseIds: releaseIds),
        ),
        everything
            ? MainMenu.shuffleTitle
            : AlbumGrid.selectionLabel(
                eraKeys.length,
                releaseIds.length,
                tracks,
              ),
      );
  ref.read(togetherNavProvider.notifier).show(TogetherScreen.host);
}

class HostRoomScreen extends ConsumerWidget {
  const HostRoomScreen({super.key});

  static const String title = 'Host a room';
  static const String subtitle =
      'Everyone plays the same songs at the same time. Up to 8 players.';
  static const String gameLabel = 'Game';
  static const String songsLabel = 'Songs';
  static const String roundsLabel = 'Rounds';
  static const String difficultyTitle = 'Difficulty';
  static const String openLabel = 'Open room →';
  static const String openingLabel = 'Opening…';
  static const String backToRoomLabel = 'Back to room →';

  static String staysOpen(String code) =>
      'Room $code stays open while you change things.';

  static final List<(int, String)> roundOptions = [
    for (final rounds in roundChoices) (rounds, '$rounds'),
  ];
  static final List<(Difficulty, String)> difficultyOptions = [
    for (final difficulty in Difficulty.values)
      (difficulty, difficultyLabel(difficulty)),
  ];

  static const double leftTop = 20;
  static const double leftBottom = 32;
  static const double leftGap = 14;
  static const double rightTop = 32;
  static const double rightBottom = 40;
  static const double sectionGap = 28;
  static const double groupGap = 10;
  static const double segmentsSpacing = 40;
  static const double segmentsRunSpacing = 24;
  static const double failureRise = 8;
  static const double spinnerTrackAlpha = 0.25;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    final room = ref.watch(roomControllerProvider);
    final roomController = ref.read(roomControllerProvider.notifier);
    final nav = ref.read(togetherNavProvider.notifier);
    ref.listen(roomControllerProvider.select((room) => room.status), (
      previous,
      next,
    ) {
      if (previous == RoomStatus.connecting && next == RoomStatus.open) {
        nav.show(TogetherScreen.hub);
      }
    });
    final settings = room.settings;
    final open = room.status == RoomStatus.open && room.role == RoomRole.host;
    final connecting = room.status == RoomStatus.connecting;
    final code = room.code;
    final failure = room.status == RoomStatus.idle ? room.failure : null;

    void change(RoomSettings next, [String? scopeLabel]) =>
        roomController.setSettings(next, scopeLabel ?? room.scopeLabel);

    void pickEras() {
      final game = ref.read(gameControllerProvider.notifier)..clearSelection();
      for (final eraKey in settings.scope.eraKeys) {
        game.toggleEra(eraKey);
      }
      for (final releaseId in settings.scope.releaseIds) {
        game.toggleRelease(releaseId);
      }
      nav.show(TogetherScreen.eras);
    }

    void openRoom() {
      final link = ServerLink.parse(
        ref.read(gameControllerProvider).progress.settings.togetherLink ?? '',
      );
      if (link != null) {
        unawaited(roomController.open(link));
      }
    }

    return ScreenEnter(
      child: TwoPane(
        left: FocusTraversalGroup(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              layout.padX,
              leftTop,
              layout.padX,
              leftBottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: leftGap,
              children: [
                BackLink(onPressed: () => backToHub(ref)),
                Semantics(
                  header: true,
                  child: WholeWordText(
                    title,
                    style: AppType.display(
                      layout.h1,
                      height: 1,
                      color: tokens.fg,
                    ),
                  ),
                ),
                Text(subtitle, style: AppType.body.copyWith(color: tokens.mut)),
                if (open && code != null)
                  Text(
                    staysOpen(code),
                    style: AppType.body.copyWith(color: tokens.fg),
                  ),
              ],
            ),
          ),
        ),
        right: FocusTraversalGroup(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              layout.padX,
              rightTop,
              layout.padX,
              rightBottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: sectionGap,
              children: [
                _Group(
                  label: gameLabel,
                  children: [
                    for (final mode in TogetherMode.values)
                      ChoiceRow(
                        title: mode.title,
                        description: mode.description,
                        selected: settings.mode == mode,
                        onTap: () => change(settings.copyWith(mode: mode)),
                      ),
                  ],
                ),
                _Group(
                  label: songsLabel,
                  children: [
                    ChoiceRow(
                      title: MainMenu.shuffleTitle,
                      description: MainMenu.shuffleDescription,
                      selected: settings.scope.everything,
                      onTap: () => change(
                        settings.copyWith(scope: const RoomScope.everything()),
                        MainMenu.shuffleTitle,
                      ),
                    ),
                    ChoiceRow(
                      title: MainMenu.erasTitle,
                      description: settings.scope.everything
                          ? MainMenu.erasDescription
                          : room.scopeLabel,
                      selected: !settings.scope.everything,
                      onTap: pickEras,
                    ),
                  ],
                ),
                if (settings.playsSound)
                  _HostVersions(
                    settings: settings,
                    onChanged: (versions) =>
                        change(settings.copyWith(versions: versions)),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: segmentsSpacing,
                    runSpacing: segmentsRunSpacing,
                    children: [
                      _Group(
                        label: roundsLabel,
                        stretch: false,
                        children: [
                          Segmented<int>(
                            options: roundOptions,
                            value: settings.rounds,
                            onChanged: (rounds) =>
                                change(settings.copyWith(rounds: rounds)),
                          ),
                        ],
                      ),
                      _Group(
                        label: difficultyTitle,
                        stretch: false,
                        children: [
                          Segmented<Difficulty>(
                            options: difficultyOptions,
                            value: settings.difficulty,
                            onChanged: (difficulty) => change(
                              settings.copyWith(difficulty: difficulty),
                            ),
                          ),
                          Text(
                            difficultyNote(settings.difficulty),
                            style: AppType.small.copyWith(color: tokens.mut),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: groupGap,
                  children: [
                    PillButton(
                      label: open
                          ? backToRoomLabel
                          : connecting
                          ? openingLabel
                          : openLabel,
                      size: PillSize.large,
                      leading: connecting
                          ? Spinner(
                              track: tokens.onCoral.withValues(
                                alpha: spinnerTrackAlpha,
                              ),
                              arc: tokens.onCoral,
                            )
                          : null,
                      onPressed: open
                          ? () => nav.show(TogetherScreen.hub)
                          : openRoom,
                    ),
                    if (failure != null)
                      Entrance(
                        key: ValueKey(failure),
                        fromOffset: const Offset(0, failureRise),
                        child: Text(
                          failureLine(failure, hosting: true),
                          style: AppType.sized(
                            14,
                            20,
                          ).copyWith(color: tokens.rose),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.label,
    required this.children,
    this.stretch = true,
  });

  final String label;
  final List<Widget> children;
  final bool stretch;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: stretch
        ? CrossAxisAlignment.stretch
        : CrossAxisAlignment.start,
    spacing: HostRoomScreen.groupGap,
    children: [SectionLabel(label), ...children],
  );
}

class _HostVersions extends ConsumerStatefulWidget {
  const _HostVersions({required this.settings, required this.onChanged});

  final RoomSettings settings;
  final ValueChanged<VersionChoice> onChanged;

  @override
  ConsumerState<_HostVersions> createState() => _HostVersionsState();
}

class _HostVersionsState extends ConsumerState<_HostVersions> {
  ({Catalogue catalogue, RoomScope scope, VersionIndex index})? _indexed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(catalogControllerProvider).catalogue.isEmpty) {
        unawaited(ref.read(catalogControllerProvider.notifier).loadCatalogue());
      }
    });
  }

  VersionIndex _indexFor(Catalogue catalogue, RoomScope scope) {
    if (_indexed
        case (catalogue: final indexed, scope: final indexedScope, :final index)
        when identical(indexed, catalogue) && indexedScope == scope) {
      return index;
    }
    final index = VersionIndex(scope.tracksIn(catalogue));
    _indexed = (catalogue: catalogue, scope: scope, index: index);
    return index;
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(
      catalogControllerProvider.select((catalog) => catalog.catalogue),
    );
    if (catalogue.isEmpty) {
      return const SizedBox.shrink();
    }
    final index = _indexFor(catalogue, widget.settings.scope);
    final versions = index.usable(widget.settings.versions);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: HostRoomScreen.sectionGap,
      children: [
        _Group(
          label: VersionCopy.versionsLabel,
          children: [
            TakeCards(
              index: index,
              choice: versions,
              onChanged: widget.onChanged,
            ),
          ],
        ),
        if (index.hasRerecorded)
          _Group(
            label: VersionCopy.rerecordedLabel,
            children: [
              RerecordedChoice(
                index: index,
                choice: versions,
                onChanged: widget.onChanged,
              ),
            ],
          ),
      ],
    );
  }
}
