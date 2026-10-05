import 'package:flutter/material.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';

enum PrimaryButtonVariant {
  action(horizontalPadding: 32, textStyle: _medium, shadows: []),
  start(horizontalPadding: 32, textStyle: _largeBold, shadows: AppShadows.lg),
  restart(horizontalPadding: 24, textStyle: _medium, shadows: []);

  const PrimaryButtonVariant({
    required this.horizontalPadding,
    required this.textStyle,
    required this.shadows,
  });

  static const _medium = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const _largeBold = TextStyle(
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  final double horizontalPadding;
  final TextStyle textStyle;
  final List<BoxShadow> shadows;
}

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PrimaryButtonVariant.action,
    this.cursor = SystemMouseCursors.basic,
  });

  static const double verticalPadding = 12;
  static const double radius = AppRadii.xl;
  static const double disabledOpacity = 0.5;
  static const double startHoverScale = 1.05;
  static const double startTapScale = 0.97;
  static const double restartHoverScale = 1.05;

  final String label;
  final VoidCallback? onPressed;
  final PrimaryButtonVariant variant;
  final MouseCursor cursor;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
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
    final variant = widget.variant;
    final onPressed = widget.onPressed;
    final enabled = onPressed != null;

    Widget button = DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.primary,
        borderRadius: BorderRadius.circular(PrimaryButton.radius),
        boxShadow: variant.shadows,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: variant.horizontalPadding,
          vertical: PrimaryButton.verticalPadding,
        ),
        child: Text(
          widget.label,
          textAlign: TextAlign.center,
          style: variant.textStyle.copyWith(color: tokens.primaryForeground),
        ),
      ),
    );

    button = AnimatedOpacity(
      opacity: enabled ? 1 : PrimaryButton.disabledOpacity,
      duration: AppMotion.cssTransitionDuration,
      curve: AppMotion.cssTransitionCurve,
      child: button,
    );

    button = MouseRegion(
      cursor: enabled ? widget.cursor : SystemMouseCursors.forbidden,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: FocusableActionDetector(
        enabled: enabled,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onPressed?.call();
              return null;
            },
          ),
        },
        child: Semantics(
          button: true,
          enabled: enabled,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: button,
          ),
        ),
      ),
    );

    return switch (variant) {
      PrimaryButtonVariant.action => button,
      PrimaryButtonVariant.start => Entrance(
        fromOpacity: 1,
        spring: AppMotion.defaultScaleSpring,
        hoverScale: PrimaryButton.startHoverScale,
        tapScale: PrimaryButton.startTapScale,
        child: button,
      ),
      PrimaryButtonVariant.restart => AnimatedBuilder(
        animation: _hover,
        builder: (context, child) => Transform.scale(
          scale: 1 + (PrimaryButton.restartHoverScale - 1) * _hover.value,
          child: child,
        ),
        child: button,
      ),
    };
  }
}
