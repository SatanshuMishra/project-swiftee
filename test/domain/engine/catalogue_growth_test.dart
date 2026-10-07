import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_store.dart';
import 'package:swiftie_quiz/domain/engine/catalogue_rules.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/util/song_title.dart';

import '../../fixtures/catalogue_fixture.dart';

const int albumId = 990000001;
const int deluxeId = 990000002;
const int singleId = 990000003;
const int tourId = 990000004;
const int repTvId = 990000005;

const List<String> newSongs = [
  'Opening Night',
  'Paper Lanterns',
  'Northbound',
  'The Last Encore',
  'Glass Garden',
  'Velvet Hour',
  'Still Standing',
  'Harbor Lights',
  'Small Town Sky',
  'Afterglow Avenue',
  'Silver Lining Street',
  'Midnight Mail',
  'Curtain Call',
];

List<RawRelease> grownReleases() {
  final bundled = decodeCatalogue(
    File(bundledCataloguePath).readAsStringSync(),
  );
  final rep = bundled.singleWhere((release) => release.id == 52612062);
  return [
    ...bundled,
    rawRelease(singleId, 'Opening Night', '2027-02-01', [
      rawTrack(9100, 'Opening Night', isrc: 'NEW00'),
    ], kind: ReleaseKind.single),
    rawRelease(albumId, 'Album Thirteen', '2027-03-01', [
      for (final (index, song) in newSongs.indexed)
        rawTrack(
          9000 + index,
          song,
          isrc: 'NEW${index.toString().padLeft(2, '0')}',
        ),
    ]),
    rawRelease(deluxeId, 'Album Thirteen (Deluxe)', '2027-03-15', [
      for (final (index, song) in newSongs.indexed)
        rawTrack(
          9200 + index,
          song,
          isrc: 'NEW${index.toString().padLeft(2, '0')}',
        ),
      rawTrack(9230, 'Lost Letters (From The Vault)', isrc: 'NEW30'),
      rawTrack(9231, 'Paper Lanterns (Acoustic Version)', isrc: 'NEW31'),
    ]),
    rawRelease(tourId, 'Album Thirteen Tour (Live)', '2027-09-01', [
      for (final (index, song) in newSongs.take(6).indexed)
        rawTrack(9300 + index, '$song (Live)', isrc: 'NEWL$index'),
    ]),
    rawRelease(repTvId, "reputation (Taylor's Version)", '2027-11-10', [
      for (final (index, track) in rep.tracks.indexed)
        rawTrack(
          9400 + index,
          "${track.title} (Taylor's Version)",
          isrc: 'REPTV$index',
        ),
      rawTrack(
        9450,
        "Never Told (Taylor's Version) (From The Vault)",
        isrc: 'REPTV50',
      ),
    ]),
  ];
}

