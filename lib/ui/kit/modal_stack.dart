import 'package:flutter_riverpod/flutter_riverpod.dart';

final modalStackProvider = NotifierProvider<ModalStack, List<Object>>(
  ModalStack.new,
);

class ModalStack extends Notifier<List<Object>> {
  @override
  List<Object> build() => const [];

  void push(Object key) {
    if (!ref.mounted) {
      return;
    }
    state = List.unmodifiable([
      for (final open in state)
        if (open != key) open,
      key,
    ]);
  }

  void remove(Object key) {
    if (!ref.mounted || !state.contains(key)) {
      return;
    }
    state = List.unmodifiable([
      for (final open in state)
        if (open != key) open,
    ]);
  }
}
