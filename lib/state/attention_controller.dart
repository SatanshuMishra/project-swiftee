import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/state/providers.dart';

final class Attention {
  const Attention({this.focused = true, this.active = true, this.away = false});

  final bool focused;
  final bool active;
  final bool away;

  bool get watching => focused && active;

  Attention copyWith({bool? focused, bool? active, bool? away}) => Attention(
    focused: focused ?? this.focused,
    active: active ?? this.active,
    away: away ?? this.away,
  );

  @override
  bool operator ==(Object other) =>
      other is Attention &&
      other.focused == focused &&
      other.active == active &&
      other.away == away;

  @override
  int get hashCode => Object.hash(focused, active, away);

  @override
  String toString() =>
      'Attention(focused: $focused, active: $active, away: $away)';
}

final attentionProvider = NotifierProvider<AttentionController, Attention>(
  AttentionController.new,
);

class AttentionController extends Notifier<Attention> {
  static const Duration activeFor = Duration(seconds: 30);
  static const Duration awayAfter = Duration(minutes: 5);

  late Duration _lastInput;
  bool _tracking = false;
  Timer? _quiet;
  Timer? _gone;

  @override
  Attention build() {
    ref.onDispose(_cancel);
    _lastInput = _now();
    return const Attention();
  }

  void track() {
    _tracking = true;
    _lastInput = _now();
    _arm();
  }

  void untrack() {
    _tracking = false;
    _cancel();
  }

  void input() {
    if (state.focused) {
      _noticed(state);
    }
  }

  void press() => _noticed(state.copyWith(focused: true));

  void focus({required bool focused}) {
    if (state.focused != focused) {
      state = state.copyWith(focused: focused);
    }
  }

  Duration _now() => ref.read(uptimeProvider)();

  void _noticed(Attention seen) {
    _lastInput = _now();
    if (_tracking) {
      _arm();
    }
    final next = seen.copyWith(active: true, away: false);
    if (next != state) {
      state = next;
    }
  }

  void _arm() {
    _quiet ??= Timer(activeFor, _checkQuiet);
    _gone ??= Timer(awayAfter, _checkGone);
  }

  Duration _sinceInput() => _now() - _lastInput;

  void _checkQuiet() {
    final left = activeFor - _sinceInput();
    if (left > Duration.zero) {
      _quiet = Timer(left, _checkQuiet);
      return;
    }
    _quiet = null;
    state = state.copyWith(active: false);
  }

  void _checkGone() {
    final left = awayAfter - _sinceInput();
    if (left > Duration.zero) {
      _gone = Timer(left, _checkGone);
      return;
    }
    _gone = null;
    state = state.copyWith(away: true);
  }

  void _cancel() {
    _quiet?.cancel();
    _gone?.cancel();
    _quiet = null;
    _gone = null;
  }
}
