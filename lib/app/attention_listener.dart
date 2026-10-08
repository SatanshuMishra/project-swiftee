import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/state/attention_controller.dart';

class AttentionListener extends ConsumerStatefulWidget {
  const AttentionListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AttentionListener> createState() => _AttentionListenerState();
}

class _AttentionListenerState extends ConsumerState<AttentionListener>
    with WidgetsBindingObserver {
  late final AttentionController _attention;

  @override
  void initState() {
    super.initState();
    _attention = ref.read(attentionProvider.notifier)..track();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_keyPressed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (WidgetsBinding.instance.lifecycleState case final state?) {
          didChangeAppLifecycleState(state);
        }
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_keyPressed);
    WidgetsBinding.instance.removeObserver(this);
    _attention.untrack();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _attention.focus(focused: state == AppLifecycleState.resumed);

  void _input() => _attention.input();

  void _press() => _attention.press();

  bool _keyPressed(KeyEvent event) {
    _press();
    return false;
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _press(),
    onPointerMove: (_) => _input(),
    onPointerHover: (_) => _input(),
    onPointerSignal: (_) => _input(),
    onPointerPanZoomStart: (_) => _input(),
    child: widget.child,
  );
}
