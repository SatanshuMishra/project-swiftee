import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/screens/main_menu.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';
import 'package:swiftie_quiz/ui/widgets/selection_card.dart';

class QuizTypeSelect extends ConsumerWidget {
  const QuizTypeSelect({super.key});

  static const double gridGap = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.read(gameControllerProvider.notifier);
    final mode = ref.watch(
      gameControllerProvider.select((state) => state.mode),
    );
    return CenteredScreen(
      onBack: () => game.setPhase(
        mode == GameMode.album ? GamePhase.albumSelect : GamePhase.menu,
      ),
      children: [
        const ScreenHeading(
          title: 'How do you want to play?',
          subtitle: 'Choose your quiz style',
        ),
        ResponsiveGrid(
          columns: const GridColumns(1, md: 2),
          gap: gridGap,
          maxWidth: TailwindContainers.xl2,
          children: [
            SelectionCard(
              glyph: LucideGlyph.volume2,
              title: 'Sound',
              description: 'Hear a clip, guess the song',
              gradient: AppGradients.violet,
              delay: const Duration(milliseconds: 100),
              onTap: () {
                game.setQuizType(QuizType.sound);
                game.setPhase(GamePhase.difficultySelect);
              },
            ),
            SelectionCard(
              glyph: LucideGlyph.bookOpen,
              title: 'Lyrics',
              description: 'Read lyrics, test your knowledge',
              gradient: AppGradients.pink,
              delay: const Duration(milliseconds: 200),
              onTap: () {
                game.setQuizType(QuizType.lyrics);
                game.setPhase(GamePhase.lyricsModeSelect);
              },
            ),
          ],
        ),
      ],
    );
  }
}
