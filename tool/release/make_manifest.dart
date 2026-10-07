import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:swiftie_quiz/domain/engine/release_notes.dart';
import 'package:swiftie_quiz/services/updater/minisign.dart' as minisign;
import 'package:swiftie_quiz/services/updater/update_config.dart';

const macPlatforms = ['darwin-aarch64', 'darwin-aarch64-app'];
const windowsPlatforms = ['windows-x86_64', 'windows-x86_64-nsis'];
const manifestOptions = {
  'version',
  'notes-file',
  'pub-date',
  'base-url',
  'mac-tar',
  'mac-sig',
  'win-exe',
  'win-sig',
  'win-open-exe',
  'win-open-sig',
  'out',
};
const usage =
    'usage: dart run tool/release/make_manifest.dart --version <x.y.z> '
    '--notes-file <file> --pub-date <rfc3339> --base-url <url> '
    '--mac-tar <file> --mac-sig <file> --win-exe <file> --win-sig <file> '
    '--win-open-exe <file> --win-open-sig <file> --out <latest.json>';

final rfc3339 = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$',
);

final class UnverifiedArtifact implements Exception {
  const UnverifiedArtifact(this.message);

  final String message;

  @override
  String toString() => message;
}

final class SignedArtifact {
  const SignedArtifact({required this.fileName, required this.signature});

  final String fileName;
  final String signature;
}

Map<String, String> platformEntry(String baseUrl, SignedArtifact artifact) {
  if (artifact.fileName.trim().isEmpty) {
    throw const FormatException('An artifact has no file name');
  }
  final signature = artifact.signature.trim();
  if (signature.isEmpty) {
    throw FormatException('The signature for ${artifact.fileName} is empty');
  }
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return Map.unmodifiable({
    'signature': signature,
    'url': '$base/${Uri.encodeComponent(artifact.fileName)}',
  });
}

Map<String, Object> buildManifest({
  required String version,
  required String notes,
  required String pubDate,
  required String baseUrl,
  required SignedArtifact macArchive,
  required SignedArtifact windowsInstaller,
  required SignedArtifact windowsOpenInstaller,
}) {
  if (version.trim().isEmpty) {
    throw const FormatException('The version is empty');
  }
  if (!rfc3339.hasMatch(pubDate)) {
    throw FormatException('pub_date "$pubDate" is not an RFC 3339 timestamp');
  }
  if (windowsOpenInstaller.fileName == windowsInstaller.fileName) {
    throw FormatException(
      'The Open installer ${windowsOpenInstaller.fileName} is the Ana '
      'installer',
    );
  }
  final macEntry = platformEntry(baseUrl, macArchive);
  final windowsEntry = platformEntry(baseUrl, windowsInstaller);
  final windowsOpenEntry = platformEntry(baseUrl, windowsOpenInstaller);
  return Map.unmodifiable({
    'version': version,
    'notes': notes,
    'pub_date': pubDate,
    'platforms': Map<String, Map<String, String>>.unmodifiable({
      for (final platform in macPlatforms) platform: macEntry,
      for (final platform in windowsPlatforms) platform: windowsEntry,
      UpdatePlatform.windowsOpen.manifestKey: windowsOpenEntry,
    }),
  });
}

String encodeManifest(Map<String, Object> manifest) =>
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n';

Map<String, String> parseOptions(List<String> arguments) {
  if (arguments.length.isOdd) {
    throw const FormatException('Every option needs a value');
  }
  final pairs = [
    for (var index = 0; index < arguments.length; index += 2)
      MapEntry(arguments[index], arguments[index + 1]),
  ];
  for (final pair in pairs) {
    if (!pair.key.startsWith('--') ||
        !manifestOptions.contains(pair.key.substring(2))) {
      throw FormatException('Unknown option ${pair.key}');
    }
  }
  final options = Map<String, String>.unmodifiable({
    for (final pair in pairs) pair.key.substring(2): pair.value,
  });
  if (options.length != pairs.length) {
    throw const FormatException('An option was given more than once');
  }
  final missing = manifestOptions.difference(options.keys.toSet());
  if (missing.isNotEmpty) {
    throw FormatException('Missing --${missing.join(', --')}');
  }
  return options;
}

Future<void> verifyArtifact({
  required String artifactPath,
  required String signature,
  required String publicKey,
}) async {
  try {
    await minisign.verify(
      File(artifactPath).readAsBytesSync(),
      signature.trim(),
      publicKey,
    );
  } on minisign.MinisignException catch (failure) {
    throw UnverifiedArtifact(
      'The signature of ${p.basename(artifactPath)} does not verify with the '
      "app's update key: ${failure.message}",
    );
  }
}

Future<int> runMakeManifest(
  List<String> arguments, {
  required StringSink output,
  required StringSink errors,
  String publicKey = updaterPublicKey,
}) async {
  try {
    final options = parseOptions(arguments);
    String read(String option) => File(options[option]!).readAsStringSync();
    final macSignature = read('mac-sig');
    final windowsSignature = read('win-sig');
    final windowsOpenSignature = read('win-open-sig');
    await verifyArtifact(
      artifactPath: options['mac-tar']!,
      signature: macSignature,
      publicKey: publicKey,
    );
    await verifyArtifact(
      artifactPath: options['win-exe']!,
      signature: windowsSignature,
      publicKey: publicKey,
    );
    await verifyArtifact(
      artifactPath: options['win-open-exe']!,
      signature: windowsOpenSignature,
      publicKey: publicKey,
    );
    final manifest = buildManifest(
      version: options['version']!,
      notes: plainReleaseNotes(read('notes-file')),
      pubDate: options['pub-date']!,
      baseUrl: options['base-url']!,
      macArchive: SignedArtifact(
        fileName: p.basename(options['mac-tar']!),
        signature: macSignature,
      ),
      windowsInstaller: SignedArtifact(
        fileName: p.basename(options['win-exe']!),
        signature: windowsSignature,
      ),
      windowsOpenInstaller: SignedArtifact(
        fileName: p.basename(options['win-open-exe']!),
        signature: windowsOpenSignature,
      ),
    );
    File(options['out']!).writeAsStringSync(encodeManifest(manifest));
    output.writeln('Wrote ${options['out']}');
    return 0;
  } on UnverifiedArtifact catch (failure) {
    errors.writeln('::error::${failure.message}');
    return 1;
  } on FormatException catch (failure) {
    errors
      ..writeln('::error::${failure.message}')
      ..writeln(usage);
    return 64;
  } on FileSystemException catch (failure) {
    errors.writeln('::error::Cannot use ${failure.path}: ${failure.message}');
    return 1;
  }
}

Future<void> main(List<String> arguments) async {
  exitCode = await runMakeManifest(arguments, output: stdout, errors: stderr);
}
