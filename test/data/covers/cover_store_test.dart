import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/covers/cover_store.dart';

const String _key = '290abe93bdda84bb8b170f30a4998c4c';
final String _url = deezerCoverUrl(_key, 250);
final Uint8List _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
final Uint8List _bundledJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xDB, 9]);

void main() {
  late Directory folder;
  late List<Uri> requested;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('covers_test');
    requested = [];
  });
  tearDown(() {
    if (folder.existsSync()) {
      folder.deleteSync(recursive: true);
    }
  });

  Directory saved() => Directory('${folder.path}/covers');

  http.Client serving(List<http.Response Function()> responses) =>
      MockClient((request) async {
        requested.add(request.url);
        return responses[requested.length - 1]();
      });

  CoverStore store({
    http.Client? client,
    bool save = false,
    Set<String> bundled = const {},
    Duration timeout = const Duration(seconds: 10),
  }) => CoverStore(
    client:
        client ??
        MockClient((request) async {
          requested.add(request.url);
          return http.Response.bytes(_jpeg, 200);
        }),
    bundledKeys: () async => bundled,
    loadAsset: (asset) async {
      expect(asset, bundledCoverAsset(_key));
      return _bundledJpeg;
    },
    folder: saved(),
    save: save,
    timeout: timeout,
    retryAfter: Duration.zero,
  );

  test('reads the cover key from a deezer link and finds bundled covers', () {
    expect(coverKey(_url), _key);
    expect(coverKey(deezerCoverUrl(_key, 500)), _key);
    expect(coverKey('https://example.com/cover.jpg'), isNull);
    expect(
      bundledCoverKeys([
        bundledCoverAsset(_key),
        'assets/catalog/catalogue.json',
        'assets/covers/readme.txt',
      ]),
      {_key},
    );
  });

  test('a bundled cover never touches the network', () async {
    final bytes = await store(bundled: {_key}).load(_url);

    expect(bytes, _bundledJpeg);
    expect(requested, isEmpty);
  });

  test('with saving off a downloaded cover is not kept', () async {
    final bytes = await store().load(_url);

    expect(bytes, _jpeg);
    expect(requested, [Uri.parse(_url)]);
    expect(saved().existsSync(), isFalse);
  });

  test(
    'with saving on a downloaded cover is kept and read back offline',
    () async {
      await store(save: true).load(_url);
      expect(File('${saved().path}/$_key.jpg').readAsBytesSync(), _jpeg);
      expect(saved().listSync(), hasLength(1));

      final offline = store(
        save: true,
        client: MockClient(
          (request) async => throw const SocketException('down'),
        ),
      );
      expect(await offline.load(_url), _jpeg);
      expect(requested, hasLength(1));
    },
  );

  test('a kept cover is not read while saving is off', () async {
    await store(save: true).load(_url);

    await store().load(_url);
    expect(requested, hasLength(2));
  });

  test('a server error is tried once more and then succeeds', () async {
    final bytes = await store(
      client: serving([
        () => http.Response('busy', 503),
        () => http.Response.bytes(_jpeg, 200),
      ]),
    ).load(_url);

    expect(bytes, _jpeg);
    expect(requested, hasLength(2));
  });

  test('a stalled request is abandoned and tried once more', () async {
    var calls = 0;
    final bytes = await store(
      timeout: const Duration(milliseconds: 50),
      client: MockClient((request) {
        calls += 1;
        return calls == 1
            ? Completer<http.Response>().future
            : Future.value(http.Response.bytes(_jpeg, 200));
      }),
    ).load(_url);

    expect(bytes, _jpeg);
    expect(calls, 2);
  });

  test('a refusal is not retried and nothing is kept', () async {
    final covers = store(
      save: true,
      client: serving([() => http.Response('', 403)]),
    );

    await expectLater(covers.load(_url), throwsA(isA<CoverUnavailable>()));
    expect(requested, hasLength(1));
    expect(saved().existsSync(), isFalse);
  });

  test('a page that is not an image is refused and never kept', () async {
    final covers = store(
      save: true,
      client: serving([
        () => http.Response('<html>sign in</html>', 200),
        () => http.Response('<html>sign in</html>', 200),
      ]),
    );

    await expectLater(covers.load(_url), throwsA(isA<CoverUnavailable>()));
    expect(saved().existsSync(), isFalse);
  });

  test(
    'a link that is not a deezer cover downloads but is never kept',
    () async {
      const other = 'https://example.com/cover.jpg';

      expect(await store(save: true).load(other), _jpeg);
      expect(saved().existsSync(), isFalse);
    },
  );

  test('forgetting removes every kept cover', () async {
    final covers = store(save: true);
    await covers.load(_url);
    expect(saved().existsSync(), isTrue);

    await covers.forget();
    expect(saved().existsSync(), isFalse);
    await covers.forget();
  });
}
