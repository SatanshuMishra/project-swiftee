import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/domain/together/scoring.dart';
import 'package:swiftie_quiz/domain/together/standings.dart';

RoundResult result(
  String id, {
  bool right = true,
  double? at = 2,
  int gain = 0,
}) => RoundResult(
  playerId: id,
  pickTrackId: at == null ? null : 7,
  pickReal: null,
  right: right,
  at: at,
  gain: gain,
);

PlayerScore scoreOf(List<PlayerScore> players, String id) =>
    players.firstWhere((player) => player.id == id);

String status({
  TogetherMode mode = TogetherMode.classic,
  bool revealed = false,
  AnswerStatus? answer,
  bool wonQuickDraw = false,
  RoundResult? outcome,
  bool left = false,
}) => statusLine(
  mode: mode,
  revealed: revealed,
  status: answer,
  wonQuickDraw: wonQuickDraw,
  result: outcome,
  left: left,
);

void main() {
  test('a round updates streaks, beads and fastest answers', () {
    const start = [
      PlayerScore.start('ana'),
      PlayerScore.start('maya'),
      PlayerScore.start('lena'),
    ];
    final departed = start.map(
      (player) => player.id == 'lena'
          ? player.copyWith(score: 150, streak: 1, best: 1, wins: 1, left: true)
          : player,
    );

    final first = applyRound(departed.toList(), [
      result('ana', at: 4.2, gain: 179),
      result('maya', right: false, at: 1.1),
      result('lena', at: 1.0, gain: 195),
    ], 'Enchanted');
    final second = applyRound(first, [
      result('ana', at: 2.6, gain: 187),
      result('maya', at: 3.0, gain: 185),
    ], 'Mine');
    final third = applyRound(second, [
      result('ana', right: false, at: 1.9),
    ], 'Style');

    expect(
      scoreOf(first, 'ana'),
      const PlayerScore(
        id: 'ana',
        score: 179,
        streak: 1,
        best: 1,
        wins: 1,
        fastest: FastestAnswer(seconds: 4.2, song: 'Enchanted'),
        left: false,
      ),
    );
    expect(
      scoreOf(third, 'ana'),
      const PlayerScore(
        id: 'ana',
        score: 366,
        streak: 0,
        best: 2,
        wins: 2,
        fastest: FastestAnswer(seconds: 2.6, song: 'Mine'),
        left: false,
      ),
    );
    expect(scoreOf(first, 'maya'), const PlayerScore.start('maya'));
    expect(
      scoreOf(third, 'maya'),
      const PlayerScore(
        id: 'maya',
        score: 185,
        streak: 0,
        best: 1,
        wins: 1,
        fastest: FastestAnswer(seconds: 3.0, song: 'Mine'),
        left: false,
      ),
    );
    expect(
      scoreOf(third, 'lena'),
      const PlayerScore(
        id: 'lena',
        score: 150,
        streak: 1,
        best: 1,
        wins: 1,
        fastest: null,
        left: true,
      ),
    );
    expect(third.map((player) => player.id), ['ana', 'maya', 'lena']);
    expect(() => third.add(start.first), throwsUnsupportedError);

    final slower = applyRound(third, [
      result('ana', at: 5.0, gain: 175),
    ], 'Willow');
    expect(
      scoreOf(slower, 'ana').fastest,
      const FastestAnswer(seconds: 2.6, song: 'Mine'),
    );
    expect(scoreOf(slower, 'ana').streak, 1);
    expect(scoreOf(slower, 'ana').best, 2);
    expect(scoreOf(slower, 'ana').wins, 3);
  });

  test('status lines follow the round and the mode', () {
    for (final mode in TogetherMode.values) {
      expect(status(mode: mode), 'Listening…');
      expect(status(mode: mode, answer: AnswerStatus.answered), 'Answered');
      expect(
        status(mode: mode, answer: AnswerStatus.answered, left: true),
        'Left',
      );
      expect(status(mode: mode, revealed: true, left: true), 'Left');
    }
    expect(
      status(mode: TogetherMode.quickDraw, answer: AnswerStatus.out),
      'Sitting out',
    );
    expect(
      status(
        mode: TogetherMode.quickDraw,
        answer: AnswerStatus.answered,
        wonQuickDraw: true,
      ),
      'Got it first',
    );

    expect(
      status(
        mode: TogetherMode.quickDraw,
        revealed: true,
        answer: AnswerStatus.answered,
        wonQuickDraw: true,
        outcome: result('ana', at: 1.4, gain: 100),
      ),
      'Got it first',
    );
    expect(
      status(
        mode: TogetherMode.quickDraw,
        revealed: true,
        answer: AnswerStatus.out,
        outcome: result('ana', right: false),
      ),
      'Wrong guess',
    );
    expect(
      status(
        mode: TogetherMode.quickDraw,
        revealed: true,
        answer: AnswerStatus.answered,
        outcome: result('ana', at: 2.2),
      ),
      '—',
    );
    expect(status(mode: TogetherMode.quickDraw, revealed: true), '—');

    for (final mode in [TogetherMode.classic, TogetherMode.lyricsOrLie]) {
      expect(
        status(
          mode: mode,
          revealed: true,
          answer: AnswerStatus.answered,
          outcome: result('ana', at: 2.34, gain: 188),
        ),
        'Right · 2.3 s',
      );
      expect(
        status(
          mode: mode,
          revealed: true,
          answer: AnswerStatus.answered,
          outcome: result('ana', right: false, at: 4),
        ),
        'Wrong',
      );
      expect(
        status(
          mode: mode,
          revealed: true,
          outcome: result('ana', right: false, at: null),
        ),
        'No answer',
      );
      expect(status(mode: mode, revealed: true), 'No answer');
    }
  });

  test('highlights pick the fastest answer and the longest streak', () {
    const players = [
      PlayerScore(
        id: 'ana',
        score: 540,
        streak: 0,
        best: 2,
        wins: 3,
        fastest: FastestAnswer(seconds: 2.4, song: 'Enchanted'),
        left: false,
      ),
      PlayerScore(
        id: 'maya',
        score: 560,
        streak: 3,
        best: 3,
        wins: 3,
        fastest: FastestAnswer(seconds: 1.8, song: 'Mine'),
        left: false,
      ),
      PlayerScore(
        id: 'lena',
        score: 0,
        streak: 0,
        best: 0,
        wins: 0,
        fastest: null,
        left: true,
      ),
      PlayerScore(
        id: 'jo',
        score: 180,
        streak: 1,
        best: 3,
        wins: 1,
        fastest: FastestAnswer(seconds: 1.8, song: 'Style'),
        left: false,
      ),
    ];

    expect(fastestHighlight(players), (
      id: 'maya',
      fastest: const FastestAnswer(seconds: 1.8, song: 'Mine'),
    ));
    expect(streakHighlight(players), (id: 'maya', best: 3));

    const nobody = [PlayerScore.start('ana'), PlayerScore.start('maya')];
    expect(fastestHighlight(nobody), isNull);
    expect(streakHighlight(nobody), isNull);
    expect(fastestHighlight(const []), isNull);
    expect(streakHighlight(const []), isNull);
  });

  test('a close classic finish is noticed at most every three rounds', () {
    bool close(
      int round,
      int lastRemarkRound, {
      TogetherMode mode = TogetherMode.classic,
      List<double> rightTimes = const [2.3, 4.1, 2.0],
    }) => closeFinish(
      mode: mode,
      rightTimes: rightTimes,
      round: round,
      lastRemarkRound: lastRemarkRound,
    );

    const never = -closeFinishEvery;
    expect(close(1, never), isTrue);
    expect(close(2, 1), isFalse);
    expect(close(3, 1), isFalse);
    expect(close(4, 1), isTrue);

    expect(close(4, never, rightTimes: const [2.0, 2.5]), isFalse);
    expect(close(4, never, rightTimes: const [2.0, 2.49]), isTrue);
    expect(close(4, never, rightTimes: const [2.0]), isFalse);
    expect(close(4, never, rightTimes: const []), isFalse);

    for (final mode in [TogetherMode.quickDraw, TogetherMode.lyricsOrLie]) {
      expect(close(1, never, mode: mode), isFalse);
      expect(close(4, 1, mode: mode), isFalse);
    }
  });
}
