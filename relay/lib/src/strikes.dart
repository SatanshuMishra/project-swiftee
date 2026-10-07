import 'dart:collection';
import 'dart:math';

typedef _Struck = ({DoubleLinkedQueueEntry<String> place, List<Duration> at});

final class Strikes {
  Strikes({
    required int threshold,
    required this._window,
    required this._capacity,
  }) : _threshold = threshold,
       _kept = max(threshold, 1);

  final int _threshold;
  final int _kept;
  final Duration _window;
  final int _capacity;
  final _clock = Stopwatch()..start();
  final _byAge = DoubleLinkedQueue<String>();
  final _struck = <String, _Struck>{};

  bool reached(String key) {
    final now = _clock.elapsed;
    _forgetBefore(now);
    final recent = _struck[key]?.at.where((at) => now - at < _window);
    return (recent?.length ?? 0) >= _threshold;
  }

  void record(String key) {
    final now = _clock.elapsed;
    final earlier = _struck.remove(key);
    earlier?.place.remove();
    final kept = earlier?.at ?? const <Duration>[];
    _byAge.addLast(key);
    _struck[key] = (
      place: _byAge.lastEntry()!,
      at: List.unmodifiable([
        ...kept.skip(max(0, kept.length - _kept + 1)),
        now,
      ]),
    );
    while (_struck.length > _capacity) {
      _forget(_byAge.firstEntry()!);
    }
    _forgetBefore(now);
  }

  void _forgetBefore(Duration now) {
    for (
      var oldest = _byAge.firstEntry();
      oldest != null && now - _struck[oldest.element]!.at.last >= _window;
      oldest = _byAge.firstEntry()
    ) {
      _forget(oldest);
    }
  }

  void _forget(DoubleLinkedQueueEntry<String> place) {
    _struck.remove(place.element);
    place.remove();
  }
}
