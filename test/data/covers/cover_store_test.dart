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
  late List<http.BaseRequest> requested;

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
  File kept() => File('${saved().path}/$_key.jpg');

  http.Client serving(List<http.Response Function()> responses) =>
      MockClient((request) async {
        requested.add(request);
        return responses[requested.length - 1]();
      });

  CoverStore store({
    http.Client? client,
    bool save = false,
    bool Function()? saving,
    Set<String> bundled = const {},
    Duration timeout = const Duration(seconds: 10),
    Directory Function()? folderOf,
  }) => CoverStore(
    client:
        client ??
        MockClient((request) async {
          requested.add(request);
          return http.Response.bytes(_jpeg, 200);
        }),
    bundledKeys: () async => bundled,
    loadAsset: (asset) async {
      expect(asset, bundledCoverAsset(_key));
      return _bundledJpeg;
    },
    folder: folderOf ?? saved,
    save: saving ?? () => save,
    timeout: timeout,
    retryAfter: Duration.zero,
  );

  test('reads the cover key only from deezer image links', () {
    expect(coverKey(_url), _key);
    expect(coverKey(deezerCoverUrl(_key, 500)), _key);
    expect(
      coverKey(
        'https://e-cdns-images.dzcdn.net/images/cover/$_key/250x250-000000-80-0-0.jpg',
      ),
      _key,
    );
    expect(coverKey('https://example.com/images/cover/$_key/x.jpg'), isNull);
    expect(
      coverKey('http://cdn-images.dzcdn.net/images/cover/$_key/x.jpg'),
      isNull,
    );
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

  test('a download is not kept while saving is off', () async {
    final bytes = await store().load(_url);

    expect(bytes, _jpeg);
    expect(requested.single.url, Uri.parse(_url));
    expect(saved().existsSync(), isFalse);
  });

  test(
    'with saving on a downloaded cover is kept and read back offline',
    () async {
      await store(save: true).load(_url);
      expect(kept().readAsBytesSync(), _jpeg);
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

  test('the setting is read at each load', () async {
    var saving = false;
    final covers = store(saving: () => saving);

    await covers.load(_url);
    expect(saved().existsSync(), isFalse);
    saving = true;
    await covers.load(_url);
    expect(kept().existsSync(), isTrue);
    saving = false;
    await covers.load(_url);
    expect(requested, hasLength(3));
  });

  test('a kept file that is not an image is replaced by a download', () async {
    saved().createSync(recursive: true);
    kept().writeAsStringSync('half a cover');

    expect(await store(save: true).load(_url), _jpeg);
    expect(kept().readAsBytesSync(), _jpeg);
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

  test('a stalled request is aborted and tried once more', () async {
    final client = _StallsOnce(_jpeg);

    final bytes = await store(
      timeout: const Duration(milliseconds: 50),
      client: client,
    ).load(_url);

    expect(bytes, _jpeg);
    expect(client.sent, hasLength(2));
    await expectLater(
      (client.sent.first as http.Abortable).abortTrigger,
      completes,
    );
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
      client: serving([() => http.Response('<html>sign in</html>', 200)]),
    );

    await expectLater(covers.load(_url), throwsA(isA<CoverUnavailable>()));
    expect(saved().existsSync(), isFalse);
  });

  test('a cover from another host downloads but is never kept', () async {
    const other = 'https://example.com/images/cover/$_key/250x250.jpg';

    expect(await store(save: true).load(other), _jpeg);
    expect(saved().existsSync(), isFalse);
  });

  test(
    'forgetting removes every kept cover, even one still downloading',
    () async {
      final sent = Completer<void>();
      final response = Completer<http.Response>();
      final covers = store(
        save: true,
        client: MockClient((request) {
          sent.complete();
          return response.future;
        }),
      );
      saved().createSync(recursive: true);
      File('${saved().path}/older.jpg').writeAsBytesSync(_jpeg);

      final loading = covers.load(_url);
      await sent.future;
      final forgetting = covers.forget();
      response.complete(http.Response.bytes(_jpeg, 200));

      expect(await loading, _jpeg);
      await forgetting;
      expect(saved().existsSync(), isFalse);
      await covers.forget();
    },
  );

  test('a cover that cannot be kept leaves no temporary file behind', () async {
    Directory(kept().path).createSync(recursive: true);

    expect(await store(save: true).load(_url), _jpeg);
    expect(
      saved().listSync().where((entity) => entity.path.endsWith('.tmp')),
      isEmpty,
    );
  });

  test('a covers folder that cannot be found leaves covers working', () async {
    final covers = store(
      save: true,
      folderOf: () => throw const FileSystemException('no home folder'),
    );

    expect(await covers.load(_url), _jpeg);
    await covers.forget();
  });
}

final class _StallsOnce extends http.BaseClient {
  _StallsOnce(this.body);

  final Uint8List body;
  List<http.BaseRequest> sent = const [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    sent = [...sent, request];
    return sent.length == 1
        ? Completer<http.StreamedResponse>().future
        : Future.value(http.StreamedResponse(Stream.value(body), 200));
  }
}
