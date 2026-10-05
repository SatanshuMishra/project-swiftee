import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

typedef TempDirectoryProvider = Future<Directory> Function(String prefix);

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

typedef ProcessStarter = Future<void> Function(
  String executable,
  List<String> arguments, {
  ProcessStartMode mode,
});

typedef ExitProcess = void Function(int code);

final class UpdateInstallException implements Exception {
  const UpdateInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class UpdateInstaller {
  Future<void> install(Uint8List bytes, {required String version});

  Future<void> relaunch();
}

String macBundlePathFromExecutable(String executablePath) {
  final executableDirectory = p.posix.dirname(executablePath);
  return executableDirectory.contains('Contents/MacOS')
      ? p.posix.dirname(p.posix.dirname(executableDirectory))
      : executableDirectory;
}

String macAdministratorSwapScript({
  required String bundlePath,
  required String newBundlePath,
}) {
  final shellCommand =
      'rm -rf ${_shellQuoted(bundlePath)} && '
      'mv -f ${_shellQuoted(newBundlePath)} ${_shellQuoted(bundlePath)}';
  return 'do shell script "${_appleScriptEscaped(shellCommand)}" '
      'with administrator privileges';
}

List<String> windowsInstallerArguments() => const [
  '/P',
  '/UPDATE',
  '/R',
  '/ARGS',
];

String windowsInstallerFileName(String version) =>
    'Swiftie Quiz-$version-installer.exe';

String _shellQuoted(String value) => "'${value.replaceAll("'", r"'\''")}'";

String _appleScriptEscaped(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

final class MacUpdateInstaller implements UpdateInstaller {
  const MacUpdateInstaller({
    required this.bundlePath,
    required this._createTempDirectory,
    required this._runProcess,
    this._exitProcess = exit,
  });

  final String bundlePath;
  final TempDirectoryProvider _createTempDirectory;
  final ProcessRunner _runProcess;
  final ExitProcess _exitProcess;

  static const _permissionDeniedCodes = {1, 13};
  static const _chmodBatchSize = 200;

  @override
  Future<void> install(Uint8List bytes, {required String version}) async {
    final backupDirectory = await _createTempDirectory(
      'swiftie_quiz_current_app',
    );
    final extractDirectory = await _createTempDirectory(
      'swiftie_quiz_updated_app',
    );
    try {
      await _unpack(bytes, extractDirectory.path);
    } on Object {
      await _deleteQuietly(extractDirectory);
      await _deleteQuietly(backupDirectory);
      rethrow;
    }
    final backupPath = p.join(backupDirectory.path, 'current_app');
    try {
      await Directory(bundlePath).rename(backupPath);
    } on FileSystemException catch (error) {
      if (_permissionDeniedCodes.contains(error.osError?.errorCode)) {
        await _deleteQuietly(backupDirectory);
        await _swapWithAdministratorPrivileges(extractDirectory);
        await _touchBundle();
        return;
      }
      await _deleteQuietly(extractDirectory);
      await _deleteQuietly(backupDirectory);
      throw UpdateInstallException(
        'Could not move the running app aside: ${_describe(error)}',
      );
    }
    try {
      await extractDirectory.rename(bundlePath);
    } on FileSystemException catch (error) {
      await _deleteQuietly(extractDirectory);
      await _restoreBackup(backupPath, error);
      await _deleteQuietly(backupDirectory);
      throw UpdateInstallException(
        'Could not move the new app into place, the previous version was '
        'restored: ${_describe(error)}',
      );
    }
    await _deleteQuietly(backupDirectory);
    await _touchBundle();
  }

  @override
  Future<void> relaunch() async {
    final result = await _runProcess('/usr/bin/open', ['-n', bundlePath]);
    if (result.exitCode != 0) {
      throw UpdateInstallException(
        'Could not relaunch the app: ${result.stderr}'.trim(),
      );
    }
    _exitProcess(0);
  }

  Future<void> _swapWithAdministratorPrivileges(
    Directory extractDirectory,
  ) async {
    final script = macAdministratorSwapScript(
      bundlePath: bundlePath,
      newBundlePath: extractDirectory.path,
    );
    final ProcessResult result;
    try {
      result = await _runProcess('/usr/bin/osascript', ['-e', script]);
    } on ProcessException {
      await _deleteQuietly(extractDirectory);
      throw const UpdateInstallException(
        'Failed to move the new app into place',
      );
    }
    if (result.exitCode != 0) {
      await _deleteQuietly(extractDirectory);
      throw const UpdateInstallException(
        'Failed to move the new app into place',
      );
    }
  }

  Future<void> _restoreBackup(
    String backupPath,
    FileSystemException moveError,
  ) async {
    try {
      await Directory(backupPath).rename(bundlePath);
    } on FileSystemException catch (restoreError) {
      throw UpdateInstallException(
        'Could not move the new app into place (${_describe(moveError)}) '
        'nor restore the previous version (${_describe(restoreError)}); '
        'it is kept at $backupPath',
      );
    }
  }

  Future<void> _touchBundle() async {
    try {
      await _runProcess('/usr/bin/touch', [bundlePath]);
    } on ProcessException {
      return;
    }
  }

  Future<void> _unpack(Uint8List bytes, String root) async {
    final entries = [
      for (final entry in _readTarEntries(bytes))
        _ArchiveEntry.plan(entry, root),
    ];
    final linkPaths = [
      for (final entry in entries)
        if (entry.kind == _EntryKind.symbolicLink) entry.path,
    ];
    final throughLink = entries.firstWhereOrNull(
      (entry) => linkPaths.any((link) => p.isWithin(link, entry.path)),
    );
    if (throughLink != null) {
      throw UpdateInstallException(
        'The update archive entry ${throughLink.path} lies inside a link',
      );
    }
    for (final entry in entries) {
      await entry.writeTo(root);
    }
    await _applyPermissions(entries);
  }

  Future<void> _applyPermissions(List<_ArchiveEntry> entries) async {
    final pathsByMode = groupBy(
      entries.where((entry) => entry.kind != _EntryKind.symbolicLink),
      (entry) => entry.permissions,
    );
    for (final MapEntry(key: permissions, value: group)
        in pathsByMode.entries) {
      final mode = permissions.toRadixString(8);
      for (final batch in group.slices(_chmodBatchSize)) {
        final result = await _runProcess('/bin/chmod', [
          mode,
          for (final entry in batch) entry.path,
        ]);
        if (result.exitCode != 0) {
          throw UpdateInstallException(
            'Could not set file permissions in the update: ${result.stderr}'
                .trim(),
          );
        }
      }
    }
  }

  static List<TarFile> _readTarEntries(Uint8List bytes) {
    try {
      final tar = const GZipDecoder().decodeBytes(bytes, verify: true);
      final decoder = TarDecoder();
      decoder.decodeBytes(tar, verify: true);
      return List.unmodifiable(decoder.files);
    } on Exception catch (error) {
      throw UpdateInstallException('The update archive is invalid: $error');
    }
  }

  static Future<void> _deleteQuietly(Directory directory) async {
    try {
      await directory.delete(recursive: true);
    } on FileSystemException {
      return;
    }
  }

  static String _describe(FileSystemException error) =>
      error.osError?.message ?? error.message;
}

enum _EntryKind { directory, file, symbolicLink }

final class _ArchiveEntry {
  const _ArchiveEntry({
    required this.kind,
    required this.path,
    required this.permissions,
    this.linkTarget,
    this.content,
  });

  factory _ArchiveEntry.plan(TarFile entry, String root) {
    final relative = _withoutFirstComponent(entry.filename);
    if (relative.contains('..')) {
      throw UpdateInstallException(
        'The update archive entry ${entry.filename} leaves the app bundle',
      );
    }
    final path = p.joinAll([root, ...relative]);
    final permissions = entry.mode & 0x1ff;
    switch (entry.typeFlag) {
      case TarFile.directory:
        return _ArchiveEntry(
          kind: _EntryKind.directory,
          path: path,
          permissions: permissions,
        );
      case TarFile.symbolicLink:
        final linkTarget = entry.nameOfLinkedFile ?? '';
        final resolved = p.normalize(p.join(p.dirname(path), linkTarget));
        final staysInside =
            relative.isNotEmpty &&
            linkTarget.isNotEmpty &&
            !p.isAbsolute(linkTarget) &&
            (p.equals(resolved, root) || p.isWithin(root, resolved));
        if (!staysInside) {
          throw UpdateInstallException(
            'The update archive link ${entry.filename} leaves the app bundle',
          );
        }
        return _ArchiveEntry(
          kind: _EntryKind.symbolicLink,
          path: path,
          permissions: permissions,
          linkTarget: linkTarget,
        );
      case TarFile.normalFile || TarFile.contFile || '':
        if (relative.isEmpty) {
          throw UpdateInstallException(
            'The update archive file ${entry.filename} is outside the app '
            'bundle',
          );
        }
        return _ArchiveEntry(
          kind: _EntryKind.file,
          path: path,
          permissions: permissions,
          content: entry.contentBytes ?? Uint8List(0),
        );
      default:
        throw UpdateInstallException(
          'The update archive entry ${entry.filename} has unsupported type '
          '${entry.typeFlag}',
        );
    }
  }

  final _EntryKind kind;
  final String path;
  final int permissions;
  final String? linkTarget;
  final Uint8List? content;

  Future<void> writeTo(String root) async {
    switch (kind) {
      case _EntryKind.directory:
        await Directory(path).create(recursive: true);
      case _EntryKind.file:
        await Directory(p.dirname(path)).create(recursive: true);
        await File(path).writeAsBytes(content ?? Uint8List(0), flush: true);
      case _EntryKind.symbolicLink:
        await Directory(p.dirname(path)).create(recursive: true);
        await Link(path).create(linkTarget ?? '');
    }
  }

  static List<String> _withoutFirstComponent(String archivePath) {
    final segments = archivePath.split('/');
    final components = [
      if (archivePath.startsWith('/')) '/',
      for (final (index, segment) in segments.indexed)
        if (segment.isNotEmpty && (segment != '.' || index == 0)) segment,
    ];
    return components.skip(1).toList(growable: false);
  }
}

final class WindowsUpdateInstaller implements UpdateInstaller {
  const WindowsUpdateInstaller({
    required this._createTempDirectory,
    required this._startProcess,
    this._exitProcess = exit,
  });

  final TempDirectoryProvider _createTempDirectory;
  final ProcessStarter _startProcess;
  final ExitProcess _exitProcess;

  @override
  Future<void> install(Uint8List bytes, {required String version}) async {
    if (bytes.length < 2 || bytes[0] != 0x4d || bytes[1] != 0x5a) {
      throw const UpdateInstallException('invalid updater binary format');
    }
    final directory = await _createTempDirectory(
      'Swiftie Quiz-$version-updater-',
    );
    final installer = File(
      p.join(directory.path, windowsInstallerFileName(version)),
    );
    await installer.writeAsBytes(bytes, flush: true);
    await _startProcess(
      installer.path,
      windowsInstallerArguments(),
      mode: ProcessStartMode.detached,
    );
    _exitProcess(0);
  }

  @override
  Future<void> relaunch() async {}
}
