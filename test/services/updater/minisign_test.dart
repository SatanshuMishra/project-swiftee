import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/services/updater/minisign.dart' as minisign;
import 'package:swiftie_quiz/services/updater/update_config.dart';
import 'package:swiftie_quiz/services/updater/update_downloader.dart';
import 'package:swiftie_quiz/services/updater/update_manifest_client.dart';

const _fixtures = 'test/fixtures/updater';

Uint8List _artifact() => File('$_fixtures/artifact.bin').readAsBytesSync();

String _artifactSignature() =>
    File('$_fixtures/artifact.bin.sig').readAsStringSync();

String _testPublicKey() => File('$_fixtures/test_key.pub').readAsStringSync();

String _editTauriText(
  String tauriText,
  List<String> Function(List<String> lines) edit,
) => base64.encode(
  utf8.encode(
    edit(utf8.decode(base64.decode(tauriText)).split('\n')).join('\n'),
  ),
);

String _editSignatureBytes(
  String tauriText,
  Uint8List Function(Uint8List bytes) edit,
) => _editTauriText(
  tauriText,
  (lines) => [
    lines[0],
    base64.encode(edit(base64.decode(lines[1]))),
    ...lines.skip(2),
  ],
);

Uint8List _replaced(Uint8List bytes, int start, List<int> replacement) =>
    Uint8List.fromList([
      ...bytes.take(start),
      ...replacement,
      ...bytes.skip(start + replacement.length),
    ]);

Uint8List _flipped(Uint8List bytes, int index) =>
    _replaced(bytes, index, [bytes[index] ^ 0x01]);

Matcher _rejectedWith(minisign.MinisignFailure failure) => throwsA(
  isA<minisign.MinisignException>().having(
    (error) => error.failure,
    'failure',
    failure,
  ),
);

final class _TestSigner {
  const _TestSigner(this._keyPair, this._keyId);

  static Future<_TestSigner> create() async => _TestSigner(
    await Ed25519().newKeyPairFromSeed(List<int>.generate(32, (i) => i * 7)),
    const [0x9e, 0xb3, 0xbe, 0x51, 0x07, 0x03, 0x7a, 0x01],
  );

  final SimpleKeyPair _keyPair;
  final List<int> _keyId;

  Future<String> publicKey() async {
    final key = await _keyPair.extractPublicKey();
    final keyLine = base64.encode([0x45, 0x64, ..._keyId, ...key.bytes]);
    return base64.encode(
      utf8.encode('untrusted comment: minisign public key: test\n$keyLine\n'),
    );
  }

  Future<String> sign(
    List<int> bytes, {
    required String trustedComment,
    bool prehashed = true,
  }) async {
    final message = prehashed ? (await Blake2b().hash(bytes)).bytes : bytes;
    final signature = await Ed25519().sign(message, keyPair: _keyPair);
    final globalSignature = await Ed25519().sign([
      ...signature.bytes,
      ...utf8.encode(trustedComment),
    ], keyPair: _keyPair);
    final signatureLine = base64.encode([
      0x45,
      prehashed ? 0x44 : 0x64,
      ..._keyId,
      ...signature.bytes,
    ]);
    return base64.encode(
      utf8.encode(
        'untrusted comment: signature from tauri secret key\n'
        '$signatureLine\n'
        'trusted comment: $trustedComment\n'
        '${base64.encode(globalSignature.bytes)}\n',
      ),
    );
  }
}

AvailableUpdate _updateSignedWith(
  String signature, {
  String version = '0.3.0',
}) => AvailableUpdate(
  manifest: UpdateManifest(
    version: version,
    notes: '',
    pubDate: '2026-10-05T12:00:00Z',
  ),
  url: Uri.parse(
    'https://github.com/SatanshuMishra/project-swiftee/releases/download/'
    'v$version/Swiftie%20Quiz.app.tar.gz',
  ),
  signature: signature,
);

MockClient _servingInChunks(Uint8List bytes, {int chunkLength = 128}) =>
    MockClient.streaming(
      (request, body) async => http.StreamedResponse(
        Stream.fromIterable([
          for (var start = 0; start < bytes.length; start += chunkLength)
            bytes.sublist(start, (start + chunkLength).clamp(0, bytes.length)),
        ]),
        200,
        contentLength: bytes.length,
      ),
    );

UpdateDownloader _downloader(
  http.Client client, {
  String? publicKey,
}) => UpdateDownloader(
  client: client,
  userAgent:
      'SwiftieQuiz/0.2.0 (+https://github.com/SatanshuMishra/project-swiftee)',
  publicKey: publicKey ?? _testPublicKey(),
);

