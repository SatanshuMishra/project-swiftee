import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/util/shuffle.dart';

void main() {
  group('shuffle parity', () {
    test('returns a new array, does not mutate original', () {
      final original = [1, 2, 3, 4, 5];
      final originalCopy = [...original];
      shuffle(original, random: Random(1));
      expect(original, originalCopy);
    });

    test('returns array of same length', () {
      final items = [1, 2, 3, 4, 5];
      expect(shuffle(items, random: Random(2)).length, 5);
    });

    test('contains all original elements', () {
      final items = [1, 2, 3, 4, 5];
      final result = shuffle(items, random: Random(3));
      expect([...result]..sort(), [1, 2, 3, 4, 5]);
    });

    test('handles empty array', () {
      expect(shuffle(<int>[], random: Random(4)), isEmpty);
    });

    test('handles single element', () {
      expect(shuffle([42], random: Random(5)), [42]);
    });

    test('accepts readonly arrays', () {
      final items = List<int>.unmodifiable([1, 2, 3]);
      final result = shuffle(items, random: Random(6));
      expect([...result]..sort(), [1, 2, 3]);
    });

    test('eventually produces different orderings', () {
      final items = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      final random = Random(7);
      final results = {
        for (var i = 0; i < 50; i++) shuffle(items, random: random).join(','),
      };
      expect(results.length, greaterThan(1));
    });

    test('the injected Random alone decides the order', () {
      final items = List.generate(10, (i) => i);
      expect(
        shuffle(items, random: Random(8)),
        shuffle(items, random: Random(8)),
      );
    });
  });
}
