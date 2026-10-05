import 'package:swiftie_quiz/domain/models/progress.dart';

const Object _unchanged = Object();

sealed class LoadResult {
  const LoadResult();
}

final class LoadFresh extends LoadResult {
  const LoadFresh();

  @override
  bool operator ==(Object other) => other is LoadFresh;

  @override
  int get hashCode => (LoadFresh).hashCode;

  @override
  String toString() => 'LoadFresh()';
}

final class LoadLoaded extends LoadResult {
  const LoadLoaded({required this.progress});

  final GameProgress progress;

  LoadLoaded copyWith({GameProgress? progress}) =>
      LoadLoaded(progress: progress ?? this.progress);

  @override
  bool operator ==(Object other) =>
      other is LoadLoaded && other.progress == progress;

  @override
  int get hashCode => Object.hash(LoadLoaded, progress);

  @override
  String toString() => 'LoadLoaded(progress: $progress)';
}

final class LoadMigrated extends LoadResult {
  const LoadMigrated({required this.progress, required this.fromVersion});

  final GameProgress progress;
  final int? fromVersion;

  LoadMigrated copyWith({
    GameProgress? progress,
    Object? fromVersion = _unchanged,
  }) => LoadMigrated(
    progress: progress ?? this.progress,
    fromVersion: identical(fromVersion, _unchanged)
        ? this.fromVersion
        : fromVersion as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is LoadMigrated &&
      other.progress == progress &&
      other.fromVersion == fromVersion;

  @override
  int get hashCode => Object.hash(LoadMigrated, progress, fromVersion);

  @override
  String toString() =>
      'LoadMigrated(progress: $progress, fromVersion: $fromVersion)';
}