void main() {
  group('minisign verification', () {
    test(
      'a file signed by the Tauri CLI signer verifies with its key',
      () async {
        final trustedComment = await minisign.verify(
          _artifact(),
          _artifactSignature(),
          _testPublicKey(),
        );

        expect(trustedComment, startsWith('timestamp:'));
        expect(trustedComment, contains('\tfile:artifact.bin'));
      },
    );

    test('a flipped byte anywhere in the file is rejected', () async {
      final artifact = _artifact();

      for (final index in [0, artifact.length ~/ 2, artifact.length - 1]) {
        await expectLater(
          minisign.verify(
            _flipped(artifact, index),
            _artifactSignature(),
            _testPublicKey(),
          ),
          _rejectedWith(minisign.MinisignFailure.invalidSignature),
          reason: 'byte $index',
        );
      }
    });

    test('an appended or removed byte is rejected', () async {
      final artifact = _artifact();

      await expectLater(
        minisign.verify(
          [...artifact, 0],
          _artifactSignature(),
          _testPublicKey(),
        ),
        _rejectedWith(minisign.MinisignFailure.invalidSignature),
      );
      await expectLater(
        minisign.verify(
          artifact.sublist(1),
          _artifactSignature(),
          _testPublicKey(),
        ),
        _rejectedWith(minisign.MinisignFailure.invalidSignature),
      );
    });

    test('a signature carrying a different key id is rejected', () async {
      final otherKeyId = _editSignatureBytes(
        _artifactSignature(),
        (bytes) => _replaced(bytes, 2, List<int>.filled(8, 0x2a)),
      );

      await expectLater(
        minisign.verify(_artifact(), otherKeyId, _testPublicKey()),
        _rejectedWith(minisign.MinisignFailure.unexpectedKeyId),
      );
    });

    test(
      'the embedded release key rejects a file signed by another key',
      () async {
        await expectLater(
          minisign.verify(_artifact(), _artifactSignature(), updaterPublicKey),
          _rejectedWith(minisign.MinisignFailure.unexpectedKeyId),
        );
      },
    );

    test('a malformed signature is rejected', () async {
      final signature = _artifactSignature();
      final malformed = {
        'empty': '',
        'not base64': 'not base64 at all!',
        'one line': base64.encode(utf8.encode('untrusted comment: only\n')),
        'short signature line': _editSignatureBytes(
          signature,
          (bytes) => bytes.sublist(0, 73),
        ),
        'missing global signature': _editTauriText(
          signature,
          (lines) => lines.take(3).toList(),
        ),
        'short global signature': _editTauriText(
          signature,
          (lines) => [
            ...lines.take(3),
            base64.encode(base64.decode(lines[3]).sublist(0, 63)),
          ],
        ),
        'trusted comment without its prefix': _editTauriText(
          signature,
          (lines) => [
            ...lines.take(2),
            lines[2].replaceFirst('trusted comment: ', 'comment: '),
            ...lines.skip(3),
          ],
        ),
        'signature line not base64': _editTauriText(
          signature,
          (lines) => [lines[0], '%%%%', ...lines.skip(2)],
        ),
      };

      for (final MapEntry(key: name, value: text) in malformed.entries) {
        await expectLater(
          minisign.verify(_artifact(), text, _testPublicKey()),
          _rejectedWith(minisign.MinisignFailure.invalidEncoding),
          reason: name,
        );
      }
    });

    test('an unknown signature algorithm is rejected', () async {
      final unknownAlgorithm = _editSignatureBytes(
        _artifactSignature(),
        (bytes) => _replaced(bytes, 0, utf8.encode('XX')),
      );

      await expectLater(
        minisign.verify(_artifact(), unknownAlgorithm, _testPublicKey()),
        _rejectedWith(minisign.MinisignFailure.unsupportedAlgorithm),
      );
    });

    test('a tampered trusted comment fails the global signature', () async {
      final tampered = _editTauriText(
        _artifactSignature(),
        (lines) => [
          ...lines.take(2),
          '${lines[2]}\tversion:9.9.9',
          ...lines.skip(3),
        ],
      );

      await expectLater(
        minisign.verify(_artifact(), tampered, _testPublicKey()),
        _rejectedWith(minisign.MinisignFailure.invalidSignature),
      );
    });

    test('a malformed public key is rejected', () async {
      final shortKey = _editTauriText(
        _testPublicKey(),
        (lines) => [
          lines[0],
          base64.encode(base64.decode(lines[1]).sublist(0, 41)),
          ...lines.skip(2),
        ],
      );

      await expectLater(
        minisign.verify(_artifact(), _artifactSignature(), shortKey),
        _rejectedWith(minisign.MinisignFailure.invalidEncoding),
      );
      await expectLater(
        minisign.verify(_artifact(), _artifactSignature(), 'not a key'),
        _rejectedWith(minisign.MinisignFailure.invalidEncoding),
      );
    });

    test('prehashed and legacy raw signatures both verify', () async {
      final signer = await _TestSigner.create();
      final publicKey = await signer.publicKey();
      final bytes = _artifact();

      for (final prehashed in [true, false]) {
        final signature = await signer.sign(
          bytes,
          trustedComment: 'timestamp:1791190270\tfile:artifact.bin',
          prehashed: prehashed,
        );

        expect(
          await minisign.verify(bytes, signature, publicKey),
          'timestamp:1791190270\tfile:artifact.bin',
        );
        await expectLater(
          minisign.verify(_flipped(bytes, 7), signature, publicKey),
          _rejectedWith(minisign.MinisignFailure.invalidSignature),
        );
      }
    });

    test('the downloader returns verified bytes and reports Started, Progress '
        'and Finished', () async {
      final artifact = _artifact();
      final events = <DownloadEvent>[];

      final bytes = await _downloader(
        _servingInChunks(artifact),
      ).download(_updateSignedWith(_artifactSignature()), onEvent: events.add);

      expect(bytes, artifact);
      expect(events, [
        DownloadStarted(contentLength: artifact.length),
        const DownloadProgress(chunkLength: 128),
        const DownloadProgress(chunkLength: 128),
        const DownloadProgress(chunkLength: 128),
        const DownloadFinished(),
      ]);
    });

    test(
      'the downloader sends the app User-Agent to the artifact URL',
      () async {
        final requests = <http.BaseRequest>[];
        final artifact = _artifact();
        final client = MockClient.streaming((request, body) async {
          requests.add(request);
          return http.StreamedResponse(Stream.value(artifact), 200);
        });

        await _downloader(client)
            .download(_updateSignedWith(_artifactSignature()), onEvent: (_) {});

        expect(
          requests.single.url.toString(),
          'https://github.com/SatanshuMishra/project-swiftee/releases/download/'
          'v0.3.0/Swiftie%20Quiz.app.tar.gz',
        );
        expect(
          requests.single.headers['User-Agent'],
          'SwiftieQuiz/0.2.0 (+https://github.com/SatanshuMishra/project-swiftee)',
        );
        expect(requests.single.headers['Accept'], 'application/octet-stream');
      },
    );

    test(
      'the downloader rejects tampered bytes with a signature error',
      () async {
        final tampered = _flipped(_artifact(), 100);

        await expectLater(
          _downloader(
            _servingInChunks(tampered),
          ).download(_updateSignedWith(_artifactSignature()), onEvent: (_) {}),
          throwsA(isA<UpdateSignatureException>()),
        );
      },
    );

    test('the downloader with the embedded key rejects another key\'s '
        'signature', () async {
      await expectLater(
        _downloader(
          _servingInChunks(_artifact()),
          publicKey: updaterPublicKey,
        ).download(_updateSignedWith(_artifactSignature()), onEvent: (_) {}),
        throwsA(isA<UpdateSignatureException>()),
      );
    });

    test(
      'the downloader rejects a signature made for another version',
      () async {
        final signer = await _TestSigner.create();
        final publicKey = await signer.publicKey();
        final bytes = _artifact();

        Future<Uint8List> downloadSignedFor(String signedVersion) async =>
            _downloader(_servingInChunks(bytes), publicKey: publicKey).download(
              _updateSignedWith(
                await signer.sign(
                  bytes,
                  trustedComment:
                      'timestamp:1791190270\tfile:Swiftie Quiz.app.tar.gz'
                      '\tversion:$signedVersion',
                ),
              ),
              onEvent: (_) {},
            );

        await expectLater(
          downloadSignedFor('0.2.9'),
          throwsA(
            isA<UpdateSignatureException>().having(
              (error) => error.message,
              'message',
              contains('signed for version 0.2.9'),
            ),
          ),
        );
        expect(await downloadSignedFor('0.3.0'), bytes);
        expect(await downloadSignedFor('v0.3.0'), bytes);
      },
    );

    test('HTTP failures are download errors, not signature errors', () async {
      await expectLater(
        _downloader(
          MockClient((request) async => http.Response('missing', 404)),
        ).download(_updateSignedWith(_artifactSignature()), onEvent: (_) {}),
        throwsA(
          isA<UpdateDownloadException>().having(
            (error) => error.message,
            'message',
            startsWith('Download request failed with status: 404'),
          ),
        ),
      );
      await expectLater(
        _downloader(
          MockClient.streaming(
            (request, body) async => http.StreamedResponse(
              Stream.error(http.ClientException('connection reset')),
              200,
            ),
          ),
        ).download(_updateSignedWith(_artifactSignature()), onEvent: (_) {}),
        throwsA(isA<UpdateDownloadException>()),
      );
    });
  });
}
