import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/util/birthday.dart';

void main() {
  group('birthday parity', () {
    group('isBirthdayPeriod', () {
      test('returns true for dates before the cutoff', () {
        expect(isBirthdayPeriod(DateTime(2026, 2, 18)), isTrue);
      });

      test('returns true for the cutoff date itself', () {
        expect(isBirthdayPeriod(DateTime(2026, 2, 19, 12)), isTrue);
      });

      test('returns true at the very end of Feb 19', () {
        expect(
          isBirthdayPeriod(DateTime(2026, 2, 19, 23, 59, 59, 999)),
          isTrue,
        );
      });

      test('returns false for Feb 20', () {
        expect(isBirthdayPeriod(DateTime(2026, 2, 20)), isFalse);
      });

      test('returns false for dates well after cutoff', () {
        expect(isBirthdayPeriod(DateTime(2027)), isFalse);
      });
    });

    group('shouldAutoShowBirthdayCard', () {
      test('returns true during birthday period when not yet shown', () {
        expect(
          shouldAutoShowBirthdayCard(DateTime(2026, 2, 15), false),
          isTrue,
        );
      });

      test('returns false during birthday period after card was shown', () {
        expect(
          shouldAutoShowBirthdayCard(DateTime(2026, 2, 15), true),
          isFalse,
        );
      });

      test('returns false after birthday period even if not shown', () {
        expect(shouldAutoShowBirthdayCard(DateTime(2026, 6), false), isFalse);
      });
    });

    group('markBirthdayCardShown', () {
      test('marking the card shown stops the auto show for the session', () {
        final now = DateTime(2026, 2, 19, 23, 59, 59, 999);
        expect(shouldAutoShowBirthdayCard(now, false), isTrue);
        expect(shouldAutoShowBirthdayCard(now, true), isFalse);
      });
    });
  });
}
