import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';
import 'package:swiftie_quiz/ui/widgets/selection_card.dart';

const violetFrom = Color(0xFF8B5CF6);
const violetTo = Color(0xFF6366F1);
const cardWidth = 320.0;
const mouseDevice = 1;

Widget harness({
  required VoidCallback onTap,
  bool disabled = false,
  String? disabledReason,
  Duration delay = Duration.zero,
}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: cardWidth,
          child: SelectionCard(
            glyph: LucideGlyph.music,
            title: 'Random Mode',
            description: 'All songs, shuffled randomly',
            gradient: const GradientPair(violetFrom, violetTo),
            onTap: onTap,
            delay: delay,
            disabled: disabled,
            disabledReason: disabledReason,
          ),
        ),
      ),
    ),
  );
}

Finder get card => find.byType(SelectionCard);

BoxDecoration cardDecoration(WidgetTester tester) =>
    tester
            .widget<Container>(
              find.descendant(of: card, matching: find.byType(Container)),
            )
            .decoration!
        as BoxDecoration;

List<Color>? overlayColors(WidgetTester tester) {
  final overlays = tester
      .widgetList<DecoratedBox>(
        find.descendant(of: card, matching: find.byType(DecoratedBox)),
      )
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .map((decoration) => decoration.gradient)
      .whereType<Gradient>()
      .where((gradient) => gradient.colors.first.a < 1);
  return overlays.isEmpty ? null : overlays.single.colors;
}

List<(Color, Offset, double, double)> painted(List<BoxShadow> shadows) => [
  for (final shadow in shadows)
    (shadow.color, shadow.offset, shadow.blurSigma, shadow.spreadRadius),
];

bool shadowsHidden(WidgetTester tester) =>
    cardDecoration(tester).boxShadow!.every((shadow) => shadow.color.a == 0);

Rect visibleRect(WidgetTester tester) => tester.getRect(
  find.descendant(of: card, matching: find.byType(FocusableActionDetector)),
);

double cardOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(of: card, matching: find.byType(Opacity)).first,
    )
    .opacity;

Future<TestGesture> hoverCard(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(card));
  await tester.pump();
  return gesture;
}

void main() {
  group('selection card', () {
    testWidgets('a tap or Enter on the card calls onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(harness(onTap: () => taps++));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Random Mode'));
      expect(taps, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 2);
    });

    testWidgets('enters from 20 px below and transparent after its delay', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(onTap: () {}, delay: const Duration(milliseconds: 300)),
      );
      final restingTop = tester.getTopLeft(card).dy;

      expect(visibleRect(tester).top, restingTop + 20);
      expect(cardOpacity(tester), 0);

      await tester.pump(const Duration(milliseconds: 250));
      expect(visibleRect(tester).top, restingTop + 20);
      expect(cardOpacity(tester), 0);

      await tester.pumpAndSettle();
      expect(visibleRect(tester).top, restingTop);
      expect(cardOpacity(tester), 1);
    });

    testWidgets('hover shows the 10 percent overlay, primary/50 border, xl '
        'shadow and 1.02 scale, and leaving restores the card', (tester) async {
      await tester.pumpWidget(harness(onTap: () {}));
      await tester.pumpAndSettle();
      const tokens = AppTokens.dark;

      expect(overlayColors(tester), isNull);
      expect(cardDecoration(tester).border, Border.all(color: tokens.border));
      expect(shadowsHidden(tester), isTrue);

      final gesture = await hoverCard(tester);
      await tester.pump(const Duration(milliseconds: 300));

      expect(overlayColors(tester), [
        violetFrom.withValues(alpha: 0.1),
        violetTo.withValues(alpha: 0.1),
      ]);
      expect(
        cardDecoration(tester).border,
        Border.all(color: const Color(0xFFFAFAFA).withValues(alpha: 0.5)),
      );
      expect(
        painted(cardDecoration(tester).boxShadow!),
        painted(AppShadows.xl),
      );

      await tester.pumpAndSettle();
      expect(visibleRect(tester).width, closeTo(cardWidth * 1.02, 0.01));
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(
          mouseDevice,
        ),
        SystemMouseCursors.basic,
      );

      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();

      expect(overlayColors(tester), isNull);
      expect(cardDecoration(tester).border, Border.all(color: tokens.border));
      expect(visibleRect(tester).width, closeTo(cardWidth, 0.01));
    });

    testWidgets('a disabled card shows its reason in yellow-500 and ignores '
        'taps, hover styling and scale', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        harness(
          onTap: () => taps++,
          disabled: true,
          disabledReason: 'Needs at least five songs with lyrics',
        ),
      );
      await tester.pumpAndSettle();

      final reason = tester.widget<Text>(
        find.text('Needs at least five songs with lyrics'),
      );
      expect(reason.style!.color, const Color(0xFFF0B100));
      expect(reason.style!.fontSize, 12);
      expect(reason.style!.height, 16 / 12);

      await tester.tap(find.text('Random Mode'));
      expect(taps, 0);

      await hoverCard(tester);
      await tester.pumpAndSettle();

      expect(
        cardDecoration(tester).border,
        Border.all(color: AppTokens.dark.border),
      );
      expect(shadowsHidden(tester), isTrue);
      expect(overlayColors(tester), isNotNull);
      expect(visibleRect(tester).width, closeTo(cardWidth, 0.01));
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(
          mouseDevice,
        ),
        SystemMouseCursors.forbidden,
      );
      expect(cardOpacity(tester), 1);
    });

    testWidgets('the reason stays hidden while the card is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(onTap: () {}, disabledReason: 'Needs at least five songs'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Needs at least five songs'), findsNothing);
    });
  });
}
