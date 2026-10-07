import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/misu_lines.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';

final DateTime _evening = DateTime(2026, 10, 7, 19);

void main() {
  test("misu has the prototype's close-finish and win lines", () {
    String line(MisuLine kind, Edition edition, {double seconds = 0}) =>
        misuLine(
          kind,
          edition: edition,
          name: displayName(edition, 'Sam'),
          now: _evening,
          seconds: seconds,
        );

    expect(
      line(MisuLine.closeFinish, Edition.ana, seconds: 4.3 - 4.0),
      "0.3 seconds apart. I'm calling it a tie.",
    );
    expect(
      line(MisuLine.wonTogether, Edition.ana),
      'You won! I knew you would.',
    );
    expect(
      line(MisuLine.closeFinish, Edition.open, seconds: 4.3 - 4.0),
      '0.3 seconds apart. Misu calls it a tie.',
    );
    expect(
      line(MisuLine.wonTogether, Edition.open),
      'You won, Sam! Misu knew it.',
    );
  });
}
