import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/game/answer_list.dart';
import 'package:swiftie_quiz/ui/game/next_prompt.dart';
import 'package:swiftie_quiz/ui/game/round_heading.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

const titles = ['cardigan', 'august', 'betty', 'the 1'];

Future<void> pumpGame(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        themeAnimationDuration: Duration.zero,
        home: Material(
          child: Center(child: SizedBox(width: 480, child: child)),
        ),
      ),
    ),
  );
}

Color? inkOf(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text).text.style?.color;

FontWeight? weightOf(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text).text.style?.fontWeight;

BoxDecoration fillOf(WidgetTester tester, Finder button) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: button, matching: find.byType(DecoratedBox)),
    )
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((decoration) => decoration.color != null);

Color borderOf(WidgetTester tester, Finder button) =>
    (fillOf(tester, button).border! as Border).top.color;

double opacityOf(WidgetTester tester, Finder button) => tester
    .widget<FadeTransition>(
      find.descendant(of: button, matching: find.byType(FadeTransition)).first,
    )
    .opacity
    .value;

Finder answerButton(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(AnswerButton));

Finder within(Finder button, String text) =>
    find.descendant(of: button, matching: find.text(text));

void main() {
  testWidgets('answer buttons show right, wrong and dimmed states', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(const SizedBox());
      final tokens = brightness == Brightness.dark
          ? AppTokens.dark
          : AppTokens.light;
      final picks = <int>[];
      await pumpGame(
        tester,
        AnswerList(labels: titles, onPick: picks.add),
        brightness: brightness,
      );
      for (final (index, title) in titles.indexed) {
        final button = answerButton(title);
        expect(within(button, '${index + 1}'), findsOneWidget);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(56));
        expect(borderOf(tester, button), tokens.line2);
        expect(inkOf(tester, find.text(title)), tokens.fg);
      }
      await tester.tap(find.text('betty'));
      await tester.pump();
      expect(picks, [2]);

      await pumpGame(
        tester,
        AnswerList(
          labels: titles,
          onPick: picks.add,
          answered: true,
          rightIndex: 1,
          pickedIndex: 2,
        ),
        brightness: brightness,
      );
      await tester.pumpAndSettle();

      final wrong = answerButton('betty');
      expect(within(wrong, '✕'), findsOneWidget);
      expect(within(wrong, '3'), findsNothing);
      expect(fillOf(tester, wrong).color, tokens.roseBg);
      expect(borderOf(tester, wrong), tokens.rose);
      expect(inkOf(tester, find.text('betty')), tokens.rose);
      expect(opacityOf(tester, wrong), 1);

      final right = answerButton('august');
      expect(within(right, '✓'), findsOneWidget);
      expect(within(right, '2'), findsNothing);
      expect(fillOf(tester, right).color, tokens.coral);
      expect(inkOf(tester, find.text('august')), tokens.onCoral);
      expect(weightOf(tester, find.text('august')), FontWeight.w600);
      expect(opacityOf(tester, right), 1);

      for (final (title, number) in [('cardigan', '1'), ('the 1', '4')]) {
        final dim = answerButton(title);
        expect(within(dim, number), findsOneWidget);
        expect(opacityOf(tester, dim), 0.55);
        expect(borderOf(tester, dim), tokens.line);
        expect(inkOf(tester, find.text(title)), tokens.faint);
      }
      for (final title in titles) {
        expect(
          tester.getSize(answerButton(title)).height,
          greaterThanOrEqualTo(56),
        );
      }

      await tester.tap(find.text('cardigan'));
      await tester.pump();
      expect(picks, [2]);
    }
  });

  testWidgets('a timeout marks the right answer and dims the rest', (
    tester,
  ) async {
    const tokens = AppTokens.dark;
    await pumpGame(
      tester,
      AnswerList(labels: titles, onPick: (_) {}, answered: true, rightIndex: 0),
    );
    await tester.pumpAndSettle();
    expect(fillOf(tester, answerButton('cardigan')).color, tokens.coral);
    expect(find.text('✕'), findsNothing);
    for (final title in titles.skip(1)) {
      expect(opacityOf(tester, answerButton(title)), 0.55);
    }
  });

  testWidgets('real and fake buttons mark the verdict the same way', (
    tester,
  ) async {
    const tokens = AppTokens.dark;
    final picks = <bool>[];
    Finder side(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(RealFakeButton),
    );

    await pumpGame(tester, RealFakeButtons(onPick: picks.add));
    expect(within(side('Real'), 'R'), findsOneWidget);
    expect(within(side('Fake'), 'F'), findsOneWidget);
    for (final label in ['Real', 'Fake']) {
      expect(tester.getSize(side(label)).height, greaterThanOrEqualTo(56));
      expect(borderOf(tester, side(label)), tokens.line2);
    }
    await tester.tap(find.text('Fake'));
    await tester.pump();
    expect(picks, [false]);

    await pumpGame(
      tester,
      RealFakeButtons(
        onPick: picks.add,
        answered: true,
        isReal: false,
        picked: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(fillOf(tester, side('Real')).color, tokens.roseBg);
    expect(borderOf(tester, side('Real')), tokens.rose);
    expect(inkOf(tester, find.text('Real')), tokens.rose);
    expect(fillOf(tester, side('Fake')).color, tokens.coral);
    expect(inkOf(tester, find.text('Fake')), tokens.onCoral);

    await pumpGame(
      tester,
      RealFakeButtons(
        onPick: picks.add,
        answered: true,
        isReal: true,
        picked: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(fillOf(tester, side('Real')).color, tokens.coral);
    expect(borderOf(tester, side('Fake')), tokens.line);
    expect(inkOf(tester, find.text('Fake')), tokens.faint);
    await tester.tap(find.text('Fake'));
    await tester.pump();
    expect(picks, [false]);
  });

  testWidgets('the round heading sets the song apart and warns in rose', (
    tester,
  ) async {
    const tokens = AppTokens.dark;
    await pumpGame(
      tester,
      const RoundHeading(
        pre: 'It was ',
        song: 'august',
        post: '.',
        subline: 'Folklore · track 8',
      ),
    );
    final title = find.text('It was august.', findRichText: true);
    expect(title, findsOneWidget);
    final spans = <TextSpan>[];
    tester.renderObject<RenderParagraph>(title).text.visitChildren((span) {
      if (span is TextSpan) {
        spans.add(span);
      }
      return true;
    });
    final song = spans.singleWhere((span) => span.text == 'august');
    expect(song.style?.fontStyle, FontStyle.italic);
    expect(song.style?.color, tokens.coralT);
    expect(inkOf(tester, find.text('Folklore · track 8')), tokens.mut);

    await pumpGame(
      tester,
      const RoundHeading(
        pre: "What's playing?",
        subline: '6 seconds left.',
        urgent: true,
      ),
    );
    expect(inkOf(tester, find.text('6 seconds left.')), tokens.rose);

    await pumpGame(
      tester,
      const RoundHeading.question(
        kicker: 'Is this lyric from',
        song: 'betty',
        subline: '12 seconds left.',
      ),
    );
    expect(find.text('Is this lyric from'), findsOneWidget);
    expect(find.text('betty?'), findsOneWidget);
    expect(inkOf(tester, find.text('betty?')), tokens.coralT);
  });

  testWidgets('next waits at 0.45 opacity until it is enabled', (tester) async {
    var nexts = 0;
    double opacity() => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.text('Next song →'),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    await pumpGame(tester, NextPrompt(onNext: () => nexts += 1));
    await tester.pumpAndSettle();
    expect(find.text('or press Enter'), findsOneWidget);
    expect(opacity(), 0.45);
    await tester.tap(find.text('Next song →'));
    await tester.pump();
    expect(nexts, 0);

    await pumpGame(tester, NextPrompt(onNext: () => nexts += 1, enabled: true));
    await tester.pumpAndSettle();
    expect(opacity(), 1);
    await tester.tap(find.text('Next song →'));
    await tester.pump();
    expect(nexts, 1);

    await pumpGame(
      tester,
      NextPrompt(
        onNext: () => nexts += 1,
        enabled: true,
        label: 'See your round →',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('See your round →'), findsOneWidget);
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.text('See your round →'),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .height,
      44,
    );
  });
}
