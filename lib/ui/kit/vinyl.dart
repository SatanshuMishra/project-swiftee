import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

@immutable
final class VinylStyle {
  const VinylStyle({
    required this.groove,
    required this.gap,
    required this.ringAlpha,
    required this.shadowOffset,
    required this.shadowBlur,
    required this.hole,
  });

  static const standard = VinylStyle(
    groove: 1,
    gap: 1.5,
    ringAlpha: 0.12,
    shadowOffset: 6,
    shadowBlur: 14,
    hole: true,
  );

  static const tile = VinylStyle(
    groove: 1,
    gap: 1.6,
    ringAlpha: 0.14,
    shadowOffset: 6,
    shadowBlur: 16,
    hole: false,
  );

  static const record = VinylStyle(
    groove: 1.5,
    gap: 1.7,
    ringAlpha: 0.14,
    shadowOffset: 14,
    shadowBlur: 34,
    hole: true,
  );

  final double groove;
  final double gap;
  final double ringAlpha;
  final double shadowOffset;
  final double shadowBlur;
  final bool hole;

  VinylStyle copyWith({
    double? groove,
    double? gap,
    double? ringAlpha,
    double? shadowOffset,
    double? shadowBlur,
    bool? hole,
  }) => VinylStyle(
    groove: groove ?? this.groove,
    gap: gap ?? this.gap,
    ringAlpha: ringAlpha ?? this.ringAlpha,
    shadowOffset: shadowOffset ?? this.shadowOffset,
    shadowBlur: shadowBlur ?? this.shadowBlur,
    hole: hole ?? this.hole,
  );

  @override
  bool operator ==(Object other) =>
      other is VinylStyle &&
      other.groove == groove &&
      other.gap == gap &&
      other.ringAlpha == ringAlpha &&
      other.shadowOffset == shadowOffset &&
      other.shadowBlur == shadowBlur &&
      other.hole == hole;

  @override
  int get hashCode =>
      Object.hash(groove, gap, ringAlpha, shadowOffset, shadowBlur, hole);
}

class VinylDisc extends StatelessWidget {
  const VinylDisc({
    super.key,
    required this.size,
    this.labelUrl,
    this.labelColor,
    this.labelFraction = 0.35,
    this.showLabelImage = true,
    this.style = VinylStyle.standard,
  });

  static const ringColor = Color(0xFFF5E5D4);
  static const double minHole = 6;
  static const double holeFraction = 0.032;

  final double size;
  final String? labelUrl;
  final Color? labelColor;
  final double labelFraction;
  final bool showLabelImage;
  final VinylStyle style;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final labelSize = size * labelFraction;
    final url = labelUrl;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            CssBoxShadow(
              color: tokens.shadow,
              offset: Offset(0, style.shadowOffset),
              blur: style.shadowBlur,
            ),
          ],
        ),
        child: CustomPaint(
          painter: _GroovePainter(
            ink: tokens.g1,
            base: tokens.g2,
            ring: ringColor.withValues(alpha: style.ringAlpha),
            style: style,
          ),
          child: Center(
            child: ClipOval(
              child: SizedBox.square(
                dimension: labelSize,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: labelColor ?? tokens.coral),
                    if (showLabelImage && url != null)
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    if (style.hole)
                      Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tokens.bg,
                          ),
                          child: SizedBox.square(
                            dimension: math.max(minHole, size * holeFraction),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroovePainter extends CustomPainter {
  const _GroovePainter({
    required this.ink,
    required this.base,
    required this.ring,
    required this.style,
  });

  final Color ink;
  final Color base;
  final Color ring;
  final VinylStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas
      ..clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      )
      ..drawCircle(center, radius, Paint()..color = base);
    final groove = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.groove;
    final period = style.groove + style.gap;
    canvas.drawCircle(center, style.groove, Paint()..color = ink);
    for (var inner = period; inner < radius; inner += period) {
      canvas.drawCircle(center, inner + style.groove / 2, groove);
    }
    canvas.drawCircle(
      center,
      radius - 0.5,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_GroovePainter oldDelegate) =>
      oldDelegate.ink != ink ||
      oldDelegate.base != base ||
      oldDelegate.ring != ring ||
      oldDelegate.style != style;
}

class AlbumSleeve extends StatelessWidget {
  const AlbumSleeve({
    super.key,
    required this.size,
    this.coverUrl,
    this.placeholder,
    this.radius = 3,
  });

  static const double shadowOffset = 10;
  static const double shadowBlur = 24;

  final double size;
  final String? coverUrl;
  final Color? placeholder;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final corners = BorderRadius.circular(radius);
    final url = coverUrl;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: corners,
          boxShadow: [
            CssBoxShadow(
              color: tokens.shadow,
              offset: const Offset(0, shadowOffset),
              blur: shadowBlur,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: corners,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: placeholder ?? tokens.card),
              if (url != null)
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
