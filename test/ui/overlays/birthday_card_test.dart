import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/overlays/birthday_card.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';

Widget harness({
  required bool isOpen,
  required VoidCallback onClose,
  ThemeData? theme,
}) => MaterialApp(
  theme: theme ?? AppTheme.dark,
  home: BirthdayCard(isOpen: isOpen, onClose: onClose),
);

Future<void> pumpCard(
  WidgetTester tester, {
  required bool isOpen,
  VoidCallback? onClose,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    harness(isOpen: isOpen, onClose: onClose ?? () {}, theme: theme),
  );
  await tester.pumpAndSettle();
}

Finder get buttons => find.descendant(
  of: find.byType(BirthdayCard),
  matching: find.byWidgetPredicate(
    (widget) => widget is Semantics && (widget.properties.button ?? false),
  ),
);

Color? textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  group('birthday card parity', () {
    testWidgets('renders nothing when isOpen is false', (tester) async {
      await pumpCard(tester, isOpen: false);

      expect(find.text('Happy Birthday!'), findsNothing);
    });

    testWidgets('renders the birthday message when isOpen is true', (
      tester,
    ) async {
      await pumpCard(tester, isOpen: true);

      expect(find.text('Happy Birthday!'), findsOneWidget);
    });

    testWidgets('renders the signature text', (tester) async {
      await pumpCard(tester, isOpen: true);

      expect(find.textContaining('Your Best Friend'), findsOneWidget);
      expect(find.textContaining('Satanshu'), findsOneWidget);
    });

    testWidgets('renders the addressee', (tester) async {
      await pumpCard(tester, isOpen: true);

      expect(find.text('Dear Ana,'), findsOneWidget);
    });

    testWidgets('renders the header with cake icons', (tester) async {
      await pumpCard(tester, isOpen: true);

      expect(find.text('Happy Birthday!'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is AppIcon && widget.glyph == LucideGlyph.cake,
        ),
        findsNWidgets(3),
      );
    });

    testWidgets('calls onClose when close button is clicked', (tester) async {
      var closes = 0;
      await pumpCard(tester, isOpen: true, onClose: () => closes++);

      expect(buttons, findsOneWidget);
      await tester.tap(buttons);

      expect(closes, 1);
    });

    testWidgets('does not call onClose when card body is clicked', (
      tester,
    ) async {
      var closes = 0;
      await pumpCard(tester, isOpen: true, onClose: () => closes++);

      await tester.tap(find.text('Happy Birthday!'));
      await tester.tap(find.text('Dear Ana,'));

      expect(closes, 0);
    });

    testWidgets('calls onClose when the backdrop is clicked', (tester) async {
      var closes = 0;
      await pumpCard(tester, isOpen: true, onClose: () => closes++);

      await tester.tapAt(const Offset(4, 4));

      expect(closes, 1);
    });

    testWidgets('stays on screen while closing and is gone afterwards', (
      tester,
    ) async {
      await pumpCard(tester, isOpen: true);

      await tester.pumpWidget(harness(isOpen: false, onClose: () {}));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Happy Birthday!'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Happy Birthday!'), findsNothing);
    });

    testWidgets('keeps the scroll position at the end', (tester) async {
      await pumpCard(tester, isOpen: true);
      tester.view.physicalSize = const Size(1024, 571);
      await tester.pumpAndSettle();
      final scrollable = find.descendant(
        of: find.byType(BirthdayCard),
        matching: find.byType(Scrollable),
      );
      final state = tester.state<ScrollableState>(scrollable);
      expect(state.position.maxScrollExtent, greaterThan(0));

      await tester.drag(scrollable, const Offset(0, -5000));
      await tester.pumpAndSettle();

      final after = tester.state<ScrollableState>(scrollable);
      expect(after, same(state));
      expect(after.position.pixels, after.position.maxScrollExtent);
    });

    testWidgets('body text uses the foreground token in light theme', (
      tester,
    ) async {
      await pumpCard(tester, isOpen: true, theme: AppTheme.light);

      const foreground = Color(0xFF030213);
      expect(AppTokens.light.foreground, foreground);
      for (final text in [
        'Dear Ana,',
        'Sending you the warmest of wishes for a very Happy Birthday!',
        'P.S. Meowwwww Meow Meaaww ~ Clef',
      ]) {
        expect(textColor(tester, text), foreground, reason: text);
      }
      expect(textColor(tester, 'Your Best Friend,'), const Color(0xFFE97F6A));
    });

    testWidgets('body text uses the foreground token in dark theme', (
      tester,
    ) async {
      await pumpCard(tester, isOpen: true);

      expect(textColor(tester, 'Dear Ana,'), AppTokens.dark.foreground);
    });
  });
}
