import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/app/attention_listener.dart';
import 'package:swiftie_quiz/state/attention_controller.dart';

class _CountingAttention extends AttentionController {
  int inputs = 0;
  int presses = 0;
  List<bool> focuses = const [];
  List<bool> tracking = const [];

  @override
  Attention build() => const Attention();

  @override
  void track() => tracking = [...tracking, true];

  @override
  void untrack() => tracking = [...tracking, false];

  @override
  void input() => inputs += 1;

  @override
  void press() => presses += 1;

  @override
  void focus({required bool focused}) => focuses = [...focuses, focused];
}

Future<_CountingAttention> _pump(
  WidgetTester tester, {
  ValueChanged<KeyEvent>? onKey,
}) async {
  final attention = _CountingAttention();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [attentionProvider.overrideWith(() => attention)],
      child: MaterialApp(
        home: AttentionListener(
          child: Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              onKey?.call(event);
              return KeyEventResult.ignored;
            },
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return attention;
}

void main() {
  testWidgets('clicks and keys count as pressing; moving, dragging, '
      'scrolling and trackpad gestures count as you being there', (
    tester,
  ) async {
    final keys = <KeyEvent>[];
    final attention = await _pump(tester, onKey: keys.add);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(const Offset(200, 200));
    expect(attention.inputs, greaterThan(0));
    expect(attention.presses, 0);

    var inputs = attention.inputs;
    await tester.tapAt(const Offset(300, 300));
    expect(attention.presses, 1);

    final drag = await tester.startGesture(const Offset(300, 300));
    inputs = attention.inputs;
    await drag.moveBy(const Offset(0, 40));
    await drag.up();
    expect(attention.inputs, greaterThan(inputs));
    expect(attention.presses, 2);

    inputs = attention.inputs;
    tester.binding.handlePointerEvent(
      const PointerScrollEvent(
        position: Offset(300, 300),
        scrollDelta: Offset(0, 40),
      ),
    );
    expect(attention.inputs, greaterThan(inputs));

    inputs = attention.inputs;
    final trackpad = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await trackpad.panZoomStart(const Offset(300, 300));
    await trackpad.panZoomEnd();
    expect(attention.inputs, greaterThan(inputs));

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(attention.presses, greaterThan(2));
    expect(
      keys.map((event) => event.logicalKey),
      contains(LogicalKeyboardKey.keyA),
      reason: 'the key still reaches the app',
    );
  });

  testWidgets('the window being in front is what counts as focused', (
    tester,
  ) async {
    final attention = await _pump(tester);
    final initial = attention.focuses.length;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(attention.focuses.skip(initial), [false, false, false, true]);
  });

  testWidgets('the tracker runs only while the listener is mounted', (
    tester,
  ) async {
    final attention = await _pump(tester);
    expect(attention.tracking, [true]);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(attention.tracking, [true, false]);
  });

  testWidgets('a window that opens in the background starts unfocused', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );

    final attention = await _pump(tester);

    expect(attention.focuses, [false]);
  });

  testWidgets('a repeated report from the window still reaches the tracker', (
    tester,
  ) async {
    final attention = await _pump(tester);
    final initial = attention.focuses.length;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(attention.focuses.skip(initial), [false, false, true]);
  });
}
