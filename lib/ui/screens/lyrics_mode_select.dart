import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/screens/main_menu.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';
import 'package:swiftie_quiz/ui/widgets/selection_card.dart';

class LyricsModeSelect extends ConsumerWidget {
  const LyricsModeSelect({super.key});

  static const double gridGap = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.read(gameControllerProvider.notifier);
    void choose(LyricsMode lyricsMode) {
      game.setLyricsMode(lyricsMode);
      game.setPhase(GamePhase.difficultySelect);
    }

    return CenteredScreen(
      onBack: () => game.setPhase(GamePhase.quizTypeSelect),
      children: [
        const ScreenHeading(
          title: 'Choose your challenge',
          subtitle: 'Pick a lyrics game mode',
        ),
        ResponsiveGrid(
          columns: const GridColumns(1, md: 2),
          gap: gridGap,
          maxWidth: TailwindContainers.xl3,
          children: [
            SelectionCard(
              glyph: LucideGlyph.bookOpen,
              title: 'Name That Song',
              description: 'Read lyrics, guess the title',
              gradient: AppGradients.violet,
              delay: const Duration(milliseconds: 100),
              cursor: SystemMouseCursors.click,
              onTap: () => choose(LyricsMode.nameThatSong),
            ),
            SelectionCard(
              glyph: LucideGlyph.eye,
              title: 'Lyrics or Lie',
              description: "See a lyric, decide if it's real or fake",
              gradient: AppGradients.orange,
              delay: const Duration(milliseconds: 200),
              cursor: SystemMouseCursors.click,
              onTap: () => choose(LyricsMode.lyricsOrLie),
            ),
          ],
        ),
      ],
    );
  }
}
