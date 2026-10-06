import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';

class ScreenEnter extends StatefulWidget {
  const ScreenEnter({super.key, required this.child});

  final Widget child;

  @override
  State<ScreenEnter> createState() => _ScreenEnterState();
}

class _ScreenEnterState extends State<ScreenEnter>
    with SingleTickerProviderStateMixin {
  static final double _fadeShare =
      AppMotion.screenFade.inMicroseconds / AppMotion.screenRise.inMicroseconds;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.screenRise,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Interval(0, _fadeShare, curve: AppMotion.screenFadeCurve),
  );
  late final Animation<double> _rise = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.screenRiseCurve,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: AnimatedBuilder(
        animation: _rise,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, AppMotion.screenRiseOffset * (1 - _rise.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
