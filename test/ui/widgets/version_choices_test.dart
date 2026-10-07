import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/ui/widgets/version_choices.dart';

void main() {
  test('the summary names only what differs from every version', () {
    const all = VersionChoice.all;

    expect(VersionCopy.summary(all), isNull);
    expect(
      VersionCopy.summary(all.copyWith(live: false)),
      'Studio, Acoustic & remixes',
    );
    expect(
      VersionCopy.summary(all.copyWith(rerecorded: Rerecorded.original)),
      'Original',
    );
    expect(
      VersionCopy.summary(
        all.copyWith(
          studio: false,
          alternate: false,
          rerecorded: Rerecorded.taylorsVersion,
        ),
      ),
      'Live · Taylor’s Version',
    );
  });

  test('a card names the recording choice that leaves it empty', () {
    expect(
      VersionCopy.noneWith(Rerecorded.taylorsVersion),
      'None in Taylor’s Version',
    );
    expect(VersionCopy.noneWith(Rerecorded.original), 'None in the originals');
  });
}
