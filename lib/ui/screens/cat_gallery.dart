import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/achievements.dart';
import 'package:swiftie_quiz/domain/models/achievement_def.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/screens/main_menu.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';

class CatGallery extends ConsumerWidget {
  const CatGallery({super.key});

  static const double padding = 32;
  static const double gap = 32;
  static const double gridGap = 24;
  static const double progressHeight = 8;
  static const List<GradientPair> tileGradients = [
    AppGradients.violet,
    AppGradients.pink,
    AppGradients.orange,
    AppGradients.cyan,
    AppGradients.green,
  ];

  static int unlockedCount(Map<String, AchievementState> achievements) =>
      achievementDefs
          .where((def) => achievements[def.id]?.unlocked ?? false)
          .length;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.read(gameControllerProvider.notifier);
    final achievements = ref.watch(
      gameControllerProvider.select((state) => state.progress.achievements),
    );
    final unlocked = unlockedCount(achievements);
    final total = achievementDefs.length;
    return ScreenScaffold(
      body: Padding(
        padding: const EdgeInsets.all(padding),
        child: Column(
          children: spacedVertically([
            BackHeader(
              maxWidth: TailwindContainers.xl5,
              onBack: () => game.setPhase(GamePhase.menu),
            ),
            MaxWidthBox(
              maxWidth: TailwindContainers.xl5,
              child: ScreenHeading(
                title: 'Cat Gallery',
                subtitle: '$unlocked of $total achievements unlocked',
                footer: _GalleryProgress(
                  fraction: total > 0 ? unlocked / total : 0,
                ),
              ),
            ),
            ResponsiveGrid(
              columns: const GridColumns(2, sm: 3, md: 5),
              gap: gridGap,
              maxWidth: TailwindContainers.xl5,
              children: [
                for (final (index, def) in achievementDefs.indexed)
                  _AchievementTile(
                    def: def,
                    state: achievements[def.id],
                    gradient: tileGradients[index % tileGradients.length],
                    delay: Duration(milliseconds: math.min(index * 50, 500)),
                  ),
              ],
            ),
          ], gap),
        ),
      ),
    );
  }
}

class _GalleryProgress extends StatelessWidget {
  const _GalleryProgress({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final radius = BorderRadius.circular(CatGallery.progressHeight / 2);
    return MaxWidthBox(
      maxWidth: TailwindContainers.xs,
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: tokens.muted,
          child: SizedBox(
            height: CatGallery.progressHeight,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fraction),
              duration: AppMotion.cssTransitionDuration,
              curve: AppMotion.cssTransitionCurve,
              builder: (context, value, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: AppGradients.play.tailwind(
                      CssGradientDirection.toRight,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.def,
    required this.state,
    required this.gradient,
    required this.delay,
  });

  static const Offset entranceOffset = Offset(0, 20);
  static const double hoverScale = 1.05;
  static const double tapScale = 0.97;
  static const double radius = AppRadii.xl;
  static const double padding = 24;
  static const double gap = 8;
  static const double accentHeight = 4;
  static const double badgeSize = 64;
  static const double lockSize = 24;
  static const String unlockedEmoji = '🐱';
  static const String lockedName = '???';
  static const String lockedDescription = 'Keep playing to unlock.';

  final AchievementDef def;
  final AchievementState? state;
  final GradientPair gradient;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final unlocked = state?.unlocked ?? false;
    return Entrance(
      fromOffset: entranceOffset,
      delay: delay,
      hoverScale: unlocked ? hoverScale : null,
      tapScale: unlocked ? tapScale : null,
      child: unlocked
          ? HoverTransition(
              builder: (context, hover) =>
                  _tileSurface(context, unlocked: true, hover: hover),
            )
          : _tileSurface(context, unlocked: false, hover: 0),
    );
  }

  Widget _tileSurface(
    BuildContext context, {
    required bool unlocked,
    required double hover,
  }) {
    final tokens = AppTokens.of(context);
    final unlockedAt = state?.unlockedAt;
    final mutedStyle = AppText.xs.copyWith(color: tokens.mutedForeground);
    return Container(
      decoration: BoxDecoration(
        color: unlocked ? tokens.card : tokens.muted.slashOpacity(50),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: unlocked ? tokens.border : tokens.border.slashOpacity(50),
        ),
        boxShadow: unlocked
            ? BoxShadow.lerpList(
                AppShadows.hidden(AppShadows.lg),
                AppShadows.lg,
                hover,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.all(padding),
              child: Column(
                spacing: gap,
                children: [
                  SizedBox.square(
                    dimension: badgeSize,
                    child: Center(
                      child: unlocked
                          ? Text(
                              unlockedEmoji,
                              style: AppText.xl3.copyWith(
                                color: tokens.foreground,
                              ),
                            )
                          : AppIcon(
                              LucideGlyph.lock,
                              size: lockSize,
                              color: tokens.mutedForeground,
                            ),
                    ),
                  ),
                  Text(
                    unlocked ? def.name : lockedName,
                    textAlign: TextAlign.center,
                    style: AppText.sm.copyWith(
                      fontWeight: FontWeight.w500,
                      color: tokens.foreground,
                    ),
                  ),
                  Text(
                    unlocked ? def.description : lockedDescription,
                    textAlign: TextAlign.center,
                    style: mutedStyle,
                  ),
                  if (unlocked && unlockedAt != null && unlockedAt.isNotEmpty)
                    Text(
                      LocalDates.isoDate(
                        unlockedAt,
                        LocalDates.systemLocale(context),
                      ),
                      style: mutedStyle,
                    ),
                ],
              ),
            ),
            if (unlocked)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: accentHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: gradient.linear(
                      CssGradientDirection.toRight,
                      ColorInterpolation.srgb,
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
