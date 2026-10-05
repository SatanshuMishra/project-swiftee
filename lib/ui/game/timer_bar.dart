import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

class TimerBar extends StatefulWidget {
  const TimerBar({
    super.key,
    required this.duration,
    required this.onExpire,
    required this.active,
  });

  static const Duration tickInterval = Duration(milliseconds: 100);
  static const double tickSeconds = 0.1;
  static const double urgentFraction = 0.3;
  static const double barHeight = 8;
  static const double labelGap = 4;

  final int duration;
  final VoidCallback onExpire;
  final bool active;

  @override
  State<TimerBar> createState() => _TimerBarState();
}

class _TimerBarState extends State<TimerBar> {
  late double _remaining = widget.duration.toDouble();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _start();
    }
  }

  @override
  void didUpdateWidget(TimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _remaining = widget.duration.toDouble();
    }
    if (oldWidget.active != widget.active) {
      _stop();
      if (widget.active) {
        _start();
      }
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _start() {
    _ticker = Timer.periodic(TimerBar.tickInterval, _tick);
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick(Timer ticker) {
    final next = _remaining - TimerBar.tickSeconds;
    if (next <= 0) {
      _stop();
      setState(() => _remaining = 0);
      widget.onExpire();
      return;
    }
    setState(() => _remaining = next);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final duration = widget.duration;
    final fraction = duration > 0
        ? (_remaining / duration).clamp(0.0, 1.0)
        : 0.0;
    final urgent = _remaining <= duration * TimerBar.urgentFraction;
    const radius = BorderRadius.all(Radius.circular(TimerBar.barHeight / 2));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            height: TimerBar.barHeight,
            width: double.infinity,
            child: ColoredBox(
              color: tokens.muted,
              child: AnimatedFractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction,
                heightFactor: 1,
                duration: AppMotion.cssTransitionDuration,
                curve: AppMotion.cssTransitionCurve,
                child: AnimatedContainer(
                  duration: AppMotion.cssTransitionDuration,
                  curve: AppMotion.cssTransitionCurve,
                  decoration: BoxDecoration(
                    color: urgent ? tokens.destructive : tokens.primary,
                    borderRadius: radius,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: TimerBar.labelGap),
        Text(
          '${_remaining.ceil()}s remaining',
          style: AppText.sm.copyWith(color: tokens.mutedForeground),
        ),
      ],
    );
  }
}
