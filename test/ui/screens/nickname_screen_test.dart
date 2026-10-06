import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/misu_controller.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/serif_input.dart';
import 'package:swiftie_quiz/ui/screens/nickname_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';

const String heading = 'Hi. What should we call you?';
const String explanation =
    "It's only used in the app. You can change it in Settings.";
const String placeholder = 'Your nickname';
const String submitLabel = "Let's go →";

class RecordingMisu extends MisuController {
  int introductions = 0;

  @override
  void introduce() => introductions += 1;
}

Widget nicknameApp(
  ProviderContainer container, {
  Widget home = const NicknameScreen(),
}) => UncontrolledProviderScope(
  key: UniqueKey(),
  container: container,
  child: MaterialApp(
    theme: AppTheme.dark,
    home: Material(child: home),
  ),
);

Future<ProviderContainer> pumpNickname(
  WidgetTester tester, {
  Size window = const Size(1024, 800),
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer.test(
    overrides: [
      editionProvider.overrideWithValue(Edition.open),
      misuControllerProvider.overrideWith(RecordingMisu.new),
    ],
  );
  container.read(gameControllerProvider.notifier).setPhase(GamePhase.nickname);
  await tester.pumpWidget(nicknameApp(container));
  return container;
}

RecordingMisu misuOf(ProviderContainer container) =>
    container.read(misuControllerProvider.notifier) as RecordingMisu;

EditableText fieldOf(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText));

double submitOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text(submitLabel),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

void expectConsistentSizing(WidgetTester tester) {
  final row =
      tester.renderObject<RenderBox>(find.byType(SerifInput)).parent!
          as RenderBox;
  expect(row.getDryLayout(row.constraints), row.size);
  expect(row.getMinIntrinsicHeight(row.size.width), row.size.height);
  expect(row.getMaxIntrinsicHeight(row.size.width), row.size.height);
  expect(
    row.getMinIntrinsicWidth(double.infinity),
    lessThanOrEqualTo(row.getMaxIntrinsicWidth(double.infinity)),
  );
  expect(row.getMinIntrinsicWidth(double.infinity), greaterThanOrEqualTo(240));
}

void main() {
  testWidgets('a nickname is saved on enter and opens the menu', (
    tester,
  ) async {
    final container = await pumpNickname(tester);
    final misu = misuOf(container);
    String? nickname() =>
        container.read(gameControllerProvider).progress.settings.nickname;
    GamePhase phase() => container.read(gameControllerProvider).phase;

    expect(find.text(heading), findsOneWidget);
    expect(find.text(explanation), findsOneWidget);
    expect(find.text(placeholder), findsOneWidget);
    final style = fieldOf(tester).style;
    expect(style.fontFamily, 'Instrument Serif');
    expect(style.fontStyle, FontStyle.italic);
    expect(style.fontSize, 44);
    expect(style.height, 52 / 44);

    expect(submitOpacity(tester), 0.45);
    await tester.tap(find.text(submitLabel), warnIfMissed: false);
    await tester.pump();
    expect(nickname(), isNull);
    expect(phase(), GamePhase.nickname);

    await tester.pump(const Duration(milliseconds: 799));
    expect(misu.introductions, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(misu.introductions, 1);

    await tester.enterText(
      find.byType(EditableText),
      'Abcdefghijklmnopqrstuvwxy',
    );
    await tester.pump();
    expect(fieldOf(tester).controller.text, 'Abcdefghijklmnopqrst');

    await tester.enterText(find.byType(EditableText), 'Ana Lee');
    await tester.pump();
    expect(submitOpacity(tester), 1);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(nickname(), 'Ana Lee');
    expect(phase(), GamePhase.menu);
    expect(misu.introductions, 1);
  });

  testWidgets('the field takes focus 400 ms after the screen appears', (
    tester,
  ) async {
    await pumpNickname(tester);

    await tester.pump(const Duration(milliseconds: 399));
    expect(fieldOf(tester).focusNode.hasFocus, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(fieldOf(tester).focusNode.hasFocus, isTrue);
  });

  testWidgets(
    'a blank nickname is ignored and the button saves a trimmed one',
    (tester) async {
      final container = await pumpNickname(tester);
      await tester.pump(const Duration(milliseconds: 800));

      await tester.enterText(find.byType(EditableText), '   ');
      await tester.pump();
      expect(submitOpacity(tester), 0.45);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        container.read(gameControllerProvider).progress.settings.nickname,
        isNull,
      );
      expect(container.read(gameControllerProvider).phase, GamePhase.nickname);
      expect(fieldOf(tester).focusNode.hasFocus, isTrue);

      await tester.enterText(find.byType(EditableText), '  Sam  ');
      await tester.pump();
      await tester.tap(find.text(submitLabel));
      await tester.pump();

      expect(
        container.read(gameControllerProvider).progress.settings.nickname,
        'Sam',
      );
      expect(container.read(gameControllerProvider).phase, GamePhase.menu);
    },
  );

  testWidgets('leaving before 800 ms cancels the introduction', (tester) async {
    final container = await pumpNickname(tester);
    final misu = misuOf(container);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(nicknameApp(container, home: const SizedBox()));
    await tester.pump(const Duration(seconds: 1));

    expect(misu.introductions, 0);
  });

  testWidgets(
    'the field fills the row beside the button and wraps above it when narrow',
    (tester) async {
      await pumpNickname(tester);
      await tester.pump(const Duration(milliseconds: 800));

      final field = tester.getRect(find.byType(SerifInput));
      final button = tester.getRect(find.byType(PillButton));
      expect(field.left, 56);
      expect(button.right, 56 + 640);
      expect(button.left - field.right, 20);
      expect(field.bottom, button.bottom);
      expect(field.width, greaterThanOrEqualTo(240));
      expectConsistentSizing(tester);

      await pumpNickname(tester, window: const Size(400, 800));
      await tester.pump(const Duration(milliseconds: 800));

      final narrowField = tester.getRect(find.byType(SerifInput));
      final narrowButton = tester.getRect(find.byType(PillButton));
      expect(narrowField.left, 32);
      expect(narrowField.width, 400 - 64);
      expect(narrowButton.left, 32);
      expect(narrowButton.top - narrowField.bottom, 20);
      expectConsistentSizing(tester);
    },
  );
}
