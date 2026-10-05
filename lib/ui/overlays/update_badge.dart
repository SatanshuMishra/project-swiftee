import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/state/updater_controller.dart';
import 'package:swiftie_quiz/ui/overlays/update_modal.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';

typedef UpdateBadgeLook = ({
  String label,
  Color color,
  LucideGlyph glyph,
  bool spinning,
});

class UpdateBadge extends ConsumerWidget {
  const UpdateBadge({super.key, required this.onPressed});

  static const double inset = 24;
  static const double iconSize = 16;
  static const double gap = 8;
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  );
  static const Color foreground = AppPalette.white;
  static const Duration spinPeriod = Duration(seconds: 1);

  final VoidCallback onPressed;

  static UpdateBadgeLook? lookFor(UpdaterMachineState state) => switch (state) {
    UpdaterAvailable(:final manifest) => (
      label: 'Update available (${manifest.version})',
      color: AppPalette.violet600,
      glyph: LucideGlyph.download,
      spinning: false,
    ),
    UpdaterDownloading(:final progress) => (
      label: 'Downloading update… $progress%',
      color: AppPalette.blue600,
      glyph: LucideGlyph.loaderCircle,
      spinning: true,
    ),
    UpdaterReady(:final manifest) => (
      label: 'Restart to install ${manifest.version}',
      color: AppPalette.emerald600,
      glyph: LucideGlyph.refreshCcw,
      spinning: false,
    ),
    UpdaterError() => (
      label: 'Update issue — click for details',
      color: AppPalette.yellow600,
      glyph: LucideGlyph.circleAlert,
      spinning: false,
    ),
    UpdaterIdle() ||
    UpdaterChecking() ||
    UpdaterUpToDate() ||
    UpdaterInstalling() ||
    UpdaterInstalled() => null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = lookFor(ref.watch(updaterStateProvider));
    if (look == null) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: inset, bottom: inset),
        child: _BadgeButton(look: look, onPressed: onPressed),
      ),
    );
  }
}

class _BadgeButton extends StatelessWidget {
  const _BadgeButton({required this.look, required this.onPressed});

  final UpdateBadgeLook look;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: look.label,
      child: FocusableActionDetector(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: ExcludeSemantics(
            child: TweenAnimationBuilder<Color>(
              tween: _OklabColorTween(end: look.color),
              duration: AppMotion.cssTransitionDuration,
              curve: AppMotion.cssTransitionCurve,
              builder: (context, color, child) => DecoratedBox(
                decoration: ShapeDecoration(
                  color: color,
                  shape: const StadiumBorder(),
                  shadows: AppShadows.lg,
                ),
                child: child,
              ),
              child: Padding(
                padding: UpdateBadge.padding,
                child: Material(
                  type: MaterialType.transparency,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: UpdateBadge.gap,
                    children: [
                      _BadgeIcon(glyph: look.glyph, spinning: look.spinning),
                      Text(
                        look.label,
                        style: AppText.sm.copyWith(
                          color: UpdateBadge.foreground,
                        ),
                      ),
                    ],
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

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.glyph, required this.spinning});

  final LucideGlyph glyph;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final icon = AppIcon(
      glyph,
      size: UpdateBadge.iconSize,
      color: UpdateBadge.foreground,
    );
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!spinning || reduceMotion) {
      return icon;
    }
    return _Spinner(child: icon);
  }
}

class _Spinner extends StatefulWidget {
  const _Spinner({required this.child});

  final Widget child;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turns = AnimationController(
    vsync: this,
    duration: UpdateBadge.spinPeriod,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_turns.repeat());
  }

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RotationTransition(turns: _turns, child: widget.child);
}

class _OklabColorTween extends Tween<Color> {
  _OklabColorTween({required Color end}) : super(end: end);

  @override
  Color lerp(double t) => Oklab.mix(begin!, end!, t);
}

class UpdateOverlay extends StatefulWidget {
  const UpdateOverlay({super.key, this.belowDialog});

  final Widget? belowDialog;

  @override
  State<UpdateOverlay> createState() => _UpdateOverlayState();
}

class _UpdateOverlayState extends State<UpdateOverlay> {
  bool _dialogOpen = false;

  void _setDialogOpen(bool open) => setState(() => _dialogOpen = open);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        UpdateBadge(onPressed: () => _setDialogOpen(true)),
        ?widget.belowDialog,
        UpdateModal(isOpen: _dialogOpen, onClose: () => _setDialogOpen(false)),
      ],
    );
  }
}
