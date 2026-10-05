import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/ui/game/result_feedback.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';
import 'package:swiftie_quiz/ui/widgets/primary_button.dart';

Track _makeTrack({String titleShort = 'Love Story'}) => Track(
  id: 1,
  title: 'Love Story',
  titleShort: titleShort,
  duration: 30,
  preview: 'https://example.com/p.mp3',
  artist: const Artist(id: 12246, name: 'Taylor Swift'),
  album: const Album(id: 100, title: 'Fearless', coverMedium: null),
);

Widget _host(ResultFeedback feedback) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: Center(child: feedback)),
);

Finder _nextButton(String label) => find.widgetWithText(PrimaryButton, label);

Finder _positiveMessage(List<String> messages) => find.byWidgetPredicate(
  (widget) => widget is Text && messages.contains(widget.data),
);

void main() {
  group('result feedback parity', () {
    testWidgets("renders Next button disabled initially with 'Next...' text", (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ResultFeedback(
            correct: true,
            correctTrack: _makeTrack(),
            onNext: () {},
          ),
        ),
      );

      final button = tester.widget<PrimaryButton>(_nextButton('Next...'));
      expect(button.onPressed, isNull);
      expect(_nextButton('Next'), findsNothing);
    });

    testWidgets('enables Next button after 2 seconds', (tester) async {
      await tester.pumpWidget(
        _host(
          ResultFeedback(
            correct: true,
            correctTrack: _makeTrack(),
            onNext: () {},
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1999));
      expect(_nextButton('Next...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      final button = tester.widget<PrimaryButton>(_nextButton('Next'));
      expect(button.onPressed, isNotNull);
      expect(button.cursor, SystemMouseCursors.click);
    });

    testWidgets('shows correct track info on incorrect answer', (tester) async {
      await tester.pumpWidget(
        _host(
          ResultFeedback(
            correct: false,
            correctTrack: _makeTrack(),
            onNext: () {},
          ),
        ),
      );

      expect(find.textContaining('Love Story'), findsOneWidget);
      expect(find.textContaining('Taylor Swift'), findsOneWidget);
      expect(find.text('It was “Love Story”'), findsOneWidget);
      expect(find.text('by Taylor Swift'), findsOneWidget);
    });

    testWidgets('shows a positive message on correct answer', (tester) async {
      await tester.pumpWidget(
        _host(
          ResultFeedback(
            correct: true,
            correctTrack: _makeTrack(),
            onNext: () {},
          ),
        ),
      );

      expect(_positiveMessage(positiveMessages), findsOneWidget);
    });

    testWidgets('does not call onNext when button is clicked while disabled', (
      tester,
    ) async {
      var nextCalls = 0;
      await tester.pumpWidget(
        _host(
          ResultFeedback(
            correct: true,
            correctTrack: _makeTrack(),
            onNext: () => nextCalls++,
          ),
        ),
      );

      await tester.tap(_nextButton('Next...'));
      await tester.pump();

      expect(nextCalls, 0);
    });

    testWidgets('does not change the positive message after the 2s re-render', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ResultFeedback(
            correct: true,
            correctTrack: _makeTrack(),
            onNext: () {},
          ),
        ),
      );
      final before = tester
          .widget<Text>(_positiveMessage(positiveMessages))
          .data;

      await tester.pump(ResultFeedback.nextDelay);

      final after = tester
          .widget<Text>(_positiveMessage(positiveMessages))
          .data;
      expect(after, before);
    });

    testWidgets('Next calls onNext once enabled', (tester) async {
      var nextCalls = 0;
      await tester.pumpWidget(
        _host(
          ResultFeedback(
            correct: true,
            correctTrack: _makeTrack(),
            onNext: () => nextCalls++,
          ),
        ),
      );

      await tester.pump(ResultFeedback.nextDelay);
      await tester.tap(_nextButton('Next'));
      await tester.pump();

      expect(nextCalls, 1);
    });

    testWidgets('lyrics rounds draw from the 30 lyrics messages', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ResultFeedback(
            correct: true,
            correctTrack: _makeTrack(),
            onNext: () {},
            quizType: QuizType.lyrics,
            lyricsMode: LyricsMode.nameThatSong,
          ),
        ),
      );

      expect(_positiveMessage(lyricsPositiveMessages), findsOneWidget);
    });

    testWidgets('a missed decoy names the song it came from', (tester) async {
      await tester.pumpWidget(
        _host(
          ResultFeedback(
            correct: false,
            correctTrack: _makeTrack(),
            onNext: () {},
            quizType: QuizType.lyrics,
            lyricsMode: LyricsMode.lyricsOrLie,
            decoySourceSong: 'Mine',
          ),
        ),
      );

      expect(find.text('That\'s actually from “Mine”.'), findsOneWidget);
      expect(find.textContaining('Taylor Swift'), findsNothing);
    });

    testWidgets('a missed real lyric says it was real', (tester) async {
      await tester.pumpWidget(
        _host(
          ResultFeedback(
            correct: false,
            correctTrack: _makeTrack(),
            onNext: () {},
            quizType: QuizType.lyrics,
            lyricsMode: LyricsMode.lyricsOrLie,
          ),
        ),
      );

      expect(find.text("Nope — that one's real!"), findsOneWidget);
    });

    testWidgets('a missed song falls back to the full title', (tester) async {
      await tester.pumpWidget(
        _host(
          ResultFeedback(
            correct: false,
            correctTrack: _makeTrack(titleShort: ''),
            onNext: () {},
            quizType: QuizType.lyrics,
            lyricsMode: LyricsMode.nameThatSong,
          ),
        ),
      );

      expect(find.text('It was “Love Story”'), findsOneWidget);
    });

    testWidgets('the result panel enters from scale 0.9', (tester) async {
      await tester.pumpWidget(
        _host(
          ResultFeedback(
            correct: true,
            correctTrack: _makeTrack(),
            onNext: () {},
          ),
        ),
      );

      final entrance = tester.widget<Entrance>(find.byType(Entrance));
      expect(entrance.fromScale, ResultFeedback.panelEntranceScale);
      expect(entrance.fromOpacity, 0);
      expect(ResultFeedback.panelEntranceScale, 0.9);
    });

    group('drawNextMessage', () {
      test('never returns the same message twice in a row', () {
        var previous = drawNextMessage();
        for (var i = 0; i < 100; i++) {
          final next = drawNextMessage();
          expect(next, isNot(previous));
          previous = next;
        }
      });

      test('cycles through all 22 messages within two full cycles', () {
        final seen = <String>{for (var i = 0; i < 44; i++) drawNextMessage()};

        expect(seen, hasLength(22));
        expect(seen, positiveMessages.toSet());
      });

      test('cycles through all 30 lyrics messages within two full cycles', () {
        final seen = <String>{
          for (var i = 0; i < 60; i++) drawNextMessage(QuizType.lyrics),
        };

        expect(seen, hasLength(30));
        expect(seen, lyricsPositiveMessages.toSet());
      });
    });
  });
}
