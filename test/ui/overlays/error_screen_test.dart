import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/overlays/error_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

Color? textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

Color? screenColor(WidgetTester tester) => tester
    .widget<Material>(
      find
          .descendant(
            of: find.byType(ErrorScreen),
            matching: find.byType(Material),
          )
          .first,
    )
    .color;

void main() {
  group('the error screen uses the redesign', () {
    testWidgets('above the app it draws itself in the dark tokens and still '
        'restarts by click or keyboard', (tester) async {
      var restarts = 0;
      await tester.pumpWidget(
        ErrorScreen(
          error: StateError('layout failed'),
          onRestart: () => restarts += 1,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(PillButton), findsOneWidget);
      expect(screenColor(tester), AppTokens.dark.bg);
      expect(textColor(tester, ErrorScreen.title), AppTokens.dark.rose);
      expect(textColor(tester, 'Bad state: layout failed'), AppTokens.dark.mut);

      await tester.tap(find.text(ErrorScreen.restartLabel));
      expect(restarts, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(restarts, 2);
    });

    for (final (name, theme, tokens) in [
      ('dark', AppTheme.dark, AppTokens.dark),
      ('light', AppTheme.light, AppTokens.light),
    ]) {
      testWidgets('inside the $name theme it takes that theme\'s tokens', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: ErrorScreen(error: null, onRestart: () {}),
          ),
        );

        expect(screenColor(tester), tokens.bg);
        expect(textColor(tester, ErrorScreen.title), tokens.rose);
        expect(textColor(tester, ErrorScreen.fallbackMessage), tokens.mut);
      });
    }
  });
}
