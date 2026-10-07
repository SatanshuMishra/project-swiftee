import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/services/audio/audio_engine.dart';
import 'package:swiftie_quiz/services/updater/update_config.dart';
import 'package:swiftie_quiz/services/updater/update_downloader.dart';
import 'package:swiftie_quiz/services/updater/update_installer.dart';
import 'package:swiftie_quiz/services/updater/update_manifest_client.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/updater_controller.dart';

const UpdateManifest _manifest = UpdateManifest(
  version: '0.3.0',
  notes: 'notes',
  pubDate: '2026-05-01T00:00:00Z',
);

final DateTime _now = DateTime.utc(2026, 10, 5, 12, 0, 0, 123, 456);
const String _nowIso = '2026-10-05T12:00:00.123Z';

AvailableUpdate _availableUpdate({UpdateManifest manifest = _manifest}) =>
    AvailableUpdate(
      manifest: manifest,
      url: Uri.parse(
        'https://github.com/SatanshuMishra/project-swiftee/releases/download/'
        'v${manifest.version}/Swiftie.Quiz.app.tar.gz',
      ),
      signature: 'signature-${manifest.version}',
    );

typedef _CheckResponse = Future<AvailableUpdate?> Function();

typedef _Transfer = Future<Uint8List> Function(
  void Function(DownloadEvent event) onEvent,
);

typedef _Install = ({Uint8List bytes, String version});

final class _FakeManifestClient implements UpdateManifestClient {
  final List<_CheckResponse> responses = [];
  final List<String> runningVersions = [];

  int get calls => runningVersions.length;

  @override
  Future<AvailableUpdate?> check(String runningVersion) {
    runningVersions.add(runningVersion);
    if (runningVersions.length > responses.length) {
      return Future.error(StateError('unexpected update check'));
    }
    return responses[runningVersions.length - 1]();
  }
}

final class _FakeDownloader implements UpdateDownloader {
  _FakeDownloader(this.bytes);

  final Uint8List bytes;
  final List<AvailableUpdate> downloads = [];
  final Completer<void> _started = Completer<void>();
  late _Transfer transfer = (onEvent) async => bytes;

  Future<void> get started => _started.future;

  @override
  Future<Uint8List> download(
    AvailableUpdate update, {
    required void Function(DownloadEvent event) onEvent,
  }) {
    downloads.add(update);
    if (!_started.isCompleted) {
      _started.complete();
    }
    return transfer(onEvent);
  }
}

final class _FakeInstaller implements UpdateInstaller {
  final List<String> calls = [];
  final List<_Install> installs = [];
  Future<void> Function() onInstall = () async {};
  Future<void> Function() onRelaunch = () async {};

  @override
  Future<void> install(Uint8List bytes, {required String version}) {
    calls.add('install');
    installs.add((bytes: bytes, version: version));
    return onInstall();
  }

  @override
  Future<void> relaunch() {
    calls.add('relaunch');
    return onRelaunch();
  }
}