void main() {
  late Catalogue catalogue;

  setUp(() => catalogue = buildCatalogue(grownReleases()));

  group('a release the app has never seen joins the catalogue', () {
    test('the bundled catalogue alone starts no new era', () {
      final bundled = buildCatalogue(
        decodeCatalogue(File(bundledCataloguePath).readAsStringSync()),
      );

      expect(bundled.derivedEras, isEmpty);
      expect(bundled.eras, eraGroups);
    });

    for (final curated in curatedEras) {
      test('with no title rule, the ${curated.key} era would still form from '
          'its own albums and hold the same recordings', () {
        final bundled = decodeCatalogue(
          File(bundledCataloguePath).readAsStringSync(),
        );
        final hidden = [
          for (final release in bundled)
            eraKeyForTitle(release.title) == curated.key
                ? RawRelease(
                    id: release.id,
                    title: 'Hidden ${curated.key} ${release.title.length}',
                    kind: release.kind,
                    releaseDate: release.releaseDate,
                    coverMedium: release.coverMedium,
                    tracks: release.tracks,
                  )
                : release,
        ];
        final original = buildCatalogue(bundled);
        final rebuilt = buildCatalogue(hidden);
        final isrcs = {
          for (final recording in original.recordings)
            if (recording.eraKey == curated.key) recording.isrc,
        };

        final derived = rebuilt.derivedEras;
        expect(derived, hasLength(1));
        expect({
          for (final recording in rebuilt.recordings)
            if (derived.any((era) => era.key == recording.eraKey))
              recording.isrc,
        }, isrcs);
      });
    }

    test('a new studio album of new songs starts its own era, named and '
        'dated from the album', () {
      final era = catalogue.derivedEras.single;

      expect(era.key, 'album-$albumId');
      expect(era.deezerAlbumId, albumId);
      expect(era.eraName, 'Album Thirteen');
      expect(era.subLabel, '2027');
      expect(catalogue.eras, [...curatedEras, era, singlesEra]);
      expect(catalogue.eraOf(albumId), era);
      expect(catalogue.coverFor(era.key), 'https://covers.test/$albumId.jpg');
    });

    test('its lead single, deluxe edition and live album join that era', () {
      const key = 'album-$albumId';

      for (final id in [singleId, deluxeId, tourId]) {
        expect(catalogue.eraOf(id)?.key, key, reason: '$id');
      }
      final titles = [
        for (final track in catalogue.tracksFor([key])) track.title,
      ];
      expect(titles, containsAll(newSongs));
      expect(
        titles,
        containsAll([
          'Lost Letters (From The Vault)',
          'Paper Lanterns (Acoustic Version)',
          'Opening Night (Live)',
        ]),
      );
      expect(titles.where((title) => title == 'Opening Night'), hasLength(1));
      expect(
        catalogue.tracksFor(['singles']).map((track) => track.title),
        isNot(contains('Opening Night')),
      );
    });

    test('its takes are sorted by the same rules as every other song', () {
      final takes = {
        for (final track in catalogue.tracksFor(['album-$albumId']))
          track.title: takeOf(track.title),
      };

      expect(takes['Opening Night'], Take.studio);
      expect(takes['Lost Letters (From The Vault)'], Take.studio);
      expect(takes['Paper Lanterns (Acoustic Version)'], Take.alternate);
      expect(takes['Opening Night (Live)'], Take.live);
      for (final title in takes.keys) {
        expect(unknownTitleLabels(title), isEmpty, reason: title);
      }
    });

    test("a new Taylor's Version joins its original era and marks those "
        'songs as re-recorded', () {
      final rep = [
        for (final track in catalogue.tracksFor(['rep'])) track.title,
      ];

      expect(catalogue.eraOf(repTvId)?.key, 'rep');
      expect(catalogue.derivedEras, hasLength(1));
      expect(rep, contains("Delicate (Taylor's Version)"));
      expect(rep, contains('Delicate'));
      expect(rep, contains("Never Told (Taylor's Version) (From The Vault)"));
      expect(isTaylorsVersion("Delicate (Taylor's Version)"), isTrue);
    });
  });

  group('naming and joining eras', () {
    test('an expanded edition with mostly new songs joins its album era '
        'instead of starting a second one', () {
      final anthology = rawRelease(
        990000009,
        'Album Thirteen: The Anthology',
        '2027-03-02',
        [
          for (final (index, song) in newSongs.indexed)
            rawTrack(
              9500 + index,
              song,
              isrc: 'NEW${index.toString().padLeft(2, '0')}',
            ),
          for (var index = 0; index < 15; index++)
            rawTrack(9600 + index, 'Anthology Song $index', isrc: 'ANT$index'),
        ],
      );
      final renamed = rawRelease(
        990000010,
        'Thirteen Revisited',
        '2027-04-01',
        [
          for (final (index, song) in newSongs.take(6).indexed)
            rawTrack(
              9700 + index,
              song,
              isrc: 'NEW${index.toString().padLeft(2, '0')}',
            ),
          for (var index = 0; index < 8; index++)
            rawTrack(9800 + index, 'Revisited Song $index', isrc: 'REV$index'),
        ],
      );

      final grown = buildCatalogue([...grownReleases(), anthology, renamed]);

      expect(grown.derivedEras, hasLength(1));
      expect(grown.eraOf(anthology.id)?.key, 'album-$albumId');
      expect(grown.eraOf(renamed.id)?.key, 'album-$albumId');
    });

    test('the curated title rules catch re-recordings and stop at word '
        'boundaries', () {
      expect(eraKeyForTitle("Taylor Swift (Taylor's Version)"), 'ts');
      expect(eraKeyForTitle('Taylor Swift'), 'ts');
      expect(eraKeyForTitle('Fearless (Platinum Edition)'), 'fearless');
      expect(eraKeyForTitle('Fearlessly'), isNull);
      expect(eraKeyForTitle('Lover (Live From Paris)'), 'lover');
      expect(eraKeyForTitle('Loverboy'), isNull);
    });

    test('an era is named after its album without edition suffixes', () {
      expect(
        eraNameFromTitle('Album Thirteen (Deluxe) [Explicit]'),
        'Album Thirteen',
      );
      expect(
        eraNameFromTitle('THE TORTURED POETS DEPARTMENT: THE ANTHOLOGY'),
        'THE TORTURED POETS DEPARTMENT',
      );
      expect(eraNameFromTitle('1989 (Deluxe Edition)'), '1989');
      expect(eraNameFromTitle('(Untitled)'), '(Untitled)');
    });
  });
}
