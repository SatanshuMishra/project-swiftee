import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/state/updater_controller.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/overlays/update_modal.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

typedef UpdateBadgeLook = ({String label, Color background, Color foreground});

final updateDialogOpenProvider = NotifierProvider<UpdateDialogOpen, bool>(
  UpdateDialogOpen.new,
);

class UpdateDialogOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void open() => state = true;

  void close() => state = false;
}

enum UpdateBadgeSize {
  mac(height: 20, fontSize: 11),
  windows(height: 22, fontSize: 12);

  const UpdateBadgeSize({required this.height, required this.fontSize});

  final double height;
  final double fontSize;
}

class UpdateBadge extends ConsumerWidget {
  const UpdateBadge({
    super.key,
    this.size = UpdateBadgeSize.mac,
    this.margin = EdgeInsets.zero,
  });

  static const double paddingX = 10;
  static const double gap = 6;
  static const double dotSize = 6;
  static const double dotOpacity = 0.8;
  static const double minTarget = 24;
  static const BorderRadius radius = BorderRadius.all(Radius.circular(999));

  final UpdateBadgeSize size;
  final EdgeInsets margin;

  static UpdateBadgeLook? lookFor(
    UpdaterMachineState state,
    AppTokens tokens,
  ) => switch (state) {
    UpdaterAvailable(:final manifest) => (
      label: 'Update available · ${manifest.version}',
      background: tokens.coral,
      foreground: tokens.onCoral,
    ),
    UpdaterDownloading(:final progress) => (
      label: 'Downloading · $progress%',
      background: tokens.btn,
      foreground: tokens.onBtn,
    ),
    UpdaterReady() => (
      label: 'Restart to update',
      background: tokens.coral,
      foreground: tokens.onCoral,
    ),
    UpdaterError() => (
      label: 'Update issue',
      background: tokens.roseBg,
      foreground: tokens.rose,
    ),
    UpdaterIdle() ||
    UpdaterChecking() ||
    UpdaterUpToDate() ||
    UpdaterInstalling() ||
    UpdaterInstalled() => null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = lookFor(
      ref.watch(updaterStateProvider),
      AppTokens.of(context),
    );
    if (look == null) {
      return const SizedBox.shrink();
    }
    void open() => ref.read(updateDialogOpenProvider.notifier).open();
    return Padding(
      padding: margin,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: open,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            height: math.max(minTarget, size.height),
            child: Center(
              widthFactor: 1,
              child: Semantics(
                container: true,
                child: Pressable(
                  onPressed: open,
                  focusRadius: radius,
                  semanticLabel: look.label,
                  builder: (context, _) => ExcludeSemantics(
                    child: _BadgePill(look: look, size: size),
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

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.look, required this.size});

  final UpdateBadgeLook look;
  final UpdateBadgeSize size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: look.background,
      borderRadius: UpdateBadge.radius,
    ),
    child: SizedBox(
      height: size.height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: UpdateBadge.paddingX),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: UpdateBadge.gap,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: look.foreground.withValues(
                  alpha: look.foreground.a * UpdateBadge.dotOpacity,
                ),
              ),
              child: const SizedBox.square(dimension: UpdateBadge.dotSize),
            ),
            Text(
              look.label,
              maxLines: 1,
              softWrap: false,
              style: AppType.sized(
                size.fontSize,
                size.height,
                weight: FontWeight.w600,
              ).copyWith(color: look.foreground),
            ),
          ],
        ),
      ),
    ),
  );
}

class UpdateOverlay extends ConsumerWidget {
  const UpdateOverlay({super.key, this.screen, this.belowDialog});

  final Widget? screen;
  final Widget? belowDialog;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Stack(
    fit: StackFit.expand,
    children: [
      Overlay.wrap(child: screen ?? const SizedBox.shrink()),
      ?belowDialog,
      UpdateModal(
        isOpen: ref.watch(updateDialogOpenProvider),
        onClose: () => ref.read(updateDialogOpenProvider.notifier).close(),
      ),
    ],
  );
}
