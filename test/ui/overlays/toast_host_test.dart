import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/toast_controller.dart';
import 'package:swiftie_quiz/ui/overlays/achievement_toasts.dart';
import 'package:swiftie_quiz/ui/overlays/toast_host.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

const String welcomeBack =
    'Welcome back! Your progress has been preserved. '
    '(Migrated from save format v2.)';
const Size surface = Size(800, 600);

void main() {
  group('toast host', () {
    late ProviderContainer container;
    late int screenTaps;

    setUp(() {
      container = ProviderContainer.test();
      screenTaps = 0;
    });

    Future<void> pumpHost(
      WidgetTester tester, {
      ThemeData? theme,
      bool reducedMotion = false,
      bool withAchievements = false,
    }) => tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? AppTheme.dark,
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reducedMotion),
            child: app!,
          ),
          home: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => screenTaps++,
                ),
              ),
              if (withAchievements) const AchievementToasts(),
              const ToastHost(),
            ],
          ),
        ),
      ),
    );

    void show(String message) =>
        container.read(toastControllerProvider.notifier).show(message);

    String? message() => container.read(toastControllerProvider);

    Future<void> letToastExpire(WidgetTester tester) async {
      await tester.pump(ToastController.displayDuration);
      await tester.pump(ToastMotion.fade);
    }

    Finder cardOf(String text) =>
        find.ancestor(of: find.text(text), matching: find.byType(ToastCard));

    Finder boxOf(String text) => find.descendant(
      of: cardOf(text),
      matching: find.byWidgetPredicate(
        (widget) => widget is Container && widget.decoration is BoxDecoration,
      ),
    );

    testWidgets('shows nothing without a message', (tester) async {
      await pumpHost(tester);

      expect(tester.getSize(find.byType(ToastHost)), Size.zero);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows the message, then fades it out after 5 s', (
      tester,
    ) async {
      await pumpHost(tester);
      show(welcomeBack);
      await tester.pump();

      expect(find.text(welcomeBack), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 4999));
      expect(find.text(welcomeBack), findsOneWidget);
      expect(message(), welcomeBack);

      await tester.pump(const Duration(milliseconds: 1));
      expect(message(), isNull);
      expect(find.text(welcomeBack), findsOneWidget);

      await tester.pump(ToastMotion.fade - const Duration(milliseconds: 1));
      expect(find.text(welcomeBack), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text(welcomeBack), findsNothing);
      expect(tester.getSize(find.byType(ToastHost)), Size.zero);
    });

    for (final (name, theme, tokens) in [
      ('dark', AppTheme.dark, AppTokens.dark),
      ('light', AppTheme.light, AppTokens.light),
    ]) {
      testWidgets(
        'the $name message sits 16 px from the top right as the card title',
        (tester) async {
          await pumpHost(tester, theme: theme);
          show('Backup restored');
          await tester.pump();
          await tester.pump(AppMotion.toastSlide);

          final rect = tester.getRect(boxOf('Backup restored'));
          expect(rect.topRight, Offset(surface.width - 16, 16));
          expect(rect.width, 300);

          final box = tester.widget<Container>(boxOf('Backup restored'));
          expect(
            box.padding,
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          );
          final decoration = box.decoration! as BoxDecoration;
          expect(decoration.color, tokens.panel);
          expect(decoration.border, Border.all(color: tokens.line2));
          expect(
            decoration.borderRadius,
            const BorderRadius.all(Radius.circular(14)),
          );
          expect(decoration.boxShadow, [
            CssBoxShadow(
              color: tokens.shadow,
              offset: const Offset(0, 12),
              blur: 32,
            ),
          ]);

          final title = tester.widget<Text>(find.text('Backup restored'));
          expect(title.style!.fontFamily, AppType.serifFamily);
          expect(title.style!.fontSize, 20);
          expect(title.style!.height, 24 / 20);
          expect(title.style!.color, tokens.fg);
          expect(
            find.descendant(
              of: cardOf('Backup restored'),
              matching: find.byType(Text),
            ),
            findsNWidgets(2),
          );
          expect(find.text('✕'), findsOneWidget);
          expect(find.byType(Image), findsNothing);

          await letToastExpire(tester);
        },
      );
    }

    testWidgets('a toast card shows the kicker, title and sub when given', (
      tester,
    ) async {
      var dismissed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: ToastSlot.width,
              child: ToastCard(
                kicker: 'Progress',
                title: 'Progress reset',
                sub: 'Your shelf is empty, for now.',
                onDismiss: () => dismissed++,
              ),
            ),
          ),
        ),
      );

      final kicker = tester.widget<Text>(find.text('Progress'));
      expect(kicker.style!.fontSize, 11);
      expect(kicker.style!.height, 14 / 11);
      expect(kicker.style!.fontWeight, FontWeight.w600);
      expect(kicker.style!.color, AppTokens.light.coralT);

      final sub = tester.widget<Text>(
        find.text('Your shelf is empty, for now.'),
      );
      expect(sub.style!.fontSize, 12);
      expect(sub.style!.height, 16 / 12);
      expect(sub.style!.color, AppTokens.light.mut);
      expect(sub.maxLines, 1);
      expect(sub.overflow, TextOverflow.ellipsis);

      final kickerRect = tester.getRect(find.text('Progress'));
      final titleRect = tester.getRect(find.text('Progress reset'));
      final subRect = tester.getRect(
        find.text('Your shelf is empty, for now.'),
      );
      expect(kickerRect.topLeft, const Offset(1 + 14, 1 + 12));
      expect(titleRect.top, kickerRect.bottom);
      expect(subRect.top, titleRect.bottom);

      await tester.tap(find.bySemanticsLabel(ToastCloseButton.label));
      expect(dismissed, 1);
    });

    testWidgets('a long message wraps inside the card', (tester) async {
      await pumpHost(tester);
      show(welcomeBack);
      await tester.pump();
      await tester.pump(AppMotion.toastSlide);

      final card = tester.getRect(boxOf(welcomeBack));
      final text = tester.getRect(find.text(welcomeBack));
      expect(card.width, 300);
      expect(text.height, greaterThan(24));
      expect(text.right, lessThanOrEqualTo(card.right - 1 - 14 - 24 - 12));
      expect(card.bottom, text.bottom + 12 + 1);

      await letToastExpire(tester);
    });

    testWidgets('is announced as a status', (tester) async {
      await pumpHost(tester);
      show(welcomeBack);
      await tester.pump();
      await tester.pump(AppMotion.toastSlide);

      expect(
        find.semantics.byPredicate((node) {
          final data = node.getSemanticsData();
          return data.role == SemanticsRole.status && data.label == welcomeBack;
        }),
        findsOne,
      );

      await letToastExpire(tester);
    });

    testWidgets('a click on the card dismisses it and it fades out', (
      tester,
    ) async {
      await pumpHost(tester);
      show(welcomeBack);
      await tester.pump();
      await tester.pump(AppMotion.toastSlide);

      await tester.tap(find.text(welcomeBack));
      await tester.pump();

      expect(message(), isNull);
      expect(screenTaps, 0);

      await tester.pump(ToastMotion.fade);
      expect(find.text(welcomeBack), findsNothing);
    });

    testWidgets('the close button dismisses it', (tester) async {
      await pumpHost(tester);
      show('Progress reset');
      await tester.pump();
      await tester.pump(AppMotion.toastSlide);

      final close = tester.getRect(
        find.bySemanticsLabel(ToastCloseButton.label),
      );
      expect(close.size, const Size.square(24));

      await tester.tap(find.bySemanticsLabel(ToastCloseButton.label));
      await tester.pump();
      expect(message(), isNull);
      expect(screenTaps, 0);

      await tester.pump(ToastMotion.fade);
      expect(find.text('Progress reset'), findsNothing);
    });

    testWidgets('clicks outside the toast reach the screen beneath', (
      tester,
    ) async {
      await pumpHost(tester);
      show(welcomeBack);
      await tester.pump();
      await tester.pump(AppMotion.toastSlide);

      final card = tester.getRect(boxOf(welcomeBack));
      await tester.tapAt(const Offset(20, 20));
      await tester.tapAt(Offset(card.left - 4, card.center.dy));
      await tester.tapAt(Offset(card.center.dx, card.bottom + 4));
      await tester.tapAt(Offset(surface.width / 2, surface.height - 4));

      expect(screenTaps, 4);
      expect(find.text(welcomeBack), findsOneWidget);

      await letToastExpire(tester);
    });

    testWidgets('a new message replaces the one on screen in place', (
      tester,
    ) async {
      await pumpHost(tester);
      show('Backup restored');
      await tester.pump();
      await tester.pump(AppMotion.toastSlide);

      show('Progress reset');
      await tester.pump();

      expect(find.text('Backup restored'), findsNothing);
      expect(find.text('Progress reset'), findsOneWidget);
      expect(tester.getRect(boxOf('Progress reset')).top, 16);

      await letToastExpire(tester);
    });

    testWidgets('it shares the top-right column with achievement toasts', (
      tester,
    ) async {
      await pumpHost(tester, withAchievements: true);
      show('Backup restored');
      await tester.pump();
      container.read(gameControllerProvider.notifier).addToast('first_meow');
      await tester.pump();
      await tester.pump(AppMotion.toastSlide);

      expect(tester.getRect(boxOf('Backup restored')).top, 16);
      expect(
        tester.getRect(boxOf('First Meow')).top,
        16 + AppMotion.toastSpacing,
      );

      container.read(toastControllerProvider.notifier).dismiss();
      await tester.pump();
      expect(
        tester.getRect(boxOf('First Meow')).top,
        16 + AppMotion.toastSpacing,
      );

      await tester.pump(ToastMotion.fade);
      expect(find.text('Backup restored'), findsNothing);
      expect(tester.getRect(boxOf('First Meow')).top, 16);

      show('Progress reset');
      await tester.pump();
      expect(
        tester.getRect(boxOf('Progress reset')).top,
        16 + AppMotion.toastSpacing,
      );

      await tester.pump(AppMotion.toastStay);
      await tester.pump(ToastMotion.fade);
      expect(find.text('First Meow'), findsNothing);
      expect(tester.getRect(boxOf('Progress reset')).top, 16);

      await letToastExpire(tester);
      expect(container.read(toastStackProvider), isEmpty);
    });

    testWidgets('removing the hosts frees their slots in the column', (
      tester,
    ) async {
      await pumpHost(tester, withAchievements: true);
      show('Backup restored');
      container.read(gameControllerProvider.notifier).addToast('first_meow');
      await tester.pump();
      expect(container.read(toastStackProvider), hasLength(2));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox.shrink(),
        ),
      );

      expect(container.read(toastStackProvider), isEmpty);
      container.read(toastControllerProvider.notifier).dismiss();
    });

    testWidgets('with reduced motion it appears and leaves at once', (
      tester,
    ) async {
      await pumpHost(tester, reducedMotion: true);
      show('Backup restored');
      await tester.pump();

      expect(
        tester.getRect(boxOf('Backup restored')).topLeft,
        Offset(surface.width - 16 - 300, 16),
      );
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: boxOf('Backup restored'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 1);

      await tester.tap(find.text('Backup restored'));
      await tester.pump();
      expect(find.text('Backup restored'), findsNothing);
    });
  });
}
