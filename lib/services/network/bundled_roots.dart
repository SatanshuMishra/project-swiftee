import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String bundledRootsAsset = 'assets/certs/cacert.pem';

final class BundledRootsOverrides extends HttpOverrides {
  BundledRootsOverrides(Uint8List roots)
    : _context = SecurityContext(withTrustedRoots: true)
        ..setTrustedCertificatesBytes(roots);

  final SecurityContext _context;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context ?? _context);
}

Future<void> trustBundledRootsOnWindows(AssetBundle bundle) async {
  if (defaultTargetPlatform != TargetPlatform.windows) {
    return;
  }
  try {
    final roots = await bundle.load(bundledRootsAsset);
    HttpOverrides.global = BundledRootsOverrides(
      roots.buffer.asUint8List(roots.offsetInBytes, roots.lengthInBytes),
    );
  } on FlutterError catch (error, stackTrace) {
    _logUntrusted(error, stackTrace);
  } on TlsException catch (error, stackTrace) {
    _logUntrusted(error, stackTrace);
  }
}

void _logUntrusted(Object error, StackTrace stackTrace) => developer.log(
  'The bundled roots could not be trusted; using the Windows store alone',
  name: 'swiftie_quiz.network',
  error: error,
  stackTrace: stackTrace,
);
