sealed class LyricsError implements Exception {
  const LyricsError(this.message);

  final String message;

  @override
  String toString() => message;
}

final class LyricsNotFound extends LyricsError {
  const LyricsNotFound() : super('Lyrics not found for this track.');
}

final class LyricsUnavailable extends LyricsError {
  const LyricsUnavailable()
    : super('Lyrics service unavailable — try again later.');
}

final class LyricsMalformed extends LyricsError {
  const LyricsMalformed() : super('Lyrics response malformed.');
}
