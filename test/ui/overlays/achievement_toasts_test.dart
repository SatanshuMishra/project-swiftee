import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/overlays/achievement_toasts.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

const Size surface = Size(800, 600);
const String firstMeow = 'first_meow';
const String warmedUp = 'getting_warmed_up';
const String streak = 'purrfect_streak';

void main() {
  group('achievement toasts', () {
    late ProviderContainer container;
    late int screenTaps;

    setUp(() {
      container = ProviderContainer.test();
      screenTaps = 0;
    });

    Future<void> pumpHost(WidgetTester tester) => tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => screenTaps++,
                ),
              ),
              const AchievementToasts(),
            ],
          ),
        ),
      ),
    );

    void unlock(String id) =>
        container.read(gameControllerProvider.notifier).addToast(id);

    List<String> pending() =>
        container.read(gameControllerProvider).pendingToasts;

    Finder toastFor(String name) => find.ancestor(
      of: find.text(name),
      matching: find.byWidgetPredicate(
        (widget) => widget is Container && widget.decoration is BoxDecoration,
      ),
    );

    testWidgets('renders nothing without pending toasts', (tester) async {
      await pumpHost(tester);

      expect(tester.getSize(find.byType(AchievementToasts)), Size.zero);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows the cat, the name and the description', (tester) async {
      await pumpHost(tester);
      unlock(firstMeow);
      await tester.pump();

      expect(find.text('\u{1F431}'), findsOneWidget);
      expect(find.text('First Meow'), findsOneWidget);
      expect(find.text('Get 1 correct answer'), findsOneWidget);

      final name = tester.widget<Text>(find.text('First Meow')).style!;
      expect(name.fontSize, 14);
      expect(name.fontWeight, FontWeight.w700);
      expect(name.color, AppTokens.dark.foreground);
      final description = tester
          .widget<Text>(find.text('Get 1 correct answer'))
          .style!;
      expect(description.fontSize, 12);
      expect(description.color, AppTokens.dark.mutedForeground);
      expect(tester.widget<Text>(find.text('\u{1F431}')).style!.fontSize, 30);

      final decoration =
          tester.widget<Container>(toastFor('First Meow')).decoration!
              as BoxDecoration;
      expect(decoration.color, AppTokens.dark.card);
      expect(
        decoration.border,
        Border.all(color: AppTokens.dark.primary.slashOpacity(50)),
      );
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(12)),
      );
      expect(decoration.boxShadow, AppShadows.lg);

      await tester.pump(AchievementToasts.displayDuration);
    });

    testWidgets('stacks toasts 16 px from the top right, newest below', (
      tester,
    ) async {
      await pumpHost(tester);
      unlock(firstMeow);
      unlock(warmedUp);
      await tester.pump();
      await tester.pump(AchievementToasts.slideDuration);

      final first = tester.getRect(toastFor('First Meow'));
      final second = tester.getRect(toastFor('Getting Warmed Up'));
      expect(first.top, AchievementToasts.inset);
      expect(first.right, surface.width - AchievementToasts.inset);
      expect(second.top, first.bottom + AchievementToasts.gap);
      expect(second.right, first.right);
      expect(second.width, first.width);

      await tester.pump(AchievementToasts.displayDuration);
    });

    testWidgets('slides in from the right over 300 ms with ease-out', (
      tester,
    ) async {
      await pumpHost(tester);
      unlock(firstMeow);
      await tester.pump();

      final width = tester.getSize(toastFor('First Meow')).width;
      final restingLeft = surface.width - AchievementToasts.inset - width;
      final opacity = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: toastFor('First Meow'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );

      expect(tester.getTopLeft(toastFor('First Meow')).dx, restingLeft + width);
      expect(opacity.opacity.value, 0);

      await tester.pump(const Duration(milliseconds: 150));
      final halfway = Curves.easeOut.transform(0.5);
      expect(
        tester.getTopLeft(toastFor('First Meow')).dx,
        moreOrLessEquals(restingLeft + width * (1 - halfway)),
      );
      expect(opacity.opacity.value, moreOrLessEquals(halfway));

      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getTopLeft(toastFor('First Meow')).dx, restingLeft);
      expect(opacity.opacity.value, 1);

      await tester.pump(AchievementToasts.displayDuration);
    });

    testWidgets(
      'each toast dismisses 4 s after it appeared, regardless of new toasts',
      (tester) async {
        await pumpHost(tester);
        unlock(firstMeow);
        await tester.pump();

        await tester.pump(const Duration(seconds: 2));
        unlock(warmedUp);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        unlock(streak);
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 998));
        expect(find.text('First Meow'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 2));
        expect(find.text('First Meow'), findsNothing);
        expect(find.text('Getting Warmed Up'), findsOneWidget);
        expect(pending(), [warmedUp, streak]);

        await tester.pump(const Duration(seconds: 2));
        expect(find.text('Getting Warmed Up'), findsNothing);
        expect(find.text('Purrfect Streak'), findsOneWidget);
        expect(pending(), [streak]);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Purrfect Streak'), findsNothing);
        expect(pending(), isEmpty);
      },
    );

    testWidgets('the close button labelled Dismiss removes only its toast', (
      tester,
    ) async {
      await pumpHost(tester);
      unlock(firstMeow);
      unlock(warmedUp);
      await tester.pump();
      await tester.pump(AchievementToasts.slideDuration);

      expect(
        find.semantics.byPredicate((node) {
          final data = node.getSemanticsData();
          return data.flagsCollection.isButton && data.label == 'Dismiss';
        }),
        findsExactly(2),
      );

      await tester.tap(find.bySemanticsLabel('Dismiss').first);
      await tester.pump();

      expect(find.text('First Meow'), findsNothing);
      expect(find.text('Getting Warmed Up'), findsOneWidget);
      expect(pending(), [warmedUp]);
      expect(screenTaps, 0);

      await tester.pump(AchievementToasts.displayDuration);
      expect(pending(), isEmpty);
    });

    testWidgets('the close button shows the cross in muted text', (
      tester,
    ) async {
      await pumpHost(tester);
      unlock(firstMeow);
      await tester.pump();

      final cross = tester.widget<Text>(find.text('✕')).style!;
      expect(cross.fontSize, 14);
      expect(cross.color, AppTokens.dark.mutedForeground);
      expect(
        tester.getTopLeft(find.text('✕')).dx -
            tester.getTopRight(find.text('Get 1 correct answer')).dx,
        12 + 8,
      );

      await tester.pump(AchievementToasts.displayDuration);
    });

    testWidgets('clicks around the toasts reach the screen beneath', (
      tester,
    ) async {
      await pumpHost(tester);
      unlock(firstMeow);
      unlock(warmedUp);
      await tester.pump();
      await tester.pump(AchievementToasts.slideDuration);

      final first = tester.getRect(toastFor('First Meow'));
      await tester.tapAt(Offset(first.center.dx, first.bottom + 4));
      await tester.tapAt(const Offset(20, 20));

      expect(screenTaps, 2);

      await tester.tap(find.text('First Meow'));
      expect(screenTaps, 2);

      await tester.pump(AchievementToasts.displayDuration);
    });

    testWidgets('an unknown id renders nothing and still expires', (
      tester,
    ) async {
      await pumpHost(tester);
      unlock('not_an_achievement');
      await tester.pump();

      expect(find.byType(Text), findsNothing);

      await tester.pump(AchievementToasts.displayDuration);
      expect(pending(), isEmpty);
    });
  });
}
