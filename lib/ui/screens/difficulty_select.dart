import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/screens/main_menu.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';
import 'package:swiftie_quiz/ui/widgets/selection_card.dart';

@immutable
class DifficultyOption {
  const DifficultyOption({
    required this.difficulty,
    required this.label,
    required this.description,
    required this.glyph,
    required this.gradient,
    required this.features,
  });

  final Difficulty difficulty;
  final String label;
  final String description;
  final LucideGlyph glyph;
  final GradientPair gradient;
  final List<String> features;
}

class DifficultySelect extends ConsumerWidget {
  const DifficultySelect({super.key});

  static const double gridGap = 24;
  static const Duration firstCardDelay = Duration(milliseconds: 100);
  static const Duration cardStagger = Duration(milliseconds: 100);

  static List<DifficultyOption> optionsFor({
    required QuizType? quizType,
    required LyricsMode? lyricsMode,
    required int mediumTimer,
    required int hardTimer,
  }) {
    final mediumTimerFeature = '$mediumTimer-second timer';
    final hardTimerFeature = '$hardTimer-second timer';
    final (easy, medium, hard) = switch ((quizType, lyricsMode)) {
      (QuizType.lyrics, LyricsMode.nameThatSong) => (
        ['4 lyric lines from chorus', 'Album hint', 'Multiple choice'],
        ['3 lyric lines', 'Multiple choice', mediumTimerFeature],
        ['2 lyric lines, no chorus', 'Type your answer', hardTimerFeature],
      ),
      (QuizType.lyrics, LyricsMode.lyricsOrLie) => (
        [
          '3 lyric lines shown',
          'Album cover shown',
          'Fakes from different eras',
          'No time limit',
        ],
        [
          '2 lyric lines shown',
          'No hints',
          'Fakes from similar albums',
          mediumTimerFeature,
        ],
        [
          '1 lyric line shown',
          'No hints',
          'Fakes from same album',
          hardTimerFeature,
        ],
      ),
      _ => (
        ['Multiple choice', 'Album hint shown', 'No time limit'],
        ['Multiple choice', 'No album hint', mediumTimerFeature],
        ['Type your answer', 'No hints', hardTimerFeature],
      ),
    };
    return List.unmodifiable([
      DifficultyOption(
        difficulty: Difficulty.easy,
        label: 'Easy',
        description: 'Quick warm-up round',
        glyph: LucideGlyph.zap,
        gradient: AppGradients.easy,
        features: List.unmodifiable(easy),
      ),
      DifficultyOption(
        difficulty: Difficulty.medium,
        label: 'Medium',
        description: 'The real thing',
        glyph: LucideGlyph.flame,
        gradient: AppGradients.medium,
        features: List.unmodifiable(medium),
      ),
      DifficultyOption(
        difficulty: Difficulty.hard,
        label: 'Hard',
        description: 'A challenge worthy of a true Swiftie',
        glyph: LucideGlyph.skull,
        gradient: AppGradients.hard,
        features: List.unmodifiable(hard),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.read(gameControllerProvider.notifier);
    final quizType = ref.watch(
      gameControllerProvider.select((state) => state.quizType),
    );
    final lyricsMode = ref.watch(
      gameControllerProvider.select((state) => state.lyricsMode),
    );
    final settings = ref.watch(
      gameControllerProvider.select((state) => state.progress.settings),
    );
    final options = optionsFor(
      quizType: quizType,
      lyricsMode: lyricsMode,
      mediumTimer: settings.mediumTimer,
      hardTimer: settings.hardTimer,
    );
    return CenteredScreen(
      onBack: () => game.setPhase(switch (quizType) {
        QuizType.lyrics => GamePhase.lyricsModeSelect,
        QuizType.sound => GamePhase.quizTypeSelect,
        null => GamePhase.menu,
      }),
      children: [
        const ScreenHeading(
          title: 'Choose Difficulty',
          subtitle: 'Select your challenge level',
        ),
        ResponsiveGrid(
          columns: const GridColumns(1, md: 3),
          gap: gridGap,
          maxWidth: TailwindContainers.xl4,
          children: [
            for (final (index, option) in options.indexed)
              SelectionCard(
                glyph: option.glyph,
                title: option.label,
                description: option.description,
                gradient: option.gradient,
                layout: SelectionCardLayout.centered,
                delay: firstCardDelay + cardStagger * index,
                footer: _FeatureList(option: option),
                onTap: () {
                  game.setDifficulty(option.difficulty);
                  game.setPhase(
                    quizType == QuizType.lyrics
                        ? GamePhase.lyricsLoading
                        : GamePhase.playing,
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.option});

  static const double listOffset = 8;
  static const double itemGap = 4;
  static const double dotSize = 6;
  static const double dotGap = 8;

  final DifficultyOption option;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final style = AppText.sm.copyWith(color: tokens.mutedForeground);
    return Padding(
      padding: const EdgeInsets.only(top: listOffset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: itemGap,
        children: [
          for (final feature in option.features)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: dotGap,
              children: [
                SizedBox.square(
                  dimension: dotSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: option.gradient.from,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Flexible(child: Text(feature, style: style)),
              ],
            ),
        ],
      ),
    );
  }
}
