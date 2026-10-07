import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const catIconV2Digest =
    '3f034645948ed7cbbf82857c12f98af31dd1314010bac21f7483ba717bb4984e';

const quackDigest =
    '3ae1c0bb3c152a89e9c82a0fccadf90da4e2e54040863b3f58d0dc2ad70e8475';

String sha256Hex(String relativePath) => const DartSha256()
    .hashSync(File(relativePath).readAsBytesSync())
    .bytes
    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();

void main() {
  group('bundled assets match the design and the Tauri assets', () {
    test('cat icon is the v2 design byte for byte', () {
      expect(sha256Hex('assets/cat/cat-icon.svg'), catIconV2Digest);
    });

    test('quack sound matches the Tauri original byte for byte', () {
      expect(sha256Hex('assets/sounds/quack.mp3'), quackDigest);
    });

    test('pubspec declares every asset folder', () {
      final pubspec = loadYaml(
        File('pubspec.yaml').readAsStringSync(),
      ) as Map<Object?, Object?>;
      final flutterSection = pubspec['flutter'] as Map<Object?, Object?>;
      final declaredAssets = (flutterSection['assets'] as List<Object?>)
          .cast<String>();

      final folders = {
        for (final entity in Directory('assets').listSync())
          if (entity is Directory && !entity.path.endsWith('fonts'))
            '${entity.path.replaceAll(r'\', '/')}/',
      };

      expect(declaredAssets.toSet(), folders);
      expect(folders, containsAll(<String>['assets/cat/', 'assets/sounds/']));
    });
  });
}
