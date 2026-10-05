import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/services/updater/update_config.dart';
import 'package:swiftie_quiz/services/updater/update_downloader.dart';
import 'package:swiftie_quiz/services/updater/update_installer.dart';
import 'package:swiftie_quiz/services/updater/update_manifest_client.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

const Duration remindLaterInterval = Duration(hours: 24);

const String _unsupportedPlatformMessage =
    'Updates are not supported on this platform';
const String _noPendingUpdateMessage = 'No pending update';
const String _noUpdateToInstallMessage = 'No update to install';
const String _notDownloadedMessage = 'The update has not been downloaded';

final RegExp _signatureFailurePattern = RegExp(
  'signature|verif',
  caseSensitive: false,
);

final updatePlatformProvider = Provider<UpdatePlatform?>(
  (ref) => UpdatePlatform.forOperatingSystem(Platform.operatingSystem),
);

final updateManifestClientProvider = FutureProvider<UpdateManifestClient?>((
  ref,
) async {
  final platform = ref.watch(updatePlatformProvider);
  if (platform == null) {
    return null;
  }
  return UpdateManifestClient(
    client: ref.watch(httpClientProvider),
    userAgent: await ref.watch(userAgentProvider.future),
    platform: platform,
  );
});

final updateDownloaderProvider = FutureProvider<UpdateDownloader>(
  (ref) async => UpdateDownloader(
    client: ref.watch(httpClientProvider),
    userAgent: await ref.watch(userAgentProvider.future),
  ),
);

final updateInstallerProvider = Provider<UpdateInstaller>(
  (ref) => Platform.isWindows
      ? WindowsUpdateInstaller(
          createTempDirectory: Directory.systemTemp.createTemp,
          startProcess: Process.start,
        )
      : MacUpdateInstaller(
          bundlePath: macBundlePathFromExecutable(Platform.resolvedExecutable),
          createTempDirectory: Directory.systemTemp.createTemp,
          runProcess: Process.run,
        ),
);

final updaterStateProvider = Provider<UpdaterMachineState>(
  (ref) =>
      ref.watch(gameControllerProvider.select((game) => game.updaterState)),
);

final updaterControllerProvider = Provider<UpdaterController>((ref) {
  final controller = UpdaterController(ref);
  ref.onDispose(controller._abandonPendingUpdate);
  return controller;
});

final class _PendingUpdate {
  _PendingUpdate(this.update);

  final AvailableUpdate update;

  UpdateManifest get manifest => update.manifest;
}

typedef _DownloadedUpdate = ({_PendingUpdate owner, Uint8List bytes});

class UpdaterController {
  UpdaterController(this._ref);

  final Ref _ref;
  _PendingUpdate? _pending;
  _DownloadedUpdate? _downloaded;

  UpdaterMachineState get state =>
      _ref.read(gameControllerProvider).updaterState;

  Future<void> check({bool manual = false}) async {
    if (_updateInHand) {
      return;
    }
    if (!manual && !_autoCheckAllowed(_progress.updater)) {
      return;
    }
    _setState(const UpdaterChecking());
    try {
      final update = await _fetchUpdate();
      if (!_ref.mounted) {
        return;
      }
      final latest = _progress;
      _game.setProgress(
        latest.copyWith(
          updater: latest.updater.copyWith(lastCheckedAt: _isoNow()),
        ),
      );
      if (_updateInHand) {
        return;
      }
      if (update == null ||
          latest.updater.skippedVersions.contains(update.manifest.version)) {
        _abandonPendingUpdate();
        _setState(const UpdaterUpToDate());
        return;
      }
      _pending = _PendingUpdate(update);
      _setState(UpdaterAvailable(manifest: update.manifest));
    } on Object catch (error) {
      if (!_ref.mounted || _updateInHand) {
        return;
      }
      _setState(
        UpdaterError(subtype: UpdaterErrorSubtype.check, message: '$error'),
      );
    }
  }

  Future<void> download() async {
    final pending = _pending;
    if (pending == null) {
      _setState(
        const UpdaterError(
          subtype: UpdaterErrorSubtype.download,
          message: _noPendingUpdateMessage,
        ),
      );
      return;
    }
    final manifest = pending.manifest;
    _setState(UpdaterDownloading(manifest: manifest, progress: 0));
    var received = 0;
    var total = 0;
    void onEvent(DownloadEvent event) {
      if (!_isPending(pending)) {
        return;
      }
      switch (event) {
        case DownloadStarted(:final contentLength):
          total = contentLength ?? 0;
        case DownloadProgress(:final chunkLength):
          received += chunkLength;
          _setState(
            UpdaterDownloading(
              manifest: manifest,
              progress: _percent(received, total),
            ),
          );
        case DownloadFinished():
          break;
      }
    }

    try {
      final downloader = await _ref.read(updateDownloaderProvider.future);
      if (!_isPending(pending)) {
        return;
      }
      final bytes = await downloader.download(pending.update, onEvent: onEvent);
      if (!_isPending(pending)) {
        return;
      }
      _downloaded = (owner: pending, bytes: bytes);
      _setState(UpdaterReady(manifest: manifest));
    } on Object catch (error) {
      if (!_isPending(pending)) {
        return;
      }
      final message = '$error';
      _setState(
        UpdaterError(
          subtype: _isSignatureFailure(error, message)
              ? UpdaterErrorSubtype.signature
              : UpdaterErrorSubtype.download,
          message: message,
        ),
      );
    }
  }

