import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/domain/together/scoring.dart';
import 'package:swiftie_quiz/domain/together/standings.dart';
import 'package:swiftie_quiz/state/together/together_game_state.dart';
import 'package:swiftie_quiz/ui/kit/bead.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/together/player_avatar.dart';
import 'package:swiftie_quiz/ui/together/player_colors.dart';
import 'package:swiftie_quiz/ui/together/standings_list.dart';
import 'package:together_protocol/together_protocol.dart';

const Player _lee = Player(id: 'p-lee', name: 'Lee', avatar: 'seedLee');
const Player _maya = Player(id: 'p-maya', name: 'Maya', avatar: 'seedMaya');
const Player _sam = Player(id: 'p-sam', name: 'Sam', avatar: 'seedSam');

PlayerScore _score(String id, int score, {int wins = 1}) => PlayerScore(
  id: id,
  score: score,
  streak: wins,
  best: wins,
  wins: wins,
  fastest: null,
  left: false,
);

final TogetherGameState _reveal = TogetherGameState.initial.copyWith(
  stage: TogetherStage.reveal,
  number: 2,
  total: 10,
  mode: TogetherMode.classic,
  difficulty: Difficulty.medium,
  roster: const [_lee, _maya, _sam],
  statuses: {_lee.id: AnswerStatus.answered, _maya.id: AnswerStatus.answered},
  results: {
    _lee.id: const RoundResult(
      playerId: 'p-lee',
      pickTrackId: 4,
      pickReal: null,
      right: false,
      at: 3.2,
      gain: 0,
    ),
    _maya.id: const RoundResult(
      playerId: 'p-maya',
      pickTrackId: 3,
      pickReal: null,
      right: true,
      at: 2.5,
      gain: 175,
    ),
  },
  standings: [
    _score(_lee.id, 100),
    _score(_maya.id, 175, wins: 2),
    _score(_sam.id, 100),
  ],
);

Future<void> pumpList(WidgetTester tester, TogetherGameState game) =>
    tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Material(
          child: Center(
            child: SizedBox(
              width: 520,
              child: StandingsList(game: game, viewerId: _sam.id),
            ),
          ),
        ),
      ),
    );

Finder rowOf(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(StandingsRow));

Finder slotOf(String name) => find.ancestor(
  of: find.text(name),
  matching: find.byType(AnimatedPositioned),
);

double topOf(WidgetTester tester, String name) =>
    tester.getTopLeft(rowOf(name)).dy -
    tester.getTopLeft(find.byType(StandingsList)).dy;

String? textIn(WidgetTester tester, String name, String text) => tester
    .widgetList<Text>(
      find.descendant(of: rowOf(name), matching: find.text(text)),
    )
    .firstOrNull
    ?.data;

