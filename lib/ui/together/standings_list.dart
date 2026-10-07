import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/domain/together/standings.dart';
import 'package:swiftie_quiz/state/together/together_game_state.dart';
import 'package:swiftie_quiz/ui/kit/bead.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/ui/together/player_avatar.dart';
import 'package:swiftie_quiz/ui/together/player_colors.dart';
import 'package:together_protocol/together_protocol.dart';

class StandingsList extends StatelessWidget {
  const StandingsList({super.key, required this.game, required this.viewerId});

  static const double rowHeight = 56;
  static const double rowGap = 8;
  static const double rowStep = rowHeight + rowGap;
  static const Duration slide = Duration(milliseconds: 600);
  static const Curve slideCurve = AppMotion.screenRiseCurve;
  static const String youSuffix = ' (you)';

  final TogetherGameState game;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final order = ranked(
      game.standings,
      viewerId: viewerId,
      joinOrder: [for (final player in game.roster) player.id],
    );
    final rows = [
      for (final (rank, score) in order.indexed)
        if (game.roster.indexWhere((player) => player.id == score.id)
            case final joinIndex when joinIndex >= 0)
          (
            rank: rank,
            score: score,
            player: game.roster[joinIndex],
            joinIndex: joinIndex,
          ),
    ];
    final duration = AppMotion.duration(context, slide);
    return SizedBox(
      height: math.max(0, rows.length * rowStep - rowGap),
      child: Stack(
        children: [
          for (final row in rows.sortedBy<num>((row) => row.joinIndex))
            AnimatedPositioned(
              key: ValueKey(row.player.id),
              duration: duration,
              curve: slideCurve,
              left: 0,
              right: 0,
              top: row.rank * rowStep,
              height: rowHeight,
              child: StandingsRow(
                rank: row.rank + 1,
                player: row.player,
                score: row.score,
                viewer: row.player.id == viewerId,
                color: playerColor(
                  viewer: row.player.id == viewerId,
                  joinIndex: row.joinIndex,
                ),
                status: game.stage == TogetherStage.ended
                    ? null
                    : statusLine(
                        mode: game.mode,
                        revealed: game.stage == TogetherStage.reveal,
                        status: game.statuses[row.player.id],
                        wonQuickDraw: game.winnerId == row.player.id,
                        result: game.results[row.player.id],
                        left: row.score.left,
                      ),
                gain: game.stage == TogetherStage.reveal
                    ? game.results[row.player.id]?.gain ?? 0
                    : 0,
              ),
            ),
        ],
      ),
    );
  }
}

class StandingsRow extends StatelessWidget {
  const StandingsRow({
    super.key,
    required this.rank,
    required this.player,
    required this.score,
    required this.viewer,
    required this.color,
    required this.status,
    required this.gain,
  });

  static const padding = EdgeInsets.symmetric(horizontal: 14);
  static const radius = BorderRadius.all(Radius.circular(12));
  static const double gap = 12;
  static const double rankWidth = 16;
  static const double avatarSize = 30;
  static const double beadSize = 9;
  static const double beadGap = 4;
  static const int maxBeads = 8;
  static const double scoreWidth = 44;
  static const double gainRise = 6;

  final int rank;
  final Player player;
  final PlayerScore score;
  final bool viewer;
  final Color color;
  final String? status;
  final int gain;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final status = this.status;
    const tabular = [FontFeature.tabularFigures()];
    final name = Text(
      viewer ? '${player.name}${StandingsList.youSuffix}' : player.name,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: AppType.sized(15, 20).copyWith(color: tokens.fg),
    );
    final beads = math.min(score.wins, maxBeads);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: radius,
        border: Border.all(color: viewer ? tokens.line2 : tokens.line),
      ),
      child: Row(
        spacing: gap,
        children: [
          SizedBox(
            width: rankWidth,
            child: Text(
              '$rank',
              style: AppType.small.copyWith(
                color: tokens.faint,
                fontFeatures: tabular,
              ),
            ),
          ),
          PlayerAvatar(
            seed: player.avatar,
            name: player.name,
            size: avatarSize,
          ),
          Expanded(
            child: status == null
                ? name
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      name,
                      Text(
                        status,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.caption.copyWith(
                          color: gain > 0 ? tokens.coralT : tokens.mut,
                        ),
                      ),
                    ],
                  ),
          ),
          if (beads > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: beadGap,
              children: [
                for (var index = 0; index < beads; index++)
                  Bead(
                    key: ValueKey(index),
                    color: color,
                    size: beadSize,
                    pop: true,
                  ),
              ],
            ),
          if (gain > 0)
            _GainTag(
              key: ValueKey(gain),
              text: '+$gain',
              style: AppType.sized(
                13,
                18,
                weight: FontWeight.w600,
              ).copyWith(color: tokens.coralT),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: scoreWidth),
            child: Text(
              '${score.score}',
              textAlign: TextAlign.right,
              style: AppType.display(
                24,
                height: 28 / 24,
                color: tokens.fg,
              ).copyWith(fontFeatures: tabular),
            ),
          ),
        ],
      ),
    );
  }
}

class _GainTag extends StatelessWidget {
  const _GainTag({super.key, required this.text, required this.style});

  static const Duration rise = Duration(milliseconds: 300);

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.duration(context, rise),
    curve: Curves.ease,
    builder: (context, progress, child) => Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, StandingsRow.gainRise * (1 - progress)),
        child: child,
      ),
    ),
    child: Text(text, style: style),
  );
}
