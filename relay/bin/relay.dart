import 'dart:io';

import 'package:swiftie_relay/relay.dart';
import 'package:together_protocol/together_protocol.dart';

const _defaultPort = 8080;
const _usageExitCode = 64;
const _healthTimeout = Duration(seconds: 3);

Future<void> main(List<String> arguments) async {
  try {
    await _run(arguments, Platform.environment);
  } on _Misconfigured catch (problem) {
    stderr.writeln(problem.reason);
    exitCode = _usageExitCode;
  }
}

Future<void> _run(
  List<String> arguments,
  Map<String, String> environment,
) async {
  final port = _portFrom(environment['RELAY_PORT']);
  switch (arguments) {
    case ['--health']:
      exitCode = await _healthy(port) ? 0 : 1;
    case []:
      await _serve(
        port: port,
        key: await _keyFrom(environment['RELAY_KEY_FILE']),
        trustCloudflareAddress: environment['RELAY_TRUST_CF_IP'] == 'true',
      );
    default:
      throw const _Misconfigured(
        'Run relay with no arguments, or with --health to check a running relay.',
      );
  }
}

int _portFrom(String? value) {
  final port = value == null ? _defaultPort : int.tryParse(value.trim());
  if (port == null || port < 1 || port > 65535) {
    throw const _Misconfigured('RELAY_PORT must be a number from 1 to 65535.');
  }
  return port;
}

Future<String> _keyFrom(String? path) async {
  if (path == null || path.trim().isEmpty) {
    throw const _Misconfigured(
      'Set RELAY_KEY_FILE to the file that holds the relay key.',
    );
  }
  final String contents;
  try {
    contents = await File(path).readAsString();
  } on Exception {
    throw const _Misconfigured(
      "Couldn't read the key file named by RELAY_KEY_FILE.",
    );
  }
  final key = contents.trim();
  if (!isServerKey(key)) {
    throw const _Misconfigured(
      'The key file must hold 43 base64url characters, such as the output of '
      'openssl rand 32 | basenc --base64url | tr -d =',
    );
  }
  return key;
}

Future<void> _serve({
  required int port,
  required String key,
  required bool trustCloudflareAddress,
}) async {
  final relay = await RelayServer.start(
    key: key,
    address: InternetAddress.anyIPv4,
    port: port,
    trustCloudflareAddress: trustCloudflareAddress,
    log: stdout.writeln,
  );
  await ProcessSignal.sigterm.watch().first;
  await relay.close();
}

Future<bool> _healthy(int port) async {
  final client = HttpClient()..connectionTimeout = _healthTimeout;
  try {
    final request = await client.getUrl(
      Uri.http('127.0.0.1:$port', '/healthz'),
    );
    final response = await request.close().timeout(_healthTimeout);
    await response.drain<void>().timeout(_healthTimeout);
    return response.statusCode == HttpStatus.ok;
  } on Exception {
    return false;
  } finally {
    client.close(force: true);
  }
}

final class _Misconfigured implements Exception {
  const _Misconfigured(this.reason);

  final String reason;
}