  Future<void> install() async {
    final pending = _pending;
    if (pending == null) {
      _setState(
        const UpdaterError(
          subtype: UpdaterErrorSubtype.install,
          message: _noUpdateToInstallMessage,
        ),
      );
      return;
    }
    _setState(const UpdaterInstalling());
    final UpdateInstaller installer;
    try {
      installer = _ref.read(updateInstallerProvider);
      await installer.install(
        _downloadedBytes(pending),
        version: pending.manifest.version,
      );
    } on Object catch (error) {
      if (_ref.mounted) {
        _setState(
          UpdaterError(subtype: UpdaterErrorSubtype.install, message: '$error'),
        );
      }
      return;
    }
    if (identical(_downloaded?.owner, pending)) {
      _downloaded = null;
    }
    try {
      await installer.relaunch();
    } on Object {
      if (_ref.mounted) {
        _setState(UpdaterInstalled(manifest: pending.manifest));
      }
    }
  }

  Future<void> retry() => switch (state) {
    UpdaterError(subtype: UpdaterErrorSubtype.check) => check(manual: true),
    UpdaterError(subtype: UpdaterErrorSubtype.download) => download(),
    UpdaterError() => install(),
    _ => Future<void>.value(),
  };

  void cancel() {
    _abandonPendingUpdate();
    _setState(const UpdaterIdle());
  }

  void skipVersion(String version) {
    final progress = _progress;
    _game.setProgress(
      progress.copyWith(
        updater: progress.updater.copyWith(
          skippedVersions: [...progress.updater.skippedVersions, version],
        ),
      ),
    );
    _abandonPendingUpdate();
    _setState(const UpdaterIdle());
  }

  void remindLater() {
    final until = _isoTimestamp(_now().add(remindLaterInterval));
    final progress = _progress;
    _game.setProgress(
      progress.copyWith(
        updater: progress.updater.copyWith(remindLaterUntil: until),
      ),
    );
    _abandonPendingUpdate();
    _setState(const UpdaterIdle());
  }

  void dismiss() => _setState(const UpdaterIdle());

  Future<AvailableUpdate?> _fetchUpdate() async {
    final client = await _ref.read(updateManifestClientProvider.future);
    if (client == null) {
      throw const UpdateCheckException(_unsupportedPlatformMessage);
    }
    return client.check(await _ref.read(appVersionProvider.future));
  }

  Uint8List _downloadedBytes(_PendingUpdate pending) {
    final downloaded = _downloaded;
    if (downloaded == null || !identical(downloaded.owner, pending)) {
      throw const UpdateInstallException(_notDownloadedMessage);
    }
    return downloaded.bytes;
  }

  bool _autoCheckAllowed(UpdaterState updater) {
    if (!updater.autoCheckEnabled) {
      return false;
    }
    final until = DateTime.tryParse(updater.remindLaterUntil ?? '');
    return until == null || !until.isAfter(_now());
  }

  bool get _updateInHand => switch (state) {
    UpdaterDownloading() ||
    UpdaterReady() ||
    UpdaterInstalling() ||
    UpdaterInstalled() => true,
    _ => false,
  };

  bool _isPending(_PendingUpdate pending) =>
      _ref.mounted && identical(_pending, pending);

  void _abandonPendingUpdate() {
    _pending = null;
    _downloaded = null;
  }

  GameProgress get _progress => _ref.read(gameControllerProvider).progress;

  GameController get _game => _ref.read(gameControllerProvider.notifier);

  void _setState(UpdaterMachineState next) => _game.setUpdaterState(next);

  DateTime _now() => _ref.read(clockProvider)();

  String _isoNow() => _isoTimestamp(_now());

  static int _percent(int received, int total) =>
      total > 0 ? (received / total * 100).round().clamp(0, 100) : 0;

  static bool _isSignatureFailure(Object error, String message) =>
      error is UpdateSignatureException ||
      _signatureFailurePattern.hasMatch(message);

  static String _isoTimestamp(DateTime moment) =>
      DateTime.fromMillisecondsSinceEpoch(
        moment.millisecondsSinceEpoch,
        isUtc: true,
      ).toIso8601String();
}
