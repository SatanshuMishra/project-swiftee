import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/game/streak_badge.dart';
import 'package:swiftie_quiz/ui/widgets/back_link.dart';
import 'package:swiftie_quiz/ui/widgets/swiftie_logo.dart';

class GameHeader extends StatelessWidget {
  const GameHeader({super.key, required this.streak, required this.onExit});

  static const String exitLabel = 'Exit';
  static const double logoSize = 40;

  final int streak;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return GameLane(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          BackLink(label: exitLabel, animateEntrance: false, onPressed: onExit),
          const SwiftieLogo(size: logoSize),
          StreakBadge(streak: streak),
        ],
      ),
    );
  }
}

class GameLane extends StatelessWidget {
  const GameLane({super.key, required this.child});

  static const double maxWidth = 512;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}
