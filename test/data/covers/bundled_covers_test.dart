import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_store.dart';
import 'package:swiftie_quiz/data/covers/bundled_covers.dart';
import 'package:swiftie_quiz/data/covers/cover_store.dart';
import 'package:swiftie_quiz/domain/engine/catalogue_rules.dart';

const int _bundleBudgetBytes = 5 * 1024 * 1024;

void main() {
  final catalogue = buildCatalogue(
    decodeCatalogue(File(bundledCataloguePath).readAsStringSync()),
  );
  final wanted = coversToBundle(catalogue);
  List<File> bundled() =>
      Directory(bundledCoversFolder).listSync().whereType<File>().toList();

  test('every release and era cover is wanted, eras at the larger size', () {
    expect(wanted, hasLength(109));
    for (final era in catalogue.eras) {
      final key = coverKey(catalogue.coverFor(era.key)!)!;
      expect(wanted[key], eraCoverSize, reason: era.key);
    }
  });

  test('every wanted cover ships with the app and nothing else does', () {
    final files = {for (final file in bundled()) p.basename(file.path): file};

    expect(
      [
        for (final key in wanted.keys)
          if (!files.containsKey('$key.jpg')) key,
      ],
      isEmpty,
      reason: 'run dart run tool/catalog/bundle_covers.dart',
    );
    expect(files.keys.toSet(), {for (final key in wanted.keys) '$key.jpg'});
    for (final file in files.values) {
      expect(file.readAsBytesSync().take(3), [0xFF, 0xD8, 0xFF]);
    }
  });

  test('the bundled covers stay inside their size budget', () {
    final bytes = bundled().fold<int>(
      0,
      (sum, file) => sum + file.lengthSync(),
    );

    expect(bytes, lessThan(_bundleBudgetBytes));
  });

  test('the app declares the covers folder as assets', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('    - $bundledCoversFolder/\n'),
    );
  });
}
