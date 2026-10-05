import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const catIconV2Digest =
    '3f034645948ed7cbbf82857c12f98af31dd1314010bac21f7483ba717bb4984e';

const quackDigest =
    '3ae1c0bb3c152a89e9c82a0fccadf90da4e2e54040863b3f58d0dc2ad70e8475';

const achievementCatDigests = <String, String>{
  'album_completionist':
      '462861734c68137a0a9a0f51d1ef60d61a7c55c06e3ce0ff0143b30b75be5f11',
  'album_explorer':
      '57ed9934d7272560edfe77cec675301dd808f796b56f42a8a1b461eef5e01698',
  'all_ears':
      'd27a9260b77c9f6bca9e9b81640bbfba4e494acd52496cae6333445c8a979ab1',
  'dual_threat':
      'b5f23dfb1f55673da3bde198ad6813fb63f06f2e8ad732f1ebbfab321b6732e4',
  'first_meow':
      '6d2c5fef213c104827a8556d949984c506aefba7a76bc50d93729c7b33101f97',
  'getting_warmed_up':
      '08d2b7d3a8c3a7f59be8fd6a0d5689667486676f1dbb9f1b5e544f60b4ea32e0',
  'hard_mode_hero':
      '177ccbf430c4a5e1b0af487da9395394a6e213bfe8c9476c1934c3780fd8ff97',
  'lie_detector':
      'd2d99887cf9e5813170e5a200637b5e71edb6d8d1107d406a8905a3e0658c498',
  'lyric_lover':
      '53f2234efbc8f1ffddec29d4d65942fa5281b4c6adb0e0c0f5973f78d9380f21',
  'lyric_streak':
      'd82ec6e3ff60aa1cfe276cc4b239e8b8472f646c92078c75a4620086e53f1f10',
  'persistent_listener':
      'd10f9b751fe9e0b6bb04bc4e33af3a60352ab4434ea286db16107bf294d6c789',
  'poet_laureate':
      'fc122543bcd93ceb6b8df1ca2fc8c8be469db99085b942138920ecd2781d8076',
  'purrfect_streak':
      'e06719837d57d71f21ee42b51084ccd9a723cb35441c87b3679c3fb906e15d92',
  'quack_collector':
      'a97c2a9aaf28e1ecdcf324cd03f12151fe40665e8cecafd7d854e0b7c837af2c',
  'silhouette':
      '54e5451b83009fd309503f12a8164c088942081bcd782d8b10884aeafef7af6a',
  'speed_demon':
      '06349e5dd28623687745dcd1bd212a6bdcce560092c0d84ec2daef306847bd3a',
};

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

    test('the 16 achievement cats match the Tauri originals byte for byte', () {
      final bundledNames = Directory('assets/cats')
          .listSync()
          .whereType<File>()
          .map((file) => p.basename(file.path))
          .toSet();

      expect(
        bundledNames,
        achievementCatDigests.keys.map((name) => '$name.svg').toSet(),
      );
      for (final MapEntry(key: name, value: digest)
          in achievementCatDigests.entries) {
        expect(sha256Hex('assets/cats/$name.svg'), digest, reason: name);
      }
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

      expect(
        declaredAssets,
        containsAll(<String>[
          'assets/cat/',
          'assets/cats/',
          'assets/icons/',
          'assets/sounds/',
        ]),
      );
    });
  });
}
