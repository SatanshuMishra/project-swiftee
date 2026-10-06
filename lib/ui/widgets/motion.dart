import 'dart:async';
import 'dart:math';

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';

final class MotionPose {
  const MotionPose({
    this.opacity = 1,
    this.offset = Offset.zero,
    this.scale = 1,
  });

  static const MotionPose rest = MotionPose();

  final double opacity;
  final Offset offset;
  final double scale;

  @override
  bool operator ==(Object other) =>
      other is MotionPose &&
      other.opacity == opacity &&
      other.offset == offset &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(opacity, offset, scale);
}

class Motion extends StatefulWidget {
  const Motion({
    required super.key,
    required this.child,
    this.initial = MotionPose.rest,
    this.exit = MotionPose.rest,
    this.delay = Duration.zero,
    this.exiting = false,
    this.onExited,
  });

  static const double restSpeed = 10;

  final Widget child;
  final MotionPose initial;
  final MotionPose exit;
  final Duration delay;
  final bool exiting;
  final VoidCallback? onExited;

  @override
  State<Motion> createState() => _MotionState();
}

class _MotionState extends State<Motion> with TickerProviderStateMixin {
  late final AnimationController _opacity = AnimationController.unbounded(
    vsync: this,
    value: widget.initial.opacity,
  );
  late final AnimationController _x = AnimationController.unbounded(
    vsync: this,
    value: widget.initial.offset.dx,
  );
  late final AnimationController _y = AnimationController.unbounded(
    vsync: this,
    value: widget.initial.offset.dy,
  );
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: widget.initial.scale,
  );
  late final Listenable _frame = Listenable.merge([_opacity, _x, _y, _scale]);

  @override
  void initState() {
    super.initState();
    if (widget.exiting) {
      _exit();
    } else {
      _animateTo(MotionPose.rest, widget.delay);
    }
  }

  @override
  void didUpdateWidget(Motion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exiting == widget.exiting) {
      return;
    }
    if (widget.exiting) {
      _exit();
    } else {
      _animateTo(MotionPose.rest, Duration.zero);
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _x.dispose();
    _y.dispose();
    _scale.dispose();
    super.dispose();
  }

  Future<void> _exit() async {
    await _animateTo(widget.exit, Duration.zero);
    if (mounted && widget.exiting) {
      widget.onExited?.call();
    }
  }

  Future<void> _animateTo(MotionPose target, Duration delay) {
    final delaySeconds = delay.inMicroseconds / Duration.microsecondsPerSecond;
    return Future.wait<void>([
      _opacity.animateWith(
        _DelayedSimulation(
          delaySeconds,
          _EasedTween(
            from: _opacity.value,
            to: target.opacity,
            seconds:
                AppMotion.defaultOpacityDuration.inMicroseconds /
                Duration.microsecondsPerSecond,
            curve: AppMotion.defaultOpacityCurve,
          ),
        ),
      ),
      _spring(_x, target.offset.dx, AppMotion.defaultTranslateSpring, delay),
      _spring(_y, target.offset.dy, AppMotion.defaultTranslateSpring, delay),
      _spring(
        _scale,
        target.scale,
        target.scale == 0
            ? AppMotion.defaultScaleToZeroSpring
            : AppMotion.defaultScaleSpring,
        delay,
      ),
    ]);
  }

  static TickerFuture _spring(
    AnimationController controller,
    double target,
    SpringDescription spring,
    Duration delay,
  ) {
    final start = controller.value;
    final delta = target - start;
    return controller.animateWith(
      _DelayedSimulation(
        delay.inMicroseconds / Duration.microsecondsPerSecond,
        SpringSimulation(
          spring,
          start,
          target,
          controller.velocity,
          tolerance: Tolerance(
            distance: delta.abs() < 5
                ? AppMotion.granularRestDelta
                : AppMotion.restDelta,
            velocity: Motion.restSpeed,
          ),
          snapToEnd: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _frame,
      builder: (context, child) {
        final scale = _scale.value;
        return Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(scale, scale, 1)
              ..setTranslationRaw(_x.value, _y.value, 0),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class MotionPresence extends StatefulWidget {
  const MotionPresence({super.key, this.child, this.spacing = 0});

  final Motion? child;
  final double spacing;

  @override
  State<MotionPresence> createState() => _MotionPresenceState();
}

class _MotionPresenceState extends State<MotionPresence> {
  late Motion? _shown = widget.child;
  bool _exiting = false;

  @override
  void didUpdateWidget(MotionPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.child;
    final shown = _shown;
    if (shown == null) {
      _shown = incoming;
      _exiting = false;
    } else if (incoming != null && incoming.key == shown.key) {
      _shown = incoming;
      _exiting = false;
    } else {
      _exiting = true;
    }
  }

  void _handleExited() {
    if (!mounted) {
      return;
    }
    setState(() {
      _shown = widget.child;
      _exiting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown == null) {
      return const SizedBox.shrink();
    }
    final motion = _exiting
        ? Motion(
            key: shown.key,
            initial: shown.initial,
            exit: shown.exit,
            delay: shown.delay,
            exiting: true,
            onExited: _handleExited,
            child: shown.child,
          )
        : shown;
    if (widget.spacing == 0) {
      return motion;
    }
    return Padding(
      padding: EdgeInsets.only(top: widget.spacing),
      child: motion,
    );
  }
}

final class _DelayedSimulation extends Simulation {
  _DelayedSimulation(this.delay, this.simulation)
    : super(tolerance: simulation.tolerance);

  final double delay;
  final Simulation simulation;

  @override
  double x(double time) =>
      time < delay ? simulation.x(0) : simulation.x(time - delay);

  @override
  double dx(double time) => time < delay ? 0 : simulation.dx(time - delay);

  @override
  bool isDone(double time) => time >= delay && simulation.isDone(time - delay);
}

final class _EasedTween extends Simulation {
  _EasedTween({
    required this.from,
    required this.to,
    required this.seconds,
    required this.curve,
  });

  final double from;
  final double to;
  final double seconds;
  final Curve curve;

  @override
  double x(double time) => time >= seconds
      ? to
      : from + (to - from) * curve.transform(max(0, time) / seconds);

  @override
  double dx(double time) => 0;

  @override
  bool isDone(double time) => time >= seconds;
}
