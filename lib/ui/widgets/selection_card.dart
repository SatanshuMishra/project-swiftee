import 'package:flutter/material.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';

enum SelectionCardLayout {
  leading(
    crossAxisAlignment: CrossAxisAlignment.start,
    textAlign: TextAlign.start,
    hoverScale: 1.02,
    tapScale: 0.98,
  ),
  centered(
    crossAxisAlignment: CrossAxisAlignment.center,
    textAlign: TextAlign.center,
    hoverScale: 1.05,
    tapScale: 0.97,
  );

  const SelectionCardLayout({
    required this.crossAxisAlignment,
    required this.textAlign,
    required this.hoverScale,
    required this.tapScale,
  });

  final CrossAxisAlignment crossAxisAlignment;
  final TextAlign textAlign;
  final double hoverScale;
  final double tapScale;

  TextStyle get titleStyle => switch (this) {
    leading => AppText.lg.copyWith(fontWeight: FontWeight.w600),
    centered => AppText.xl2.copyWith(fontWeight: FontWeight.w700),
  };
}

class SelectionCard extends StatefulWidget {
  const SelectionCard({
    super.key,
    required this.glyph,
    required this.title,
    required this.description,
    required this.gradient,
    required this.onTap,
    this.delay = Duration.zero,
    this.layout = SelectionCardLayout.leading,
    this.footer,
    this.disabled = false,
    this.disabledReason,
    this.cursor = SystemMouseCursors.basic,
  });

  static const entranceOffset = Offset(0, 20);
  static const double radius = AppRadii.xl2;
  static const double borderWidth = 1;
  static const double padding = 32;
  static const double gap = 16;
  static const double badgePadding = 12;
  static const double badgeRadius = AppRadii.xl;
  static const double iconSize = 24;
  static const double descriptionGap = 4;
  static const double reasonGap = 8;
  static const double hoverOverlayOpacity = 0.1;
  static const int hoverBorderPercent = 50;

  final LucideGlyph glyph;
  final String title;
  final String description;
  final GradientPair gradient;
  final VoidCallback onTap;
  final Duration delay;
  final SelectionCardLayout layout;
  final Widget? footer;
  final bool disabled;
  final String? disabledReason;
  final MouseCursor cursor;

  @override
  State<SelectionCard> createState() => _SelectionCardState();
}

class _SelectionCardState extends State<SelectionCard>
    with TickerProviderStateMixin {
  late final AnimationController _card = AnimationController(
    vsync: this,
    duration: AppMotion.cardTransitionDuration,
  );
  late final AnimationController _overlay = AnimationController(
    vsync: this,
    duration: AppMotion.cssTransitionDuration,
  );
  late final Listenable _frame = Listenable.merge([_card, _overlay]);

  bool _hovered = false;

  @override
  void didUpdateWidget(SelectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.disabled != widget.disabled) {
      _syncHover();
    }
  }

  @override
  void dispose() {
    _card.dispose();
    _overlay.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (_hovered == hovered) {
      return;
    }
    _hovered = hovered;
    _syncHover();
  }

  void _syncHover() {
    _overlay.animateTo(_hovered ? 1 : 0, curve: AppMotion.cssTransitionCurve);
    _card.animateTo(
      _hovered && !widget.disabled ? 1 : 0,
      curve: AppMotion.cssTransitionCurve,
    );
  }

  void _activate() {
    if (!widget.disabled) {
      widget.onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final layout = widget.layout;
    final reason = widget.disabledReason;
    final hoverBorder = tokens.primary.slashOpacity(
      SelectionCard.hoverBorderPercent,
    );

    final content = Padding(
      padding: const EdgeInsets.all(SelectionCard.padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: layout.crossAxisAlignment,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SelectionCard.badgeRadius),
              gradient: widget.gradient.diagonal,
            ),
            child: Padding(
              padding: const EdgeInsets.all(SelectionCard.badgePadding),
              child: AppIcon(
                widget.glyph,
                size: SelectionCard.iconSize,
                color: AppPalette.white,
              ),
            ),
          ),
          const SizedBox(height: SelectionCard.gap),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: layout.crossAxisAlignment,
            children: [
              Text(
                widget.title,
                textAlign: layout.textAlign,
                style: layout.titleStyle.copyWith(color: tokens.foreground),
              ),
              const SizedBox(height: SelectionCard.descriptionGap),
              Text(
                widget.description,
                textAlign: layout.textAlign,
                style: AppText.sm.copyWith(color: tokens.mutedForeground),
              ),
              if (widget.disabled && reason != null) ...[
                const SizedBox(height: SelectionCard.reasonGap),
                Text(
                  reason,
                  textAlign: layout.textAlign,
                  style: AppText.xs.copyWith(color: AppPalette.yellow500),
                ),
              ],
            ],
          ),
          if (widget.footer case final footer?) ...[
            const SizedBox(height: SelectionCard.gap),
            footer,
          ],
        ],
      ),
    );

    final card = AnimatedBuilder(
      animation: _frame,
      builder: (context, child) {
        final overlayOpacity =
            SelectionCard.hoverOverlayOpacity * _overlay.value;
        return Container(
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(SelectionCard.radius),
            border: Border.all(
              color: Oklab.mix(tokens.border, hoverBorder, _card.value),
              width: SelectionCard.borderWidth,
            ),
            boxShadow: BoxShadow.lerpList(
              AppShadows.hidden(AppShadows.xl),
              AppShadows.xl,
              _card.value,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                SelectionCard.radius - SelectionCard.borderWidth,
              ),
              gradient: overlayOpacity > 0
                  ? widget.gradient.diagonal.scale(overlayOpacity)
                  : null,
            ),
            child: child,
          ),
        );
      },
      child: content,
    );

    return Entrance(
      fromOffset: SelectionCard.entranceOffset,
      delay: widget.delay,
      hoverScale: layout.hoverScale,
      tapScale: layout.tapScale,
      gesturesEnabled: !widget.disabled,
      child: MouseRegion(
        cursor: widget.disabled ? SystemMouseCursors.forbidden : widget.cursor,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: FocusableActionDetector(
          enabled: !widget.disabled,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _activate();
                return null;
              },
            ),
          },
          child: MergeSemantics(
            child: Semantics(
              button: true,
              enabled: !widget.disabled,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.disabled ? null : widget.onTap,
                child: card,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
