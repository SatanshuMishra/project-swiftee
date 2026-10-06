import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/game/transport_bar.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

const extendedNote = 'Clip extended to help with your guess';

const clipSeconds = {1: 10, 2: 10, 3: 15, 4: 15, 5: 20, 6: 20, 7: 30};

const endedCaption = {
  1: 'Listen again (10s)',
  2: 'Listen again (15s)',
  3: 'Listen again (15s)',
  4: 'Listen again (20s)',
  5: 'Listen again (20s)',
  6: 'Play full clip (30s)',
  7: 'Play full clip (30s)',
};

const statusCaption = {
  TransportStatus.idle: 'Space to pause',
  TransportStatus.playing: 'Space to pause',
  TransportStatus.paused: 'Paused',
  TransportStatus.loading: 'Loading the clip…',
};

Future<void> pumpGame(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark,
        themeAnimationDuration: Duration.zero,
        home: Material(child: Center(child: child)),
      ),
    ),
  );
}

Color? inkOf(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text).text.style?.color;

Finder buttonLabelled(String label) => find.descendant(
  of: find.byType(TransportButton),
  matching: find.bySemanticsLabel(label),
);

void main() {
  testWidgets('transport captions follow the relisten schedule', (
    tester,
  ) async {
    const tokens = AppTokens.dark;
    for (var stage = 1; stage <= 7; stage++) {
      final seconds = clipSeconds[stage]!;
      for (final status in TransportStatus.values) {
        final ended = status == TransportStatus.ended;
        final elapsed = ended ? seconds.toDouble() : 4.7;
        final reason = 'stage $stage $status';
        await pumpGame(
          tester,
          TransportBar(
            status: status,
            stage: stage,
            elapsed: elapsed,
            duration: seconds.toDouble(),
            onToggle: () {},
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final track = find.descendant(
          of: find.byType(TransportBar),
          matching: find.byWidgetPredicate(
            (widget) => widget is SizedBox && widget.height == 3,
          ),
        );
        final fill = find.descendant(
          of: track,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                (widget.decoration as BoxDecoration).color == tokens.fg,
          ),
        );
        expect(tester.getSize(track).height, 3, reason: reason);
        expect(
          tester.getSize(fill).width,
          closeTo(tester.getSize(track).width * elapsed / seconds, 1e-9),
          reason: reason,
        );

        final caption = ended ? endedCaption[stage]! : statusCaption[status]!;
        expect(find.text(caption), findsOneWidget, reason: reason);
        expect(inkOf(tester, find.text(caption)), tokens.faint, reason: reason);
        final time = ended ? '${seconds}s / ${seconds}s' : '4s / ${seconds}s';
        expect(find.text(time), findsOneWidget, reason: reason);
        expect(inkOf(tester, find.text(time)), tokens.mut, reason: reason);
        expect(
          find.text(extendedNote),
          stage >= 3 ? findsOneWidget : findsNothing,
          reason: reason,
        );

        final button = find.byType(TransportButton);
        if (status == TransportStatus.loading) {
          expect(button, findsNothing, reason: reason);
          expect(find.byType(CatLoader), findsOneWidget, reason: reason);
          continue;
        }
        expect(tester.getSize(button), const Size.square(44), reason: reason);
        final pauseBars = find.descendant(
          of: button,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox && widget.width == 4 && widget.height == 14,
          ),
        );
        final playTriangle = find.descendant(
          of: button,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint && widget.size == const Size(13, 16),
          ),
        );
        final replay = find.descendant(of: button, matching: find.text('↻'));
        expect(
          (
            pauseBars.evaluate().length,
            playTriangle.evaluate().length,
            replay.evaluate().length,
          ),
          switch (status) {
            TransportStatus.playing => (2, 0, 0),
            TransportStatus.ended => (0, 0, 1),
            _ => (0, 1, 0),
          },
          reason: reason,
        );
      }
    }
  });

  testWidgets('the transport button toggles playback', (tester) async {
    final semantics = tester.ensureSemantics();
    var toggles = 0;
    await pumpGame(
      tester,
      TransportBar(
        status: TransportStatus.playing,
        stage: 1,
        elapsed: 2,
        duration: 10,
        onToggle: () => toggles += 1,
      ),
    );
    expect(buttonLabelled('Pause'), findsOneWidget);
    await tester.tap(find.byType(TransportButton));
    await tester.pump();
    expect(toggles, 1);

    await pumpGame(
      tester,
      TransportBar(
        status: TransportStatus.ended,
        stage: 2,
        elapsed: 10,
        duration: 10,
        onToggle: () => toggles += 1,
      ),
    );
    expect(buttonLabelled('Listen again (15s)'), findsOneWidget);
    semantics.dispose();
  });
}
