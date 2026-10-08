import 'dart:typed_data';

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

int? jpegWidth(Uint8List bytes) {
  var at = 2;
  while (at + 8 < bytes.length) {
    if (bytes[at] != 0xFF) {
      at += 1;
      continue;
    }
    final marker = bytes[at + 1];
    if (marker >= 0xC0 && marker <= 0xC3) {
      return bytes[at + 7] << 8 | bytes[at + 8];
    }
    at += 2 + (bytes[at + 2] << 8 | bytes[at + 3]);
  }
  return null;
}
