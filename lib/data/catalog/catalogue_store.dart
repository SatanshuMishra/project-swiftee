import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:swiftie_quiz/data/catalog/catalog_error.dart';
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

  static const Duration recentWindow = Duration(days: 90);
  static const int releasesPerCheck = 25;

  final Future<String> Function() _loadBundled;
  final File updatesFile;
  final DateTime Function() _now;

  Future<List<RawRelease>> load() async {
    final bundled = decodeCatalogueEntries(await _loadBundled());
    final bundledAt = {
      for (final entry in bundled) entry.release.id: entry.fetchedAt,
    };
    final updates = await _readUpdates();
    final kept = [
      for (final entry in updates)
        if (bundledAt[entry.release.id] case final bundledTime
            when bundledTime == null || entry.fetchedAt.isAfter(bundledTime))
          entry,
    ];
    if (kept.length != updates.length) {
      await _pruneUpdates(kept);
    }
    final newer = {for (final entry in kept) entry.release.id: entry.release};
    return List.unmodifiable([
      for (final entry in bundled) newer[entry.release.id] ?? entry.release,
      for (final entry in kept)
        if (!bundledAt.containsKey(entry.release.id)) entry.release,
    ]);
  }

  Future<void> _pruneUpdates(List<CatalogueEntry> kept) async {
    try {
      await _writeUpdates(kept);
    } on FileSystemException {
      return;
    }
  }

  Future<List<RawRelease>> refreshReleases(
    DeezerClient client,
    Map<int, RawRelease> known,
  ) async {
    final since = _now().subtract(recentWindow);
    final summaries = await client.fetchReleaseSummaries();
    final due = [
      for (final summary in summaries)
        if (!known.containsKey(summary.id)) summary,
      for (final summary in summaries)
        if (known.containsKey(summary.id) && _releasedSince(summary, since))
          summary,
    ].take(releasesPerCheck);
    final fetched = <CatalogueEntry>[];
    for (final summary in due) {
      final List<RawTrack> tracks;
      try {
        tracks = await client.fetchReleaseTracks(summary.id);
      } on CatalogError {
        break;
      }
      final release = summary.copyWith(tracks: tracks);
      if (known[summary.id] != release) {
        fetched.add((release: release, fetchedAt: _now()));
      }
    }
    if (fetched.isNotEmpty) {
      final refreshed = {for (final entry in fetched) entry.release.id};
      await _writeUpdates([
        for (final entry in await _readUpdates())
          if (!refreshed.contains(entry.release.id)) entry,
        ...fetched,
      ]);
    }
    return List.unmodifiable([for (final entry in fetched) entry.release]);
  }

  static bool _releasedSince(RawRelease release, DateTime since) =>
      switch (DateTime.tryParse(release.releaseDate)) {
        final date? => !date.isBefore(since),
        null => false,
      };

  Future<List<CatalogueEntry>> _readUpdates() async {
    if (!updatesFile.existsSync()) {
      return const [];
    }
    try {
      return decodeCatalogueEntries(
        await updatesFile.readAsString(),
        unstamped: DateTime.utc(1970),
      );
    } on Object {
      return const [];
    }
  }

  Future<void> _writeUpdates(List<CatalogueEntry> entries) async {
    await updatesFile.parent.create(recursive: true);
    final temp = File(p.setExtension(updatesFile.path, '.json.tmp'));
    await temp.writeAsString(
      encodeCatalogueEntries(entries, fetchedAt: _now()),
      flush: true,
    );
    await temp.rename(updatesFile.path);
  }
}
