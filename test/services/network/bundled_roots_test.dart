import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/services/network/bundled_roots.dart';

final class _SystemRootsOnly extends HttpOverrides {}

final class _Bundle extends AssetBundle {
  _Bundle(this._load);

  final Future<ByteData> Function() _load;

  @override
  Future<ByteData> load(String key) => _load();

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) async => parser(await loadString(key));
}

const String _bundledRootsSha256 =
    'a41b5d356aea97a529fe27e0f7316d2f9d946d75927476cf9cf1b90637d00505';

const List<String> _rootsTheAppReaches = [
  'GTS Root R4',
  'ISRG Root X1',
  'ISRG Root X2',
  'DigiCert Global Root G2',
  'USERTrust ECC Certification Authority',
  'Starfield Root Certificate Authority - G2',
];

Iterable<String> _bundledRootNames(String pem) => RegExp(
  r'^(.+)\n=+\n-----BEGIN CERTIFICATE-----',
  multiLine: true,
).allMatches(pem).map((match) => match.group(1)!.trim());

final class _Certificates {
  _Certificates(this.dir);

  final Directory dir;

  String path(String file) => '${dir.path}/$file';

  Future<void> _openssl(List<String> arguments) async {
    final result = await Process.run(
      'openssl',
      arguments,
      workingDirectory: dir.path,
    );
    if (result.exitCode != 0) {
      throw StateError('openssl ${arguments.first}: ${result.stderr}');
    }
  }

  Future<void> root(String name) => _openssl([
    'req',
    '-x509',
    '-newkey',
    'rsa:2048',
    '-nodes',
    '-keyout',
    '$name.key',
    '-out',
    '$name.pem',
    '-days',
    '2',
    '-subj',
    '/CN=Swiftie Test $name',
    '-addext',
    'basicConstraints=critical,CA:TRUE',
    '-addext',
    'keyUsage=critical,keyCertSign,cRLSign',
  ]);

  Future<void> server(
    String name, {
    required String root,
    String san = 'IP:127.0.0.1',
  }) async {
    File(path('$name.ext')).writeAsStringSync(
      'subjectAltName=$san\n'
      'basicConstraints=CA:FALSE\n'
      'keyUsage=digitalSignature,keyEncipherment\n'
      'extendedKeyUsage=serverAuth\n',
    );
    await _openssl([
      'req',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      '$name.key',
      '-out',
      '$name.csr',
      '-subj',
      '/CN=$name',
    ]);
    await _openssl([
      'x509',
      '-req',
      '-in',
      '$name.csr',
      '-CA',
      '$root.pem',
      '-CAkey',
      '$root.key',
      '-CAcreateserial',
      '-out',
      '$name.pem',
      '-days',
      '2',
      '-extfile',
      '$name.ext',
    ]);
  }

  Future<Uri> serve(String name) async {
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      SecurityContext()
        ..useCertificateChain(path('$name.pem'))
        ..usePrivateKey(path('$name.key')),
    );
    addTearDown(() => server.close(force: true));
    server.listen(
      (request) => request.response
        ..statusCode = HttpStatus.noContent
        ..close(),
    );
    return Uri.https('127.0.0.1:${server.port}', '/');
  }

  BundledRootsOverrides bundleOf(String root) =>
      BundledRootsOverrides(File(path('$root.pem')).readAsBytesSync());
}

Future<_Certificates> _certificates() async {
  final dir = await Directory.systemTemp.createTemp('bundled_roots_test');
  addTearDown(() => dir.delete(recursive: true));
  return _Certificates(dir);
}

Future<int> _statusThrough(
  HttpOverrides overrides,
  Uri uri, {
  HttpClient Function() client = HttpClient.new,
}) => HttpOverrides.runWithHttpOverrides(() async {
  final made = client();
  try {
    final response = await (await made.getUrl(uri)).close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    made.close(force: true);
  }
}, overrides);

void main() {
  group('the bundle override', () {
    test(
      'a server signed by a bundled root is trusted only through the bundle',
      () async {
        final certificates = await _certificates();
        await certificates.root('bundled');
        await certificates.server('server', root: 'bundled');
        final uri = await certificates.serve('server');

        expect(
          await _statusThrough(certificates.bundleOf('bundled'), uri),
          HttpStatus.noContent,
        );
        await expectLater(
          _statusThrough(_SystemRootsOnly(), uri),
          throwsA(isA<HandshakeException>()),
        );
      },
    );

    test(
      'still refuses a server signed by a root outside the bundle',
      () async {
        final certificates = await _certificates();
        await certificates.root('bundled');
        await certificates.root('stranger');
        await certificates.server('server', root: 'stranger');
        final uri = await certificates.serve('server');

        await expectLater(
          _statusThrough(certificates.bundleOf('bundled'), uri),
          throwsA(isA<HandshakeException>()),
        );
      },
    );

    test('still checks that the certificate names the host', () async {
      final certificates = await _certificates();
      await certificates.root('bundled');
      await certificates.server(
        'server',
        root: 'bundled',
        san: 'DNS:other.invalid',
      );
      final uri = await certificates.serve('server');

      await expectLater(
        _statusThrough(certificates.bundleOf('bundled'), uri),
        throwsA(isA<HandshakeException>()),
      );
    });

    test(
      'leaves a client with its own security context to that context',
      () async {
        final certificates = await _certificates();
        await certificates.root('bundled');
        await certificates.server('server', root: 'bundled');
        final uri = await certificates.serve('server');

        await expectLater(
          _statusThrough(
            certificates.bundleOf('bundled'),
            uri,
            client: () => HttpClient(context: SecurityContext()),
          ),
          throwsA(isA<HandshakeException>()),
        );
      },
    );
  });

  group('the shipped bundle', () {
    test('is the pinned copy of curl\'s Mozilla bundle', () async {
      final hash = await Sha256().hash(
        File(bundledRootsAsset).readAsBytesSync(),
      );

      expect(
        hash.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
        _bundledRootsSha256,
      );
    });

    test('holds the roots behind LRCLIB, Deezer, its covers, GitHub and the '
        'relay, and '
        'loads into a security context', () {
      final pem = File(bundledRootsAsset).readAsStringSync();

      expect(_bundledRootNames(pem), containsAll(_rootsTheAppReaches));
      expect(
        () => BundledRootsOverrides(File(bundledRootsAsset).readAsBytesSync()),
        returnsNormally,
      );
    });
  });

  group('installing the bundle', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    Future<HttpOverrides?> installedOn(
      TargetPlatform platform, [
      AssetBundle? bundle,
    ]) async {
      final before = HttpOverrides.current;
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        HttpOverrides.global = before;
      });
      HttpOverrides.global = null;
      await trustBundledRootsOnWindows(bundle ?? rootBundle);
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

    test(
      'a bundle that cannot be read leaves Windows on its own store',
      () async {
        final missing = _Bundle(
          () async => throw FlutterError('Unable to load asset'),
        );

        expect(await installedOn(TargetPlatform.windows, missing), isNull);
      },
    );

    test('a corrupt bundle leaves Windows on its own store', () async {
      final corrupt = _Bundle(
        () async => ByteData.sublistView(Uint8List.fromList([1, 2, 3, 4])),
      );

      expect(await installedOn(TargetPlatform.windows, corrupt), isNull);
    });
  });
}
