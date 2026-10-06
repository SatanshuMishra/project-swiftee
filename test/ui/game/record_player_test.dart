import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/game/lyric_paper.dart';
import 'package:swiftie_quiz/ui/game/record_player.dart';
import 'package:swiftie_quiz/ui/kit/vinyl.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

const albumA = 'https://e-cdns-images.dzcdn.net/images/cover/folklore.jpg';
const albumB = 'https://e-cdns-images.dzcdn.net/images/cover/lover.jpg';
const placeholderA = Color(0xFF5A6B57);
const placeholderB = Color(0xFF9A5E7A);
const sleeve = 270.0;
const flip = Duration(milliseconds: 550);
const frame = Duration(milliseconds: 10);

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
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ),
  );
}

Finder coverImage(String url) => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is NetworkImage &&
      (widget.image as NetworkImage).url == url,
);

RecordSleeve sleeveOf(WidgetTester tester) =>
    tester.widget<RecordSleeve>(find.byType(RecordSleeve));

Offset discOffset(WidgetTester tester) =>
    tester.getTopLeft(find.byType(VinylDisc)) -
    tester.getTopLeft(find.byType(RecordPlayer));

Color backFill(WidgetTester tester) => tester
    .widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(SleeveBack),
            matching: find.byType(ColoredBox),
          )
          .first,
    )
    .color;

double discDegrees(WidgetTester tester) =>
    tester
        .widget<RotationTransition>(
          find.ancestor(
            of: find.byType(VinylDisc),
            matching: find.byType(RotationTransition),
          ),
        )
        .turns
        .value *
    360;

