import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

abstract final class AppMotion {
  static const spring = SpringDescription(mass: 1, stiffness: 300, damping: 30);

  static const defaultTranslateSpring = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 25,
  );

  static const defaultScaleSpring = SpringDescription(
    mass: 1,
    stiffness: 550,
    damping: 30,
  );

  static final defaultScaleToZeroSpring = SpringDescription(
    mass: 1,
    stiffness: 550,
    damping: 2 * math.sqrt(550),
  );

  static const defaultOpacityDuration = Duration(milliseconds: 300);
  static const defaultOpacityCurve = Cubic(0.25, 0.1, 0.35, 1);

  static const tweenEaseInOut = Cubic(0.42, 0, 0.58, 1);

  static const cssTransitionDuration = Duration(milliseconds: 150);
  static const cssTransitionCurve = Cubic(0.4, 0, 0.2, 1);

  static const cardTransitionDuration = Duration(milliseconds: 300);

  static const granularRestDelta = 0.005;
  static const granularRestSpeed = 0.01;
  static const restDelta = 0.5;
  static const restSpeed = 2.0;

  static Tolerance restTolerance(double initialDelta) => initialDelta.abs() < 5
      ? const Tolerance(
          distance: granularRestDelta,
          velocity: granularRestSpeed,
        )
      : const Tolerance(distance: restDelta, velocity: restSpeed);
}
