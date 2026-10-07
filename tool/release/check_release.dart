import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const developmentKeyId = '2A43CC33F3FB57BB';
const minimumPublicKeyLength = 64;
const pubspecPath = 'pubspec.yaml';
const changelogPath = 'CHANGELOG.md';
const updateConfigPath = 'lib/services/updater/update_config.dart';
const trustedRootsPath = 'assets/certs/cacert.pem';
const maxTrustedRootsAge = Duration(days: 180);
const months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

final updaterPublicKeyLine = RegExp(
  r"^const updaterPublicKey = '([^']*)';$",
  multiLine: true,
);
final standardBase64 = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');
final releaseVersion = RegExp(r'^\d+\.\d+\.\d+$');
final trustedRootsTaken = RegExp(
  r'^## Certificate data from Mozilla as of: \w{3} (\w{3}) +(\d{1,2}) '
  r'\d{2}:\d{2}:\d{2} (\d{4}) GMT$',
  multiLine: true,
);

final class ReleaseCheckFailure implements Exception {
  const ReleaseCheckFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

String versionFromTag(String tag) =>
    tag.startsWith('v') ? tag.substring(1) : tag;

String pubspecVersion(String pubspec) {
  final document = loadYaml(pubspec);
  final version = document is YamlMap ? document['version'] : null;
  if (version == null || '$version'.trim().isEmpty) {
    throw const ReleaseCheckFailure('pubspec.yaml has no version');
  }
  return '$version'.split('+').first.trim();
}

bool isBlank(String line) => line.trim().isEmpty;

String changelogSection(String changelog, String version) {
  final lines = const LineSplitter().convert(changelog);
  final heading = '## [$version]';
  final start = lines.indexWhere((line) => line.startsWith(heading));
  if (start < 0) {
    throw ReleaseCheckFailure('No CHANGELOG.md entry found for $heading');
  }
  final section = lines
      .skip(start + 1)
      .takeWhile((line) => !line.startsWith('## ['))
      .toList();
  final first = section.indexWhere((line) => !isBlank(line));
  if (first < 0) {
    throw ReleaseCheckFailure('The CHANGELOG section for $version is empty');
  }
  final last = section.lastIndexWhere((line) => !isBlank(line));
  return section.sublist(first, last + 1).join('\n');
}

List<int>? decodeStandardBase64(String text) {
  if (!standardBase64.hasMatch(text)) {
    return null;
  }
  try {
    return base64.decode(text);
  } on FormatException {
    return null;
  }
}

void checkUpdaterPublicKey(String updateConfig) {
  final match = updaterPublicKeyLine.firstMatch(updateConfig);
  if (match == null) {
    throw const ReleaseCheckFailure(
      '$updateConfigPath does not declare '
      "const updaterPublicKey = '...'; on a line of its own",
    );
  }
  final key = match.group(1)!;
  if (key.length < minimumPublicKeyLength) {
    throw const ReleaseCheckFailure(
      'The updater public key is empty or implausibly short. '
      'Embed the production minisign public key before releasing.',
    );
  }
  final decoded = decodeStandardBase64(key);
  if (decoded == null) {
    throw const ReleaseCheckFailure(
      'The updater public key is not valid base64.',
    );
  }
  if (utf8.decode(decoded, allowMalformed: true).contains(developmentKeyId)) {
    throw const ReleaseCheckFailure(
      'The development minisign public key (key ID $developmentKeyId) is '
      'still embedded. Rotate to the production key pair before releasing.',
    );
  }
}

DateTime? trustedRootsDate(String pem) {
  final match = trustedRootsTaken.firstMatch(pem);
  final month = months.indexOf(match?.group(1) ?? '') + 1;
  if (match == null || month == 0) {
    return null;
  }
  return DateTime.utc(
    int.parse(match.group(3)!),
    month,
    int.parse(match.group(2)!),
  );
}

void checkTrustedRootsAge(String pem, DateTime now) {
  final taken = trustedRootsDate(pem);
  if (taken == null) {
    throw const ReleaseCheckFailure(
      '$trustedRootsPath does not say when its roots were taken from '
      'Mozilla; replace it with https://curl.se/ca/cacert.pem',
    );
  }
  if (now.difference(taken) > maxTrustedRootsAge) {
    throw ReleaseCheckFailure(
      '$trustedRootsPath holds Mozilla roots from '
      '${taken.toIso8601String().substring(0, 10)}, more than '
      '${maxTrustedRootsAge.inDays} days old. Refresh it as '
      'docs/decisions/2026-10-07-windows-trusted-roots.md describes.',
    );
  }
}

String checkRelease({
  required String tag,
  required String pubspec,
  required String changelog,
  required String updateConfig,
}) {
  final version = versionFromTag(tag);
  if (!releaseVersion.hasMatch(version)) {
    throw ReleaseCheckFailure(
      'Releases use MAJOR.MINOR.PATCH versions; $tag is not one, and the '
      'Windows installer cannot be built for it',
    );
  }
  final declared = pubspecVersion(pubspec);
  if (version != declared) {
    throw ReleaseCheckFailure(
      'Version drift: tag $tag is $version but pubspec.yaml is $declared',
    );
  }
  final notes = changelogSection(changelog, version);
  checkUpdaterPublicKey(updateConfig);
  return notes;
}

int runCheckRelease(
  List<String> arguments, {
  required String root,
  required StringSink output,
  required StringSink errors,
  required DateTime now,
}) {
  if (arguments.length != 1 || arguments.single.isEmpty) {
    errors.writeln('usage: dart run tool/release/check_release.dart <tag>');
    return 64;
  }
  String read(String relativePath) =>
      File(p.join(root, relativePath)).readAsStringSync();
  try {
    final notes = checkRelease(
      tag: arguments.single,
      pubspec: read(pubspecPath),
      changelog: read(changelogPath),
      updateConfig: read(updateConfigPath),
    );
    checkTrustedRootsAge(read(trustedRootsPath), now);
    output.writeln(notes);
    return 0;
  } on ReleaseCheckFailure catch (failure) {
    errors.writeln('::error::${failure.message}');
    return 1;
  } on FileSystemException catch (failure) {
    errors.writeln('::error::Cannot read ${failure.path}: ${failure.message}');
    return 1;
  }
}

void main(List<String> arguments) {
  exitCode = runCheckRelease(
    arguments,
    root: Directory.current.path,
    output: stdout,
    errors: stderr,
    now: DateTime.now().toUtc(),
  );
}
