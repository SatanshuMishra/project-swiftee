import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_store.dart';
import 'package:swiftie_quiz/domain/engine/catalogue_rules.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/era.dart';

const String _api = 'https://api.deezer.com';
const Duration _spacing = Duration(milliseconds: 250);
const int _attempts = 5;

Future<void> main(List<String> arguments) async {
  final out = File(arguments.isEmpty ? bundledCataloguePath : arguments.single);
  final client = http.Client();
  try {
    final summaries = await _pages(
      client,
      Uri.parse('$_api/artist/$taylorArtistId/albums?limit=100'),
      parseReleaseSummary,
    );
    final releases = <RawRelease>[];
    for (final summary in summaries) {
      final tracks = await _pages(
        client,
        Uri.parse('$_api/album/${summary.id}/tracks?limit=100'),
        parseRawTrack,
      );
      releases.add(summary.copyWith(tracks: tracks));
    }
    await out.parent.create(recursive: true);
    await out.writeAsString(
      encodeCatalogue(
        releases,
        fetchedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    final catalogue = buildCatalogue(releases);
    stdout.writeln(
      'wrote ${out.path}: ${releases.length} releases, '
      '${catalogue.recordings.length} playable recordings',
    );
    for (final era in eraGroups) {
      stdout.writeln('  ${era.eraName}: ${catalogue.trackCount(era.key)}');
    }
  } finally {
    client.close();
  }
}

Future<List<T>> _pages<T>(
  http.Client client,
  Uri first,
  T Function(Object? item) parse,
) async {
  final items = <T>[];
  Uri? page = first;
  final seen = <Uri>{};
  while (page != null && seen.add(page)) {
    final body = await _get(client, page);
    items.addAll([
      for (final item in body['data'] as List<Object?>) parse(item),
    ]);
    final next = body['next'] as String?;
    page = next == null ? null : Uri.parse(next);
  }
  return items;
}

Future<Map<String, Object?>> _get(http.Client client, Uri url) async {
  for (var attempt = 1; attempt <= _attempts; attempt++) {
    await Future<void>.delayed(_spacing * attempt);
    final response = await client.get(url);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 &&
        body is Map<String, Object?> &&
        !body.containsKey('error')) {
      return body;
    }
  }
  throw HttpException('Deezer did not answer $url', uri: url);
}
