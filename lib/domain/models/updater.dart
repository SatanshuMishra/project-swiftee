final class UpdateManifest {
  const UpdateManifest({
    required this.version,
    required this.notes,
    required this.pubDate,
  });

  final String version;
  final String notes;
  final String pubDate;

  UpdateManifest copyWith({String? version, String? notes, String? pubDate}) =>
      UpdateManifest(
        version: version ?? this.version,
        notes: notes ?? this.notes,
        pubDate: pubDate ?? this.pubDate,
      );

  @override
  bool operator ==(Object other) =>
      other is UpdateManifest &&
      other.version == version &&
      other.notes == notes &&
      other.pubDate == pubDate;

  @override
  int get hashCode => Object.hash(version, notes, pubDate);

  @override
  String toString() =>
      'UpdateManifest(version: $version, notes: $notes, pubDate: $pubDate)';
}

enum UpdaterErrorSubtype { check, download, signature, install }

sealed class UpdaterMachineState {
  const UpdaterMachineState();
}

final class UpdaterIdle extends UpdaterMachineState {
  const UpdaterIdle();

  @override
  bool operator ==(Object other) => other is UpdaterIdle;

  @override
  int get hashCode => (UpdaterIdle).hashCode;

  @override
  String toString() => 'UpdaterIdle()';
}

final class UpdaterChecking extends UpdaterMachineState {
  const UpdaterChecking();

  @override
  bool operator ==(Object other) => other is UpdaterChecking;

  @override
  int get hashCode => (UpdaterChecking).hashCode;

  @override
  String toString() => 'UpdaterChecking()';
}

final class UpdaterUpToDate extends UpdaterMachineState {
  const UpdaterUpToDate();

  @override
  bool operator ==(Object other) => other is UpdaterUpToDate;

  @override
  int get hashCode => (UpdaterUpToDate).hashCode;

  @override
  String toString() => 'UpdaterUpToDate()';
}

final class UpdaterAvailable extends UpdaterMachineState {
  const UpdaterAvailable({required this.manifest});

  final UpdateManifest manifest;

  UpdaterAvailable copyWith({UpdateManifest? manifest}) =>
      UpdaterAvailable(manifest: manifest ?? this.manifest);

  @override
  bool operator ==(Object other) =>
      other is UpdaterAvailable && other.manifest == manifest;

  @override
  int get hashCode => Object.hash(UpdaterAvailable, manifest);

  @override
  String toString() => 'UpdaterAvailable(manifest: $manifest)';
}

final class UpdaterDownloading extends UpdaterMachineState {
  const UpdaterDownloading({required this.manifest, required this.progress})
    : assert(progress >= 0 && progress <= 100);

  final UpdateManifest manifest;
  final int progress;

  UpdaterDownloading copyWith({UpdateManifest? manifest, int? progress}) =>
      UpdaterDownloading(
        manifest: manifest ?? this.manifest,
        progress: progress ?? this.progress,
      );

  @override
  bool operator ==(Object other) =>
      other is UpdaterDownloading &&
      other.manifest == manifest &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(UpdaterDownloading, manifest, progress);

  @override
  String toString() =>
      'UpdaterDownloading(manifest: $manifest, progress: $progress)';
}

final class UpdaterReady extends UpdaterMachineState {
  const UpdaterReady({required this.manifest});

  final UpdateManifest manifest;

  UpdaterReady copyWith({UpdateManifest? manifest}) =>
      UpdaterReady(manifest: manifest ?? this.manifest);

  @override
  bool operator ==(Object other) =>
      other is UpdaterReady && other.manifest == manifest;

  @override
  int get hashCode => Object.hash(UpdaterReady, manifest);

  @override
  String toString() => 'UpdaterReady(manifest: $manifest)';
}

final class UpdaterInstalling extends UpdaterMachineState {
  const UpdaterInstalling();

  @override
  bool operator ==(Object other) => other is UpdaterInstalling;

  @override
  int get hashCode => (UpdaterInstalling).hashCode;

  @override
  String toString() => 'UpdaterInstalling()';
}

final class UpdaterInstalled extends UpdaterMachineState {
  const UpdaterInstalled({required this.manifest});

  final UpdateManifest manifest;

  UpdaterInstalled copyWith({UpdateManifest? manifest}) =>
      UpdaterInstalled(manifest: manifest ?? this.manifest);

  @override
  bool operator ==(Object other) =>
      other is UpdaterInstalled && other.manifest == manifest;

  @override
  int get hashCode => Object.hash(UpdaterInstalled, manifest);

  @override
  String toString() => 'UpdaterInstalled(manifest: $manifest)';
}

final class UpdaterError extends UpdaterMachineState {
  const UpdaterError({required this.subtype, required this.message});

  final UpdaterErrorSubtype subtype;
  final String message;

  UpdaterError copyWith({UpdaterErrorSubtype? subtype, String? message}) =>
      UpdaterError(
        subtype: subtype ?? this.subtype,
        message: message ?? this.message,
      );

  @override
  bool operator ==(Object other) =>
      other is UpdaterError &&
      other.subtype == subtype &&
      other.message == message;

  @override
  int get hashCode => Object.hash(UpdaterError, subtype, message);

  @override
  String toString() => 'UpdaterError(subtype: $subtype, message: $message)';
}
