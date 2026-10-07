import 'package:swiftie_quiz/data/covers/cover_store.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';

const int releaseCoverSize = 250;
const int eraCoverSize = 500;

Map<String, int> coversToBundle(Catalogue catalogue) {
  final sizes = <String, int>{
    for (final release in catalogue.sources)
      ?coverKey(release.coverMedium ?? ''): releaseCoverSize,
  };
  for (final era in catalogue.eras) {
    if (coverKey(catalogue.coverFor(era.key) ?? '') case final key?) {
      sizes[key] = eraCoverSize;
    }
  }
  return Map.unmodifiable(sizes);
}
