import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/kit/arrow_row.dart';
import 'package:swiftie_quiz/ui/kit/bead.dart';
import 'package:swiftie_quiz/ui/kit/choice_row.dart';
import 'package:swiftie_quiz/ui/kit/confirm_dialog.dart';
import 'package:swiftie_quiz/ui/kit/modal_stack.dart';
import 'package:swiftie_quiz/ui/kit/option_tile.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/kit/section_label.dart';
import 'package:swiftie_quiz/ui/kit/segmented.dart';
import 'package:swiftie_quiz/ui/kit/serif_input.dart';
import 'package:swiftie_quiz/ui/kit/swiftie_modal.dart';
import 'package:swiftie_quiz/ui/kit/text_link.dart';
import 'package:swiftie_quiz/ui/kit/two_pane.dart';
import 'package:swiftie_quiz/ui/kit/vinyl.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/ui/widgets/back_link.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';

const themes = [('dark', Brightness.dark), ('light', Brightness.light)];

AppTokens tokensFor(Brightness brightness) =>
    brightness == Brightness.dark ? AppTokens.dark : AppTokens.light;

Future<void> pumpKit(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.dark,
  Size size = const Size(1024, 800),
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        themeAnimationDuration: Duration.zero,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reducedMotion),
          child: app!,
        ),
        home: Material(child: child),
      ),
    ),
  );
}

const parked = Offset(1023, 799);

Future<TestGesture> mouseOf(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: parked);
  addTearDown(mouse.removePointer);
  return mouse;
}

Future<void> hover(
  WidgetTester tester,
  TestGesture mouse,
  Finder target,
) async {
  await mouse.moveTo(tester.getCenter(target));
  await tester.pumpAndSettle();
}

Future<void> leave(WidgetTester tester, TestGesture mouse) async {
  await mouse.moveTo(parked);
  await tester.pumpAndSettle();
}

Color? inkOf(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text).text.style?.color;

BoxDecoration boxAround(WidgetTester tester, Finder text) =>
    tester
            .widget<DecoratedBox>(
              find
                  .ancestor(of: text, matching: find.byType(DecoratedBox))
                  .first,
            )
            .decoration
        as BoxDecoration;

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

Finder focusRings(Color coral) => find.byWidgetPredicate(
  (widget) =>
      widget is DecoratedBox &&
      widget.position == DecorationPosition.foreground &&
      widget.decoration is BoxDecoration &&
      (widget.decoration as BoxDecoration).border ==
          Border.all(
            color: coral,
            width: Pressable.focusRingWidth,
            strokeAlign:
                BorderSide.strokeAlignOutside +
                2 * Pressable.focusRingGap / Pressable.focusRingWidth,
          ),
);

