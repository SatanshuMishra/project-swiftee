import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/util/levenshtein.dart';

void main() {
  group('levenshtein parity', () {
    group('levenshteinDistance', () {
      test('returns 0 for identical strings', () {
        expect(levenshteinDistance('hello', 'hello'), 0);
      });

      test('returns string length for empty comparison', () {
        expect(levenshteinDistance('hello', ''), 5);
        expect(levenshteinDistance('', 'hello'), 5);
      });

      test('counts single substitution', () {
        expect(levenshteinDistance('cat', 'bat'), 1);
      });

      test('counts insertion', () {
        expect(levenshteinDistance('cat', 'cats'), 1);
      });

      test('counts deletion', () {
        expect(levenshteinDistance('cats', 'cat'), 1);
      });

      test('handles transposition (2 operations)', () {
        expect(levenshteinDistance('anit', 'anti'), 2);
      });
    });

    group('isCloseMatch', () {
      test('allows distance <= 2 for long strings', () {
        expect(isCloseMatch('enchanted', 'enchantd'), isTrue);
        expect(isCloseMatch('enchanted', 'enchnted'), isTrue);
        expect(isCloseMatch('enchanted', 'enchntd'), isTrue);
      });

      test('requires exact match for short strings (< 5 chars)', () {
        expect(isCloseMatch('22', '22'), isTrue);
        expect(isCloseMatch('22', '23'), isFalse);
        expect(isCloseMatch('me', 'me'), isTrue);
        expect(isCloseMatch('me', 'mee'), isFalse);
      });

      test('accepts exact matches always', () {
        expect(isCloseMatch('anti hero', 'anti hero'), isTrue);
        expect(isCloseMatch('22', '22'), isTrue);
      });
    });
  });
}
