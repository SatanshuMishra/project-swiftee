import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/misu_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/kit/bead.dart';
import 'package:swiftie_quiz/ui/kit/vinyl.dart';
import 'package:swiftie_quiz/ui/screens/round_summary_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

final DateTime tuesdayEvening = DateTime(2026, 10, 6, 20);

final Era red = curatedEras.firstWhere((era) => era.key == 'red');

final Era folklore = curatedEras.firstWhere((era) => era.key == 'folklore');

const Duration misuDelay = Duration(milliseconds: 900);

const Artist taylor = Artist(id: 12246, name: 'Taylor Swift');

Track roundTrack(int index, Era era) => Track(
  id: 1000 + index,
  title: 'Song ${index + 1}',
  titleShort: 'Song ${index + 1}',
  duration: 200,
  preview: 'https://previews.test/$index.mp3',
  artist: taylor,
  album: Album(
    id: era.deezerAlbumId,
    title: era.eraName,
    coverMedium: 'https://covers.test/${era.key}/$index.jpg',
  ),
  trackPosition: index + 1,
);

List<bool> roundOf(int right) => [
  for (var index = 0; index < quickRoundLength; index++) index < right,
];

final class RecordingMisu extends MisuController {
  List<int> summaries = const [];

  @override
  void afterQuickRound(int right) => summaries = [...summaries, right];
}

typedef SummaryHarness = ({ProviderContainer container, RecordingMisu misu});

Future<SummaryHarness> pumpSummary(
  WidgetTester tester,
  List<bool> outcomes, {
  Era? era,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final misu = RecordingMisu();
  final container = ProviderContainer.test(
    overrides: [
      misuControllerProvider.overrideWith(() => misu),
      clockProvider.overrideWithValue(() => tuesdayEvening),
    ],
  );
  final game = container.read(gameControllerProvider.notifier)
    ..startQuickRound();
  for (final (index, correct) in outcomes.indexed) {
    final track = roundTrack(index, era ?? red);
    if (correct) {
      game.answerCorrect(track);
    } else {
      game.answerIncorrect(track);
    }
  }
  game.finishQuickRound();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      key: ObjectKey(container),
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const Material(child: RoundSummaryScreen()),
      ),
    ),
  );
  return (container: container, misu: misu);
}

GamePhase phaseOf(SummaryHarness harness) =>
    harness.container.read(gameControllerProvider).phase;

AppTokens tokensOf(WidgetTester tester) =>
    AppTokens.of(tester.element(find.byType(RoundSummaryScreen)));

BoxDecoration ringOf(WidgetTester tester, Element bead) =>
    tester
            .widget<DecoratedBox>(
              find
                  .ancestor(
                    of: find.byElementPredicate((element) => element == bead),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

Iterable<T> summaryWidgets<T extends Widget>(WidgetTester tester) =>
    tester.widgetList<T>(
      find.descendant(
        of: find.byType(RoundSummaryScreen),
        matching: find.byType(T),
      ),
    );

void main() {
  testWidgets('the summary shows the score line and the songs you knew', (
    tester,
  ) async {
    final outcomes = [
      true,
      false,
      true,
      true,
      false,
      true,
      false,
      true,
      false,
      true,
    ];
    final harness = await pumpSummary(tester, outcomes);

    await tester.pump(misuDelay - const Duration(milliseconds: 1));
    expect(harness.misu.summaries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(harness.misu.summaries, [6]);

    expect(find.text('6 of 10'), findsOneWidget);
    expect(find.text('A solid round.'), findsOneWidget);
    expect(find.text("Tonight's era · Red"), findsOneWidget);

    final tokens = tokensOf(tester);
    final beads = find.byType(Bead).evaluate().toList();
    expect(beads, hasLength(10));
    for (final (index, bead) in beads.indexed) {
      final color = (bead.widget as Bead).color;
      final ring = (ringOf(tester, bead).border! as Border).top;
      expect(ring.width, 1.5);
      if (outcomes[index]) {
        expect(color, tokens.coral);
        expect(ring.color, tokens.coral);
      } else {
        expect(color.a, 0);
        expect(ring.color, tokens.line2);
      }
    }

    final known = [
      for (final (index, correct) in outcomes.indexed)
        if (correct) roundTrack(index, red),
    ];
    expect(find.text('The ones you knew'), findsOneWidget);
    final sleeves = tester.widgetList<AlbumSleeve>(find.byType(AlbumSleeve));
    expect(sleeves, hasLength(6));
    expect(
      [for (final sleeve in sleeves) sleeve.coverUrl],
      [for (final track in known) track.album.coverMedium],
    );
    expect([
      for (final sleeve in sleeves) sleeve.placeholder,
    ], List.filled(6, Color(red.placeholderArgb)));
    for (final (index, correct) in outcomes.indexed) {
      expect(
        find.text(roundTrack(index, red).title),
        correct ? findsOneWidget : findsNothing,
      );
    }

    await tester.tap(find.text('Another round →'));
    await tester.pump();
    final again = harness.container.read(gameControllerProvider);
    expect(again.phase, GamePhase.playing);
    expect(again.mode, GameMode.tonight);
    expect(again.quickRoundTotal, quickRoundLength);
    expect(again.roundResults, isEmpty);

    await tester.tap(find.text('Back to menu'));
    await tester.pump();
    expect(phaseOf(harness), GamePhase.menu);
  });

  testWidgets('each score gets its line and a blank round has no covers', (
    tester,
  ) async {
    const lines = {
      10: 'A near-perfect run.',
      8: 'A near-perfect run.',
      7: 'A solid round.',
      5: 'A solid round.',
      4: 'Every Swiftie has an off night.',
      1: 'Every Swiftie has an off night.',
      0: 'Not a single one. The vault stays locked.',
    };
    for (final MapEntry(key: right, value: line) in lines.entries) {
      await pumpSummary(tester, roundOf(right));
      await tester.pump(misuDelay);

      expect(find.text('$right of 10'), findsOneWidget);
      expect(find.text(line), findsOneWidget);
      expect(find.byType(AlbumSleeve), findsNWidgets(right));
      expect(
        find.text('The ones you knew'),
        right > 0 ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('the era label names the era the round was played in', (
    tester,
  ) async {
    await pumpSummary(tester, roundOf(3), era: folklore);
    await tester.pump(misuDelay);
    expect(find.text("Tonight's era · folklore"), findsOneWidget);

    await pumpSummary(tester, const []);
    await tester.pump(misuDelay);
    expect(find.text("Tonight's era · Red"), findsOneWidget);
  });

  testWidgets('leaving the summary before Misu arrives keeps him quiet', (
    tester,
  ) async {
    final harness = await pumpSummary(tester, roundOf(9));

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(misuDelay * 2);

    expect(harness.misu.summaries, isEmpty);
  });

  testWidgets('with reduced motion the summary appears at once', (
    tester,
  ) async {
    await pumpSummary(tester, roundOf(6), reduceMotion: true);

    final opacities = summaryWidgets<Opacity>(tester);
    expect(opacities, hasLength(greaterThanOrEqualTo(6)));
    for (final opacity in opacities) {
      expect(opacity.opacity, 1);
    }
    for (final fade in summaryWidgets<FadeTransition>(tester)) {
      expect(fade.opacity.value, 1);
    }

    await tester.pump(misuDelay);
  });

  testWidgets('the keyboard reaches Another round and starts it', (
    tester,
  ) async {
    final harness = await pumpSummary(tester, roundOf(6));
    await tester.pump(misuDelay);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(phaseOf(harness), GamePhase.playing);
  });
}
