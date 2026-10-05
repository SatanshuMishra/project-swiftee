import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/state/toast_controller.dart';
import 'package:swiftie_quiz/ui/overlays/toast_host.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

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
              const ToastHost(),
            ],
          ),
        ),
      ),
    );

    void show(String message) =>
        container.read(toastControllerProvider.notifier).show(message);

    Future<void> letToastExpire(WidgetTester tester) =>
        tester.pump(ToastController.displayDuration);

    Finder toastBox() => find.descendant(
      of: find.byType(ToastHost),
      matching: find.byType(Container),
    );

    testWidgets('shows nothing without a message', (tester) async {
      await pumpHost(tester);

      expect(tester.getSize(find.byType(ToastHost)), Size.zero);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows the message, then removes it after 5 s', (tester) async {
      await pumpHost(tester);
      show(welcomeBack);
      await tester.pump();

      expect(find.text(welcomeBack), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 4999));
      expect(find.text(welcomeBack), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text(welcomeBack), findsNothing);
      expect(container.read(toastControllerProvider), isNull);
    });

    testWidgets('sits 24 px above the bottom, centred, in emerald', (
      tester,
    ) async {
      await pumpHost(tester);
      show('Saved');
      await tester.pump();

      final rect = tester.getRect(toastBox());
      expect(rect.bottom, surface.height - ToastHost.bottomInset);
      expect(rect.center.dx, surface.width / 2);

      final decoration =
          tester.widget<Container>(toastBox()).decoration! as BoxDecoration;
      expect(decoration.color, AppPalette.emerald600);
      expect(decoration.color, const Color(0xFF009966));
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(6)),
      );
      expect(decoration.boxShadow, AppShadows.lg);
      expect(
        tester.widget<Container>(toastBox()).padding,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      );

      final style = tester.widget<Text>(find.text('Saved')).style!;
      expect(style.fontSize, 14);
      expect(style.height, 20 / 14);
      expect(style.color, AppPalette.white);

      await letToastExpire(tester);
    });

    testWidgets('wraps within half the window width', (tester) async {
      await pumpHost(tester);
      show(welcomeBack);
      await tester.pump();

      final rect = tester.getRect(toastBox());
      expect(rect.width, lessThanOrEqualTo(surface.width / 2));
      expect(rect.center.dx, surface.width / 2);
      expect(rect.height, greaterThan(20 + 16));

      await letToastExpire(tester);
    });

    testWidgets('is announced as a status', (tester) async {
      await pumpHost(tester);
      show(welcomeBack);
      await tester.pump();

      expect(
        find.semantics.byPredicate((node) {
          final data = node.getSemanticsData();
          return data.role == SemanticsRole.status && data.label == welcomeBack;
        }),
        findsOne,
      );

      await letToastExpire(tester);
    });

    testWidgets('a click dismisses it at once', (tester) async {
      await pumpHost(tester);
      show(welcomeBack);
      await tester.pump();

      await tester.tap(find.text(welcomeBack));
      await tester.pump();

      expect(find.text(welcomeBack), findsNothing);
      expect(container.read(toastControllerProvider), isNull);
      expect(screenTaps, 0);
    });

    testWidgets('clicks outside the toast reach the screen beneath', (
      tester,
    ) async {
      await pumpHost(tester);
      show(welcomeBack);
      await tester.pump();

      await tester.tapAt(const Offset(20, 20));
      await tester.tapAt(Offset(surface.width / 2, surface.height - 4));

      expect(screenTaps, 2);
      expect(find.text(welcomeBack), findsOneWidget);

      await letToastExpire(tester);
    });
  });
}
