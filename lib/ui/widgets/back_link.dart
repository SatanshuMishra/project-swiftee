import 'package:flutter/material.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';

class BackLink extends StatefulWidget {
  const BackLink({
    super.key,
    required this.onPressed,
    this.label = 'Back',
    this.animateEntrance = true,
  });

  static const entranceOffset = Offset(-10, 0);
  static const double iconSize = 16;
  static const double gap = 8;

  final VoidCallback onPressed;
  final String label;
  final bool animateEntrance;

  @override
  State<BackLink> createState() => _BackLinkState();
}

class _BackLinkState extends State<BackLink>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hover = AnimationController(
    vsync: this,
    duration: AppMotion.cssTransitionDuration,
  );

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    _hover.animateTo(hovered ? 1 : 0, curve: AppMotion.cssTransitionCurve);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final link = FocusableActionDetector(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        child: MouseRegion(
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: AnimatedBuilder(
              animation: _hover,
              builder: (context, _) {
                final color = Oklab.mix(
                  tokens.mutedForeground,
                  tokens.foreground,
                  _hover.value,
                );
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(
                      LucideGlyph.arrowLeft,
                      size: BackLink.iconSize,
                      color: color,
                    ),
                    const SizedBox(width: BackLink.gap),
                    Text(
                      widget.label,
                      style: AppText.sm.copyWith(color: color),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    if (!widget.animateEntrance) {
      return link;
    }
    return Entrance(fromOffset: BackLink.entranceOffset, child: link);
  }
}
