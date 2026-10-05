import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:swiftie_quiz/data/catalog/deezer_client.dart';
import 'package:swiftie_quiz/data/http_identity.dart';
import 'package:swiftie_quiz/data/lyrics/danger_zones.dart';
import 'package:swiftie_quiz/data/lyrics/lrclib_client.dart';
import 'package:swiftie_quiz/data/save/save_location.dart';
import 'package:swiftie_quiz/data/save/save_store.dart';

final appVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

final userAgentProvider = FutureProvider<String>(
  (ref) async => appUserAgent(await ref.watch(appVersionProvider.future)),
);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final randomProvider = Provider<Random>((ref) => Random());

final deezerClientProvider = FutureProvider<DeezerClient>(
  (ref) async => DeezerClient(
    client: ref.watch(httpClientProvider),
    userAgent: await ref.watch(userAgentProvider.future),
    now: ref.watch(clockProvider),
  ),
);

final lrclibClientProvider = FutureProvider<LrclibClient>(
  (ref) async => LrclibClient(
    client: ref.watch(httpClientProvider),
    userAgent: await ref.watch(userAgentProvider.future),
    now: ref.watch(clockProvider),
  ),
);

final dangerZoneServiceProvider = FutureProvider<DangerZoneService>(
  (ref) async => DangerZoneService(
    client: ref.watch(httpClientProvider),
    userAgent: await ref.watch(userAgentProvider.future),
  ),
);

final saveStoreProvider = Provider<SaveStore>(
  (ref) => SaveStore(File(defaultSaveFilePath()), ref.watch(clockProvider)),
);
