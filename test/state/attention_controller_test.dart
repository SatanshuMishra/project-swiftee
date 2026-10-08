import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/state/attention_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

const Duration _justBefore = Duration(milliseconds: 1);

ProviderContainer _container(FakeAsync async) {
  final container = ProviderContainer.test(
    overrides: [uptimeProvider.overrideWithValue(() => async.elapsed)],
  );
  container.read(attentionProvider.notifier).track();
  return container;
}

void main() {
  test('you stay active for thirty seconds after you last moved and are '
      'away after five minutes', () {
    fakeAsync((async) {
      final container = _container(async);
      final attention = container.read(attentionProvider.notifier);
      Attention read() => container.read(attentionProvider);

      expect(read(), const Attention());
      expect(read().watching, isTrue);

      async.elapse(const Duration(seconds: 20));
      attention.input();
      async.elapse(AttentionController.activeFor - _justBefore);
      expect(read().active, isTrue);
      async.elapse(_justBefore);
      expect(read(), const Attention(active: false));
      expect(read().watching, isFalse);

      async.elapse(
        AttentionController.awayAfter -
            AttentionController.activeFor -
            _justBefore,
      );
      expect(read().away, isFalse);
      async.elapse(_justBefore);
      expect(read(), const Attention(active: false, away: true));

      attention.input();
      expect(read(), const Attention());
    });
  });

  test('watching needs the window in front as well as recent input', () {
    fakeAsync((async) {
      final container = _container(async);
      final attention = container.read(attentionProvider.notifier)
        ..focus(focused: false);

      expect(container.read(attentionProvider).watching, isFalse);
      attention.focus(focused: true);
      expect(container.read(attentionProvider).watching, isTrue);
    });
  });

  test('a click or key proves the window is in front, but moving over a '
      'window in the background does not count as you', () {
    fakeAsync((async) {
      final container = _container(async);
      final attention = container.read(attentionProvider.notifier)
        ..focus(focused: false);
      Attention read() => container.read(attentionProvider);

      async.elapse(AttentionController.activeFor);
      attention.input();
      expect(read(), const Attention(focused: false, active: false));

      async.elapse(AttentionController.awayAfter);
      attention.input();
      expect(read().away, isTrue, reason: 'hovering from another app');

      attention.press();
      expect(read(), const Attention());
    });
  });

  test('a stream of mouse moves keeps two timers, not one per move', () {
    fakeAsync((async) {
      final container = _container(async);
      final attention = container.read(attentionProvider.notifier);
      for (var move = 0; move < 500; move++) {
        attention.input();
        async.elapse(const Duration(milliseconds: 16));
      }

      expect(async.pendingTimers, hasLength(2));
      expect(container.read(attentionProvider).active, isTrue);

      container.dispose();
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('attention copies and compares by value', () {
    const attention = Attention(focused: false, active: true, away: true);

    expect(attention.copyWith(), attention);
    expect(attention.copyWith().hashCode, attention.hashCode);
    expect(attention.copyWith(focused: true).focused, isTrue);
    expect(attention.copyWith(away: false).away, isFalse);
    expect(attention, isNot(const Attention()));
  });
}
