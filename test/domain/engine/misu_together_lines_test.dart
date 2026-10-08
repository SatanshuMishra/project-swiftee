import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/misu_lines.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';

final DateTime _evening = DateTime(2026, 10, 7, 19);

void main() {
  test("misu keeps the prototype's close-finish and win lines first", () {
    List<String> lines(MisuLine kind, Edition edition, {double seconds = 0}) =>
        misuLines(
          kind,
          edition: edition,
          name: displayName(edition, 'Sam'),
          now: _evening,
          seconds: seconds,
        );

    expect(
      lines(MisuLine.closeFinish, Edition.ana, seconds: 4.3 - 4.0).first,
      "0.3 seconds apart. I'm calling it a tie.",
    );
    expect(
      lines(MisuLine.wonTogether, Edition.ana).first,
      'You won! I knew you would.',
    );
    expect(
      lines(MisuLine.closeFinish, Edition.open, seconds: 4.3 - 4.0).first,
      '0.3 seconds apart. Misu calls it a tie.',
    );
    expect(
      lines(MisuLine.wonTogether, Edition.open).first,
      'You won, Sam! Misu knew it.',
    );
  });
}
