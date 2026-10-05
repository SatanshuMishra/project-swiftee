typedef _Entry = ({Object value, DateTime? expiresAt});

final class ResponseCache {
  ResponseCache({required this._now});

  final DateTime Function() _now;
  Map<String, _Entry> _entries = const {};

  T? get<T extends Object>(String key) => switch (_entries[key]) {
    (value: final T value, expiresAt: null) => value,
    (value: final T value, expiresAt: final DateTime expiresAt)
        when _now().isBefore(expiresAt) =>
      value,
    _ => null,
  };

  void put(String key, Object value, {DateTime? expiresAt}) {
    _entries = Map.unmodifiable({
      ..._entries,
      key: (value: value, expiresAt: expiresAt),
    });
  }
}
