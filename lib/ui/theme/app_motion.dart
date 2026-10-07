import 'package:flutter/widgets.dart';

abstract final class AppMotion {
  static const spring = SpringDescription(mass: 1, stiffness: 300, damping: 30);

  static const granularRestDelta = 0.005;
  static const granularRestSpeed = 0.01;
  static const restDelta = 0.5;
  static const restSpeed = 2.0;

  static const screenFade = Duration(milliseconds: 280);
  static const Curve screenFadeCurve = Curves.ease;
  static const screenRise = Duration(milliseconds: 400);
  static const screenRiseCurve = Cubic(0.2, 0.8, 0.2, 1);
  static const double screenRiseOffset = 10;

  static const hoverLift = Duration(milliseconds: 200);
  static const hoverLiftCurve = Cubic(0.34, 1.56, 0.64, 1);
  static const double hoverLiftOffset = 1;
  static const double pressScale = 0.97;

  static const colorShift = Duration(milliseconds: 150);
  static const Curve colorShiftCurve = Curves.ease;
  static const selectionShift = Duration(milliseconds: 200);

  static const rowHoverPad = Duration(milliseconds: 250);
  static const rowHoverPadCurve = Cubic(0.2, 0.8, 0.2, 1);
  static const double rowHoverPadOffset = 8;

  static const recordFlip = Duration(milliseconds: 550);
  static const recordFlipCurve = Cubic(0.4, 0, 0.2, 1);
  static const double discDegreesPerMs = 0.2;

  static const beadPop = Duration(milliseconds: 450);
  static const beadPopCurve = Cubic(0.34, 1.56, 0.64, 1);
  static const double beadPopPeak = 1.25;
  static const double beadPopPeakAt = 0.7;

  static const quackBurst = Duration(milliseconds: 1300);

  static const misuRise = Duration(milliseconds: 450);
  static const misuRiseCurve = Cubic(0.34, 1.3, 0.64, 1);
  static const misuBubbleDelay = Duration(milliseconds: 120);
  static const misuStay = Duration(milliseconds: 4200);
  static const misuStayLong = Duration(milliseconds: 7000);

  static const toastSlide = Duration(milliseconds: 350);
  static const toastSlideCurve = Cubic(0.2, 0.8, 0.2, 1);
  static const double toastSlideOffset = 24;
  static const double toastSpacing = 84;
  static const toastStay = Duration(seconds: 4);

  static const modalRise = Duration(milliseconds: 200);
  static const Curve modalRiseCurve = Curves.ease;
  static const double modalRiseOffset = 8;

  static const themeFade = Duration(milliseconds: 300);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ??
      View.maybeOf(context)
          ?.platformDispatcher
          .accessibilityFeatures
          .disableAnimations ??
      false;

  static Duration duration(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;

  static Tolerance restTolerance(double initialDelta) => initialDelta.abs() < 5
      ? const Tolerance(
          distance: granularRestDelta,
          velocity: granularRestSpeed,
        )
      : const Tolerance(distance: restDelta, velocity: restSpeed);
}