void main() {
  testWidgets('the chosen segment paints the button colours', (tester) async {
    for (final (name, brightness) in themes) {
      final tokens = tokensFor(brightness);
      var changes = const <String>[];
      await pumpKit(
        tester,
        Center(
          child: Segmented<String>(
            options: const [
              ('dark', 'Dark'),
              ('light', 'Light'),
              ('system', 'System'),
            ],
            value: 'light',
            onChanged: (value) => changes = [...changes, value],
          ),
        ),
        brightness: brightness,
      );
      await tester.pumpAndSettle();

      final chosen = find.text('Light');
      expect(boxAround(tester, chosen).color, tokens.btn, reason: name);
      expect(inkOf(tester, chosen), tokens.onBtn, reason: name);
      for (final label in ['Dark', 'System']) {
        final other = find.text(label);
        expect(boxAround(tester, other).color?.a, 0, reason: '$name $label');
        expect(inkOf(tester, other), tokens.mut, reason: '$name $label');
      }

      await tester.tap(find.text('System'));
      await tester.pump();
      expect(changes, ['system'], reason: name);
    }
  });

  testWidgets('two pane stacks into one column below 900 px', (tester) async {
    const left = Key('left');
    const right = Key('right');
    Widget pane(Key key, double height) =>
        SizedBox(key: key, height: height, width: double.infinity);
    final tokens = tokensFor(Brightness.dark);
    final divider = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).border ==
              Border(right: BorderSide(color: tokens.line)),
    );

    await pumpKit(
      tester,
      TwoPane(left: pane(left, 120), right: pane(right, 300)),
      size: const Size(899, 800),
    );
    expect(tester.getTopLeft(find.byKey(left)), Offset.zero);
    expect(tester.getTopLeft(find.byKey(right)), const Offset(0, 120));
    expect(tester.getSize(find.byKey(left)).width, 899);
    expect(tester.getSize(find.byKey(right)).width, 899);
    expect(divider, findsNothing);

    await pumpKit(
      tester,
      TwoPane(left: pane(left, 120), right: pane(right, 1200)),
      size: const Size(1024, 800),
    );
    expect(tester.getTopLeft(find.byKey(left)), Offset.zero);
    expect(tester.getTopLeft(find.byKey(right)), const Offset(380, 0));
    expect(tester.getSize(find.byKey(left)).width, 379);
    expect(tester.getSize(find.byKey(right)).width, 1024 - 380);
    expect(divider, findsOneWidget);
    expect(tester.getRect(divider), const Rect.fromLTWH(0, 0, 380, 1200));
    expect(tester.getSize(find.byKey(left)).height, 1200);
  });

  testWidgets(
    'a disabled pill button is drawn at 45 percent and ignores taps',
    (tester) async {
      var presses = 0;
      await pumpKit(
        tester,
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PillButton(
                label: 'Off',
                size: PillSize.large,
                enabled: false,
                onPressed: () => presses += 1,
              ),
              const PillButton(label: 'Unwired', onPressed: null),
              PillButton(label: 'On', onPressed: () => presses += 100),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      double opacityOf(String label) => tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;

      expect(PillButton.disabledOpacity, 0.45);
      expect(opacityOf('Off'), 0.45);
      expect(opacityOf('Unwired'), 0.45);
      expect(opacityOf('On'), 1);

      await tester.tap(find.text('Off'), warnIfMissed: false);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(presses, 100);

      await tester.tap(find.text('On'));
      await tester.pump();
      expect(presses, 200);
    },
  );

  testWidgets(
    'the confirm dialog answers false on escape and true on confirm',
    (tester) async {
      await pumpKit(tester, const SizedBox.expand());
      final context = tester.element(find.byType(SizedBox));

      Future<(Future<bool>,)> open({bool destructive = false}) async {
        final answer = showConfirmDialog(
          context,
          title: 'Reset progress?',
          message: 'This clears your record shelf and stats.',
          confirmLabel: 'Reset',
          destructive: destructive,
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('Reset progress?'), findsOneWidget);
        expect(containerOf(tester).read(modalStackProvider), hasLength(1));
        return (answer,);
      }

      final (escaped,) = await open();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(await escaped, isFalse);
      expect(find.text('Reset progress?'), findsNothing);
      expect(containerOf(tester).read(modalStackProvider), isEmpty);

      final (confirmed,) = await open();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(await confirmed, isTrue);

      final (cancelled,) = await open(destructive: true);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await cancelled, isFalse);

      final (scrimmed,) = await open();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(await scrimmed, isFalse);
      expect(containerOf(tester).read(modalStackProvider), isEmpty);
    },
  );

  testWidgets('the confirm dialog draws the handoff panel and buttons', (
    tester,
  ) async {
    for (final (name, brightness) in themes) {
      final tokens = tokensFor(brightness);
      await pumpKit(tester, const SizedBox.expand(), brightness: brightness);
      final context = tester.element(find.byType(SizedBox));
      for (final destructive in [false, true]) {
        final answer = showConfirmDialog(
          context,
          title: 'Restore this backup?',
          message: 'Your current save will be replaced with this one.',
          confirmLabel: 'Restore',
          destructive: destructive,
        );
        await tester.pumpAndSettle();

        final panel = find.ancestor(
          of: find.text('Restore this backup?'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).color == tokens.panel,
          ),
        );
        expect(panel, findsOneWidget, reason: name);
        final decoration =
            tester.widget<DecoratedBox>(panel).decoration as BoxDecoration;
        expect(decoration.borderRadius, SwiftieModal.radius, reason: name);
        expect(decoration.border, Border.all(color: tokens.line2));
        expect(tester.getSize(panel).width, 440, reason: name);

        final title = tester.widget<Text>(find.text('Restore this backup?'));
        expect(title.style?.fontFamily, AppType.serifFamily);
        expect(title.style?.fontSize, 30);
        expect(inkOf(tester, find.text('Cancel')), tokens.mut, reason: name);
        expect(
          boxAround(tester, find.text('Restore')).color,
          destructive ? tokens.rose : tokens.coral,
          reason: '$name $destructive',
        );
        expect(
          inkOf(tester, find.text('Restore')),
          destructive ? tokens.bg : tokens.onCoral,
          reason: '$name $destructive',
        );
        final scrim = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byType(BackdropFilter),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(scrim.color, tokens.scrim, reason: name);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(await answer, isFalse);
      }
    }
  });

  testWidgets('only the newest modal answers escape', (tester) async {
    var dismissed = const <String>[];
    Widget modal(String name) => SwiftieModal(
      onDismiss: () => dismissed = [...dismissed, name],
      child: Text(name),
    );

    await pumpKit(tester, Stack(children: [modal('update'), modal('confirm')]));
    await tester.pumpAndSettle();
    expect(containerOf(tester).read(modalStackProvider), hasLength(2));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(dismissed, ['confirm']);

    await pumpKit(tester, Stack(children: [modal('update')]));
    await tester.pumpAndSettle();
    expect(containerOf(tester).read(modalStackProvider), hasLength(1));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(dismissed, ['confirm', 'update']);

    await pumpKit(tester, const SizedBox());
    await tester.pumpAndSettle();
    expect(containerOf(tester).read(modalStackProvider), isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(dismissed, ['confirm', 'update']);
  });

  testWidgets('a modal holds keyboard focus and hands it back on close', (
    tester,
  ) async {
    var behind = 0;
    var inside = 0;
    final open = ValueNotifier(false);
    addTearDown(open.dispose);
    await pumpKit(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: open,
        builder: (context, isOpen, _) => Stack(
          children: [
            Center(
              child: PillButton(
                label: 'Next song →',
                onPressed: () => behind += 1,
              ),
            ),
            if (isOpen)
              SwiftieModal(
                onDismiss: () => open.value = false,
                child: PillButton(
                  label: 'Install',
                  onPressed: () => inside += 1,
                ),
              ),
          ],
        ),
      ),
    );
    FocusNode focusOf(String label) =>
        Focus.of(tester.element(find.text(label)));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusOf('Next song →').hasPrimaryFocus, isTrue);

    open.value = true;
    await tester.pumpAndSettle();
    expect(focusOf('Next song →').hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(behind, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusOf('Install').hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect((behind, inside), (0, 1));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Install'), findsNothing);
    expect(focusOf('Next song →').hasPrimaryFocus, isTrue);
  });

  test('the modal stack keeps unmodifiable keys in opening order', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final stack = container.read(modalStackProvider.notifier);
    final first = Object();
    final second = Object();

    stack
      ..push(first)
      ..push(second);
    expect(container.read(modalStackProvider), [first, second]);
    expect(
      () => container.read(modalStackProvider).add(Object()),
      throwsUnsupportedError,
    );

    stack.remove(first);
    expect(container.read(modalStackProvider), [second]);
    stack
      ..remove(first)
      ..remove(second);
    expect(container.read(modalStackProvider), isEmpty);
  });

  testWidgets('pill kinds paint their handoff colours in both themes', (
    tester,
  ) async {
    final mouse = await mouseOf(tester);
    for (final (name, brightness) in themes) {
      final tokens = tokensFor(brightness);
      await pumpKit(
        tester,
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final kind in PillKind.values)
                PillButton(label: kind.name, kind: kind, onPressed: () {}),
            ],
          ),
        ),
        brightness: brightness,
      );
      await tester.pumpAndSettle();
      final expected = {
        PillKind.coral: (tokens.coral, tokens.onCoral, FontWeight.w600),
        PillKind.solid: (tokens.btn, tokens.onBtn, FontWeight.w600),
        PillKind.danger: (tokens.rose, tokens.bg, FontWeight.w600),
        PillKind.outline: (null, tokens.fg, FontWeight.w400),
        PillKind.quiet: (null, tokens.mut, FontWeight.w400),
      };
      for (final MapEntry(key: kind, value: (fill, ink, weight))
          in expected.entries) {
        final label = find.text(kind.name);
        final box = boxAround(tester, label);
        if (fill == null) {
          expect(box.color?.a, 0, reason: '$name $kind');
        } else {
          expect(box.color, fill, reason: '$name $kind');
        }
        expect(box.borderRadius, PillButton.radius);
        expect(inkOf(tester, label), ink, reason: '$name $kind');
        expect(
          tester.renderObject<RenderParagraph>(label).text.style?.fontWeight,
          weight,
        );
      }
      expect(
        boxAround(tester, find.text('outline')).border,
        Border.all(color: tokens.line2),
      );

      await hover(tester, mouse, find.text('quiet'));
      expect(inkOf(tester, find.text('quiet')), tokens.fg, reason: name);
      expect(boxAround(tester, find.text('quiet')).color, tokens.hover);
      await leave(tester, mouse);
    }
  });

  testWidgets('pills lift on hover and shrink while pressed', (tester) async {
    await pumpKit(
      tester,
      Center(
        child: PillButton(label: 'Start →', onPressed: () {}),
      ),
    );
    final label = find.text('Start →');
    final resting = tester.getTopLeft(label);

    final mouse = await mouseOf(tester);
    await hover(tester, mouse, label);
    expect(tester.getTopLeft(label).dy, closeTo(resting.dy - 1, 1e-6));

    await mouse.down(tester.getCenter(label));
    await tester.pumpAndSettle();
    final scale = tester.widget<AnimatedScale>(
      find.ancestor(of: label, matching: find.byType(AnimatedScale)),
    );
    expect(scale.scale, AppMotion.pressScale);
    await mouse.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a keyboard-focused pill shows a coral ring and activates', (
    tester,
  ) async {
    var presses = 0;
    await pumpKit(
      tester,
      Center(
        child: PillButton(label: 'Continue →', onPressed: () => presses += 1),
      ),
    );
    final coral = AppTokens.dark.coral;
    expect(focusRings(coral), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusRings(coral), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(presses, 2);
  });

  testWidgets('arrow rows slide 8 px right on hover and mark the primary row', (
    tester,
  ) async {
    final tokens = tokensFor(Brightness.dark);
    var taps = 0;
    await pumpKit(
      tester,
      Column(
        children: [
          ArrowRow(
            title: 'Shuffle everything',
            description: 'Every era in one stack.',
            primary: true,
            onTap: () => taps += 1,
          ),
          ArrowRow(
            title: 'Pick your eras',
            description: 'Choose the albums.',
            onTap: () => taps += 10,
          ),
        ],
      ),
    );
    final title = find.text('Pick your eras');
    final resting = tester.getTopLeft(title).dx;
    expect(tester.widget<Text>(title).style?.fontSize, 38);

    await hover(tester, await mouseOf(tester), title);
    expect(tester.getTopLeft(title).dx, resting + AppMotion.rowHoverPadOffset);

    final arrows = find.text(ArrowRow.arrow);
    expect(boxAround(tester, arrows.first).color, tokens.coral);
    expect(inkOf(tester, arrows.first), tokens.onCoral);
    expect(boxAround(tester, arrows.last).color?.a, 0);
    expect(
      boxAround(tester, arrows.last).border,
      Border.all(color: tokens.line2),
    );
    expect(inkOf(tester, arrows.last), tokens.fg);
    expect(
      tester.getSize(
        find.ancestor(of: arrows.first, matching: find.byType(SizedBox)).first,
      ),
      const Size.square(ArrowRow.arrowSize),
    );

    await tester.tap(find.text('Shuffle everything'));
    await tester.tap(title);
    expect(taps, 11);
  });

  testWidgets('choice rows and option tiles mark the selection in coral', (
    tester,
  ) async {
    final mouse = await mouseOf(tester);
    for (final (name, brightness) in themes) {
      final tokens = tokensFor(brightness);
      var picks = const <String>[];
      await pumpKit(
        tester,
        Column(
          children: [
            ChoiceRow(
              title: 'Sound',
              description: 'Hear a clip, name the song.',
              selected: true,
              onTap: () => picks = [...picks, 'sound'],
            ),
            ChoiceRow(
              title: 'Lyrics',
              description: 'Read the words, test what you know.',
              selected: false,
              onTap: () => picks = [...picks, 'lyrics'],
            ),
            Row(
              children: [
                Expanded(
                  child: OptionTile(
                    title: 'Easy',
                    description: 'Quick warm-up',
                    selected: false,
                    onTap: () => picks = [...picks, 'easy'],
                  ),
                ),
                Expanded(
                  child: OptionTile(
                    title: 'Medium',
                    description: 'The real thing',
                    selected: true,
                    onTap: () => picks = [...picks, 'medium'],
                  ),
                ),
              ],
            ),
          ],
        ),
        brightness: brightness,
      );
      await tester.pumpAndSettle();

      BoxDecoration card(String title) =>
          tester
                  .widget<AnimatedContainer>(
                    find
                        .ancestor(
                          of: find.text(title),
                          matching: find.byType(AnimatedContainer),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;

      expect(card('Sound').color, tokens.card, reason: name);
      expect(card('Sound').border, Border.all(color: tokens.coral));
      expect(card('Sound').borderRadius, ChoiceRow.radius);
      expect(card('Lyrics').color?.a, 0, reason: name);
      expect(card('Lyrics').border, Border.all(color: tokens.line2));
      expect(card('Medium').color, tokens.card, reason: name);
      expect(card('Medium').border, Border.all(color: tokens.coral));
      expect(card('Easy').border, Border.all(color: tokens.line2));

      final rings = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((decoration) => decoration.shape == BoxShape.circle)
          .map((decoration) => decoration.border)
          .toList();
      expect(rings, [
        Border.all(color: tokens.coral, width: ChoiceRow.radioBorder),
        Border.all(color: tokens.line2, width: ChoiceRow.radioBorder),
      ]);

      await hover(tester, mouse, find.text('Lyrics'));
      expect(card('Lyrics').border, Border.all(color: tokens.coral));
      await leave(tester, mouse);

      for (final title in ['Lyrics', 'Easy']) {
        await tester.tap(find.text(title));
      }
      expect(picks, ['lyrics', 'easy'], reason: name);
    }
  });

  testWidgets('serif input turns its underline coral on focus', (tester) async {
    final tokens = tokensFor(Brightness.dark);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var submitted = const <String>[];
    await pumpKit(
      tester,
      Padding(
        padding: const EdgeInsets.all(32),
        child: SerifInput(
          controller: controller,
          placeholder: 'Your nickname',
          fontSize: 44,
          lineHeight: 52,
          maxLength: 20,
          onSubmitted: (value) => submitted = [...submitted, value],
        ),
      ),
    );
    BorderSide underline() =>
        ((tester
                            .widget<AnimatedContainer>(
                              find
                                  .descendant(
                                    of: find.byType(SerifInput),
                                    matching: find.byType(AnimatedContainer),
                                  )
                                  .first,
                            )
                            .decoration!
                        as BoxDecoration)
                    .border!
                as Border)
            .bottom;

    expect(underline(), BorderSide(color: tokens.line2));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.cursorColor, tokens.coral);
    expect(field.style?.fontFamily, AppType.serifFamily);
    expect(field.style?.fontStyle, FontStyle.italic);
    expect(field.style?.fontSize, 44);
    expect(field.decoration?.hintStyle?.color, tokens.faint);
    expect(find.text('Your nickname'), findsOneWidget);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(underline(), BorderSide(color: tokens.coral));

    await tester.enterText(find.byType(TextField), 'A' * 25);
    await tester.pump();
    expect(controller.text, 'A' * 20);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(submitted, ['A' * 20]);
  });

  testWidgets('screen enter fades and rises unless motion is reduced', (
    tester,
  ) async {
    const content = Key('content');
    await pumpKit(
      tester,
      const ScreenEnter(child: SizedBox(key: content, height: 40)),
    );
    final fade = find.ancestor(
      of: find.byKey(content),
      matching: find.byType(FadeTransition),
    );
    expect(tester.widget<FadeTransition>(fade.first).opacity.value, 0);
    expect(tester.getTopLeft(find.byKey(content)).dy, 10);

    await tester.pump(AppMotion.screenFade);
    expect(tester.widget<FadeTransition>(fade.first).opacity.value, 1);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(content)).dy, 0);

    await pumpKit(tester, const SizedBox());
    await pumpKit(
      tester,
      const ScreenEnter(child: SizedBox(key: content, height: 40)),
      reducedMotion: true,
    );
    expect(tester.widget<FadeTransition>(fade.first).opacity.value, 1);
    expect(tester.getTopLeft(find.byKey(content)).dy, 0);
  });

  testWidgets('a popping bead overshoots to 1.25 and settles at full size', (
    tester,
  ) async {
    const color = Color(0xFF6FA8DC);
    await pumpKit(tester, const Center(child: Bead(color: color, pop: true)));
    double scale() => tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byType(Bead),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;

    expect(scale(), 0);
    await tester.pump(AppMotion.beadPop * AppMotion.beadPopPeakAt);
    expect(scale(), closeTo(AppMotion.beadPopPeak, 1e-6));
    await tester.pumpAndSettle();
    expect(scale(), 1);
    expect(tester.getSize(find.byType(Bead)), const Size.square(12));
    final bead = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(Bead),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((bead.decoration as BoxDecoration).color, color);

    await pumpKit(tester, const SizedBox());
    await pumpKit(
      tester,
      const Center(child: Bead(color: color, size: 14, pop: true)),
      reducedMotion: true,
    );
    expect(scale(), 1);
    expect(tester.getSize(find.byType(Bead)), const Size.square(14));
  });

  testWidgets('vinyl discs and sleeves draw in the theme colours', (
    tester,
  ) async {
    for (final (name, brightness) in themes) {
      final tokens = tokensFor(brightness);
      const label = Color(0xFF8A5A44);
      await pumpKit(
        tester,
        const Row(
          children: [
            VinylDisc(size: 80, labelColor: label),
            AlbumSleeve(size: 88, placeholder: label),
          ],
        ),
        brightness: brightness,
      );
      expect(tester.getSize(find.byType(VinylDisc)), const Size.square(80));
      expect(tester.getSize(find.byType(AlbumSleeve)), const Size.square(88));
      final labelBox = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(VinylDisc),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(labelBox.color, label, reason: name);
      expect(
        tester.getSize(
          find
              .descendant(
                of: find.byType(VinylDisc),
                matching: find.byType(ClipOval),
              )
              .first,
        ),
        const Size.square(28),
      );
      final shadows = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .expand((decoration) => decoration.boxShadow ?? const <BoxShadow>[])
          .map((shadow) => (shadow.color, shadow.offset))
          .toList();
      expect(shadows, [
        (tokens.shadow, const Offset(0, 6)),
        (tokens.shadow, const Offset(0, 10)),
      ], reason: name);
      final hole = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(VinylDisc),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((decoration) => decoration.color == tokens.bg);
      expect(hole, hasLength(1), reason: name);
    }
  });

  testWidgets('vinyl grooves stay inside the disc', (tester) async {
    final tokens = tokensFor(Brightness.dark);
    await pumpKit(tester, const Center(child: VinylDisc(size: 51)));
    final grooves = tester.renderObject(
      find
          .descendant(
            of: find.byType(VinylDisc),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect(
      grooves,
      paints
        ..clipPath(
          pathMatcher: isPathThat(
            includes: const [Offset(25.5, 25.5), Offset(25.5, 0.5)],
            excludes: const [Offset(0.5, 0.5), Offset(50.5, 50.5)],
          ),
        )
        ..circle(color: tokens.g2),
    );
  });

  testWidgets('a back link appears at once when motion is reduced', (
    tester,
  ) async {
    final entrance = find.descendant(
      of: find.byType(BackLink),
      matching: find.byType(Entrance),
    );
    await pumpKit(tester, BackLink(onPressed: () {}));
    expect(entrance, findsOneWidget);

    await pumpKit(tester, const SizedBox());
    await pumpKit(tester, BackLink(onPressed: () {}), reducedMotion: true);
    expect(entrance, findsNothing);
    expect(inkOf(tester, find.text('Back')), AppTokens.dark.mut);
  });

  testWidgets('links, back links and section labels use the handoff ink', (
    tester,
  ) async {
    final tokens = tokensFor(Brightness.light);
    var taps = const <String>[];
    await pumpKit(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackLink(onPressed: () => taps = [...taps, 'back']),
          TextLink(
            label: 'Settings',
            onTap: () => taps = [...taps, 'settings'],
          ),
          const SectionLabel('Look and sound'),
        ],
      ),
      brightness: Brightness.light,
    );
    await tester.pumpAndSettle();

    expect(find.text('Back'), findsOneWidget);
    expect(find.text('← '), findsOneWidget);
    expect(inkOf(tester, find.text('Back')), tokens.mut);
    expect(inkOf(tester, find.text('Settings')), tokens.mut);
    expect(
      tester.getSize(find.byType(TextLink)).height,
      greaterThanOrEqualTo(TextLink.minHeight),
    );
    expect(
      tester.getSize(find.byType(BackLink)).height,
      greaterThanOrEqualTo(BackLink.minHeight),
    );
    final label = tester.renderObject<RenderParagraph>(
      find.text('Look and sound'),
    );
    expect(label.text.style?.color, tokens.mut);
    expect(label.text.style?.fontSize, 12);
    expect(label.text.style?.fontWeight, FontWeight.w600);

    final mouse = await mouseOf(tester);
    await hover(tester, mouse, find.text('Back'));
    expect(inkOf(tester, find.text('Back')), tokens.fg);
    await hover(tester, mouse, find.text('Settings'));
    expect(inkOf(tester, find.text('Settings')), tokens.fg);

    await tester.tap(find.text('Back'));
    await tester.tap(find.text('Settings'));
    expect(taps, ['back', 'settings']);
  });
}
