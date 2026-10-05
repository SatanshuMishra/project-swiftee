import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:cryptography/cryptography.dart';

enum MinisignFailure {
  invalidEncoding('Invalid encoding in minisign data'),
  unsupportedAlgorithm(
    'This signature algorithm is not supported by this implementation',
  ),
  unexpectedKeyId(
    'The signature was created with a different key than the one provided',
  ),
  invalidSignature('The signature verification failed');

  const MinisignFailure(this.message);

  final String message;
}

final class MinisignException implements Exception {
  const MinisignException(this.failure);

  final MinisignFailure failure;

  String get message => failure.message;

  @override
  String toString() => message;
}

Future<String> verify(
  List<int> bytes,
  String signatureText,
  String publicKeyText,
) async {
  final publicKey = _MinisignPublicKey.decode(_decodeTauriText(publicKeyText));
  final signature = _MinisignSignature.decode(_decodeTauriText(signatureText));
  if (!const ListEquality<int>().equals(publicKey.keyId, signature.keyId)) {
    throw const MinisignException(MinisignFailure.unexpectedKeyId);
  }
  final signedMessage = signature.isPrehashed
      ? (await Blake2b().hash(bytes)).bytes
      : bytes;
  final globalMessage = [
    ...signature.signature,
    ...utf8.encode(signature.trustedComment),
  ];
  final verified =
      await _ed25519Verifies(
        signedMessage,
        signature.signature,
        publicKey.key,
      ) &&
      await _ed25519Verifies(
        globalMessage,
        signature.globalSignature,
        publicKey.key,
      );
  if (!verified) {
    throw const MinisignException(MinisignFailure.invalidSignature);
  }
  return signature.trustedComment;
}

Future<bool> _ed25519Verifies(
  List<int> message,
  Uint8List signature,
  Uint8List publicKey,
) => Ed25519().verify(
  message,
  signature: Signature(
    signature,
    publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
  ),
);

String _decodeTauriText(String base64Text) {
  try {
    return utf8.decode(base64.decode(base64Text.trim()));
  } on FormatException {
    throw const MinisignException(MinisignFailure.invalidEncoding);
  }
}

Uint8List _decodeLine(String line, int expectedLength) {
  final Uint8List bytes;
  try {
    bytes = base64.decode(line);
  } on FormatException {
    throw const MinisignException(MinisignFailure.invalidEncoding);
  }
  if (bytes.length != expectedLength) {
    throw const MinisignException(MinisignFailure.invalidEncoding);
  }
  return bytes;
}

List<String> _lines(String text) => [
  for (final line in text.split('\n'))
    line.endsWith('\r') ? line.substring(0, line.length - 1) : line,
];

String _line(List<String> lines, int index) {
  if (index >= lines.length) {
    throw const MinisignException(MinisignFailure.invalidEncoding);
  }
  return lines[index];
}

const _algorithmByteE = 0x45;
const _algorithmByteRaw = 0x64;
const _algorithmBytePrehashed = 0x44;
const _keyIdLength = 8;
const _trustedCommentPrefix = 'trusted comment: ';

final class _MinisignPublicKey {
  const _MinisignPublicKey({required this.keyId, required this.key});

  factory _MinisignPublicKey.decode(String text) {
    final lines = _lines(text);
    final bytes = _decodeLine(_line(lines, 1), 42);
    final algorithmSupported =
        bytes[0] == _algorithmByteE &&
        (bytes[1] == _algorithmByteRaw || bytes[1] == _algorithmBytePrehashed);
    if (!algorithmSupported) {
      throw const MinisignException(MinisignFailure.unsupportedAlgorithm);
    }
    return _MinisignPublicKey(
      keyId: Uint8List.sublistView(bytes, 2, 2 + _keyIdLength),
      key: Uint8List.sublistView(bytes, 2 + _keyIdLength),
    );
  }

  final Uint8List keyId;
  final Uint8List key;
}

final class _MinisignSignature {
  const _MinisignSignature({
    required this.isPrehashed,
    required this.keyId,
    required this.signature,
    required this.trustedComment,
    required this.globalSignature,
  });

  factory _MinisignSignature.decode(String text) {
    final lines = _lines(text);
    final signatureBytes = _decodeLine(_line(lines, 1), 74);
    final trustedCommentLine = _line(lines, 2);
    final globalSignature = _decodeLine(_line(lines, 3), 64);
    if (!trustedCommentLine.startsWith(_trustedCommentPrefix)) {
      throw const MinisignException(MinisignFailure.invalidEncoding);
    }
    final isPrehashed = switch ((signatureBytes[0], signatureBytes[1])) {
      (_algorithmByteE, _algorithmByteRaw) => false,
      (_algorithmByteE, _algorithmBytePrehashed) => true,
      _ => throw const MinisignException(MinisignFailure.unsupportedAlgorithm),
    };
    return _MinisignSignature(
      isPrehashed: isPrehashed,
      keyId: Uint8List.sublistView(signatureBytes, 2, 2 + _keyIdLength),
      signature: Uint8List.sublistView(signatureBytes, 2 + _keyIdLength),
      trustedComment: trustedCommentLine.substring(
        _trustedCommentPrefix.length,
      ),
      globalSignature: globalSignature,
    );
  }

  final bool isPrehashed;
  final Uint8List keyId;
  final Uint8List signature;
  final String trustedComment;
  final Uint8List globalSignature;
}
