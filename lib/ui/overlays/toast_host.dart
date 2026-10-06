import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/state/toast_controller.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

final toastStackProvider = NotifierProvider<ToastStack, List<Object>>(
  ToastStack.new,
);

class ToastStack extends Notifier<List<Object>> {
  @override
  List<Object> build() => const [];

  void add(Object slot) {
    if (!ref.mounted || state.contains(slot)) {
      return;
    }
    state = List.unmodifiable([...state, slot]);
  }

  void remove(Object slot) {
    if (!ref.mounted || !state.contains(slot)) {
      return;
    }
    state = List.unmodifiable([
      for (final shown in state)
        if (shown != slot) shown,
    ]);
  }
}

class ToastSlot extends StatelessWidget {
  const ToastSlot({super.key, required this.index, required this.child});

  static const double inset = 16;
  static const double width = 300;

  static double topFor(int index) =>
      inset + math.max(0, index) * AppMotion.toastSpacing;

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Positioned(top: topFor(index), right: inset, width: width, child: child);
}

class ToastMotion extends StatelessWidget {
  const ToastMotion({super.key, required this.shown, required this.child});

  static const Duration fade = Duration(milliseconds: 300);
  static const Curve fadeCurve = Curves.ease;

  final bool shown;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return IgnorePointer(
      ignoring: !shown,
      child: ExcludeFocus(
        excluding: !shown,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: shown ? 1 : 0),
          duration: reduced ? Duration.zero : fade,
          curve: fadeCurve,
          builder: (context, opacity, child) =>
              Opacity(opacity: opacity, child: child),
          child: TweenAnimationBuilder<double>(
            tween: Tween(
              begin: AppMotion.toastSlideOffset,
              end: shown ? 0 : AppMotion.toastSlideOffset,
            ),
            duration: reduced ? Duration.zero : AppMotion.toastSlide,
            curve: AppMotion.toastSlideCurve,
            builder: (context, dx, child) =>
                Transform.translate(offset: Offset(dx, 0), child: child),
            child: child,
          ),
        ),
      ),
    );
  }
}

class ToastCard extends StatelessWidget {
  const ToastCard({
    super.key,
    required this.title,
    required this.onDismiss,
    this.kicker,
    this.sub,
    this.leading,
    this.onTap,
  });

  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 12,
  );
  static const double radius = 14;
  static const double gap = 12;
  static const Offset shadowOffset = Offset(0, 12);
  static const double shadowBlur = 32;
  static final TextStyle kickerStyle = AppType.sized(
    11,
    14,
    weight: FontWeight.w600,
  );
  static final TextStyle titleStyle = AppType.display(20, height: 24 / 20);
  static const TextStyle subStyle = AppType.caption;

  final String title;
  final VoidCallback onDismiss;
  final String? kicker;
  final String? sub;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: const BorderRadius.all(Radius.circular(radius)),
        border: Border.all(color: tokens.line2),
        boxShadow: [
          CssBoxShadow(
            color: tokens.shadow,
            offset: shadowOffset,
            blur: shadowBlur,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            spacing: gap,
            children: [
              ?leading,
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (kicker case final kicker?)
                      Text(
                        kicker,
                        style: kickerStyle.copyWith(color: tokens.coralT),
                      ),
                    Text(title, style: titleStyle.copyWith(color: tokens.fg)),
                    if (sub case final sub?)
                      Text(
                        sub,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: subStyle.copyWith(color: tokens.mut),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: ToastCloseButton.size),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: ToastCloseButton(onPressed: onDismiss),
          ),
        ],
      ),
    );
    final tap = onTap;
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        container: true,
        role: SemanticsRole.status,
        child: tap == null
            ? card
            : MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: tap,
                  child: card,
                ),
              ),
      ),
    );
  }
}

class ToastCloseButton extends StatelessWidget {
  const ToastCloseButton({super.key, required this.onPressed});

  static const double size = 24;
  static const BorderRadius radius = BorderRadius.all(Radius.circular(6));
  static const String glyph = '✕';
  static const String label = 'Dismiss';
  static final TextStyle style = AppType.sized(13, 18);

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Semantics(
      container: true,
      child: Pressable(
        onPressed: onPressed,
        semanticLabel: label,
        focusRadius: radius,
        builder: (context, state) => DecoratedBox(
          decoration: BoxDecoration(
            color: state.hovered ? tokens.hover : null,
            borderRadius: radius,
          ),
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: ExcludeSemantics(
                child: Text(
                  glyph,
                  style: style.copyWith(
                    color: state.hovered ? tokens.fg : tokens.mut,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ToastHost extends ConsumerStatefulWidget {
  const ToastHost({super.key});

  @override
  ConsumerState<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends ConsumerState<ToastHost> {
  final Object _slot = Object();
  late final ToastStack _stack;
  String? _message;
  bool _leaving = false;
  bool _reduced = false;
  Timer? _removal;

  @override
  void initState() {
    super.initState();
    _stack = ref.read(toastStackProvider.notifier);
    final stack = _stack;
    final slot = _slot;
    _message = ref.read(toastControllerProvider);
    if (_message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _message != null) {
          stack.add(slot);
        }
      });
    }
    ref.listenManual(toastControllerProvider, (_, message) => _sync(message));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = AppMotion.reduced(context);
  }

  @override
  void dispose() {
    _removal?.cancel();
    final stack = _stack;
    final slot = _slot;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => stack.remove(slot))
      ..ensureVisualUpdate();
    super.dispose();
  }

  void _sync(String? message) {
    if (message != null) {
      _removal?.cancel();
      _removal = null;
      _stack.add(_slot);
      setState(() {
        _message = message;
        _leaving = false;
      });
      return;
    }
    if (_message == null || _leaving) {
      return;
    }
    if (_reduced) {
      _remove();
      return;
    }
    setState(() => _leaving = true);
    _removal = Timer(ToastMotion.fade, _remove);
  }

  void _remove() {
    _removal = null;
    _stack.remove(_slot);
    setState(() {
      _message = null;
      _leaving = false;
    });
  }

  void _dismiss() => ref.read(toastControllerProvider.notifier).dismiss();

  @override
  Widget build(BuildContext context) {
    final message = _message;
    if (message == null) {
      return const SizedBox.shrink();
    }
    final order = ref.watch(toastStackProvider);
    return Stack(
      children: [
        ToastSlot(
          index: order.indexOf(_slot),
          child: ToastMotion(
            shown: !_leaving,
            child: ToastCard(
              title: message,
              onDismiss: _dismiss,
              onTap: _dismiss,
            ),
          ),
        ),
      ],
    );
  }
}
