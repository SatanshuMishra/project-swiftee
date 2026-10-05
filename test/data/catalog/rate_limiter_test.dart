import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/catalog/catalog_error.dart';
import 'package:swiftie_quiz/data/catalog/rate_limiter.dart';

void main() {
  group('rate limiter parity', () {
    late DateTime clock;
    late RateLimiter limiter;

    setUp(() {
      clock = DateTime.utc(2026, 10, 5, 12);
      limiter = RateLimiter(now: () => clock);
    });

    void drain() {
      for (var i = 0; i < RateLimiter.maxTokens; i++) {
        limiter.acquire();
      }
    }

    test('new limiter has full tokens', () {
      expect(RateLimiter.maxTokens, 50);
      expect(drain, returnsNormally);
    });

    test('limiter rejects when exhausted', () {
      drain();
      expect(
        limiter.acquire,
        throwsA(
          isA<RateLimited>().having(
            (error) => error.message,
            'message',
            'Taking a breather — try again in a moment.',
          ),
        ),
      );
    });

    test('limiter refills all tokens after 60 s', () {
      drain();
      clock = clock.add(const Duration(seconds: 59, milliseconds: 999));
      expect(limiter.acquire, throwsA(isA<RateLimited>()));

      clock = clock.add(const Duration(milliseconds: 1));
      expect(drain, returnsNormally);
      expect(limiter.acquire, throwsA(isA<RateLimited>()));
    });

    test('refill window restarts at the refill time', () {
      drain();
      clock = clock.add(const Duration(seconds: 90));
      drain();
      clock = clock.add(const Duration(seconds: 59));
      expect(limiter.acquire, throwsA(isA<RateLimited>()));

      clock = clock.add(const Duration(seconds: 1));
      expect(limiter.acquire, returnsNormally);
    });
  });
}
