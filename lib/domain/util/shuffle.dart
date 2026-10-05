import 'dart:collection';
import 'dart:math';

List<T> shuffle<T>(Iterable<T> items, {Random? random}) {
  final generator = random ?? Random();
  final result = [...items];
  for (var i = result.length - 1; i > 0; i--) {
    final j = generator.nextInt(i + 1);
    final displaced = result[i];
    result[i] = result[j];
    result[j] = displaced;
  }
  return UnmodifiableListView(result);
}
