import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/domain/together/scoring.dart';

int gain(
  TogetherMode mode, {
  bool right = true,
  double at = 5,
  Difficulty difficulty = Difficulty.medium,
  bool won = false,
}) => roundGain(mode, right: right, at: at, difficulty: difficulty, won: won);

TimedAnswer answer(String id, {required int receivedMs, double at = 2}) =>
    TimedAnswer(
      playerId: id,
      right: true,
      at: at,
      receivedAt: Duration(milliseconds: receivedMs),
    );

void main() {
  test('each mode scores as the prototype does', () {
    expect(gain(TogetherMode.classic, at: 5), 175);
    expect(gain(TogetherMode.classic, at: 0), 200);
    expect(gain(TogetherMode.classic, at: 20), 100);
    expect(gain(TogetherMode.classic, at: 21.4), 100);
    expect(gain(TogetherMode.classic, at: 2.5), 188);
    expect(gain(TogetherMode.classic, right: false, at: 5), 0);
    expect(gain(TogetherMode.classic, right: false, at: 0, won: true), 0);

    expect(gain(TogetherMode.quickDraw, won: true), 100);
    expect(gain(TogetherMode.quickDraw, at: 0.4), 0);
    expect(gain(TogetherMode.quickDraw, right: false), 0);

    expect(gain(TogetherMode.lyricsOrLie, at: 1), 100);
    expect(gain(TogetherMode.lyricsOrLie, at: 19), 100);
    expect(gain(TogetherMode.lyricsOrLie, right: false), 0);
  });

  test('quick draw goes to the fastest right answer inside the window', () {
    final answers = [
      answer('ana', receivedMs: 0, at: 4.0),
      answer('maya', receivedMs: 300, at: 3.5),
      answer('lena', receivedMs: 700, at: 1.0),
      const TimedAnswer(
        playerId: 'jo',
        right: false,
        at: 0.5,
        receivedAt: Duration(milliseconds: 100),
      ),
    ];

    expect(quickDrawWinner(answers), 'maya');
    expect(quickDrawWinner(answers.reversed.toList()), 'maya');
    expect(
      quickDrawWinner([
        answer('ana', receivedMs: 200, at: 3.0),
        answer('maya', receivedMs: 100, at: 3.0),
      ]),
      'maya',
    );
    expect(quickDrawWinner([answers.last]), isNull);
    expect(quickDrawWinner(const []), isNull);

    expect(
      answerStatus(TogetherMode.quickDraw, right: false),
      AnswerStatus.out,
    );
    expect(
      answerStatus(TogetherMode.quickDraw, right: true),
      AnswerStatus.answered,
    );
    expect(
      answerStatus(TogetherMode.classic, right: false),
      AnswerStatus.answered,
    );
    expect(
      answerStatus(TogetherMode.lyricsOrLie, right: false),
      AnswerStatus.answered,
    );

    expect(
      everyoneDone(
        ['ana', 'jo'],
        {'ana': AnswerStatus.answered, 'jo': AnswerStatus.out},
      ),
      isTrue,
    );
    expect(everyoneDone(['ana', 'jo'], {'jo': AnswerStatus.out}), isFalse);
    expect(everyoneDone(['ana'], {'ana': AnswerStatus.answered}), isTrue);
  });

  test('round limits follow difficulty only', () {
    expect(roundSeconds(Difficulty.easy), 30);
    expect(roundSeconds(Difficulty.medium), 20);
    expect(roundSeconds(Difficulty.hard), 12);

    expect(
      difficultyNote(Difficulty.easy),
      'Album cover shown · 30 seconds a round',
    );
    expect(difficultyNote(Difficulty.medium), 'No hints · 20 seconds a round');
    expect(difficultyNote(Difficulty.hard), 'No hints · 12 seconds a round');

    expect(
      gain(TogetherMode.classic, at: 15, difficulty: Difficulty.easy),
      150,
    );
    expect(gain(TogetherMode.classic, at: 6, difficulty: Difficulty.hard), 150);
    expect(
      gain(TogetherMode.classic, at: 12, difficulty: Difficulty.hard),
      100,
    );
    expect(
      gain(TogetherMode.classic, at: 12, difficulty: Difficulty.easy),
      160,
    );
  });
}
