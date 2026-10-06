import 'dart:async';

import 'package:flutter/material.dart';
import 'package:swiftie_quiz/services/window/window_controls.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

enum CaptionGlyph {
  minimize('Minimise'),
  maximize('Maximise'),
  restore('Restore'),
  close('Close');

  const CaptionGlyph(this.label);

  final String label;
}

class CaptionButtons extends StatelessWidget {
  const CaptionButtons({
    super.key,
    required this.controls,
    required this.height,
    required this.maximized,
  });

  final WindowControls controls;
  final double height;
  final bool maximized;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CaptionButton(
        glyph: CaptionGlyph.minimize,
        height: height,
        onPressed: () => unawaited(controls.minimize()),
      ),
      CaptionButton(
        glyph: maximized ? CaptionGlyph.restore : CaptionGlyph.maximize,
        height: height,
        onPressed: () => unawaited(controls.toggleMaximize()),
      ),
      CaptionButton(
        glyph: CaptionGlyph.close,
        height: height,
        onPressed: () => unawaited(controls.close()),
      ),
    ],
  );
}

class CaptionButton extends StatefulWidget {
  const CaptionButton({
    super.key,
    required this.glyph,
    required this.height,
    required this.onPressed,
  });

  static const double width = 46;
  static const double glyphSize = 10;
  static const double focusRingWidth = 2;
  static const Color closeHoverInk = Color(0xFFFFFFFF);

  final CaptionGlyph glyph;
  final double height;
  final VoidCallback onPressed;

  @override
  State<CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<CaptionButton> {
  bool _hovered = false;
  bool _focused = false;

  void _setHovered(bool hovered) {
    if (hovered != _hovered) {
      setState(() => _hovered = hovered);
    }
  }

  void _setFocused(bool focused) {
    if (focused != _focused) {
      setState(() => _focused = focused);
    }
  }

  Object? _activate(Intent _) {
    widget.onPressed();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final closing = widget.glyph == CaptionGlyph.close;
    final hoverFill = closing ? BrandColors.closeHover : tokens.hover;
    final hoverInk = closing ? CaptionButton.closeHoverInk : tokens.fg;
    return FocusableActionDetector(
      onShowFocusHighlight: _setFocused,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: _activate),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
          onInvoke: _activate,
        ),
      },
      child: MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: Semantics(
          container: true,
          button: true,
          label: widget.glyph.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _hovered ? 1 : 0),
              duration: AppMotion.duration(context, AppMotion.colorShift),
              curve: AppMotion.colorShiftCurve,
              builder: (context, hover, _) => DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.lerp(
                    hoverFill.withValues(alpha: 0),
                    hoverFill,
                    hover,
                  ),
                ),
                position: DecorationPosition.background,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: _focused
                      ? BoxDecoration(
                          border: Border.all(
                            color: tokens.coral,
                            width: CaptionButton.focusRingWidth,
                          ),
                        )
                      : const BoxDecoration(),
                  child: SizedBox(
                    width: CaptionButton.width,
                    height: widget.height,
                    child: Center(
                      child: CaptionGlyphIcon(
                        glyph: widget.glyph,
                        color: Color.lerp(tokens.fg, hoverInk, hover)!,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CaptionGlyphIcon extends StatelessWidget {
  const CaptionGlyphIcon({super.key, required this.glyph, required this.color});

  final CaptionGlyph glyph;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(CaptionButton.glyphSize),
    painter: _CaptionGlyphPainter(glyph: glyph, color: color),
  );
}

class _CaptionGlyphPainter extends CustomPainter {
  const _CaptionGlyphPainter({required this.glyph, required this.color});

  static const double stroke = 1;
  static const double cornerRadius = 1.5;
  static const double restoreOffset = 2;

  final CaptionGlyph glyph;
  final Color color;

  Paint get _line => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke;

  RRect _outline(Rect box) => RRect.fromRectAndRadius(
    box.deflate(stroke / 2),
    const Radius.circular(cornerRadius),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    switch (glyph) {
      case CaptionGlyph.minimize:
        canvas.drawRect(
          Rect.fromLTWH(
            0,
            ((size.height - stroke) / 2).floorToDouble(),
            size.width,
            stroke,
          ),
          Paint()..color = color,
        );
      case CaptionGlyph.maximize:
        canvas.drawRRect(_outline(box), _line);
      case CaptionGlyph.restore:
        final front = _outline(
          Rect.fromLTRB(
            0,
            restoreOffset,
            size.width - restoreOffset,
            size.height,
          ),
        );
        final back = Rect.fromLTRB(
          restoreOffset,
          0,
          size.width,
          size.height - restoreOffset,
        ).deflate(stroke / 2);
        const corner = Radius.circular(cornerRadius);
        canvas
          ..drawRRect(front, _line)
          ..drawPath(
            Path()
              ..moveTo(back.left, front.top)
              ..lineTo(back.left, back.top + cornerRadius)
              ..arcToPoint(
                Offset(back.left + cornerRadius, back.top),
                radius: corner,
              )
              ..lineTo(back.right - cornerRadius, back.top)
              ..arcToPoint(
                Offset(back.right, back.top + cornerRadius),
                radius: corner,
              )
              ..lineTo(back.right, back.bottom - cornerRadius)
              ..arcToPoint(
                Offset(back.right - cornerRadius, back.bottom),
                radius: corner,
              )
              ..lineTo(front.right, back.bottom),
            _line,
          );
      case CaptionGlyph.close:
        canvas
          ..drawLine(box.topLeft, box.bottomRight, _line)
          ..drawLine(box.topRight, box.bottomLeft, _line);
    }
  }

  @override
  bool shouldRepaint(_CaptionGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
