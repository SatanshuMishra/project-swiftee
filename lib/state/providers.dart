import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:swiftie_quiz/data/catalog/catalogue_store.dart';
import 'package:swiftie_quiz/data/catalog/deezer_client.dart';
import 'package:swiftie_quiz/data/http_identity.dart';
import 'package:swiftie_quiz/data/lyrics/danger_zones.dart';
import 'package:swiftie_quiz/data/lyrics/lrclib_client.dart';
import 'package:swiftie_quiz/data/save/save_location.dart';
import 'package:swiftie_quiz/data/save/save_store.dart';
import 'package:swiftie_quiz/data/together/relay_connection.dart';
import 'package:together_protocol/together_protocol.dart' show maxMessageBytes;

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

final catalogueStoreProvider = Provider<CatalogueStore>(
  (ref) => CatalogueStore(
    loadBundled: () => rootBundle.loadString(bundledCataloguePath),
    updatesFile: File(
      p.join(p.dirname(defaultSaveFilePath()), catalogueUpdatesFileName),
    ),
    now: ref.watch(clockProvider),
  ),
);

final relayConnectorProvider = Provider<RelayConnector>(
  (ref) => HttpRelayConnector(
    client: ref.watch(httpClientProvider),
    openSocket: (uri, headers) async => (await WebSocket.connect(
      uri.toString(),
      headers: headers,
      compression: CompressionOptions.compressionOff,
      maxPayloadLength: maxMessageBytes,
    ))..pingInterval = const Duration(seconds: 20),
  ),
);
