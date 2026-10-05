import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';

class LoadingGate extends StatefulWidget {
  const LoadingGate({
    super.key,
    required this.loading,
    required this.child,
    this.size = CatLoaderSize.lg,
    this.label,
    this.labelStyle = CatLoader.defaultLabelStyle,
    this.onReady,
  });

  static const Duration transition = Duration(milliseconds: 300);
  static const double exitScale = 0.95;

  final bool loading;
  final Widget child;
  final CatLoaderSize size;
  final String? label;
  final TextStyle labelStyle;
  final VoidCallback? onReady;

  @override
  State<LoadingGate> createState() => _LoadingGateState();
}

class _LoadingGateState extends State<LoadingGate>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: LoadingGate.transition,
  );
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: LoadingGate.transition,
  )..addStatusListener(_onExitStatus);
  late final Animation<double> _entered = CurvedAnimation(
    parent: _enter,
    curve: Curves.easeInOut,
  );
  late final Animation<double> _exited = CurvedAnimation(
    parent: _exit,
    curve: Curves.easeInOut,
  );
  late bool _showContent = !widget.loading;

  @override
  void initState() {
    super.initState();
    if (widget.loading) {
      _enter.forward();
    }
  }

  @override
  void didUpdateWidget(LoadingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading == oldWidget.loading) return;
    if (!widget.loading) {
      _enter.stop();
      _exit.forward();
      return;
    }
    if (_showContent || _exit.isCompleted) {
      _showContent = false;
      _exit.value = 0;
      _enter.forward(from: 0);
    } else {
      _exit.reverse();
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _exit.dispose();
    super.dispose();
  }

  void _onExitStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || widget.loading) return;
    setState(() => _showContent = true);
    widget.onReady?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_showContent) return widget.child;
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_entered, _exited]),
        builder: (context, loader) => Opacity(
          opacity: _entered.value * (1 - _exited.value),
          child: Transform.scale(
            scale: 1 - (1 - LoadingGate.exitScale) * _exited.value,
            child: loader,
          ),
        ),
        child: CatLoader(
          size: widget.size,
          label: widget.label,
          labelStyle: widget.labelStyle,
        ),
      ),
    );
  }
}
