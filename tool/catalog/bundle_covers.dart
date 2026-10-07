import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_store.dart';
import 'package:swiftie_quiz/data/covers/bundled_covers.dart';
import 'package:swiftie_quiz/data/covers/cover_store.dart';
import 'package:swiftie_quiz/domain/engine/catalogue_rules.dart';

Future<void> main() async {
  final catalogue = buildCatalogue(
    decodeCatalogue(File(bundledCataloguePath).readAsStringSync()),
  );
  final wanted = coversToBundle(catalogue);
  final folder = Directory(bundledCoversFolder)..createSync(recursive: true);
  final client = http.Client();
  final failed = <String>[];
  var fetched = 0;
  try {
    for (final MapEntry(:key, value: size) in wanted.entries) {
      final file = File(p.join(folder.path, '$key.jpg'));
      if (file.existsSync() && jpegWidth(file.readAsBytesSync()) == size) {
        continue;
      }
      final url = deezerCoverUrl(key, size);
      final response = await client.get(Uri.parse(url));
      if (response.statusCode != HttpStatus.ok) {
        failed.add('$url: HTTP ${response.statusCode}');
        continue;
      }
      file.writeAsBytesSync(response.bodyBytes);
      fetched += 1;
    }
  } finally {
    client.close();
  }
  final files = folder.listSync().whereType<File>().toList();
  final stale = [
    for (final file in files)
      if (!wanted.containsKey(p.basenameWithoutExtension(file.path))) file.path,
  ];
  final bytes = files.fold<int>(0, (sum, file) => sum + file.lengthSync());
  stdout
    ..writeln('Covers wanted: ${wanted.length}, downloaded now: $fetched')
    ..writeln('Bundled: ${files.length} files, $bytes bytes');
  for (final path in stale) {
    stdout.writeln('No longer in the catalogue: $path');
  }
  if (failed.isNotEmpty) {
    failed.forEach(stderr.writeln);
    exitCode = 1;
  }
}