void main() {
  testWidgets('rows rank, label and slide', (tester) async {
    await pumpList(tester, _reveal);
    await tester.pump(const Duration(seconds: 1));

    expect(topOf(tester, 'Maya'), 0);
    expect(topOf(tester, 'Sam (you)'), 64);
    expect(topOf(tester, 'Lee'), 128);
    for (final name in ['Maya', 'Sam (you)', 'Lee']) {
      expect(tester.getSize(rowOf(name)).height, 56, reason: name);
    }
    expect(tester.getSize(find.byType(StandingsList)).height, 3 * 56 + 2 * 8);
    for (final (name, rank) in [
      ('Maya', '1'),
      ('Sam (you)', '2'),
      ('Lee', '3'),
    ]) {
      expect(textIn(tester, name, rank), rank, reason: name);
    }
    expect(find.text('Sam'), findsNothing);

    const tokens = AppTokens.dark;
    expect(textIn(tester, 'Maya', 'Right · 2.5 s'), isNotNull);
    expect(
      tester.widget<Text>(find.text('Right · 2.5 s')).style?.color,
      tokens.coralT,
    );
    expect(textIn(tester, 'Maya', '+175'), isNotNull);
    expect(textIn(tester, 'Lee', 'Wrong'), isNotNull);
    expect(tester.widget<Text>(find.text('Wrong')).style?.color, tokens.mut);
    expect(textIn(tester, 'Sam (you)', 'No answer'), isNotNull);
    expect(find.text('+0'), findsNothing);
    for (final (name, score) in [
      ('Maya', '175'),
      ('Sam (you)', '100'),
      ('Lee', '100'),
    ]) {
      expect(textIn(tester, name, score), score, reason: name);
    }

    Iterable<Bead> beadsOf(String name) => tester.widgetList<Bead>(
      find.descendant(of: rowOf(name), matching: find.byType(Bead)),
    );
    expect(
      [for (final bead in beadsOf('Maya')) bead.color],
      [
        playerColor(viewer: false, joinIndex: 1),
        playerColor(viewer: false, joinIndex: 1),
      ],
    );
    expect(
      [for (final bead in beadsOf('Sam (you)')) bead.color],
      [const Color(0xFFE97F6A)],
    );
    expect(
      tester
          .widget<PlayerAvatar>(
            find.descendant(
              of: rowOf('Lee'),
              matching: find.byType(PlayerAvatar),
            ),
          )
          .seed,
      'seedLee',
    );
    Color borderOf(String name) =>
        ((tester
                            .widget<Container>(
                              find
                                  .descendant(
                                    of: rowOf(name),
                                    matching: find.byType(Container),
                                  )
                                  .first,
                            )
                            .decoration!
                        as BoxDecoration)
                    .border!
                as Border)
            .top
            .color;
    expect(borderOf('Sam (you)'), tokens.line2);
    expect(borderOf('Maya'), tokens.line);

    await pumpList(
      tester,
      _reveal.copyWith(
        standings: [
          _score(_lee.id, 300, wins: 2),
          _score(_maya.id, 175, wins: 2),
          _score(_sam.id, 100),
        ],
      ),
    );
    final slot = tester.widget<AnimatedPositioned>(slotOf('Lee'));
    expect(slot.top, 0);
    expect(slot.duration, const Duration(milliseconds: 600));
    expect(tester.widget<AnimatedPositioned>(slotOf('Maya')).top, 64);
    expect(tester.widget<AnimatedPositioned>(slotOf('Sam (you)')).top, 128);

    await tester.pump(const Duration(milliseconds: 300));
    expect(topOf(tester, 'Lee'), allOf(greaterThan(0), lessThan(128)));
    await tester.pump(const Duration(milliseconds: 301));
    expect(topOf(tester, 'Lee'), 0);
    expect(topOf(tester, 'Maya'), 64);
    expect(topOf(tester, 'Sam (you)'), 128);
    expect(textIn(tester, 'Lee', '1'), '1');

    await pumpList(
      tester,
      _reveal.copyWith(
        stage: TogetherStage.ended,
        standings: [
          _score(_lee.id, 300, wins: 2),
          _score(_maya.id, 175, wins: 2),
          _score(_sam.id, 100).copyWith(left: true),
        ],
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Right · 2.5 s'), findsNothing);
    expect(find.text('+175'), findsNothing);
    expect(find.text('Left'), findsNothing);

    await pumpList(
      tester,
      _reveal.copyWith(
        stage: TogetherStage.round,
        results: const {},
        statuses: {_maya.id: AnswerStatus.answered},
        standings: [
          _score(_lee.id, 300, wins: 2),
          _score(_maya.id, 175, wins: 2),
          _score(_sam.id, 100).copyWith(left: true),
        ],
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(textIn(tester, 'Maya', 'Answered'), isNotNull);
    expect(textIn(tester, 'Lee', 'Listening…'), isNotNull);
    expect(textIn(tester, 'Sam (you)', 'Left'), isNotNull);
  });
}
