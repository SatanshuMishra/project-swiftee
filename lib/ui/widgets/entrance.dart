import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';

class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.fromOffset = Offset.zero,
    this.fromOpacity = 0,
    this.fromScale = 1,
    this.delay = Duration.zero,
    this.spring = AppMotion.spring,
    this.hoverScale,
    this.tapScale,
    this.gestureSpring,
    this.gesturesEnabled = true,
  });

  final Widget child;
  final Offset fromOffset;
  final double fromOpacity;
  final double fromScale;
  final Duration delay;
  final SpringDescription spring;
  final double? hoverScale;
  final double? tapScale;
  final SpringDescription? gestureSpring;
  final bool gesturesEnabled;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with TickerProviderStateMixin {
  late final _SpringValue _x = _SpringValue(this, widget.fromOffset.dx);
  late final _SpringValue _y = _SpringValue(this, widget.fromOffset.dy);
  late final _SpringValue _opacity = _SpringValue(this, widget.fromOpacity);
  late final _SpringValue _scale = _SpringValue(this, widget.fromScale);
  late final Listenable _frame = Listenable.merge([
    _x.controller,
    _y.controller,
    _opacity.controller,
    _scale.controller,
  ]);

  bool _hovered = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _x.animateTo(0, widget.spring, widget.delay);
    _y.animateTo(0, widget.spring, widget.delay);
    _opacity.animateTo(1, widget.spring, widget.delay);
    _updateScale();
  }

  @override
  void didUpdateWidget(Entrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gesturesEnabled != widget.gesturesEnabled ||
        oldWidget.hoverScale != widget.hoverScale ||
        oldWidget.tapScale != widget.tapScale) {
      _updateScale();
    }
  }

  @override
  void dispose() {
    _x.controller.dispose();
    _y.controller.dispose();
    _opacity.controller.dispose();
    _scale.controller.dispose();
    super.dispose();
  }

  double? get _gestureTarget {
    if (!widget.gesturesEnabled) {
      return null;
    }
    if (_pressed && widget.tapScale != null) {
      return widget.tapScale;
    }
    if (_hovered && widget.hoverScale != null) {
      return widget.hoverScale;
    }
    return null;
  }

  void _updateScale() {
    final gestureTarget = _gestureTarget;
    final ownSpring = gestureTarget == null ? null : widget.gestureSpring;
    _scale.animateTo(
      gestureTarget ?? 1,
      ownSpring ?? widget.spring,
      ownSpring == null ? widget.delay : Duration.zero,
    );
  }

  void _setHovered(bool hovered) {
    if (_hovered == hovered) {
      return;
    }
    _hovered = hovered;
    _updateScale();
  }

  void _setPressed(bool pressed) {
    if (_pressed == pressed) {
      return;
    }
    _pressed = pressed;
    _updateScale();
  }

  void _handlePointerDown(PointerDownEvent event) {
    final isPrimary =
        event.kind != PointerDeviceKind.mouse ||
        event.buttons == kPrimaryMouseButton;
    if (isPrimary) {
      _setPressed(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget target = widget.child;
    if (widget.hoverScale != null) {
      target = MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: target,
      );
    }
    if (widget.tapScale != null) {
      target = Listener(
        onPointerDown: _handlePointerDown,
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: target,
      );
    }
    return AnimatedBuilder(
      animation: _frame,
      builder: (context, child) {
        final scale = _scale.controller.value;
        return Opacity(
          opacity: _opacity.controller.value.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(scale, scale, 1)
              ..setTranslationRaw(_x.controller.value, _y.controller.value, 0),
            child: child,
          ),
        );
      },
      child: target,
    );
  }
}

class _SpringValue {
  _SpringValue(TickerProvider vsync, double initial)
    : controller = AnimationController.unbounded(vsync: vsync, value: initial),
      _target = initial;

  final AnimationController controller;
  double _target;

  void animateTo(double target, SpringDescription spring, Duration delay) {
    if (target == _target) {
      return;
    }
    _target = target;
    final start = controller.value;
    controller.animateWith(
      _DelayedSimulation(
        delay: delay.inMicroseconds / Duration.microsecondsPerSecond,
        simulation: SpringSimulation(
          spring,
          start,
          target,
          controller.velocity,
          tolerance: AppMotion.restTolerance(target - start),
          snapToEnd: true,
        ),
      ),
    );
  }
}

class _DelayedSimulation extends Simulation {
  _DelayedSimulation({required this.delay, required this.simulation})
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
