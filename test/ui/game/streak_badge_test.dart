import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/game/streak_badge.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';

const String _fireEmoji = '\u{1F525}';

Widget _host(int streak) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(
    body: Center(child: StreakBadge(streak: streak)),
  ),
);

void main() {
  group('streak badge parity', () {
    testWidgets('renders the streak count', (tester) async {
      await tester.pumpWidget(_host(5));

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('renders a Sparkles icon (svg) instead of the fire emoji', (
      tester,
    ) async {
      await tester.pumpWidget(_host(3));

      final icon = tester.widget<AppIcon>(find.byType(AppIcon));
      expect(icon.glyph, LucideGlyph.sparkles);
      expect(icon.size, StreakBadge.iconSize);
      expect(icon.color, AppPalette.orange400);
      expect(
        find.descendant(
          of: find.byType(StreakBadge),
          matching: find.byType(SvgPicture),
        ),
        findsOneWidget,
      );
      expect(find.textContaining(_fireEmoji), findsNothing);
    });

    testWidgets('renders streak 0 without crashing', (tester) async {
      await tester.pumpWidget(_host(0));

      expect(find.text('0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses the orange pill of StreakBadge.tsx', (tester) async {
      await tester.pumpWidget(_host(7));

      final pill = tester.widget<Container>(
        find.descendant(
          of: find.byType(StreakBadge),
          matching: find.byType(Container),
        ),
      );
      final decoration = pill.decoration! as ShapeDecoration;
      final shape = decoration.shape as StadiumBorder;
      expect(pill.padding, StreakBadge.padding);
      expect(decoration.color, AppPalette.orange500.withValues(alpha: 0.1));
      expect(shape.side.color, AppPalette.orange500.withValues(alpha: 0.2));
      final label = tester.widget<Text>(find.text('7'));
      expect(label.style!.fontSize, 14);
      expect(label.style!.fontWeight, FontWeight.w500);
      expect(label.style!.color, AppPalette.orange400);
    });
  });
}
