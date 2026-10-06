import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/ui/game/quiz_card.dart';
import 'package:swiftie_quiz/ui/widgets/motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/widgets/primary_button.dart';

const Artist _taylor = Artist(id: 12246, name: 'Taylor Swift');
const Album _fearless = Album(id: 100, title: 'Fearless', coverMedium: null);

Track _track(int id, String title, {String? titleShort}) => Track(
  id: id,
  title: title,
  titleShort: titleShort ?? title,
  duration: 200,
  preview: 'https://cdnt-preview.dzcdn.net/api/1/1/$id.mp3',
  artist: _taylor,
  album: _fearless,
);

final List<Track> _options = [
  _track(1, 'Love Story (Taylor’s Version)', titleShort: 'Love Story'),
  _track(2, 'You Belong With Me'),
  _track(3, 'Fifteen', titleShort: ''),
  _track(4, 'White Horse'),
];

Widget _host({
  required Difficulty difficulty,
  required ValueChanged<Object> onAnswer,
  String? albumHint,
  bool disabled = false,
}) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 600,
        child: QuizCard(
          difficulty: difficulty,
          options: _options,
          albumHint: albumHint,
          onAnswer: onAnswer,
          disabled: disabled,
        ),
      ),
    ),
  ),
);

Finder get _field => find.byType(TextField);

PrimaryButton _submitButton(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Submit'));

void main() {
  group('quiz card parity', () {
    testWidgets('easy shows the album hint and every option label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          difficulty: Difficulty.easy,
          albumHint: 'Fearless',
          onAnswer: (_) {},
        ),
      );

      expect(find.text('Album: Fearless'), findsOneWidget);
      expect(find.text('Love Story'), findsOneWidget);
      expect(find.text('You Belong With Me'), findsOneWidget);
      expect(find.text('Fifteen'), findsOneWidget);
      expect(find.text('White Horse'), findsOneWidget);
      expect(_field, findsNothing);
    });

    testWidgets('medium shows options without the album hint', (tester) async {
      await tester.pumpWidget(
        _host(
          difficulty: Difficulty.medium,
          albumHint: 'Fearless',
          onAnswer: (_) {},
        ),
      );

      expect(find.text('Album: Fearless'), findsNothing);
      expect(find.text('Love Story'), findsOneWidget);
      expect(_field, findsNothing);
    });

    testWidgets('tapping an option answers with its track id', (tester) async {
      final answers = <Object>[];
      await tester.pumpWidget(
        _host(difficulty: Difficulty.easy, onAnswer: answers.add),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('White Horse'));
      await tester.tap(find.text('Love Story'));

      expect(answers, [4, 1]);
    });

    testWidgets('disabled options are dimmed and ignore taps', (tester) async {
      final answers = <Object>[];
      await tester.pumpWidget(
        _host(
          difficulty: Difficulty.medium,
          onAnswer: answers.add,
          disabled: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Love Story'));

      expect(answers, isEmpty);
      final dimmed = tester.widgetList<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(dimmed.map((opacity) => opacity.opacity), everyElement(0.5));
    });

    testWidgets('options enter 0.05 s apart from 10 px to the left', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(difficulty: Difficulty.easy, onAnswer: (_) {}),
      );

      final motions = tester.widgetList<Motion>(find.byType(Motion)).toList();
      expect(motions.map((motion) => motion.delay), const [
        Duration.zero,
        Duration(milliseconds: 50),
        Duration(milliseconds: 100),
        Duration(milliseconds: 150),
      ]);
      expect(
        motions.map((motion) => motion.initial),
        everyElement(const MotionPose(opacity: 0, offset: Offset(-10, 0))),
      );
    });

    testWidgets('hard shows a focused text box instead of options', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          difficulty: Difficulty.hard,
          albumHint: 'Fearless',
          onAnswer: (_) {},
        ),
      );
      await tester.pump();

      expect(find.text('Love Story'), findsNothing);
      expect(find.text('Album: Fearless'), findsNothing);
      expect(find.text('Type your answer...'), findsOneWidget);
      final field = tester.widget<TextField>(_field);
      expect(field.autofocus, isTrue);
      expect(field.focusNode!.hasFocus, isTrue);
      expect(_submitButton(tester).onPressed, isNull);
    });

    testWidgets('Enter submits the trimmed answer', (tester) async {
      final answers = <Object>[];
      await tester.pumpWidget(
        _host(difficulty: Difficulty.hard, onAnswer: answers.add),
      );
      await tester.pump();

      await tester.enterText(_field, '  love story  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(answers, ['love story']);
      expect(tester.widget<TextField>(_field).focusNode!.hasFocus, isTrue);
    });

    testWidgets('Enter with only spaces submits nothing', (tester) async {
      final answers = <Object>[];
      await tester.pumpWidget(
        _host(difficulty: Difficulty.hard, onAnswer: answers.add),
      );
      await tester.pump();

      await tester.enterText(_field, '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(answers, isEmpty);
      expect(_submitButton(tester).onPressed, isNull);
    });

    testWidgets('Submit enables with text and submits it', (tester) async {
      final answers = <Object>[];
      await tester.pumpWidget(
        _host(difficulty: Difficulty.hard, onAnswer: answers.add),
      );
      await tester.pump();

      await tester.enterText(_field, 'Fifteen');
      await tester.pump();
      expect(_submitButton(tester).onPressed, isNotNull);

      await tester.tap(find.text('Submit'));
      await tester.pump();

      expect(answers, ['Fifteen']);
    });

    testWidgets('a disabled hard card blocks typing and submitting', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(difficulty: Difficulty.hard, onAnswer: (_) {}, disabled: true),
      );
      await tester.pump();

      expect(tester.widget<TextField>(_field).enabled, isFalse);
      expect(_submitButton(tester).onPressed, isNull);
    });
  });
}
