final class BackupEntry {
  const BackupEntry({
    required this.timestamp,
    required this.path,
    required this.sizeBytes,
  });

  final int timestamp;
  final String path;
  final int sizeBytes;

  BackupEntry copyWith({int? timestamp, String? path, int? sizeBytes}) =>
      BackupEntry(
        timestamp: timestamp ?? this.timestamp,
        path: path ?? this.path,
        sizeBytes: sizeBytes ?? this.sizeBytes,
      );

  @override
  bool operator ==(Object other) =>
      other is BackupEntry &&
      other.timestamp == timestamp &&
      other.path == path &&
      other.sizeBytes == sizeBytes;

  @override
  int get hashCode => Object.hash(timestamp, path, sizeBytes);

  @override
  String toString() =>
      'BackupEntry(timestamp: $timestamp, path: $path, sizeBytes: $sizeBytes)';
}
