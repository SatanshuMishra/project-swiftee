import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/game/quack_burst.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';

const burst = Duration(milliseconds: 1300);

Future<void> pumpGame(
  WidgetTester tester,
  Widget child, {
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark,
        themeAnimationDuration: Duration.zero,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reducedMotion),
          child: app!,
        ),
        home: Material(
          child: Center(
            child: SizedBox(
              width: 500,
              height: 400,
              child: Stack(children: [Positioned.fill(child: child)]),
            ),
          ),
        ),
      ),
    ),
  );
}

Finder quacks() => find.text('quack');

List<double> opacities(WidgetTester tester) => [
  for (var index = 0; index < quacks().evaluate().length; index++)
    tester
        .widget<Opacity>(
          find
              .ancestor(of: quacks().at(index), matching: find.byType(Opacity))
              .first,
        )
        .opacity,
];

void main() {
  testWidgets('quack words escalate to a ring of fourteen', (tester) async {
    expect(QuackBurst.wordsFor(3), const [
      QuackWord(
        offset: Offset(30, -34),
        degrees: -8,
        delay: Duration.zero,
        size: 16,
      ),
      QuackWord(
        offset: Offset(64, -44),
        degrees: 0,
        delay: Duration(milliseconds: 120),
        size: 18,
      ),
      QuackWord(
        offset: Offset(98, -54),
        degrees: 8,
        delay: Duration(milliseconds: 240),
        size: 20,
      ),
    ]);
    final ring = QuackBurst.wordsFor(5);
    expect(ring, hasLength(14));
    expect(ring.first.offset.dx, closeTo(140, 1e-9));
    expect(ring.first.offset.dy, closeTo(0, 1e-9));
    expect(ring.first.degrees, -24);
    expect(ring.first.size, 18);
    expect(ring[1].offset.dx, closeTo(math.cos(math.pi / 7) * 170, 1e-9));
    expect(ring[1].offset.dy, closeTo(math.sin(math.pi / 7) * 120, 1e-9));
    expect(ring[1].degrees, -12);
    expect(ring[1].delay, const Duration(milliseconds: 30));
    expect(ring[1].size, 24);
    expect(ring[7].offset.dx, closeTo(-170, 1e-9));
    expect(ring.last.delay, const Duration(milliseconds: 390));
    expect(QuackBurst.wordsFor(9), ring);

    await pumpGame(tester, const QuackBurst(key: ValueKey(1), level: 3));
    expect(quacks(), findsNWidgets(3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(opacities(tester).first, greaterThan(0.5));
    await tester.pump(burst - const Duration(milliseconds: 300));
    expect(quacks(), findsNWidgets(3));
    expect(opacities(tester).first, 0);
    await tester.pump(const Duration(milliseconds: 240));
    expect(quacks(), findsNothing);

    await pumpGame(tester, const QuackBurst(key: ValueKey(2), level: 5));
    expect(quacks(), findsNWidgets(14));
    await tester.pump(const Duration(milliseconds: 600));
    expect(opacities(tester).every((opacity) => opacity > 0), isTrue);
    await tester.pump(
      burst +
          const Duration(milliseconds: 390) -
          const Duration(milliseconds: 600),
    );
    expect(quacks(), findsNothing);

    await pumpGame(tester, const QuackBurst(key: ValueKey(3), level: 7));
    expect(quacks(), findsNWidgets(14));
  });

  testWidgets('a new key restarts the burst and reduced motion skips it', (
    tester,
  ) async {
    await pumpGame(tester, const QuackBurst(key: ValueKey(1), level: 2));
    await tester.pumpAndSettle();
    expect(quacks(), findsNothing);

    await pumpGame(tester, const QuackBurst(key: ValueKey(2), level: 2));
    expect(quacks(), findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(quacks(), findsNothing);

    await pumpGame(tester, const QuackBurst(key: ValueKey(3), level: 0));
    expect(quacks(), findsNothing);

    await pumpGame(tester, const QuackBurst(key: ValueKey(5), level: 4));
    await tester.pump(const Duration(milliseconds: 200));
    expect(quacks(), findsNWidgets(4));
    await pumpGame(
      tester,
      const QuackBurst(key: ValueKey(5), level: 4),
      reducedMotion: true,
    );
    await tester.pump();
    expect(quacks(), findsNothing);

    await pumpGame(
      tester,
      const QuackBurst(key: ValueKey(4), level: 5),
      reducedMotion: true,
    );
    expect(quacks(), findsNothing);
  });
}
