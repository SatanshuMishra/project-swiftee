import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/cat/cat_icon.dart';
import 'package:swiftie_quiz/ui/kit/modal_stack.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/overlays/birthday_card.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

const String dedication = 'For Ana';
const String heading = 'Happy Birthday!';
const String addressee = 'Dear Ana,';
const List<String> letter = [
  'Sending you the warmest of wishes for a very Happy Birthday!',
  'Thank you for always being there for me over these past couple of years. '
      "I'm very grateful and lucky to have a friend like you.",
  "I've said it before, and I'll say it again: there is nothing you can't "
      'accomplish once you put your mind to it. As you enter this next year, '
      'which will hopefully be filled with exciting opportunities and '
      'unforgettable memories, I have no doubt in my mind that you will find '
      'success and reach the goals you set for yourself!',
  "I can't wait to see what you accomplish in the year ahead! Know that I am "
      'always rooting for you!',
];
const String closing = 'Your Best Friend,';
const String signature = 'Satanshu :)';
const String postscript = 'P.S. Meowwwww Meow Meaaww ~ Clef';

Widget harness({
  required bool isOpen,
  required VoidCallback onClose,
  ThemeData? theme,
}) => ProviderScope(
  child: MaterialApp(
    theme: theme ?? AppTheme.dark,
    home: Material(
      child: BirthdayCard(isOpen: isOpen, onClose: onClose),
    ),
  ),
);

Future<void> pumpCard(
  WidgetTester tester, {
  required bool isOpen,
  VoidCallback? onClose,
  ThemeData? theme,
  Size size = const Size(1024, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    harness(isOpen: isOpen, onClose: onClose ?? () {}, theme: theme),
  );
  await tester.pumpAndSettle();
}

Color? inkOf(WidgetTester tester, String text) => tester
    .renderObject<RenderParagraph>(
      find.descendant(of: find.text(text), matching: find.byType(RichText)),
    )
    .text
    .style
    ?.color;

Finder paper(AppTokens tokens) => find.byWidgetPredicate(
  (widget) =>
      widget is DecoratedBox &&
      widget.decoration is BoxDecoration &&
      (widget.decoration as BoxDecoration).color == tokens.paper,
);

List<Object> openModals(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(modalStackProvider);

void main() {
  testWidgets(
    'the birthday card shows the letter on paper with the coral header',
    (tester) async {
      for (final (theme, tokens) in [
        (AppTheme.dark, AppTokens.dark),
        (AppTheme.light, AppTokens.light),
      ]) {
        var closes = 0;
        await pumpCard(
          tester,
          isOpen: true,
          theme: theme,
          onClose: () => closes++,
        );
        final reason = '${theme.brightness}';

        for (final text in [
          dedication,
          heading,
          addressee,
          ...letter,
          closing,
          signature,
          postscript,
        ]) {
          expect(find.text(text), findsOneWidget, reason: '$reason: $text');
        }

        final card = find.ancestor(
          of: find.text(addressee),
          matching: paper(tokens),
        );
        expect(card, findsOneWidget, reason: reason);
        expect(
          (tester.widget<DecoratedBox>(card).decoration as BoxDecoration)
              .borderRadius,
          const BorderRadius.all(Radius.circular(14)),
          reason: reason,
        );
        expect(tester.getSize(card).width, 540, reason: reason);
        for (final text in [addressee, ...letter, postscript]) {
          expect(inkOf(tester, text), tokens.paperFg, reason: '$reason: $text');
        }
        expect(inkOf(tester, closing), const Color(0xFFB4533F));
        expect(inkOf(tester, signature), const Color(0xFFB4533F));
        expect(inkOf(tester, heading), const Color(0xFF1A1514));
        expect(
          inkOf(tester, dedication),
          const Color.from(
            alpha: 0.7,
            red: 26 / 255,
            green: 21 / 255,
            blue: 20 / 255,
          ),
        );

        final header = find.ancestor(
          of: find.text(heading),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ColoredBox && widget.color == const Color(0xFFE97F6A),
          ),
        );
        expect(header, findsOneWidget, reason: reason);
        final headerRect = tester.getRect(header);
        expect(headerRect.height, 132, reason: reason);
        final cat = find.descendant(of: header, matching: find.byType(CatIcon));
        expect(tester.getSize(cat), const Size(54, 108), reason: reason);
        expect(tester.getRect(cat).bottom, headerRect.bottom + 34);
        expect(tester.getRect(cat).right, headerRect.right - 40);
        expect(openModals(tester), hasLength(1), reason: reason);

        await tester.tap(find.text(addressee));
        await tester.tap(find.text(heading));
        expect(closes, 0, reason: reason);

        await tester.tap(find.text('✕'));
        expect(closes, 1, reason: reason);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(closes, 2, reason: reason);

        await tester.tapAt(const Offset(4, 4));
        expect(closes, 3, reason: reason);

        await tester.pumpWidget(
          harness(isOpen: false, onClose: () {}, theme: theme),
        );
        await tester.pump();
        expect(find.text(heading), findsNothing, reason: reason);
        expect(openModals(tester), isEmpty, reason: reason);
      }
    },
  );

  testWidgets('renders nothing when isOpen is false', (tester) async {
    await pumpCard(tester, isOpen: false);

    expect(find.text(heading), findsNothing);
    expect(find.text(addressee), findsNothing);
  });

  testWidgets('the close button is a 32 px circle 12 px from the top right', (
    tester,
  ) async {
    await pumpCard(tester, isOpen: true);

    final close = find.ancestor(
      of: find.text('✕'),
      matching: find.byType(AnimatedContainer),
    );
    final card = find.ancestor(
      of: find.text(addressee),
      matching: paper(AppTokens.dark),
    );
    final closeRect = tester.getRect(close);
    final cardRect = tester.getRect(card);
    expect(closeRect.size, const Size(32, 32));
    expect(closeRect.top - cardRect.top, 12);
    expect(cardRect.right - closeRect.right, 12);
    expect(
      tester.getSemantics(close),
      isSemantics(label: 'Close', isButton: true, hasTapAction: true),
    );
  });

  testWidgets('the letter scrolls inside the card on a short window', (
    tester,
  ) async {
    await pumpCard(tester, isOpen: true, size: const Size(1024, 571));
    final scrollable = find.descendant(
      of: find.byType(BirthdayCard),
      matching: find.byType(Scrollable),
    );
    final state = tester.state<ScrollableState>(scrollable);
    expect(state.position.maxScrollExtent, greaterThan(0));

    await tester.drag(scrollable, const Offset(0, -5000));
    await tester.pumpAndSettle();

    expect(state.position.pixels, state.position.maxScrollExtent);
    expect(find.text(postscript).hitTestable(), findsOneWidget);
  });
  testWidgets('tab stays on the close button inside the open card', (
    tester,
  ) async {
    await pumpCard(tester, isOpen: true);

    for (var press = 0; press < 4; press++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<Pressable>()
            ?.semanticLabel,
        'Close',
        reason: 'tab $press',
      );
    }
  });
}
