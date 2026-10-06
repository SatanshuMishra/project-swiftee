import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/data/catalog/deezer_client.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';

const String bundledCataloguePath = 'assets/catalog/catalogue.json';
const String catalogueUpdatesFileName = 'catalogue_updates.json';

final class CatalogueStore {
  const CatalogueStore({
    required this._loadBundled,
    required this.updatesFile,
    required this._now,
  });

  static const int releasesPerRefresh = 8;

  final Future<String> Function() _loadBundled;
  final File updatesFile;
  final DateTime Function() _now;

  Future<List<RawRelease>> load() async {
    final bundled = decodeCatalogue(await _loadBundled());
    final updates = await _readUpdates();
    final updatedIds = {for (final release in updates) release.id};
    return List.unmodifiable([
      for (final release in bundled)
        if (!updatedIds.contains(release.id)) release,
      ...updates,
    ]);
  }

  Future<List<RawRelease>> addNewReleases(
    DeezerClient client,
    Set<int> knownIds,
  ) async {
    final unknown = (await client.fetchReleaseSummaries())
        .where((release) => !knownIds.contains(release.id))
        .take(releasesPerRefresh)
        .toList(growable: false);
    final added = <RawRelease>[
      for (final release in unknown)
        release.copyWith(tracks: await client.fetchReleaseTracks(release.id)),
    ];
    if (added.isNotEmpty) {
      await _writeUpdates([...await _readUpdates(), ...added]);
    }
    return List.unmodifiable(added);
  }

  Future<List<RawRelease>> _readUpdates() async {
    if (!updatesFile.existsSync()) {
      return const [];
    }
    try {
      return decodeCatalogue(await updatesFile.readAsString());
    } on Object {
      return const [];
    }
  }

  Future<void> _writeUpdates(List<RawRelease> releases) async {
    await updatesFile.parent.create(recursive: true);
    final temp = File(p.setExtension(updatesFile.path, '.json.tmp'));
    await temp.writeAsString(
      encodeCatalogue(releases, fetchedAt: _now().toUtc().toIso8601String()),
      flush: true,
    );
    await temp.rename(updatesFile.path);
  }
}
