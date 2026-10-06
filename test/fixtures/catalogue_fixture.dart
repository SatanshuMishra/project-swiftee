import 'dart:io';

import 'package:flutter_riverpod/misc.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_store.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';

const int taylor = 12246;

RawTrack rawTrack(
  int id,
  String title, {
  String? isrc,
  String version = '',
  int duration = 200,
  int artistId = taylor,
  bool preview = true,
}) => RawTrack(
  id: id,
  title: title,
  titleShort: title,
  titleVersion: version,
  duration: duration,
  artistId: artistId,
  isrc: isrc ?? 'ISRC$id',
  hasPreview: preview,
);

RawRelease rawRelease(
  int id,
  String title,
  String date,
  List<RawTrack> tracks, {
  ReleaseKind kind = ReleaseKind.album,
  String? cover,
}) => RawRelease(
  id: id,
  title: title,
  kind: kind,
  releaseDate: date,
  coverMedium: cover ?? 'https://covers.test/$id.jpg',
  tracks: tracks,
);

final List<RawRelease> fixtureReleases = [
  rawRelease(130721292, 'Red', '2012-10-22', [
    rawTrack(1, 'State Of Grace', isrc: 'RED01'),
    rawTrack(2, 'Everything Has Changed', isrc: 'RED02'),
    rawTrack(3, 'Red', isrc: 'RED03'),
  ]),
  rawRelease(130716962, 'Red (Deluxe Edition)', '2013-05-14', [
    rawTrack(11, 'State Of Grace', isrc: 'RED01'),
    rawTrack(12, 'The Moment I Knew', isrc: 'RED04'),
    rawTrack(13, 'State Of Grace (Acoustic Version)', isrc: 'RED05'),
  ]),
  rawRelease(272247412, "Red (Taylor's Version)", '2021-11-12', [
    rawTrack(21, "State Of Grace (Taylor's Version)", isrc: 'TV01'),
    rawTrack(22, "Red (Taylor's Version)", isrc: 'TV02'),
    rawTrack(
      23,
      "All Too Well (10 Minute Version) (Taylor's Version) (From The Vault)",
      isrc: 'TV03',
      duration: 613,
    ),
  ]),
  rawRelease(
    417939037,
    "The More Red (Taylor's Version) Chapter",
    '2023-03-17',
    [
      rawTrack(31, "Red (Taylor's Version)", isrc: 'TV02'),
      rawTrack(
        32,
        "All Too Well (Sad Girl Autumn Version) - Recorded at Long Pond Studios",
        isrc: 'TV04',
      ),
    ],
    kind: ReleaseKind.ep,
  ),
  rawRelease(108447472, 'Lover', '2019-08-23', [
    rawTrack(41, 'Cruel Summer', isrc: 'LOV01'),
  ]),
  rawRelease(510515281, 'The Cruelest Summer', '2023-11-09', [
    rawTrack(
      51,
      'Cruel Summer (LP Giobbi Remix)',
      isrc: 'LOV02',
      version: '(LP Giobbi Remix)',
    ),
    rawTrack(52, 'Cruel Summer (Live from The Eras Tour)', isrc: 'LOV03'),
  ], kind: ReleaseKind.ep),
  rawRelease(829966251, 'The Life of a Showgirl', '2025-10-03', [
    rawTrack(61, 'The Life of a Showgirl', isrc: 'SG01'),
  ]),
  rawRelease(1103662682, 'The Life of a Showgirl: The Encore', '2026-09-25', [
    rawTrack(71, 'The Life of a Showgirl', isrc: 'SG01'),
    rawTrack(72, 'Babylon', isrc: 'SG02'),
  ]),
  rawRelease(
    835672072,
    'The Life of a Showgirl (Track by Track Version)',
    '2025-10-07',
    [rawTrack(81, 'The Life of a Showgirl (Track by Track)', isrc: 'SG03')],
  ),
  rawRelease(1201, 'I Knew It, I Knew You (From "Toy Story 5")', '2026-06-12', [
    rawTrack(91, 'I Knew It, I Knew You (From "Toy Story 5")', isrc: 'TS501'),
  ], kind: ReleaseKind.single),
  rawRelease(1202, 'Anti-Hero (ILLENIUM Remix)', '2022-11-04', [
    rawTrack(
      101,
      'Anti-Hero (ILLENIUM Remix)',
      isrc: 'MID09',
      version: '(ILLENIUM Remix)',
    ),
  ], kind: ReleaseKind.single),
  rawRelease(1203, 'Us.', '2024-10-01', [
    rawTrack(111, 'Us.', isrc: 'GA01', artistId: 999),
  ], kind: ReleaseKind.single),
];

CatalogueStore fixtureCatalogueStore({
  List<RawRelease>? releases,
  Directory? folder,
  Future<String> Function()? loadBundled,
}) => CatalogueStore(
  loadBundled:
      loadBundled ??
      () async => encodeCatalogue(
        releases ?? fixtureReleases,
        fetchedAt: '2026-10-06T00:00:00Z',
      ),
  updatesFile: File(
    '${(folder ?? Directory.systemTemp.createTempSync('catalogue')).path}/'
    '$catalogueUpdatesFileName',
  ),
  now: () => DateTime.utc(2026, 10, 6),
);

Override fixtureCatalogue({List<RawRelease>? releases}) =>
    catalogueStoreProvider.overrideWithValue(
      fixtureCatalogueStore(releases: releases),
    );

Override bundledCatalogue() => catalogueStoreProvider.overrideWithValue(
  fixtureCatalogueStore(
    loadBundled: () async => File(bundledCataloguePath).readAsString(),
  ),
);
