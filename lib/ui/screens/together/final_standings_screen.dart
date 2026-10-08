import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/misu_lines.dart';
import 'package:swiftie_quiz/domain/together/standings.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/together/room_controller.dart';
import 'package:swiftie_quiz/state/together/together_game_controller.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/kit/section_label.dart';
import 'package:swiftie_quiz/ui/kit/two_pane.dart';
import 'package:swiftie_quiz/ui/kit/whole_word_text.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/ui/together/standings_list.dart';

class FinalStandingsScreen extends ConsumerWidget {
  const FinalStandingsScreen({super.key});

  static const String fastestLabel = 'Fastest answer';
  static const String streakLabel = 'Longest streak';
  static const String you = 'You';
  static const String nextLabel = 'Next →';

  static String title(String mode) => 'Final standings · $mode';

  static String fastestLine(String who, double seconds, String song) =>
      '$who · ${seconds.toStringAsFixed(1)} s on $song';

  static String streakLine(String who, int best) => '$who · $best in a row';

  static const double pad = 40;
  static const double leftGap = 16;
  static const double titleHeight = 1.02;
  static const double highlightsTop = 14;
  static const double highlightsGap = 10;
  static const double rightGap = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    final game = ref.watch(togetherGameControllerProvider);
    final viewerName = displayName(
      ref.watch(editionProvider),
      ref.watch(
        gameControllerProvider.select(
          (state) => state.progress.settings.nickname,
        ),
      ),
    );
    final youId =
        ref.watch(roomControllerProvider.select((room) => room.you?.id)) ?? '';
    String nameOf(String id) => id == youId
        ? you
        : game.roster.firstWhereOrNull((player) => player.id == id)?.name ?? '';
    final winner = ranked(
      game.standings,
      viewerId: youId,
      joinOrder: [for (final player in game.roster) player.id],
    ).firstOrNull;
    final fastest = fastestHighlight(game.standings);
    final streak = streakHighlight(game.standings);
    final highlights = [
      if (fastest != null)
        (
          fastestLabel,
          fastestLine(
            nameOf(fastest.id),
            fastest.fastest.seconds,
            fastest.fastest.song,
          ),
        ),
      if (streak != null)
        (streakLabel, streakLine(nameOf(streak.id), streak.best)),
    ];
    return ScreenEnter(
      child: TwoPane(
        left: FocusTraversalGroup(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: layout.padX,
              vertical: pad,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: leftGap,
              children: [
                SectionLabel(title(game.mode.title)),
                if (winner != null) ...[
                  Semantics(
                    header: true,
                    child: WholeWordText(
                      winnerTitle(
                        viewerWon: winner.id == youId,
                        viewerName: viewerName,
                        winnerName: nameOf(winner.id),
                      ),
                      style: AppType.display(
                        layout.h1,
                        height: titleHeight,
                        color: tokens.fg,
                      ),
                    ),
                  ),
                  Text(
                    winnerSubline(winner.score, game.total),
                    style: AppType.bodyLarge.copyWith(color: tokens.mut),
                  ),
                ],
                if (highlights.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.only(top: highlightsTop),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: tokens.line)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: highlightsGap,
                      children: [
                        for (final (label, line) in highlights)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionLabel(label),
                              Text(
                                line,
                                style: AppType.body.copyWith(color: tokens.fg),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        right: FocusTraversalGroup(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: layout.padX,
              vertical: pad,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: rightGap,
              children: [
                StandingsList(game: game, viewerId: youId),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PillButton(
                    label: nextLabel,
                    size: PillSize.large,
                    onPressed: ref
                        .read(togetherGameControllerProvider.notifier)
                        .next,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
