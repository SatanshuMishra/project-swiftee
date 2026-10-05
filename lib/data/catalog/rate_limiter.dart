import 'package:swiftie_quiz/data/catalog/catalog_error.dart';

typedef _Bucket = ({int tokens, DateTime lastRefill});

final class RateLimiter {
  RateLimiter({required DateTime Function() now})
    : _now = now,
      _bucket = (tokens: maxTokens, lastRefill: now());

  static const int maxTokens = 50;
  static const Duration refillInterval = Duration(seconds: 60);

  final DateTime Function() _now;
  _Bucket _bucket;

  void acquire() {
    final refilled = _refilledAt(_now());
    if (refilled.tokens == 0) {
      _bucket = refilled;
      throw const RateLimited();
    }
    _bucket = (tokens: refilled.tokens - 1, lastRefill: refilled.lastRefill);
  }

  _Bucket _refilledAt(DateTime now) =>
      now.difference(_bucket.lastRefill).inSeconds >= refillInterval.inSeconds
      ? (tokens: maxTokens, lastRefill: now)
      : _bucket;
}
