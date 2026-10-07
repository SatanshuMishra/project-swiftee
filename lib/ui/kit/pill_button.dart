import 'package:flutter/material.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

typedef PressState = ({bool hovered, bool pressed, bool focused, bool enabled});

typedef PressableBuilder = Widget Function(
  BuildContext context,
  PressState state,
);

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onPressed,
    required this.builder,
    this.enabled = true,
    this.focusRadius = BorderRadius.zero,
    this.selected,
    this.checked,
    this.semanticLabel,
    this.autofocus = false,
    this.focusNode,
  });

  static const double focusRingWidth = 2;
  static const double focusRingGap = 2;

  final VoidCallback? onPressed;
  final PressableBuilder builder;
  final bool enabled;
  final BorderRadius focusRadius;
  final bool? selected;
  final bool? checked;
  final String? semanticLabel;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.enabled && widget.onPressed != null;

  void _activate() {
    if (_enabled) {
      widget.onPressed!();
    }
  }

  void _setHovered(bool hovered) {
    if (_hovered != hovered) {
      setState(() => _hovered = hovered);
    }
  }

  void _setPressed(bool pressed) {
    if (_pressed != pressed) {
      setState(() => _pressed = pressed);
    }
  }

  void _setFocused(bool focused) {
    if (_focused != focused) {
      setState(() => _focused = focused);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final state = (
      hovered: enabled && _hovered,
      pressed: enabled && _pressed,
      focused: enabled && _focused,
      enabled: enabled,
    );
    final ring = state.focused
        ? BoxDecoration(
            borderRadius: widget.focusRadius,
            border: Border.all(
              color: AppTokens.of(context).coral,
              width: Pressable.focusRingWidth,
              strokeAlign:
                  BorderSide.strokeAlignOutside +
                  2 * Pressable.focusRingGap / Pressable.focusRingWidth,
            ),
          )
        : const BoxDecoration();
    return FocusableActionDetector(
      enabled: enabled,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: _setFocused,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: Semantics(
          button: widget.checked == null,
          enabled: enabled,
          selected: widget.selected,
          checked: widget.checked,
          label: widget.semanticLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => _setPressed(true) : null,
            onTapUp: enabled ? (_) => _setPressed(false) : null,
            onTapCancel: enabled ? () => _setPressed(false) : null,
            onTap: enabled ? _activate : null,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: ring,
              child: widget.builder(context, state),
            ),
          ),
        ),
      ),
    );
  }
}

enum PillKind { coral, solid, outline, quiet, danger }

enum PillSize {
  large(
    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 26),
    fontSize: 16,
    lineHeight: 20,
  ),
  regular(
    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 18),
    fontSize: 14,
    lineHeight: 20,
  );

  const PillSize({
    required this.padding,
    required this.fontSize,
    required this.lineHeight,
  });

  final EdgeInsets padding;
  final double fontSize;
  final double lineHeight;
}

class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = PillKind.coral,
    this.size = PillSize.regular,
    this.enabled = true,
    this.leading,
    this.autofocus = false,
  });

  static const double disabledOpacity = 0.45;
  static const double leadingGap = 8;
  static const radius = BorderRadius.all(Radius.circular(999));

  final String label;
  final VoidCallback? onPressed;
  final PillKind kind;
  final PillSize size;
  final bool enabled;
  final Widget? leading;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final active = enabled && onPressed != null;
    final colorShift = AppMotion.duration(context, AppMotion.colorShift);
    final lift = AppMotion.duration(context, AppMotion.hoverLift);
    return AnimatedOpacity(
      opacity: active ? 1 : disabledOpacity,
      duration: AppMotion.duration(context, AppMotion.selectionShift),
      curve: Curves.ease,
      child: Pressable(
        onPressed: onPressed,
        enabled: enabled,
        autofocus: autofocus,
        focusRadius: radius,
        builder: (context, state) {
          final (fill, ink, weight) = switch (kind) {
            PillKind.coral => (tokens.coral, tokens.onCoral, FontWeight.w600),
            PillKind.solid => (tokens.btn, tokens.onBtn, FontWeight.w600),
            PillKind.danger => (tokens.rose, tokens.bg, FontWeight.w600),
            PillKind.outline => (
              state.hovered ? tokens.hover : tokens.hover.withValues(alpha: 0),
              tokens.fg,
              FontWeight.w400,
            ),
            PillKind.quiet => (
              state.hovered ? tokens.hover : tokens.hover.withValues(alpha: 0),
              state.hovered ? tokens.fg : tokens.mut,
              FontWeight.w400,
            ),
          };
          return TweenAnimationBuilder<double>(
            tween: Tween(
              end: state.hovered && !state.pressed
                  ? -AppMotion.hoverLiftOffset
                  : 0,
            ),
            duration: lift,
            curve: AppMotion.hoverLiftCurve,
            builder: (context, dy, child) =>
                Transform.translate(offset: Offset(0, dy), child: child),
            child: AnimatedScale(
              scale: state.pressed ? AppMotion.pressScale : 1,
              duration: lift,
              curve: AppMotion.hoverLiftCurve,
              child: AnimatedContainer(
                duration: colorShift,
                curve: AppMotion.colorShiftCurve,
                padding: size.padding,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: radius,
                  border: kind == PillKind.outline
                      ? Border.all(color: tokens.line2)
                      : null,
                ),
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: ink),
                  duration: colorShift,
                  curve: AppMotion.colorShiftCurve,
                  builder: (context, color, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leading case final leading?) ...[
                        IconTheme.merge(
                          data: IconThemeData(color: color),
                          child: DefaultTextStyle.merge(
                            style: TextStyle(color: color),
                            child: leading,
                          ),
                        ),
                        const SizedBox(width: leadingGap),
                      ],
                      Text(
                        label,
                        style: AppType.sized(
                          size.fontSize,
                          size.lineHeight,
                          weight: weight,
                        ).copyWith(color: color),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
