sealed class SaveError implements Exception {
  const SaveError();

  String get message;

  @override
  String toString() => message;
}

final class SaveFileError extends SaveError {
  const SaveFileError(this.detail);

  final String detail;

  @override
  String get message => 'File error: $detail';
}

final class SaveParseError extends SaveError {
  const SaveParseError(this.detail);

  final String detail;

  @override
  String get message => 'Parse error: $detail';
}

final class MissingMigrationError extends SaveError {
  const MissingMigrationError(this.fromVersion);

  final int fromVersion;

  @override
  String get message => 'Missing migration step from version $fromVersion';
}

final class FutureSaveVersionError extends SaveError {
  const FutureSaveVersionError(this.version);

  final int version;

  @override
  String get message =>
      'Save file is from a newer version (v$version) than this app supports';
}
