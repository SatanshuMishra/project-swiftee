import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/catalogue_rules.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/era.dart';

import '../../fixtures/catalogue_fixture.dart';

void main() {
  late Catalogue catalogue;

  setUp(() => catalogue = buildCatalogue(fixtureReleases));

  List<String> titlesFor(String eraKey) => [
    for (final track in catalogue.tracksFor([eraKey])) track.title,
  ];

  group('catalogue rules', () {
    test(
      'every Taylor-led recording plays once, however many releases hold it',
      () {
        final titles = [for (final track in catalogue.allTracks) track.title];
        expect(
          titles.where((title) => title == 'State Of Grace'),
          hasLength(1),
        );
        expect(
          titles.where((title) => title == "Red (Taylor's Version)"),
          hasLength(1),
        );
        expect(titles, contains('Everything Has Changed'));
        expect(titles, isNot(contains('Us.')));
      },
    );

    test("taylor's versions and originals are separate recordings", () {
      expect(
        titlesFor('red'),
        containsAll([
          'State Of Grace',
          "State Of Grace (Taylor's Version)",
          'Red',
          "Red (Taylor's Version)",
        ]),
      );
    });

    test(
      'remixes and commentary never play, live and acoustic versions do',
      () {
        final titles = [for (final track in catalogue.allTracks) track.title];
        expect(titles, isNot(contains('Anti-Hero (ILLENIUM Remix)')));
        expect(titles, isNot(contains('Cruel Summer (LP Giobbi Remix)')));
        expect(
          titles,
          isNot(contains('The Life of a Showgirl (Track by Track)')),
        );
        expect(titles, contains('Cruel Summer (Live from The Eras Tour)'));
        expect(titles, contains('State Of Grace (Acoustic Version)'));
      },
    );

    test('a remix is caught by its title as well as its version', () {
      expect(
        isPlayableTitle(
          "Message In A Bottle (Fat Max G Remix) (Taylor's Version)",
          '',
          220,
        ),
        isFalse,
      );
      expect(isPlayableTitle('Love Story (Pop Mix)', '', 233), isFalse);
      expect(
        isPlayableTitle('Delicate (Sawyr And Ryan Tedder Mix)', '', 200),
        isFalse,
      );
      expect(isPlayableTitle('Mine', '', 230), isTrue);
      expect(
        isPlayableTitle('Christmas Tree Farm (Old Timey Version)', '', 220),
        isTrue,
      );
    });

    test('releases join an era by title, then by the songs they hold, else singles', () {
      expect(catalogue.eraOf(130716962)?.key, 'red');
      expect(catalogue.eraOf(417939037)?.key, 'red');
      expect(catalogue.eraOf(1103662682)?.key, 'showgirl');
      expect(catalogue.eraOf(510515281)?.key, 'lover');
      expect(catalogue.eraOf(1201)?.key, singlesEra.key);
    });

    test('every playable recording is reachable from exactly one era tile', () {
      final byTile = [
        for (final era in eraGroups) ...catalogue.tracksFor([era.key]),
      ];
      expect(byTile.length, catalogue.allTracks.length);
      expect(byTile.toSet().length, catalogue.allTracks.length);
      expect(titlesFor('showgirl'), contains('Babylon'));
      expect(titlesFor(singlesEra.key), [
        'I Knew It, I Knew You (From "Toy Story 5")',
      ]);
    });

    test('a recording belongs to the first album that holds it, at its track number', () {
      final grace = catalogue.allTracks.firstWhere(
        (track) => track.title == 'State Of Grace',
      );
      expect(grace.album.id, 130721292);
      expect(grace.trackPosition, 1);
      final babylon = catalogue.allTracks.firstWhere(
        (track) => track.title == 'Babylon',
      );
      expect(babylon.album.id, 1103662682);
      expect(babylon.trackPosition, 2);
      expect(babylon.preview, isEmpty);
    });

    test('counts and covers follow the era tiles', () {
      expect(catalogue.trackCount('red'), titlesFor('red').length);
      expect(catalogue.coverFor('red'), 'https://covers.test/272247412.jpg');
      expect(
        catalogue.coverFor(singlesEra.key),
        'https://covers.test/1201.jpg',
      );
      expect(catalogue.albums.map((album) => album.id), contains(1203));
      expect(catalogue.homeTotals[130721292], 3);
    });

    test('a playlist of every era never pulls other eras into its own', () {
      final rebuilt = buildCatalogue([
        rawRelease(1, 'Speak Now', '2010-10-25', [
          rawTrack(101, 'Mine'),
          rawTrack(102, 'Sparks Fly'),
          rawTrack(103, 'Enchanted'),
        ]),
        rawRelease(2, 'Red', '2012-10-22', [
          rawTrack(201, 'Red'),
          rawTrack(202, '22'),
        ]),
        rawRelease(3, 'reputation', '2017-11-10', [rawTrack(301, 'Delicate')]),
        rawRelease(
          4,
          'reputation Stadium Tour Surprise Song Playlist',
          '2018-05-08',
          [
            rawTrack(401, 'Mine', isrc: 'ISRC101'),
            rawTrack(402, 'Sparks Fly', isrc: 'ISRC102'),
            rawTrack(403, 'Enchanted', isrc: 'ISRC103'),
            rawTrack(404, 'Red', isrc: 'ISRC201'),
            rawTrack(405, '22', isrc: 'ISRC202'),
            rawTrack(406, 'Delicate', isrc: 'ISRC301'),
          ],
        ),
        rawRelease(5, 'Live At The Stadium', '2026-11-20', [
          rawTrack(501, 'Mine (Live)'),
          rawTrack(502, 'Sparks Fly (Live)'),
          rawTrack(503, 'Enchanted (Live)'),
          rawTrack(504, 'Red (Live)'),
          rawTrack(505, '22 (Live)'),
        ]),
      ]);
      expect(rebuilt.eraOf(5)?.key, 'speaknow');
    });

    test('an album is home to a recording its earlier single also holds', () {
      final rebuilt = buildCatalogue([
        rawRelease(1, "Love Story (Taylor's Version)", '2021-02-12', [
          rawTrack(101, "Love Story (Taylor's Version)", isrc: 'TV-LS'),
        ], kind: ReleaseKind.single),
        rawRelease(2, "Fearless (Taylor's Version)", '2021-04-09', [
          rawTrack(201, "Fearless (Taylor's Version)"),
          rawTrack(202, "Love Story (Taylor's Version)", isrc: 'TV-LS'),
        ]),
      ]);
      final loveStory = rebuilt.allTracks.singleWhere(
        (track) => track.title.startsWith('Love Story'),
      );
      expect(loveStory.album.id, 2);
      expect(loveStory.trackPosition, 2);
      expect(loveStory.eraKey, 'fearless');
    });

    test('a recording without an ISRC is kept under its Deezer id', () {
      final rebuilt = buildCatalogue([
        rawRelease(5, 'evermore', '2020-12-11', [
          rawTrack(501, 'willow', isrc: ''),
          rawTrack(502, 'gold rush', isrc: ''),
        ]),
      ]);
      expect(rebuilt.allTracks, hasLength(2));
    });
  });
}