void main() {
  group('updater controller parity', () {
    late ProviderContainer container;
    late _FakeManifestClient manifestClient;
    late _FakeDownloader downloader;
    late _FakeInstaller installer;
    late Uint8List downloadedBytes;

    UpdaterController updater() => container.read(updaterControllerProvider);

    UpdaterMachineState state() => updater().state;

    GameController game() => container.read(gameControllerProvider.notifier);

    GameProgress progress() => container.read(gameControllerProvider).progress;

    void setUpdaterPrefs(UpdaterState Function(UpdaterState updater) change) =>
        game().setProgress(
          progress().copyWith(updater: change(progress().updater)),
        );

    Future<void> reachReady() async {
      manifestClient.responses.add(() async => _availableUpdate());
      await updater().check();
      await updater().download();
    }

    setUp(() {
      downloadedBytes = Uint8List.fromList([0x1f, 0x8b, 0x08, 0x00]);
      manifestClient = _FakeManifestClient();
      downloader = _FakeDownloader(downloadedBytes);
      installer = _FakeInstaller();
      container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          appVersionProvider.overrideWithValue(const AsyncData('0.2.0')),
          clockProvider.overrideWithValue(() => _now),
          updateManifestClientProvider.overrideWithValue(
            AsyncData(manifestClient),
          ),
          updateDownloaderProvider.overrideWithValue(AsyncData(downloader)),
          updateInstallerProvider.overrideWithValue(installer),
        ],
      );
    });

    test('starts in idle', () {
      expect(state(), const UpdaterIdle());
      expect(container.read(updaterStateProvider), const UpdaterIdle());
    });

    test('transitions idle → checking → up-to-date when no update', () async {
      manifestClient.responses.add(() async => null);

      final checking = updater().check();
      expect(state(), const UpdaterChecking());
      await checking;

      expect(state(), const UpdaterUpToDate());
      expect(manifestClient.runningVersions, ['0.2.0']);
    });

    test(
      'transitions idle → checking → available when update exists',
      () async {
        manifestClient.responses.add(
          () async => _availableUpdate(
            manifest: const UpdateManifest(
              version: '0.3.0',
              notes: '## Changes\n- thing',
              pubDate: '2026-05-01T00:00:00Z',
            ),
          ),
        );

        await updater().check();

        final available = state();
        expect(available, isA<UpdaterAvailable>());
        final manifest = (available as UpdaterAvailable).manifest;
        expect(manifest.version, '0.3.0');
        expect(manifest.notes, contains('Changes'));
      },
    );

    test('transitions to error: check on check failure', () async {
      manifestClient.responses.add(
        () => Future.error(const UpdateCheckException('network down')),
      );

      await updater().check();

      final error = state();
      expect(error, isA<UpdaterError>());
      expect((error as UpdaterError).subtype, UpdaterErrorSubtype.check);
      expect(error.message, contains('network'));
    });

    test('download() transitions available → downloading → ready', () async {
      downloader.transfer = (onEvent) async {
        onEvent(const DownloadStarted(contentLength: 1000));
        onEvent(const DownloadProgress(chunkLength: 500));
        onEvent(const DownloadProgress(chunkLength: 500));
        onEvent(const DownloadFinished());
        return downloadedBytes;
      };
      manifestClient.responses.add(() async => _availableUpdate());

      await updater().check();
      final downloading = updater().download();
      expect(
        state(),
        const UpdaterDownloading(manifest: _manifest, progress: 0),
      );
      await downloading;

      expect(state(), const UpdaterReady(manifest: _manifest));
      expect(downloader.downloads, [_availableUpdate()]);
    });

    test(
      'download() error mapped to error.subtype=signature when message hints '
      'verification failure',
      () async {
        downloader.transfer = (onEvent) => Future.error(
          const UpdateDownloadException('signature verification failed'),
        );
        manifestClient.responses.add(() async => _availableUpdate());

        await updater().check();
        await updater().download();

        final error = state();
        expect(error, isA<UpdaterError>());
        expect((error as UpdaterError).subtype, UpdaterErrorSubtype.signature);
      },
    );

    test(
      'download() error mapped to error.subtype=signature for every signature '
      'failure of the downloader',
      () async {
        downloader.transfer = (onEvent) => Future.error(
          const UpdateSignatureException('Invalid encoding in minisign data'),
        );
        manifestClient.responses.add(() async => _availableUpdate());

        await updater().check();
        await updater().download();

        expect(
          state(),
          const UpdaterError(
            subtype: UpdaterErrorSubtype.signature,
            message: 'Invalid encoding in minisign data',
          ),
        );
      },
    );

    test(
      'download() error mapped to error.subtype=download for generic failures',
      () async {
        downloader.transfer = (onEvent) =>
            Future.error(const UpdateDownloadException('connection reset'));
        manifestClient.responses.add(() async => _availableUpdate());

        await updater().check();
        await updater().download();

        final error = state();
        expect(error, isA<UpdaterError>());
        expect((error as UpdaterError).subtype, UpdaterErrorSubtype.download);
      },
    );

    test('download() reports whole-number percent progress', () async {
      downloader.transfer = (onEvent) async {
        onEvent(const DownloadStarted(contentLength: 1000));
        onEvent(const DownloadProgress(chunkLength: 333));
        onEvent(const DownloadProgress(chunkLength: 334));
        onEvent(const DownloadProgress(chunkLength: 333));
        onEvent(const DownloadFinished());
        return downloadedBytes;
      };
      manifestClient.responses.add(() async => _availableUpdate());
      final states = <UpdaterMachineState>[];
      container.listen(
        gameControllerProvider.select((game) => game.updaterState),
        (_, next) => states.add(next),
      );

      await updater().check();
      await updater().download();

      expect(
        [
          for (final downloading in states.whereType<UpdaterDownloading>())
            downloading.progress,
        ],
        [0, 33, 67, 100],
      );
      expect(states.last, const UpdaterReady(manifest: _manifest));
    });

    test('download() without a content length reports 0 percent', () async {
      downloader.transfer = (onEvent) async {
        onEvent(const DownloadStarted(contentLength: null));
        onEvent(const DownloadProgress(chunkLength: 500));
        expect(
          state(),
          const UpdaterDownloading(manifest: _manifest, progress: 0),
        );
        return downloadedBytes;
      };
      manifestClient.responses.add(() async => _availableUpdate());

      await updater().check();
      await updater().download();

      expect(state(), const UpdaterReady(manifest: _manifest));
    });

    test(
      'download() without a pending update reports a download error',
      () async {
        await updater().download();

        expect(
          state(),
          const UpdaterError(
            subtype: UpdaterErrorSubtype.download,
            message: 'No pending update',
          ),
        );
        expect(downloader.downloads, isEmpty);
      },
    );

    test(
      'install() relaunches the app after the update is installed',
      () async {
        await reachReady();

        await updater().install();

        expect(installer.calls, ['install', 'relaunch']);
        expect(installer.installs.single.bytes, same(downloadedBytes));
        expect(installer.installs.single.version, '0.3.0');
      },
    );

    test(
      'install() failure reports an install error and does not relaunch',
      () async {
        installer.onInstall = () =>
            Future.error(const UpdateInstallException('permission denied'));
        await reachReady();

        await updater().install();

        expect(installer.calls, ['install']);
        expect(
          state(),
          const UpdaterError(
            subtype: UpdaterErrorSubtype.install,
            message: 'permission denied',
          ),
        );
      },
    );

    test(
      'install() without a pending update reports an install error',
      () async {
        await updater().install();

        expect(
          state(),
          const UpdaterError(
            subtype: UpdaterErrorSubtype.install,
            message: 'No update to install',
          ),
        );
        expect(installer.calls, isEmpty);
      },
    );

    test('dismiss clears error to idle', () async {
      manifestClient.responses.add(
        () => Future.error(const UpdateCheckException('oops')),
      );

      await updater().check();
      expect(state(), isA<UpdaterError>());

      updater().dismiss();

      expect(state(), const UpdaterIdle());
    });

    test('cancel clears pending update and returns to idle', () async {
      manifestClient.responses.add(() async => _availableUpdate());

      await updater().check();
      expect(state(), isA<UpdaterAvailable>());

      updater().cancel();

      expect(state(), const UpdaterIdle());
      await updater().download();
      expect(downloader.downloads, isEmpty);
    });

    test(
      'skipVersion appends to gameStore.progress.updater.skippedVersions',
      () {
        updater().skipVersion('0.3.0');

        expect(progress().updater.skippedVersions, contains('0.3.0'));
        expect(state(), const UpdaterIdle());
      },
    );

    test('skipVersion preserves prior skippedVersions (immutable append)', () {
      setUpdaterPrefs((prefs) => prefs.copyWith(skippedVersions: ['0.2.5']));
      final before = progress().updater.skippedVersions;

      updater().skipVersion('0.3.0');

      expect(progress().updater.skippedVersions, ['0.2.5', '0.3.0']);
      expect(before, ['0.2.5']);
    });

    test('remindLater sets remindLaterUntil to ~24h in the future', () {
      final before = _now.millisecondsSinceEpoch;

      updater().remindLater();

      final remindLaterUntil = progress().updater.remindLaterUntil;
      expect(remindLaterUntil, isNotNull);
      final until = DateTime.parse(remindLaterUntil!).millisecondsSinceEpoch;
      expect(until - before, greaterThan(23 * 3600 * 1000));
      expect(until - before, lessThan(25 * 3600 * 1000));
      expect(remindLaterUntil, '2026-10-06T12:00:00.123Z');
      expect(state(), const UpdaterIdle());
    });

    test('auto-check is skipped when autoCheckEnabled is false', () async {
      setUpdaterPrefs((prefs) => prefs.copyWith(autoCheckEnabled: false));

      await updater().check();

      expect(manifestClient.calls, 0);
      expect(state(), const UpdaterIdle());
    });

    test('auto-check is skipped during remindLater cooldown', () async {
      final future = _now.add(const Duration(hours: 12)).toIso8601String();
      setUpdaterPrefs((prefs) => prefs.copyWith(remindLaterUntil: future));

      await updater().check();

      expect(manifestClient.calls, 0);
      expect(state(), const UpdaterIdle());
    });

    test(
      'auto-check runs again once the remindLater cooldown has passed',
      () async {
        final past = _now
            .subtract(const Duration(minutes: 1))
            .toIso8601String();
        setUpdaterPrefs((prefs) => prefs.copyWith(remindLaterUntil: past));
        manifestClient.responses.add(() async => null);

        await updater().check();

        expect(manifestClient.calls, 1);
        expect(state(), const UpdaterUpToDate());
      },
    );

    test('manual check bypasses autoCheckEnabled=false', () async {
      setUpdaterPrefs((prefs) => prefs.copyWith(autoCheckEnabled: false));
      manifestClient.responses.add(() async => null);

      await updater().check(manual: true);

      expect(manifestClient.calls, 1);
      expect(state(), const UpdaterUpToDate());
    });

    test('manual check bypasses the remindLater cooldown', () async {
      final future = _now.add(const Duration(hours: 12)).toIso8601String();
      setUpdaterPrefs((prefs) => prefs.copyWith(remindLaterUntil: future));
      manifestClient.responses.add(() async => _availableUpdate());

      await updater().check(manual: true);

      expect(manifestClient.calls, 1);
      expect(state(), const UpdaterAvailable(manifest: _manifest));
    });

    test('available update is demoted to up-to-date if version is in '
        'skippedVersions', () async {
      setUpdaterPrefs((prefs) => prefs.copyWith(skippedVersions: ['0.3.0']));
      manifestClient.responses.add(
        () async => _availableUpdate(
          manifest: const UpdateManifest(
            version: '0.3.0',
            notes: '',
            pubDate: '',
          ),
        ),
      );

      await updater().check();

      expect(state(), const UpdaterUpToDate());
    });

    test('a skipped version is not offered on a manual check either', () async {
      setUpdaterPrefs((prefs) => prefs.copyWith(skippedVersions: ['0.3.0']));
      manifestClient.responses.add(() async => _availableUpdate());

      await updater().check(manual: true);

      expect(state(), const UpdaterUpToDate());
      await updater().download();
      expect(downloader.downloads, isEmpty);
    });

    test('successful check writes lastCheckedAt to progress.updater', () async {
      manifestClient.responses.add(() async => null);

      await updater().check();

      final lastChecked = progress().updater.lastCheckedAt;
      expect(lastChecked, isNotNull);
      expect(lastChecked, _nowIso);
    });

    test('a failed check leaves lastCheckedAt unset', () async {
      manifestClient.responses.add(
        () => Future.error(const UpdateCheckException('network down')),
      );

      await updater().check();

      expect(progress().updater.lastCheckedAt, isNull);
    });

    test(
      'a check keeps progress changes made while it was in flight',
      () async {
        final response = Completer<AvailableUpdate?>();
        manifestClient.responses.add(() => response.future);

        final pending = updater().check();
        await pumpEventQueue();
        expect(manifestClient.calls, 1);
        game().setProgress(
          progress().copyWith(
            stats: progress().stats.copyWith(totalCorrect: 7),
          ),
        );
        response.complete(null);
        await pending;

        expect(progress().stats.totalCorrect, 7);
        expect(progress().updater.lastCheckedAt, isNotNull);
      },
    );

    for (final (kind, inHand) in const <(String, UpdaterMachineState)>[
      ('downloading', UpdaterDownloading(manifest: _manifest, progress: 40)),
      ('ready', UpdaterReady(manifest: _manifest)),
      ('installing', UpdaterInstalling()),
      ('installed', UpdaterInstalled(manifest: _manifest)),
    ]) {
      test('a check while the update is $kind leaves it alone', () async {
        game().setUpdaterState(inHand);

        await updater().check(manual: true);

        expect(manifestClient.calls, 0);
        expect(state(), inHand);
      });
    }

    for (final (outcome, settle)
        in <(String, void Function(Completer<AvailableUpdate?>))>[
          (
            'finds an update',
            (second) => second.complete(
              _availableUpdate(manifest: _manifest.copyWith(version: '0.4.0')),
            ),
          ),
          (
            'fails',
            (second) => second.completeError(
              const UpdateCheckException('network down'),
            ),
          ),
        ]) {
      test('a check that $outcome after a download started leaves the download '
          'alone', () async {
        final first = Completer<AvailableUpdate?>();
        final second = Completer<AvailableUpdate?>();
        final downloaded = _availableUpdate();
        manifestClient.responses
          ..add(() => first.future)
          ..add(() => second.future);

        final firstCheck = updater().check(manual: true);
        final secondCheck = updater().check(manual: true);
        first.complete(downloaded);
        await firstCheck;
        await updater().download();
        settle(second);
        await secondCheck;

        expect(manifestClient.calls, 2);
        expect(state(), const UpdaterReady(manifest: _manifest));

        await updater().install();

        expect(installer.installs, hasLength(1));
        expect(installer.installs.single.version, '0.3.0');
        expect(installer.installs.single.bytes, same(downloadedBytes));
        expect(downloader.downloads, [downloaded]);
      });
    }

    for (final (outcome, settle)
        in <(String, void Function(Completer<Uint8List>))>[
          ('completes', (transfer) => transfer.complete(Uint8List(4))),
          (
            'fails',
            (transfer) => transfer.completeError(
              const UpdateDownloadException('connection reset'),
            ),
          ),
        ]) {
      test(
        'a cancelled download that later $outcome leaves the updater idle and '
        'checkable',
        () async {
          final transfer = Completer<Uint8List>();
          void Function(DownloadEvent event) report = (_) {};
          downloader.transfer = (onEvent) {
            report = onEvent;
            return transfer.future;
          };
          manifestClient.responses
            ..add(() async => _availableUpdate())
            ..add(() async => null);

          await updater().check();
          final downloading = updater().download();
          await downloader.started;
          updater().cancel();
          report(const DownloadStarted(contentLength: 100));
          report(const DownloadProgress(chunkLength: 100));
          settle(transfer);
          await downloading;

          expect(state(), const UpdaterIdle());

          await updater().check(manual: true);

          expect(manifestClient.calls, 2);
          expect(state(), const UpdaterUpToDate());
          await updater().install();
          expect(installer.calls, isEmpty);
        },
      );
    }

    test('a failed restart after a successful install reports the update as '
        'installed', () async {
      installer.onRelaunch = () =>
          Future.error(const UpdateInstallException('restart not allowed'));
      await reachReady();

      await updater().install();

      expect(installer.installs, hasLength(1));
      expect(state(), const UpdaterInstalled(manifest: _manifest));
    });

    test(
      'retry after a failed check checks again and never installs',
      () async {
        manifestClient.responses
          ..add(() => Future.error(const UpdateCheckException('network down')))
          ..add(() async => _availableUpdate());
        await updater().check();
        expect(state(), isA<UpdaterError>());

        await updater().retry();

        expect(manifestClient.calls, 2);
        expect(installer.calls, isEmpty);
        expect(state(), const UpdaterAvailable(manifest: _manifest));
      },
    );

    test('retry after a failed download downloads again', () async {
      downloader.transfer = (onEvent) async => downloader.downloads.length == 1
          ? throw const UpdateDownloadException('connection reset')
          : downloadedBytes;
      manifestClient.responses.add(() async => _availableUpdate());
      await updater().check();
      await updater().download();
      expect(state(), isA<UpdaterError>());

      await updater().retry();

      expect(downloader.downloads, hasLength(2));
      expect(manifestClient.calls, 1);
      expect(installer.calls, isEmpty);
      expect(state(), const UpdaterReady(manifest: _manifest));
    });

    test('retry after a failed install installs again', () async {
      installer.onInstall = () => installer.installs.length == 1
          ? Future.error(const UpdateInstallException('permission denied'))
          : Future<void>.value();
      await reachReady();
      await updater().install();
      expect(state(), isA<UpdaterError>());

      await updater().retry();

      expect(installer.calls, ['install', 'install', 'relaunch']);
      expect(manifestClient.calls, 1);
    });
  });

  group('update platform', () {
    for (final edition in Edition.values) {
      test('the ${edition.name} edition reads the manifest key of its '
          'build', () {
        final container = ProviderContainer.test(
          overrides: [editionProvider.overrideWithValue(edition)],
        );

        expect(
          container.read(updatePlatformProvider),
          UpdatePlatform.forBuild(Platform.operatingSystem, edition),
        );
      });
    }
  });

  group('leaving the app', () {
    ProviderContainer exitContainer(_ShutdownEngine engine, List<String> log) =>
        ProviderContainer.test(
          overrides: [
            audioEngineProvider.overrideWithValue(engine),
            processExitProvider.overrideWithValue(
              (code) => log.add('exit $code'),
            ),
          ],
        );

    test('shuts the audio engine down before the process exits', () async {
      final log = <String>[];
      final engine = _ShutdownEngine(log, () async {});

      await exitContainer(engine, log).read(appExitProvider)(0);

      expect(log, ['shutdown', 'exit 0']);
    });

    test('still exits when the audio engine fails to shut down', () async {
      final log = <String>[];
      final engine = _ShutdownEngine(
        log,
        () => Future<void>.error(StateError('device lost')),
      );

      await exitContainer(engine, log).read(appExitProvider)(0);

      expect(log, ['shutdown', 'exit 0']);
    });

    test('exits once the shutdown limit passes when the audio engine '
        'never finishes', () {
      fakeAsync((async) {
        final log = <String>[];
        final engine = _ShutdownEngine(log, () => Completer<void>().future);

        unawaited(exitContainer(engine, log).read(appExitProvider)(0));
        async.elapse(audioShutdownLimit - const Duration(milliseconds: 1));
        expect(log, ['shutdown']);

        async.elapse(const Duration(milliseconds: 1));
        expect(log, ['shutdown', 'exit 0']);
      });
    });
  });
}

final class _ShutdownEngine implements AudioEngine {
  _ShutdownEngine(this._log, this._shutdown);

  final List<String> _log;
  final Future<void> Function() _shutdown;

  @override
  Future<void> shutdown() {
    _log.add('shutdown');
    return _shutdown();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} was not expected');
}
