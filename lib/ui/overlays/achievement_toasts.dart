import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/achievements.dart';
import 'package:swiftie_quiz/domain/models/achievement_def.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

final Map<String, AchievementDef> _definitionsById = Map.unmodifiable({
  for (final definition in achievementDefs) definition.id: definition,
});

class AchievementToasts extends ConsumerStatefulWidget {
  const AchievementToasts({super.key});

  static const double inset = 16;
  static const double gap = 8;
  static const Duration displayDuration = Duration(seconds: 4);
  static const Duration slideDuration = Duration(milliseconds: 300);
  static const Curve slideCurve = Curves.easeOut;
  static const Offset slideFrom = Offset(1, 0);

  @override
  ConsumerState<AchievementToasts> createState() => _AchievementToastsState();
}

class _AchievementToastsState extends ConsumerState<AchievementToasts> {
  Map<String, Timer> _expiries = const {};

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      gameControllerProvider.select((game) => game.pendingToasts),
      (_, ids) => _scheduleExpiries(ids),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    for (final expiry in _expiries.values) {
      expiry.cancel();
    }
    super.dispose();
  }

  void _scheduleExpiries(List<String> ids) {
    final pending = ids.toSet();
    for (final MapEntry(key: id, value: expiry) in _expiries.entries) {
      if (!pending.contains(id)) {
        expiry.cancel();
      }
    }
    _expiries = Map.unmodifiable({
      for (final id in pending)
        id:
            _expiries[id] ??
            Timer(AchievementToasts.displayDuration, () => _dismiss(id)),
    });
  }

  void _dismiss(String id) =>
      ref.read(gameControllerProvider.notifier).dismissToast(id);

  @override
  Widget build(BuildContext context) {
    final ids = ref.watch(
      gameControllerProvider.select((game) => game.pendingToasts),
    );
    final toasts = [
      for (final id in ids)
        if (_definitionsById[id] case final definition?)
          _AchievementToast(
            key: ValueKey(id),
            definition: definition,
            onDismiss: () => _dismiss(id),
          ),
    ];
    if (toasts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(
          top: AchievementToasts.inset,
          right: AchievementToasts.inset,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AchievementToasts.gap,
              children: toasts,
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementToast extends StatefulWidget {
  const _AchievementToast({
    super.key,
    required this.definition,
    required this.onDismiss,
  });

  static const double radius = AppRadii.xl;
  static const double padding = 16;
  static const double gap = 12;
  static const double dismissLeadingMargin = 8;
  static const String cat = '\u{1F431}';

  final AchievementDef definition;
  final VoidCallback onDismiss;

  @override
  State<_AchievementToast> createState() => _AchievementToastState();
}

class _AchievementToastState extends State<_AchievementToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: AchievementToasts.slideDuration,
  );
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _entrance,
    curve: AchievementToasts.slideCurve,
  );
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: AchievementToasts.slideFrom,
    end: Offset.zero,
  ).animate(_progress);

  @override
  void initState() {
    super.initState();
    unawaited(_entrance.forward());
  }

  @override
  void dispose() {
    _progress.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final definition = widget.definition;
    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _progress,
        child: Container(
          padding: const EdgeInsets.all(_AchievementToast.padding),
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: const BorderRadius.all(
              Radius.circular(_AchievementToast.radius),
            ),
            border: Border.all(color: tokens.primary.slashOpacity(50)),
            boxShadow: AppShadows.lg,
          ),
          child: Row(
            spacing: _AchievementToast.gap,
            children: [
              const Text(_AchievementToast.cat, style: AppText.xl3),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.name,
                      style: AppText.sm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tokens.foreground,
                      ),
                    ),
                    Text(
                      definition.description,
                      style: AppText.xs.copyWith(color: tokens.mutedForeground),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: _AchievementToast.dismissLeadingMargin,
                ),
                child: _DismissButton(onPressed: widget.onDismiss),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DismissButton extends StatefulWidget {
  const _DismissButton({required this.onPressed});

  static const String label = 'Dismiss';
  static const String glyph = '✕';

  final VoidCallback onPressed;

  @override
  State<_DismissButton> createState() => _DismissButtonState();
}

class _DismissButtonState extends State<_DismissButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hover = AnimationController(
    vsync: this,
    duration: AppMotion.cssTransitionDuration,
  );

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    unawaited(
      _hover.animateTo(hovered ? 1 : 0, curve: AppMotion.cssTransitionCurve),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Semantics(
      container: true,
      button: true,
      label: _DismissButton.label,
      child: FocusableActionDetector(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: MouseRegion(
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _hover,
                builder: (context, _) => Text(
                  _DismissButton.glyph,
                  style: AppText.sm.copyWith(
                    color: Oklab.mix(
                      tokens.mutedForeground,
                      tokens.foreground,
                      _hover.value,
                    ),
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