void main() {
  testWidgets('the sleeve never shows the next cover on medium', (
    tester,
  ) async {
    await pumpGame(
      tester,
      const RecordPlayer(
        revealed: true,
        answered: true,
        spinning: false,
        coverUrl: albumA,
        placeholder: placeholderA,
      ),
    );
    await tester.pumpAndSettle();
    expect(sleeveOf(tester).degrees, 180);
    expect(
      find.descendant(
        of: find.byType(SleeveBack),
        matching: coverImage(albumA),
      ),
      findsOneWidget,
    );

    await pumpGame(
      tester,
      const RecordPlayer(
        revealed: false,
        answered: false,
        spinning: false,
        coverUrl: albumB,
        placeholder: placeholderB,
        previousCoverUrl: albumA,
        previousPlaceholder: placeholderA,
      ),
    );

    var backFrames = 0;
    for (var elapsed = Duration.zero; elapsed <= flip; elapsed += frame) {
      expect(coverImage(albumB), findsNothing, reason: 'at $elapsed');
      if (sleeveOf(tester).showsBack) {
        backFrames += 1;
        expect(
          find.descendant(
            of: find.byType(SleeveBack),
            matching: coverImage(albumA),
          ),
          findsOneWidget,
          reason: 'at $elapsed',
        );
        expect(backFill(tester), placeholderA, reason: 'at $elapsed');
      }
      await tester.pump(frame);
    }
    expect(backFrames, greaterThan(0));
    await tester.pumpAndSettle();
    expect(sleeveOf(tester).degrees, 0);
    expect(coverImage(albumB), findsNothing);
    expect(find.text('Side A'), findsOneWidget);
    expect(find.text('33⅓'), findsOneWidget);
  });

  testWidgets('the sleeve flips to the cover on reveal', (tester) async {
    await pumpGame(
      tester,
      const RecordPlayer(
        revealed: false,
        answered: false,
        spinning: false,
        coverUrl: albumA,
        placeholder: placeholderA,
      ),
    );
    expect(
      tester.getSize(find.byType(RecordPlayer)),
      const Size(sleeve * 1.47, sleeve),
    );
    expect(
      tester.getSize(find.byType(VinylDisc)),
      const Size.square(sleeve * 0.94),
    );
    expect(sleeveOf(tester).degrees, 0);
    expect(find.text('Side A'), findsOneWidget);
    expect(find.text('33⅓'), findsOneWidget);
    expect(coverImage(albumA), findsNothing);
    expect(discOffset(tester).dx, closeTo(sleeve * 0.40, 1e-9));
    expect(discOffset(tester).dy, closeTo(sleeve * 0.03, 1e-9));

    await pumpGame(
      tester,
      const RecordPlayer(
        revealed: true,
        answered: true,
        spinning: false,
        coverUrl: albumA,
        placeholder: placeholderA,
      ),
    );
    await tester.pump(flip ~/ 2);
    expect(sleeveOf(tester).degrees, inExclusiveRange(0, 180));
    await tester.pump(flip ~/ 2 - const Duration(milliseconds: 1));
    expect(sleeveOf(tester).degrees, lessThan(180));
    expect(discOffset(tester).dx, lessThan(sleeve * 0.52));
    await tester.pump(const Duration(milliseconds: 1));
    expect(sleeveOf(tester).degrees, 180);
    expect(discOffset(tester).dx, closeTo(sleeve * 0.52, 1e-9));
    expect(find.text('Side A'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SleeveBack),
        matching: coverImage(albumA),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(VinylDisc), matching: coverImage(albumA)),
      findsOneWidget,
    );

    await pumpGame(tester, const SizedBox());
    await pumpGame(
      tester,
      const RecordPlayer(
        revealed: true,
        answered: false,
        spinning: false,
        coverUrl: albumA,
        placeholder: placeholderA,
      ),
    );
    expect(sleeveOf(tester).degrees, 180);
    expect(find.text('Side A'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SleeveBack),
        matching: coverImage(albumA),
      ),
      findsOneWidget,
    );
    expect(discOffset(tester).dx, closeTo(sleeve * 0.40, 1e-9));
  });

  testWidgets('the disc spins at 0.2 degrees per ms only while playing', (
    tester,
  ) async {
    Widget record({required bool spinning}) => RecordPlayer(
      revealed: false,
      answered: false,
      spinning: spinning,
      coverUrl: albumA,
    );

    await pumpGame(tester, record(spinning: true));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(discDegrees(tester), closeTo(200, 1e-6));

    await pumpGame(tester, record(spinning: false));
    await tester.pump(const Duration(milliseconds: 500));
    final paused = discDegrees(tester);
    expect(paused, closeTo(200, 0.5));

    await pumpGame(tester, record(spinning: true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(discDegrees(tester), closeTo(paused + 100, 1e-6));

    await pumpGame(tester, const SizedBox());
    await pumpGame(tester, record(spinning: true), reducedMotion: true);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(discDegrees(tester), 0);

    await pumpGame(
      tester,
      const RecordPlayer(
        revealed: true,
        answered: true,
        spinning: false,
        coverUrl: albumA,
      ),
      reducedMotion: true,
    );
    await tester.pump();
    expect(sleeveOf(tester).degrees, 180);
    expect(discOffset(tester).dx, closeTo(sleeve * 0.52, 1e-9));
  });

  testWidgets('the lyric paper hints the era and reveals the song', (
    tester,
  ) async {
    const lines = ['First line', 'Second line', 'Third line'];
    const tokens = AppTokens.dark;
    Widget paper({required bool revealed, required bool showHint}) => SizedBox(
      width: 500,
      child: LyricPaper(
        lines: lines,
        song: 'cardigan',
        era: 'Folklore',
        coverUrl: albumA,
        placeholder: placeholderA,
        revealed: revealed,
        showHint: showHint,
      ),
    );

    await pumpGame(tester, paper(revealed: false, showHint: false));
    for (final line in lines) {
      expect(find.text(line), findsOneWidget);
    }
    expect(find.text('From Folklore'), findsNothing);
    expect(find.text('cardigan'), findsNothing);
    final tilt = tester.widget<Transform>(
      find
          .ancestor(
            of: find.text(lines.first),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(
      math.atan2(tilt.transform.entry(1, 0), tilt.transform.entry(0, 0)),
      closeTo(-math.pi / 180, 1e-9),
    );
    final card = tester
        .widgetList<DecoratedBox>(
          find.ancestor(
            of: find.text(lines.first),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) => decoration.color != null);
    expect(card.color, tokens.paper);
    expect(
      tester
          .renderObject<RenderParagraph>(find.text(lines.first))
          .text
          .style
          ?.color,
      tokens.paperFg,
    );

    await pumpGame(tester, paper(revealed: false, showHint: true));
    expect(find.text('From Folklore'), findsOneWidget);
    expect(coverImage(albumA), findsOneWidget);

    await pumpGame(tester, paper(revealed: true, showHint: false));
    await tester.pumpAndSettle();
    expect(find.text('cardigan'), findsOneWidget);
    expect(find.text('Folklore'), findsOneWidget);
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('cardigan'))
          .text
          .style
          ?.color,
      const Color(0xFFB4533F),
    );

    await pumpGame(
      tester,
      const SizedBox(width: 500, child: LyricPaper.quote(lines: ['A line'])),
    );
    expect(find.text('“A line”'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('“A line”'),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
  });
}
