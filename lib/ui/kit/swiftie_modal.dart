import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/ui/kit/modal_stack.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

class SwiftieModal extends ConsumerStatefulWidget {
  const SwiftieModal({
    super.key,
    required this.child,
    this.maxWidth = 440,
    this.onDismiss,
    this.bare = false,
    this.blur = 4,
  });

  static const panelPadding = EdgeInsets.fromLTRB(26, 26, 26, 22);
  static const radius = BorderRadius.all(Radius.circular(16));
  static const double scrimPadding = 24;
  static const double barePadding = 20;
  static const double shadowOffset = 24;
  static const double shadowBlur = 60;

  final Widget child;
  final double maxWidth;
  final VoidCallback? onDismiss;
  final bool bare;
  final double blur;

  @override
  ConsumerState<SwiftieModal> createState() => _SwiftieModalState();
}

class _SwiftieModalState extends ConsumerState<SwiftieModal>
    with SingleTickerProviderStateMixin {
  final Object _key = Object();
  final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'SwiftieModal');
  late final ModalStack _stack = ref.read(modalStackProvider.notifier);
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: AppMotion.modalRise,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _enter,
    curve: AppMotion.modalRiseCurve,
  );
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final stack = _stack;
    final key = _key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        stack.push(key);
        if (!_scope.hasFocus) {
          _scope.requestFocus();
        }
      }
    });
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (AppMotion.reduced(context)) {
      _enter.value = 1;
    } else {
      _enter.forward();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _scope.dispose();
    final stack = _stack;
    final key = _key;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => stack.remove(key))
      ..ensureVisualUpdate();
    _enter.dispose();
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    final open = ref.read(modalStackProvider);
    if (open.isEmpty || open.last != _key) {
      return false;
    }
    widget.onDismiss?.call();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final content = widget.bare
        ? widget.child
        : DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.panel,
              borderRadius: SwiftieModal.radius,
              border: Border.all(color: tokens.line2),
              boxShadow: [
                CssBoxShadow(
                  color: tokens.shadow,
                  offset: const Offset(0, SwiftieModal.shadowOffset),
                  blur: SwiftieModal.shadowBlur,
                ),
              ],
            ),
            child: Padding(
              padding: SwiftieModal.panelPadding,
              child: widget.child,
            ),
          );
    return Material(
      type: MaterialType.transparency,
      child: FadeTransition(
        opacity: _progress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismiss,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.blur,
                    sigmaY: widget.blur,
                  ),
                  child: ColoredBox(color: tokens.scrim),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(
                widget.bare
                    ? SwiftieModal.barePadding
                    : SwiftieModal.scrimPadding,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: widget.maxWidth),
                  child: SizedBox(
                    width: double.infinity,
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(
                          0,
                          AppMotion.modalRiseOffset * (1 - _progress.value),
                        ),
                        child: child,
                      ),
                      child: FocusScope(node: _scope, child: content),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
