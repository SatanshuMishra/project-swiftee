import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/covers/cover_store.dart';
import 'package:swiftie_quiz/state/covers.dart';
import 'package:swiftie_quiz/ui/kit/cover_picture.dart';

final String _url = deezerCoverUrl('290abe93bdda84bb8b170f30a4998c4c', 250);
final List<int> _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  testWidgets('a cover that fails is fetched again the next time it shows', (
    tester,
  ) async {
    var requests = 0;
    final store = CoverStore(
      client: MockClient((request) async {
        requests += 1;
        return requests == 1
            ? http.Response('', 403)
            : http.Response.bytes(_png, 200);
      }),
      bundledKeys: () async => const {},
      loadAsset: (asset) async => throw StateError(asset),
      folder: Directory.systemTemp.createTempSync('cover_picture_test'),
      save: false,
      retryAfter: Duration.zero,
    );
    Future<void> show(Widget child) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [coverStoreProvider.overrideWithValue(store)],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: SizedBox.square(dimension: 40, child: child)),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    RawImage? drawn() =>
        tester.widgetList<RawImage>(find.byType(RawImage)).firstOrNull;

    await show(CoverPicture(_url));
    expect(requests, 1);
    expect(drawn()?.image, isNull);
    expect(tester.takeException(), isNull);

    await show(const SizedBox.shrink());
    await show(CoverPicture(_url));
    expect(requests, 2);
    expect(drawn()?.image, isNotNull);
  });
}
