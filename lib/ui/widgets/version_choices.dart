import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/domain/engine/version_filter.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/util/song_title.dart';
import 'package:swiftie_quiz/ui/kit/choice_grid.dart';
import 'package:swiftie_quiz/ui/kit/segmented.dart';
import 'package:swiftie_quiz/ui/kit/toggle_card.dart';

abstract final class VersionCopy {
  static const String versionsLabel = 'Versions';
  static const String rerecordedLabel = 'Re-recorded songs';
  static const String noneInPick = 'None in your pick';

  static String take(Take take) => switch (take) {
    Take.studio => 'Studio',
    Take.live => 'Live',
    Take.alternate => 'Acoustic & remixes',
  };

  static String rerecorded(Rerecorded rerecorded) => switch (rerecorded) {
    Rerecorded.taylorsVersion => 'Taylor’s Version',
    Rerecorded.original => 'Original',
    Rerecorded.both => 'Both',
  };

  static String tracks(int count) => count == 1 ? '1 track' : '$count tracks';

  static String? summary(VersionChoice choice) {
    final takes = [
      for (final kind in Take.values)
        if (choice.plays(kind)) take(kind),
    ];
    final parts = [
      if (takes.length < Take.values.length) takes.join(', '),
      ...switch (choice.rerecorded) {
        Rerecorded.taylorsVersion => [rerecorded(Rerecorded.taylorsVersion)],
        Rerecorded.original => ['Originals'],
        Rerecorded.both => const <String>[],
      },
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class TakeCards extends StatelessWidget {
  const TakeCards({
    super.key,
    required this.index,
    required this.choice,
    required this.onChanged,
  });

  final VersionIndex index;
  final VersionChoice choice;
  final ValueChanged<VersionChoice> onChanged;

  @override
  Widget build(BuildContext context) => ChoiceGrid(
    columns: Take.values.length,
    minTileWidth: ToggleCard.minWidthFor(MediaQuery.textScalerOf(context)),
    children: [
      for (final take in Take.values)
        ToggleCard(
          key: ValueKey(take),
          title: VersionCopy.take(take),
          detail: switch (index.countOf(take, choice)) {
            0 => VersionCopy.noneInPick,
            final count => VersionCopy.tracks(count),
          },
          checked: choice.plays(take),
          onTap: index.canToggle(choice, take)
              ? () => onChanged(choice.toggled(take))
              : null,
        ),
    ],
  );
}

class RerecordedChoice extends StatelessWidget {
  const RerecordedChoice({
    super.key,
    required this.index,
    required this.choice,
    required this.onChanged,
  });

  static final List<(Rerecorded, String)> options = [
    for (final rerecorded in Rerecorded.values)
      (rerecorded, VersionCopy.rerecorded(rerecorded)),
  ];

  final VersionIndex index;
  final VersionChoice choice;
  final ValueChanged<VersionChoice> onChanged;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Segmented<Rerecorded>(
        options: options,
        value: choice.rerecorded,
        enabled: (rerecorded) => index.canChoose(choice, rerecorded),
        onChanged: (rerecorded) =>
            onChanged(choice.copyWith(rerecorded: rerecorded)),
      ),
    ),
  );
}
