import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/http_identity.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/services/updater/update_config.dart';
import 'package:swiftie_quiz/services/updater/update_manifest_client.dart';

Map<String, Object?> _fixtureManifest() =>
    jsonDecode(File('test/fixtures/updater/latest.json').readAsStringSync())
        as Map<String, Object?>;

Map<String, Object?> _platformEntry(String key) =>
    (_fixtureManifest()['platforms']! as Map<String, Object?>)[key]!
        as Map<String, Object?>;

Map<String, Object?> _manifestWith(Map<String, Object?> changes) => {
  ..._fixtureManifest(),
  ...changes,
};

MockClient _serving(Object body, {int status = 200}) => MockClient(
  (request) async => http.Response.bytes(
    utf8.encode(body is String ? body : jsonEncode(body)),
    status,
    headers: const {'content-type': 'application/json'},
  ),
);

UpdateManifestClient _clientFor(
  http.Client client, {
  UpdatePlatform platform = UpdatePlatform.macos,
}) => UpdateManifestClient(
  client: client,
  userAgent: appUserAgent('0.2.0'),
  platform: platform,
);

void main() {
  group('manifest selection and version gate', () {
    test('reads version, notes, pub_date and the darwin-aarch64 entry on '
        'macOS', () async {
      final mac = _platformEntry('darwin-aarch64');

      final update = await _clientFor(_serving(_fixtureManifest()))
          .check('0.2.0');

      expect(
        update,
        AvailableUpdate(
          manifest: UpdateManifest(
            version: '0.3.0',
            notes: _fixtureManifest()['notes']! as String,
            pubDate: '2026-10-05T12:00:00Z',
          ),
          url: Uri.parse(mac['url']! as String),
          signature: mac['signature']! as String,
        ),
      );
      expect(
        update!.url.toString(),
        'https://github.com/SatanshuMishra/project-swiftee/releases/download/'
        'v0.3.0/Swiftie%20Quiz.app.tar.gz',
      );
    });

    test('picks the windows-x86_64 entry on Windows', () async {
      final windows = _platformEntry('windows-x86_64');

      final update = await _clientFor(
        _serving(_fixtureManifest()),
        platform: UpdatePlatform.windows,
      ).check('0.2.0');

      expect(update!.url, Uri.parse(windows['url']! as String));
      expect(update.signature, windows['signature']);
      expect(
        update.signature,
        isNot(_platformEntry('darwin-aarch64')['signature']),
      );
    });

    test('maps the running operating system to its platform key', () {
      expect(
        UpdatePlatform.forOperatingSystem('macos')?.manifestKey,
        'darwin-aarch64',
      );
      expect(
        UpdatePlatform.forOperatingSystem('windows')?.manifestKey,
        'windows-x86_64',
      );
      expect(UpdatePlatform.forOperatingSystem('linux'), isNull);
    });

    test(
      'requests the GitHub latest release with the app User-Agent',
      () async {
        final requests = <http.BaseRequest>[];
        final client = MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode(_fixtureManifest()), 200);
        });

        await _clientFor(client).check('0.2.0');

        expect(requests, hasLength(1));
        expect(requests.single.method, 'GET');
        expect(
          requests.single.url.toString(),
          'https://github.com/SatanshuMishra/project-swiftee/releases/latest/'
          'download/latest.json',
        );
        expect(
          requests.single.headers['User-Agent'],
          'SwiftieQuiz/0.2.0 (+https://github.com/SatanshuMishra/project-swiftee)',
        );
      },
    );

    const runningVersion = '0.2.0';
    const versionCases = {
      '0.2.0': false,
      '0.1.5': false,
      '0.2.1': true,
      '0.3.0': true,
      '1.0.0': true,
    };
    for (final MapEntry(key: remoteVersion, value: offered)
        in versionCases.entries) {
      test('$runningVersion ${offered ? 'accepts' : 'rejects'} '
          '$remoteVersion', () async {
        final update = await _clientFor(
          _serving(_manifestWith({'version': remoteVersion})),
        ).check(runningVersion);

        expect(update != null, offered);
        if (offered) {
          expect(update!.manifest.version, remoteVersion);
        }
      });
    }

    test(
      '0.3.0 is offered to 0.2.2 but 0.2.2 is not offered to 0.3.0',
      () async {
        final newer = await _clientFor(
          _serving(_manifestWith({'version': '0.3.0'})),
        ).check('0.2.2');
        final older = await _clientFor(
          _serving(_manifestWith({'version': '0.2.2'})),
        ).check('0.3.0');

        expect(newer?.manifest.version, '0.3.0');
        expect(older, isNull);
      },
    );

    test(
      'a leading v on the remote version is ignored, as Tauri does',
      () async {
        final update = await _clientFor(
          _serving(_manifestWith({'version': 'v0.3.0'})),
        ).check('0.2.0');

        expect(update?.manifest.version, '0.3.0');
      },
    );

    test('missing notes and pub_date become empty strings', () async {
      final manifest = {
        for (final MapEntry(:key, :value) in _fixtureManifest().entries)
          if (key != 'notes' && key != 'pub_date') key: value,
      };

      final update = await _clientFor(_serving(manifest)).check('0.2.0');

      expect(update?.manifest.notes, '');
      expect(update?.manifest.pubDate, '');
    });

    test('a manifest without the running platform is a check error', () async {
      final manifest = _manifestWith({
        'platforms': {'windows-x86_64': _platformEntry('windows-x86_64')},
      });

      expect(
        _clientFor(_serving(manifest)).check('0.2.0'),
        throwsA(
          isA<UpdateCheckException>().having(
            (error) => error.message,
            'message',
            contains('darwin-aarch64'),
          ),
        ),
      );
    });

    test('a download URL that is not https is a check error', () async {
      final manifest = _manifestWith({
        'platforms': {
          'darwin-aarch64': {
            ..._platformEntry('darwin-aarch64'),
            'url': 'http://example.com/Swiftie%20Quiz.app.tar.gz',
          },
        },
      });

      expect(
        _clientFor(_serving(manifest)).check('0.2.0'),
        throwsA(isA<UpdateCheckException>()),
      );
    });

    test('invalid version, pub_date and JSON are check errors', () async {
      final invalidBodies = [
        jsonEncode(_manifestWith({'version': 'latest'})),
        jsonEncode(_manifestWith({'pub_date': 'yesterday'})),
        jsonEncode(_manifestWith({'version': null})),
        '{"version": ',
        '[]',
      ];

      for (final body in invalidBodies) {
        await expectLater(
          _clientFor(_serving(body)).check('0.2.0'),
          throwsA(isA<UpdateCheckException>()),
          reason: body,
        );
      }
    });

    test('204 means no update and other failures are check errors', () async {
      expect(
        await _clientFor(MockClient((request) async => http.Response('', 204)))
            .check('0.2.0'),
        isNull,
      );
      await expectLater(
        _clientFor(_serving('Not Found', status: 404)).check('0.2.0'),
        throwsA(isA<UpdateCheckException>()),
      );
      await expectLater(
        _clientFor(
          MockClient((request) async => throw http.ClientException('offline')),
        ).check('0.2.0'),
        throwsA(
          isA<UpdateCheckException>().having(
            (error) => error.message,
            'message',
            'offline',
          ),
        ),
      );
    });

    test('the check gives up after 10 seconds', () {
      fakeAsync((async) {
        final client = _clientFor(
          MockClient((request) => Completer<http.Response>().future),
        );
        Object? failure;
        client
            .check('0.2.0')
            .then<void>((_) {}, onError: (Object error) => failure = error);

        async.elapse(const Duration(milliseconds: 9999));
        expect(failure, isNull);

        async.elapse(const Duration(milliseconds: 1));
        expect(failure, isA<UpdateCheckException>());
      });
    });
  });
}
