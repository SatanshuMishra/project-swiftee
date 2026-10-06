import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/era.dart';

void main() {
  test('the twelve curated eras keep the design order', () {
    expect(curatedEras.map((era) => era.key), [
      'ts',
      'fearless',
      'speaknow',
      'red',
      '1989',
      'rep',
      'lover',
      'folklore',
      'evermore',
      'midnights',
      'ttpd',
      'showgirl',
    ]);
    expect(curatedEras.map((era) => era.deezerAlbumId).toSet(), hasLength(12));
  });

  test('day of year counts the first of january as day one', () {
    expect(dayOfYear(DateTime(2026, 1, 1, 0, 30)), 1);
    expect(dayOfYear(DateTime(2026, 12, 31, 23, 59)), 365);
    expect(dayOfYear(DateTime(2028, 12, 31, 12)), 366);
  });

  test("tonight's era is the curated era at day of year mod twelve", () {
    expect(tonightsEra(DateTime(2026, 10, 6, 21)).key, 'red');
    expect(tonightsEra(DateTime(2026, 1, 12, 9)).key, 'ts');
    expect(tonightsEra(DateTime(2026, 1, 1, 9)).key, 'fearless');
  });

  test('an album id finds its era and an unknown id finds none', () {
    expect(eraForAlbumId(52612062)?.eraName, 'reputation');
    expect(eraForAlbumId(1), isNull);
  });
}
