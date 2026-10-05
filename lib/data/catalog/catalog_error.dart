sealed class CatalogError implements Exception {
  const CatalogError();

  String get message;

  @override
  String toString() => message;
}

final class RateLimited extends CatalogError {
  const RateLimited();

  @override
  String get message => 'Taking a breather — try again in a moment.';

  @override
  bool operator ==(Object other) => other is RateLimited;

  @override
  int get hashCode => (RateLimited).hashCode;
}

final class NetworkError extends CatalogError {
  const NetworkError(this.detail);

  final String detail;

  @override
  String get message => 'Network error: $detail';

  @override
  bool operator ==(Object other) =>
      other is NetworkError && other.detail == detail;

  @override
  int get hashCode => Object.hash(NetworkError, detail);
}

final class ApiError extends CatalogError {
  const ApiError(this.detail);

  final String detail;

  @override
  String get message => 'API error: $detail';

  @override
  bool operator ==(Object other) => other is ApiError && other.detail == detail;

  @override
  int get hashCode => Object.hash(ApiError, detail);
}

final class ParseError extends CatalogError {
  const ParseError(this.detail);

  final String detail;

  @override
  String get message => 'Parse error: $detail';

  @override
  bool operator ==(Object other) =>
      other is ParseError && other.detail == detail;

  @override
  int get hashCode => Object.hash(ParseError, detail);
}
