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
  final roots = await bundle.load(bundledRootsAsset);
  HttpOverrides.global = BundledRootsOverrides(
    roots.buffer.asUint8List(roots.offsetInBytes, roots.lengthInBytes),
  );
}
