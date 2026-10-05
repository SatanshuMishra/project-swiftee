import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/game/timer_bar.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

const Duration _tick = Duration(milliseconds: 100);

Widget _host({
  required int duration,
  required bool active,
  required VoidCallback onExpire,
}) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 512,
        child: TimerBar(duration: duration, onExpire: onExpire, active: active),
      ),
    ),
  ),
);

Color? _barColor(WidgetTester tester) =>
    (tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration
            as BoxDecoration?)
        ?.color;

double _barFraction(WidgetTester tester) => tester
    .widget<AnimatedFractionallySizedBox>(
      find.byType(AnimatedFractionallySizedBox),
    )
    .widthFactor!;

Future<void> _advanceTicks(WidgetTester tester, int ticks) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(_tick);
  }
}

void main() {
  group('timer bar parity', () {
    testWidgets('starts full with the duration remaining', (tester) async {
      await tester.pumpWidget(
        _host(duration: 30, active: false, onExpire: () {}),
      );

      expect(find.text('30s remaining'), findsOneWidget);
      expect(_barFraction(tester), 1);
      expect(_barColor(tester), AppTokens.dark.primary);
    });

    testWidgets('counts down in 100 ms ticks while active', (tester) async {
      await tester.pumpWidget(
        _host(duration: 10, active: true, onExpire: () {}),
      );

      await tester.pump(const Duration(milliseconds: 99));
      expect(_barFraction(tester), 1);

      await tester.pump(const Duration(milliseconds: 1));
      expect(_barFraction(tester), closeTo(0.99, 1e-9));
      expect(find.text('10s remaining'), findsOneWidget);

      await _advanceTicks(tester, 9);
      expect(_barFraction(tester), closeTo(0.9, 1e-9));
      expect(find.text('10s remaining'), findsOneWidget);

      await tester.pump(_tick);
      expect(find.text('9s remaining'), findsOneWidget);
    });

    testWidgets('the label rounds up the accumulated time as Timer.tsx does', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(duration: 10, active: true, onExpire: () {}),
      );

      await _advanceTicks(tester, 40);

      expect(find.text('7s remaining'), findsOneWidget);
      expect(_barFraction(tester), closeTo(0.6, 1e-9));
    });

    testWidgets('does not tick while inactive', (tester) async {
      await tester.pumpWidget(
        _host(duration: 10, active: false, onExpire: () {}),
      );

      await tester.pump(const Duration(seconds: 5));

      expect(find.text('10s remaining'), findsOneWidget);
      expect(_barFraction(tester), 1);
    });

    testWidgets('pausing keeps the remaining time and resuming continues', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(duration: 10, active: true, onExpire: () {}),
      );
      await _advanceTicks(tester, 21);
      expect(find.text('8s remaining'), findsOneWidget);

      await tester.pumpWidget(
        _host(duration: 10, active: false, onExpire: () {}),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('8s remaining'), findsOneWidget);
      expect(_barFraction(tester), closeTo(0.79, 1e-9));

      await tester.pumpWidget(
        _host(duration: 10, active: true, onExpire: () {}),
      );
      await _advanceTicks(tester, 10);
      expect(find.text('7s remaining'), findsOneWidget);
      expect(_barFraction(tester), closeTo(0.69, 1e-9));
    });

    testWidgets('calls onExpire once when the time runs out', (tester) async {
      var expired = 0;
      await tester.pumpWidget(
        _host(duration: 10, active: true, onExpire: () => expired++),
      );

      await _advanceTicks(tester, 100);
      expect(expired, 0);

      await tester.pump(_tick);
      expect(expired, 1);
      expect(find.text('0s remaining'), findsOneWidget);
      expect(_barFraction(tester), 0);

      await tester.pump(const Duration(seconds: 5));
      expect(expired, 1);
    });

    testWidgets('turns destructive with 30 percent left', (tester) async {
      await tester.pumpWidget(
        _host(duration: 10, active: true, onExpire: () {}),
      );

      await _advanceTicks(tester, 70);
      expect(_barColor(tester), AppTokens.dark.primary);

      await tester.pump(_tick);
      expect(_barColor(tester), AppTokens.dark.destructive);
      expect(find.text('3s remaining'), findsOneWidget);
    });

    testWidgets('turns destructive at 30 percent of 20 s', (tester) async {
      await tester.pumpWidget(
        _host(duration: 20, active: true, onExpire: () {}),
      );

      await _advanceTicks(tester, 139);
      expect(_barColor(tester), AppTokens.dark.primary);

      await tester.pump(_tick);
      expect(_barColor(tester), AppTokens.dark.destructive);
    });

    testWidgets('a new duration restarts the countdown', (tester) async {
      await tester.pumpWidget(
        _host(duration: 10, active: true, onExpire: () {}),
      );
      await _advanceTicks(tester, 41);
      expect(find.text('6s remaining'), findsOneWidget);

      await tester.pumpWidget(
        _host(duration: 20, active: true, onExpire: () {}),
      );

      expect(find.text('20s remaining'), findsOneWidget);
      expect(_barFraction(tester), 1);
    });

    testWidgets('label matches Timer.tsx', (tester) async {
      await tester.pumpWidget(
        _host(duration: 15, active: false, onExpire: () {}),
      );

      final label = tester.widget<Text>(find.text('15s remaining'));
      expect(label.style!.fontSize, AppText.sm.fontSize);
      expect(label.style!.color, AppTokens.dark.mutedForeground);
    });
  });
}
