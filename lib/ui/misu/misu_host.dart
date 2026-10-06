import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/state/misu_controller.dart';
import 'package:swiftie_quiz/ui/cat/cat_icon.dart';
import 'package:swiftie_quiz/ui/kit/modal_stack.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

class MisuHost extends ConsumerStatefulWidget {
  const MisuHost({super.key});

  static const double leftInset = 40;
  static const double rightInset = 48;
  static const double gap = 10;
  static const Size catWindow = Size(76, 62);
  static const double catHeight = 152;
  static const double catHiddenOffset = 1.1;
  static const double lineMaxWidth = 340;
  static const double bubbleLift = 44;
  static const EdgeInsets bubblePadding = EdgeInsets.symmetric(
    vertical: 12,
    horizontal: 16,
  );
  static const BorderRadius bubbleRadius = BorderRadius.all(
    Radius.circular(14),
  );
  static const double bubbleRing = 1;
  static const double bubbleShadowOffset = 8;
  static const double bubbleShadowBlur = 24;
  static const double fontSize = 20;
  static const double lineHeight = 24;
  static const double tailSize = 12;
  static const double tailOutset = 6;
  static const double tailBottom = 14;
  static const double bubbleDrop = 8;
  static const double bubbleHiddenScale = 0.96;
  static const Duration bubbleFade = Duration(milliseconds: 300);
  static const Curve bubbleFadeCurve = Curves.ease;
  static const Duration bubbleRise = Duration(milliseconds: 350);
  static const Curve bubbleRiseCurve = Cubic(0.2, 0.8, 0.2, 1);
  static const Duration sinkAway = Duration(milliseconds: 420);
  static const String semanticLabel = 'Misu';

  @override
  ConsumerState<MisuHost> createState() => _MisuHostState();
}

class _MisuHostState extends ConsumerState<MisuHost> {
  MisuVisit? _visit;
  bool _up = false;
  Timer? _unmount;

  @override
  void initState() {
    super.initState();
    _visit = ref.read(misuControllerProvider).visit;
    _up = _visit != null;
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _cancelUnmount();
    super.dispose();
  }

  void _follow(MisuVisit? next) {
    _cancelUnmount();
    if (next != null) {
      setState(() {
        _visit = next;
        _up = true;
      });
      return;
    }
    if (_visit == null) {
      return;
    }
    if (AppMotion.reduced(context)) {
      setState(() {
        _visit = null;
        _up = false;
      });
      return;
    }
    setState(() => _up = false);
    _unmount = Timer(MisuHost.sinkAway, () {
      _unmount = null;
      if (mounted) {
        setState(() => _visit = null);
      }
    });
  }

  void _cancelUnmount() {
    _unmount?.cancel();
    _unmount = null;
  }

  void _dismiss() => ref.read(misuControllerProvider.notifier).dismiss();

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape ||
        ref.read(misuControllerProvider).visit == null ||
        ref.read(modalStackProvider).isNotEmpty) {
      return false;
    }
    _dismiss();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      misuControllerProvider.select((misu) => misu.visit),
      (_, next) => _follow(next),
    );
    final visit = _visit;
    if (visit == null) {
      return const SizedBox.shrink();
    }
    final left = visit.side == MisuSide.left;
    return Stack(
      children: [
        Positioned(
          left: left ? MisuHost.leftInset : null,
          right: left ? null : MisuHost.rightInset,
          bottom: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            textDirection: left ? TextDirection.ltr : TextDirection.rtl,
            spacing: MisuHost.gap,
            children: [
              _MisuCat(up: _up, onPressed: _dismiss),
              Padding(
                padding: const EdgeInsets.only(bottom: MisuHost.bubbleLift),
                child: _MisuBubble(text: visit.text, tailLeft: left, up: _up),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MisuCat extends StatelessWidget {
  const _MisuCat({required this.up, required this.onPressed});

  final bool up;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    onPressed: onPressed,
    enabled: up,
    semanticLabel: MisuHost.semanticLabel,
    builder: (context, _) => SizedBox.fromSize(
      size: MisuHost.catWindow,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: MisuHost.catHeight,
          child: TweenAnimationBuilder<double>(
            tween: Tween(
              begin: MisuHost.catHiddenOffset,
              end: up ? 0 : MisuHost.catHiddenOffset,
            ),
            duration: AppMotion.duration(context, AppMotion.misuRise),
            curve: AppMotion.misuRiseCurve,
            builder: (context, offset, child) => FractionalTranslation(
              translation: Offset(0, offset),
              child: child,
            ),
            child: const CatIcon(height: MisuHost.catHeight),
          ),
        ),
      ),
    ),
  );
}

class _MisuBubble extends StatelessWidget {
  const _MisuBubble({
    required this.text,
    required this.tailLeft,
    required this.up,
  });

  final String text;
  final bool tailLeft;
  final bool up;

  static (Duration, Curve) _afterCat(
    BuildContext context,
    Duration duration,
    Curve curve,
  ) {
    final total = AppMotion.misuBubbleDelay + duration;
    return (
      AppMotion.duration(context, total),
      Interval(
        AppMotion.misuBubbleDelay.inMicroseconds / total.inMicroseconds,
        1,
        curve: curve,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final shown = up ? 1.0 : 0.0;
    final (fadeDuration, fadeCurve) = _afterCat(
      context,
      MisuHost.bubbleFade,
      MisuHost.bubbleFadeCurve,
    );
    final (riseDuration, riseCurve) = _afterCat(
      context,
      MisuHost.bubbleRise,
      MisuHost.bubbleRiseCurve,
    );
    final bubble = Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.bubble,
            borderRadius: MisuHost.bubbleRadius,
            boxShadow: [
              BoxShadow(color: tokens.line, spreadRadius: MisuHost.bubbleRing),
              CssBoxShadow(
                color: tokens.shadow,
                offset: const Offset(0, MisuHost.bubbleShadowOffset),
                blur: MisuHost.bubbleShadowBlur,
              ),
            ],
          ),
          child: Padding(
            padding: MisuHost.bubblePadding,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: MisuHost.lineMaxWidth,
              ),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  text,
                  style: AppType.display(
                    MisuHost.fontSize,
                    height: MisuHost.lineHeight / MisuHost.fontSize,
                    color: tokens.bubbleFg,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: tailLeft ? -MisuHost.tailOutset : null,
          right: tailLeft ? null : -MisuHost.tailOutset,
          bottom: MisuHost.tailBottom,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: SizedBox.square(
              dimension: MisuHost.tailSize,
              child: ColoredBox(color: tokens.bubble),
            ),
          ),
        ),
      ],
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: shown),
      duration: fadeDuration,
      curve: fadeCurve,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: shown),
        duration: riseDuration,
        curve: riseCurve,
        builder: (context, rise, child) => Transform.translate(
          offset: Offset(0, MisuHost.bubbleDrop * (1 - rise)),
          child: Transform.scale(
            scale:
                MisuHost.bubbleHiddenScale +
                (1 - MisuHost.bubbleHiddenScale) * rise,
            child: child,
          ),
        ),
        child: bubble,
      ),
    );
  }
}
