import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';

class Bead extends StatefulWidget {
  const Bead({
    super.key,
    required this.color,
    this.size = 12,
    this.pop = false,
  });

  static const ringColor = Color.from(alpha: 0.12, red: 0, green: 0, blue: 0);
  static const double ringWidth = 1;

  final Color color;
  final double size;
  final bool pop;

  @override
  State<Bead> createState() => _BeadState();
}

class _BeadState extends State<Bead> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.beadPop,
    value: 1,
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0,
        end: AppMotion.beadPopPeak,
      ).chain(CurveTween(curve: AppMotion.beadPopCurve)),
      weight: AppMotion.beadPopPeakAt,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: AppMotion.beadPopPeak,
        end: 1,
      ).chain(CurveTween(curve: AppMotion.beadPopCurve)),
      weight: 1 - AppMotion.beadPopPeakAt,
    ),
  ]).animate(_controller);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (widget.pop) {
      _popIn();
    }
  }

  @override
  void didUpdateWidget(Bead oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pop && !oldWidget.pop) {
      _popIn();
    }
  }

  void _popIn() {
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: SizedBox.square(
        dimension: widget.size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            border: Border.all(
              color: Bead.ringColor,
              width: Bead.ringWidth,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
        ),
      ),
    );
  }
}
