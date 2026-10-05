import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/screens/cat_gallery.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';

const String firstMeowUnlockedAt = '2026-03-04T10:00:00.000Z';
const String speedDemonUnlockedAt = '2026-09-28T23:30:00.000Z';

Future<void> pumpGallery(
  WidgetTester tester, {
  Map<String, AchievementState> achievements = const {},
  Locale locale = const Locale('en', 'US'),
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localeTestValue = locale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  final container = ProviderContainer.test();
  final game = container.read(gameControllerProvider.notifier);
  game.setProgress(defaultProgress.copyWith(achievements: achievements));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.dark, home: const CatGallery()),
    ),
  );
  await tester.pumpAndSettle();
}

const Map<String, AchievementState> twoUnlocked = {
  'first_meow': AchievementState(
    unlocked: true,
    unlockedAt: firstMeowUnlockedAt,
  ),
  'speed_demon': AchievementState(
    unlocked: true,
    unlockedAt: speedDemonUnlockedAt,
  ),
  'album_explorer': AchievementState(unlocked: false, unlockedAt: null),
};

Finder get progressFill => find.descendant(
  of: find.byType(FractionallySizedBox),
  matching: find.byType(DecoratedBox),
);

Finder get lockIcons => find.byWidgetPredicate(
  (widget) => widget is AppIcon && widget.glyph == LucideGlyph.lock,
);

void main() {
  group('cat gallery parity', () {
    testWidgets('counts unlocked achievements out of 15', (tester) async {
      await pumpGallery(tester, achievements: twoUnlocked);

      expect(find.text('Cat Gallery'), findsOneWidget);
      expect(find.text('2 of 15 achievements unlocked'), findsOneWidget);
    });

    testWidgets('unlocked tiles show the cat, name and description', (
      tester,
    ) async {
      await pumpGallery(tester, achievements: twoUnlocked);

      expect(find.text('🐱'), findsNWidgets(2));
      expect(find.text('First Meow'), findsOneWidget);
      expect(find.text('Get 1 correct answer'), findsOneWidget);
      expect(find.text('Speed Demon'), findsOneWidget);
      expect(find.text('Answer correctly within 3 seconds'), findsOneWidget);
    });

    testWidgets('locked tiles hide the achievement behind a lock', (
      tester,
    ) async {
      await pumpGallery(tester, achievements: twoUnlocked);

      expect(find.text('???'), findsNWidgets(13));
      expect(find.text('Keep playing to unlock.'), findsNWidgets(13));
      expect(lockIcons, findsNWidgets(13));
      expect(find.text('Album Explorer'), findsNothing);
      expect(find.text('Play songs from 5 different albums'), findsNothing);
    });

    testWidgets('unlocked tiles show the unlock date in the short date', (
      tester,
    ) async {
      await pumpGallery(tester, achievements: twoUnlocked);

      for (final iso in [firstMeowUnlockedAt, speedDemonUnlockedAt]) {
        final local = DateTime.parse(iso).toLocal();
        expect(
          find.text('${local.month}/${local.day}/${local.year}'),
          findsOneWidget,
          reason: iso,
        );
      }
    });

    testWidgets('unlock dates follow the system locale', (tester) async {
      await pumpGallery(
        tester,
        achievements: twoUnlocked,
        locale: const Locale('de', 'DE'),
      );

      final local = DateTime.parse(firstMeowUnlockedAt).toLocal();
      expect(
        find.text('${local.day}.${local.month}.${local.year}'),
        findsOneWidget,
      );
    });

    testWidgets('the progress bar fills to the unlocked share', (tester) async {
      await pumpGallery(tester, achievements: twoUnlocked);

      final track = tester.getSize(
        find.ancestor(
          of: find.byType(FractionallySizedBox),
          matching: find.byType(ClipRRect),
        ),
      );
      final fill = tester.getSize(progressFill);
      expect(track, const Size(320, 8));
      expect(fill.width, closeTo(320 * 2 / 15, 0.001));
    });

    testWidgets('with nothing unlocked every tile is locked', (tester) async {
      await pumpGallery(tester);

      expect(find.text('0 of 15 achievements unlocked'), findsOneWidget);
      expect(find.text('🐱'), findsNothing);
      expect(lockIcons, findsNWidgets(15));
      expect(tester.getSize(progressFill).width, 0);
    });

    testWidgets('an unlocked state without a date shows no date', (
      tester,
    ) async {
      await pumpGallery(
        tester,
        achievements: const {
          'first_meow': AchievementState(unlocked: true, unlockedAt: null),
        },
      );

      expect(find.text('1 of 15 achievements unlocked'), findsOneWidget);
      expect(find.textContaining(RegExp(r'\d+/\d+/\d+')), findsNothing);
    });
  });
}
