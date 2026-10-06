import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/game/bracelet.dart';
import 'package:swiftie_quiz/ui/game/game_top_bar.dart';
import 'package:swiftie_quiz/ui/kit/bead.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

const designBeads = [
  Color(0xFFF5E5D4),
  Color(0xFFD4A0A0),
  Color(0xFF6FA8DC),
  Color(0xFFE97F6A),
  Color(0xFFFBF0E6),
];

Future<void> pumpGame(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark,
        themeAnimationDuration: Duration.zero,
        home: Material(
          child: Align(alignment: Alignment.topCenter, child: child),
        ),
      ),
    ),
  );
}

Color? inkOf(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text).text.style?.color;

List<Bead> beadsOf(WidgetTester tester) =>
    tester.widgetList<Bead>(find.byType(Bead)).toList();

double beadScale(WidgetTester tester, int index) => tester
    .widget<ScaleTransition>(
      find.descendant(
        of: find.byType(Bead).at(index),
        matching: find.byType(ScaleTransition),
      ),
    )
    .scale
    .value;

Finder timerFill() => find.descendant(
  of: find.byType(TimerFill),
  matching: find.byType(ColoredBox),
);

Widget topBar({
  int streak = 12,
  double? timeFraction = 0.25,
  int? totalRounds = 10,
  VoidCallback? onExit,
}) => GameTopBar(
  modeLabel: 'Name That Song',
  difficultyLabel: 'Medium',
  round: 3,
  totalRounds: totalRounds,
  streak: streak,
  timeFraction: timeFraction,
  timerRunning: true,
  onExit: onExit ?? () {},
);

void main() {
  testWidgets('the bracelet shows the streak in the design colours', (
    tester,
  ) async {
    const tokens = AppTokens.dark;
    var exits = 0;
    await pumpGame(tester, topBar(onExit: () => exits += 1));

    final beads = beadsOf(tester);
    expect(beads, hasLength(10));
    expect(beads.map((bead) => bead.color).toList(), [
      for (var position = 2; position < 12; position++)
        designBeads[position % 5],
    ]);
    for (var index = 0; index < 10; index++) {
      expect(
        tester.getSize(find.byType(Bead).at(index)),
        const Size.square(12),
      );
    }
    expect(beadScale(tester, 9), 0);
    for (var index = 0; index < 9; index++) {
      expect(beadScale(tester, index), 1, reason: 'bead $index');
    }
    await tester.pump(const Duration(milliseconds: 450));
    expect(beadScale(tester, 9), 1);

    final tag = find.descendant(
      of: find.byType(Bracelet),
      matching: find.text('12'),
    );
    expect(tag, findsOneWidget);
    expect(inkOf(tester, tag), tokens.paperFg);
    expect(
      tester.getCenter(tag).dx,
      greaterThan(tester.getCenter(find.byType(Bead).last).dx),
    );

    final mode = find.text('Name That Song · Medium');
    final round = find.text('· Round 3 of 10');
    expect(mode, findsOneWidget);
    expect(round, findsOneWidget);
    expect(inkOf(tester, mode), tokens.mut);
    expect(inkOf(tester, round), tokens.fg);
    expect(
      tester.getTopLeft(round).dx,
      greaterThan(tester.getTopRight(mode).dx),
    );

    expect(find.text('Exit'), findsOneWidget);
    expect(find.text('← '), findsOneWidget);
    await tester.tap(find.text('Exit'));
    await tester.pump();
    expect(exits, 1);

    final track = find.ancestor(
      of: find.byType(TimerFill),
      matching: find.byType(ColoredBox),
    );
    expect(tester.widget<ColoredBox>(track.first).color, tokens.line);
    expect(tester.getSize(track.first).height, 2);
    expect(tester.widget<ColoredBox>(timerFill()).color, tokens.rose);
    expect(
      tester.getSize(timerFill()).width,
      closeTo(tester.getSize(track.first).width * 0.25, 1e-9),
    );

    await pumpGame(tester, topBar(timeFraction: 0.3));
    await tester.pumpAndSettle();
    expect(tester.widget<ColoredBox>(timerFill()).color, tokens.rose);

    await pumpGame(tester, topBar(timeFraction: 0.31));
    await tester.pumpAndSettle();
    expect(tester.widget<ColoredBox>(timerFill()).color, tokens.coral);
  });

  testWidgets('a growing streak pops only the newest bead', (tester) async {
    await pumpGame(tester, topBar(streak: 3, totalRounds: null));
    await tester.pumpAndSettle();
    expect(beadsOf(tester).map((bead) => bead.color).toList(), [
      designBeads[0],
      designBeads[1],
      designBeads[2],
    ]);
    expect(find.text('Name That Song · Medium'), findsOneWidget);
    expect(find.textContaining('Round'), findsNothing);

    await pumpGame(tester, topBar(streak: 4, totalRounds: null));
    expect(beadsOf(tester).last.color, designBeads[3]);
    expect(beadScale(tester, 3), 0);
    for (var index = 0; index < 3; index++) {
      expect(beadScale(tester, index), 1, reason: 'bead $index');
    }

    await pumpGame(tester, topBar(streak: 12));
    await tester.pumpAndSettle();
    await pumpGame(tester, topBar(streak: 13));
    expect(beadsOf(tester).map((bead) => bead.color).toList(), [
      for (var position = 3; position < 13; position++)
        designBeads[position % 5],
    ]);
    expect(beadScale(tester, 9), 0);
    for (var index = 0; index < 9; index++) {
      expect(beadScale(tester, index), 1, reason: 'bead $index');
    }

    await pumpGame(tester, topBar(streak: 0, timeFraction: null));
    await tester.pumpAndSettle();
    expect(find.byType(Bead), findsNothing);
    expect(
      find.descendant(of: find.byType(Bracelet), matching: find.text('0')),
      findsOneWidget,
    );
    expect(find.byType(TimerFill), findsNothing);
  });
}
