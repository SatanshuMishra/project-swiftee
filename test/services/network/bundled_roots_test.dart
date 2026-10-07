import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/services/network/bundled_roots.dart';

final class _SystemRootsOnly extends HttpOverrides {}

const List<String> _rootsTheAppReaches = [
  'GTS Root R4',
  'ISRG Root X1',
  'ISRG Root X2',
  'DigiCert Global Root G2',
  'USERTrust ECC Certification Authority',
];

Iterable<String> _bundledRootNames(String pem) => RegExp(
  r'^(.+)\n=+\n-----BEGIN CERTIFICATE-----',
  multiLine: true,
).allMatches(pem).map((match) => match.group(1)!.trim());

Future<Directory> _issueServerCertificate() async {
  final dir = await Directory.systemTemp.createTemp('bundled_roots_test');
  Future<void> openssl(List<String> arguments) async {
    final result = await Process.run(
      'openssl',
      arguments,
      workingDirectory: dir.path,
    );
    if (result.exitCode != 0) {
      throw StateError('openssl ${arguments.first}: ${result.stderr}');
    }
  }

  File('${dir.path}/server.ext').writeAsStringSync(
    'subjectAltName=IP:127.0.0.1\n'
    'basicConstraints=CA:FALSE\n'
    'keyUsage=digitalSignature,keyEncipherment\n'
    'extendedKeyUsage=serverAuth\n',
  );
  await openssl([
    'req',
    '-x509',
    '-newkey',
    'rsa:2048',
    '-nodes',
    '-keyout',
    'root.key',
    '-out',
    'root.pem',
    '-days',
    '2',
    '-subj',
    '/CN=Swiftie Test Root',
    '-addext',
    'basicConstraints=critical,CA:TRUE',
    '-addext',
    'keyUsage=critical,keyCertSign,cRLSign',
  ]);
  await openssl([
    'req',
    '-newkey',
    'rsa:2048',
    '-nodes',
    '-keyout',
    'server.key',
    '-out',
    'server.csr',
    '-subj',
    '/CN=127.0.0.1',
  ]);
  await openssl([
    'x509',
    '-req',
    '-in',
    'server.csr',
    '-CA',
    'root.pem',
    '-CAkey',
    'root.key',
    '-CAcreateserial',
    '-out',
    'server.pem',
    '-days',
    '2',
    '-extfile',
    'server.ext',
  ]);
  return dir;
}

Future<int> _statusThrough(HttpOverrides overrides, Uri uri) =>
    HttpOverrides.runWithHttpOverrides(() async {
      final client = HttpClient();
      try {
        final response = await (await client.getUrl(uri)).close();
        await response.drain<void>();
        return response.statusCode;
      } finally {
        client.close(force: true);
      }
    }, overrides);

void main() {
  test(
    'a server signed by a bundled root is trusted only through the bundle',
    () async {
      final certificates = await _issueServerCertificate();
      addTearDown(() => certificates.delete(recursive: true));
      final server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        SecurityContext()
          ..useCertificateChain('${certificates.path}/server.pem')
          ..usePrivateKey('${certificates.path}/server.key'),
      );
      addTearDown(() => server.close(force: true));
      server.listen(
        (request) => request.response
          ..statusCode = HttpStatus.noContent
          ..close(),
      );
      final uri = Uri.https('127.0.0.1:${server.port}', '/');
      final bundle = BundledRootsOverrides(
        File('${certificates.path}/root.pem').readAsBytesSync(),
      );

      expect(await _statusThrough(bundle, uri), HttpStatus.noContent);
      await expectLater(
        _statusThrough(_SystemRootsOnly(), uri),
        throwsA(isA<HandshakeException>()),
      );
    },
  );

  test('the bundle holds the roots behind LRCLIB, Deezer, GitHub and the '
      'relay, and loads into a security context', () {
    final pem = File(bundledRootsAsset).readAsStringSync();

    expect(_bundledRootNames(pem), containsAll(_rootsTheAppReaches));
    expect(
      () => BundledRootsOverrides(File(bundledRootsAsset).readAsBytesSync()),
      returnsNormally,
    );
  });

  group('installing the bundle', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    Future<HttpOverrides?> installedOn(TargetPlatform platform) async {
      final before = HttpOverrides.current;
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        HttpOverrides.global = before;
      });
      HttpOverrides.global = null;
      await trustBundledRootsOnWindows(rootBundle);
      return HttpOverrides.current;
    }

    test('happens on Windows', () async {
      expect(
        await installedOn(TargetPlatform.windows),
        isA<BundledRootsOverrides>(),
      );
    });

    test('leaves macOS on its own certificate checks', () async {
      expect(await installedOn(TargetPlatform.macOS), isNull);
    });
  });
}
