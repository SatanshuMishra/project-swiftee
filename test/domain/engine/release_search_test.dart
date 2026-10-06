import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_store.dart';
import 'package:swiftie_quiz/domain/engine/catalogue_rules.dart';
import 'package:swiftie_quiz/domain/engine/release_search.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';

void main() {
  late Catalogue catalogue;
  late ReleaseSearch search;

  setUpAll(() {
    catalogue = buildCatalogue(
      decodeCatalogue(File(bundledCataloguePath).readAsStringSync()),
    );
    search = ReleaseSearch(catalogue.releases);
  });

  Map<String, String?> found(String query) => {
    for (final match in search.matches(query)) match.release.title: match.song,
  };

  group('release search', () {
    test('an empty search lists every release in order', () {
      expect([
        for (final match in search.matches('  ')) match.release,
      ], catalogue.releases);
    });

    test('finds a release by its title, ignoring case and punctuation', () {
      final results = found('MIDNIGHTS (3AM');

      expect(results, containsPair('Midnights (3am Edition)', null));
      expect(results.values.every((song) => song == null), isTrue);
    });

    test('finds a release by a song on it and names the song', () {
      final results = found('cruel summer');

      expect(results, containsPair('Lover', 'Cruel Summer'));
      expect(results, isNot(contains('Red')));
    });

    test("names a re-recorded song without its Taylor's Version label", () {
      expect(found('mr perfectly fine').values, contains('Mr. Perfectly Fine'));
    });

    test('folds curly apostrophes and accents', () {
      expect(foldForSearch('’tis the damn season'), "'tis the damn season");
      expect(foldForSearch('Café  Señorita!'), 'cafe senorita');
      expect(found('tis the damn'), isNotEmpty);
    });

    test('a search with no match finds nothing', () {
      expect(search.matches('zzzz not a song'), isEmpty);
    });
  });
}
