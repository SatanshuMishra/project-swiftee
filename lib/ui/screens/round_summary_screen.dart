import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/misu_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/game/next_prompt.dart';
import 'package:swiftie_quiz/ui/kit/bead.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/kit/section_label.dart';
import 'package:swiftie_quiz/ui/kit/two_pane.dart';
import 'package:swiftie_quiz/ui/kit/vinyl.dart';
import 'package:swiftie_quiz/ui/screens/game_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

class RoundSummaryScreen extends ConsumerStatefulWidget {
  const RoundSummaryScreen({super.key});

  static const Duration misuDelay = Duration(milliseconds: 900);
  static const String knewLabel = 'The ones you knew';
  static const String againLabel = 'Another round →';
  static const String menuLabel = 'Back to menu';

  static String eraLabel(Era era) => "Tonight's era · ${era.eraName}";

  static String scoreLabel(int right, int total) => '$right of $total';

  static String scoreLine(int right) => switch (right) {
    >= 8 => 'A near-perfect run.',
    >= 5 => 'A solid round.',
    > 0 => 'Every Swiftie has an off night.',
    _ => 'Not a single one. The vault stays locked.',
  };

  static int rightCount(List<RoundOutcome> results) =>
      results.where((outcome) => outcome.correct).length;

  static Era roundEra(List<RoundOutcome> results, DateTime now) =>
      results
          .map((outcome) => eraForAlbumId(outcome.track.album.id))
          .nonNulls
          .firstOrNull ??
      tonightsEra(now);

  @override
  ConsumerState<RoundSummaryScreen> createState() => _RoundSummaryScreenState();
}

class _RoundSummaryScreenState extends ConsumerState<RoundSummaryScreen> {
  late final Timer _misuVisit;

  @override
  void initState() {
    super.initState();
    final right = RoundSummaryScreen.rightCount(
      ref.read(gameControllerProvider).roundResults,
    );
    _misuVisit = Timer(
      RoundSummaryScreen.misuDelay,
      () => ref.read(misuControllerProvider.notifier).afterQuickRound(right),
    );
  }

  @override
  void dispose() {
    _misuVisit.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(
      gameControllerProvider.select((state) => state.roundResults),
    );
    final era = RoundSummaryScreen.roundEra(
      results,
      ref.watch(clockProvider)(),
    );
    final game = ref.read(gameControllerProvider.notifier);
    final known = [
      for (final outcome in results)
        if (outcome.correct) outcome.track,
    ];
    return ScreenEnter(
      child: TwoPane(
        left: _ScoreColumn(era: era, results: results, right: known.length),
        right: _KnownColumn(
          known: known,
          onAgain: game.startQuickRound,
          onMenu: game.resetGame,
        ),
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  const _ScoreColumn({
    required this.era,
    required this.results,
    required this.right,
  });

  static const double padY = 40;
  static const double gap = 16;
  static const double scoreSize = 96;

  final Era era;
  final List<RoundOutcome> results;
  final int right;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: padY, horizontal: layout.padX),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: [
          SectionLabel(RoundSummaryScreen.eraLabel(era)),
          Text(
            RoundSummaryScreen.scoreLabel(right, results.length),
            style: AppType.display(scoreSize, height: 1, color: tokens.fg),
          ),
          Text(
            RoundSummaryScreen.scoreLine(right),
            style: AppType.bodyLarge.copyWith(color: tokens.mut),
          ),
          _BeadRow(results: results),
        ],
      ),
    );
  }
}

class _BeadRow extends StatelessWidget {
  const _BeadRow({required this.results});

  static const double padY = 10;
  static const double gap = 6;
  static const double lineWidth = 1;

  final List<RoundOutcome> results;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        Positioned.fill(
          child: Center(
            child: SizedBox(
              width: double.infinity,
              height: lineWidth,
              child: ColoredBox(color: tokens.line2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: padY),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final outcome in results)
                _ResultBead(correct: outcome.correct),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultBead extends StatelessWidget {
  const _ResultBead({required this.correct});

  static const double size = 14;
  static const double ringWidth = 1.5;

  final bool correct;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: correct ? tokens.coral : tokens.line2,
          width: ringWidth,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: ClipOval(
        clipper: const _InsetOval(Bead.ringWidth),
        child: Bead(
          color: correct ? tokens.coral : tokens.coral.withValues(alpha: 0),
          size: size,
        ),
      ),
    );
  }
}

class _InsetOval extends CustomClipper<Rect> {
  const _InsetOval(this.inset);

  final double inset;

  @override
  Rect getClip(Size size) => (Offset.zero & size).deflate(inset);

  @override
  bool shouldReclip(_InsetOval oldClipper) => oldClipper.inset != inset;
}

class _KnownColumn extends StatelessWidget {
  const _KnownColumn({
    required this.known,
    required this.onAgain,
    required this.onMenu,
  });

  static const double padY = 40;
  static const double gap = 24;
  static const double labelGap = 14;
  static const double buttonGap = 12;

  final List<Track> known;
  final VoidCallback onAgain;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: padY, horizontal: layout.padX),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: [
          if (known.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: labelGap,
              children: [
                const SectionLabel(RoundSummaryScreen.knewLabel),
                _KnownGrid(tracks: known),
              ],
            ),
          Wrap(
            spacing: buttonGap,
            runSpacing: buttonGap,
            children: [
              PillButton(
                label: RoundSummaryScreen.againLabel,
                onPressed: onAgain,
                size: PillSize.large,
              ),
              PillButton(
                label: RoundSummaryScreen.menuLabel,
                onPressed: onMenu,
                kind: PillKind.outline,
                size: PillSize.large,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KnownGrid extends StatelessWidget {
  const _KnownGrid({required this.tracks});

  static const int columns = 5;
  static const double columnGap = 12;
  static const double rowGap = 16;
  static const double subpixels = 64;
  static const Duration rise = Duration(milliseconds: 400);

  final List<Track> tracks;

  static double tileWidth(double width) =>
      ((width - columnGap * (columns - 1)) / columns * subpixels)
          .floorToDouble() /
      subpixels;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = tileWidth(constraints.maxWidth);
      return Wrap(
        spacing: columnGap,
        runSpacing: rowGap,
        children: [
          for (final (index, track) in tracks.indexed)
            SizedBox(
              key: ValueKey(index),
              width: width,
              child: RiseIn(
                duration: rise,
                child: _KnownRecord(track: track, size: width),
              ),
            ),
        ],
      );
    },
  );
}

class _KnownRecord extends StatelessWidget {
  const _KnownRecord({required this.track, required this.size});

  static const double titleGap = 6;
  static const double titleSize = 16;
  static const double titleLineHeight = 19;

  final Track track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final era = eraForAlbumId(track.album.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: titleGap,
      children: [
        AlbumSleeve(
          size: size,
          coverUrl: track.album.coverMedium,
          placeholder: era == null ? null : Color(era.placeholderArgb),
        ),
        Text(
          songTitle(track),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: AppType.display(
            titleSize,
            italic: true,
            height: titleLineHeight / titleSize,
            color: tokens.fg,
          ),
        ),
      ],
    );
  }
}
