import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swiftie_quiz/data/catalog/catalogue_store.dart';
import 'package:swiftie_quiz/services/audio/soloud_audio_engine.dart';
import 'package:swiftie_quiz/ui/cat/cat_icon.dart';
import 'package:swiftie_quiz/ui/screens/settings_screen.dart';
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

    test('pubspec declares every asset folder that holds files, and only '
        'those', () {
      final pubspec = loadYaml(
        File('pubspec.yaml').readAsStringSync(),
      ) as Map<Object?, Object?>;
      final flutterSection = pubspec['flutter'] as Map<Object?, Object?>;
      final declaredAssets = (flutterSection['assets'] as List<Object?>)
          .cast<String>()
          .toSet();
      bool holdsFiles(Directory folder) => folder
          .listSync(recursive: true)
          .whereType<File>()
          .any((file) => !p.basename(file.path).startsWith('.'));
      final folders = {
        for (final entity in Directory('assets').listSync())
          if (entity is Directory &&
              p.basename(entity.path) != 'fonts' &&
              holdsFiles(entity))
            'assets/${p.basename(entity.path)}/',
      };

      expect(declaredAssets, folders);
    });

    test('every asset the app loads by path is bundled', () {
      final pubspec = loadYaml(
        File('pubspec.yaml').readAsStringSync(),
      ) as Map<Object?, Object?>;
      final declaredAssets =
          ((pubspec['flutter'] as Map<Object?, Object?>)['assets']
                  as List<Object?>)
              .cast<String>();

      for (final asset in [
        CatIcon.asset,
        SettingsScreen.appIcon,
        bundledCataloguePath,
        SoLoudAudioEngine.quackAsset,
      ]) {
        expect(File(asset).existsSync(), isTrue, reason: asset);
        expect(declaredAssets, contains('${p.dirname(asset)}/'), reason: asset);
      }
    });
  });
}
