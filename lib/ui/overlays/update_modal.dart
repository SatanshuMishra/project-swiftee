import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/state/updater_controller.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

class UpdateModal extends ConsumerStatefulWidget {
  const UpdateModal({super.key, required this.isOpen, required this.onClose});

  static const double hiddenScale = 0.95;
  static const double maxWidth = 512;
  static const double horizontalInset = 24;
  static const double padding = 24;
  static const double radius = AppRadii.xl2;
  static const double notesMaxHeight = 256;
  static const Color backdrop = Color.from(
    alpha: 0.6,
    red: 0,
    green: 0,
    blue: 0,
  );

  final bool isOpen;
  final VoidCallback onClose;

  @override
  ConsumerState<UpdateModal> createState() => _UpdateModalState();
}

class _UpdateModalState extends ConsumerState<UpdateModal>
    with TickerProviderStateMixin {
  late final AnimationController _opacity = AnimationController(
    vsync: this,
    duration: AppMotion.defaultOpacityDuration,
  );
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: UpdateModal.hiddenScale,
  );
  late bool _present = widget.isOpen;
  bool _reduceMotion = false;
  bool _listening = false;
  bool _entered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_entered && widget.isOpen) {
      _enter();
    }
  }

  @override
  void didUpdateWidget(UpdateModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen == oldWidget.isOpen) {
      return;
    }
    if (widget.isOpen) {
      _enter();
    } else {
      _exit();
    }
  }

  @override
  void dispose() {
    _listenForEscape(false);
    _opacity.dispose();
    _scale.dispose();
    super.dispose();
  }

  void _enter() {
    _entered = true;
    _present = true;
    _listenForEscape(true);
    if (_reduceMotion) {
      _opacity.value = 1;
      _scale.value = 1;
      return;
    }
    unawaited(_fadeTo(1));
    unawaited(_springScaleTo(1));
  }

  void _exit() {
    _listenForEscape(false);
    if (_reduceMotion) {
      _opacity.value = 0;
      _scale.value = UpdateModal.hiddenScale;
      _present = false;
      return;
    }
    unawaited(_animateOut());
  }

  Future<void> _animateOut() async {
    try {
      await Future.wait([
        _fadeTo(0).orCancel,
        _springScaleTo(UpdateModal.hiddenScale).orCancel,
      ]);
    } on TickerCanceled {
      return;
    }
    if (mounted && !widget.isOpen) {
      setState(() => _present = false);
    }
  }

  TickerFuture _fadeTo(double target) => _opacity.animateTo(
    target,
    duration: AppMotion.defaultOpacityDuration,
    curve: AppMotion.defaultOpacityCurve,
  );

  TickerFuture _springScaleTo(double target) {
    final start = _scale.value;
    return _scale.animateWith(
      SpringSimulation(
        AppMotion.defaultScaleSpring,
        start,
        target,
        _scale.velocity,
        tolerance: AppMotion.restTolerance(target - start),
        snapToEnd: true,
      ),
    );
  }

  void _listenForEscape(bool listen) {
    if (listen == _listening) {
      return;
    }
    _listening = listen;
    if (listen) {
      HardwareKeyboard.instance.addHandler(_handleKey);
    } else {
      HardwareKeyboard.instance.removeHandler(_handleKey);
    }
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyUpEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_present) {
      return const SizedBox.shrink();
    }
    final tokens = AppTokens.of(context);
    final state = ref.watch(updaterStateProvider);
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(UpdateModal.padding),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: const BorderRadius.all(
          Radius.circular(UpdateModal.radius),
        ),
        border: Border.all(color: tokens.border),
        boxShadow: AppShadows.xl2,
      ),
      child: _ModalContent(
        state: state,
        updater: () => ref.read(updaterControllerProvider),
        onClose: widget.onClose,
      ),
    );
    return IgnorePointer(
      ignoring: !widget.isOpen,
      child: ExcludeFocus(
        excluding: !widget.isOpen,
        child: ExcludeSemantics(
          excluding: !widget.isOpen,
          child: BlockSemantics(
            blocking: widget.isOpen,
            child: FadeTransition(
              opacity: _opacity,
              alwaysIncludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: widget.onClose,
                child: ColoredBox(
                  color: UpdateModal.backdrop,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UpdateModal.horizontalInset,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: UpdateModal.maxWidth,
                        ),
                        child: ScaleTransition(
                          scale: _scale,
                          child: FadeTransition(
                            opacity: _opacity,
                            alwaysIncludeSemantics: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              excludeFromSemantics: true,
                              onTap: () {},
                              child: Semantics(
                                container: true,
                                explicitChildNodes: true,
                                scopesRoute: true,
                                role: SemanticsRole.dialog,
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: card,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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

typedef _UpdaterAccess = UpdaterController Function();

final class _Block {
  const _Block(this.child, {this.top = 0, this.bottom = 0});

  final Widget child;
  final double top;
  final double bottom;
}

class _ModalContent extends StatelessWidget {
  const _ModalContent({
    required this.state,
    required this.updater,
    required this.onClose,
  });

  static const String verificationFailure =
      'The downloaded update could not be verified. The download may be '
      'corrupted or the release may be misconfigured.';

  final UpdaterMachineState state;
  final _UpdaterAccess updater;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final blocks = _blocksFor(tokens);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _collapseMargins(blocks),
    );
  }

  List<_Block> _blocksFor(AppTokens tokens) => switch (state) {
    UpdaterAvailable(:final manifest) => [
      _header('Version ${manifest.version} available', tokens.foreground),
      if (manifest.notes.isNotEmpty) _notes(manifest.notes, tokens),
      _actions([
        _ModalButton(
          'Download',
          kind: _ButtonKind.primary,
          onPressed: () => updater().download(),
        ),
        _ModalButton(
          'Skip this version',
          kind: _ButtonKind.secondary,
          onPressed: () => updater().skipVersion(manifest.version),
        ),
        _ModalButton(
          'Remind me later',
          kind: _ButtonKind.secondary,
          onPressed: () => updater().remindLater(),
        ),
        _ModalButton('Close', kind: _ButtonKind.tertiary, onPressed: onClose),
      ]),
    ],
    UpdaterDownloading(:final manifest, :final progress) => [
      _header('Downloading ${manifest.version}', tokens.foreground),
      _Block(_ProgressBar(value: progress), top: 16, bottom: 16),
      _actions([
        _ModalButton(
          'Cancel',
          kind: _ButtonKind.secondary,
          onPressed: () => updater().cancel(),
        ),
        _ModalButton('Hide', kind: _ButtonKind.tertiary, onPressed: onClose),
      ]),
    ],
    UpdaterReady(:final manifest) => [
      _header('Version ${manifest.version} ready', tokens.foreground),
      _paragraph('Restart the app to apply the update.', tokens),
      _actions([
        _ModalButton(
          'Install & Restart',
          kind: _ButtonKind.primary,
          onPressed: () => updater().install(),
        ),
        _ModalButton('Close', kind: _ButtonKind.tertiary, onPressed: onClose),
      ]),
    ],
    UpdaterError(subtype: UpdaterErrorSubtype.signature) => [
      _header('Update verification failed', AppPalette.red200),
      _banner(verificationFailure, AppPalette.red500, AppPalette.red200),
      _actions([
        _ModalButton(
          'Dismiss',
          kind: _ButtonKind.primary,
          onPressed: () => updater().dismiss(),
        ),
      ]),
    ],
    UpdaterError(:final subtype, :final message) => [
      _header('Update failed', AppPalette.yellow200),
      _banner(message, AppPalette.yellow500, AppPalette.yellow200),
      _actions([
        _ModalButton(
          'Retry',
          kind: _ButtonKind.primary,
          onPressed: () => switch (subtype) {
            UpdaterErrorSubtype.check => updater().check(manual: true),
            UpdaterErrorSubtype.download => updater().download(),
            _ => updater().install(),
          },
        ),
        _ModalButton(
          'Close',
          kind: _ButtonKind.tertiary,
          onPressed: () => updater().dismiss(),
        ),
      ]),
    ],
    UpdaterInstalled(:final manifest) => [
      _header('Version ${manifest.version} installed', tokens.foreground),
      _paragraph('Quit and reopen Swiftie Quiz to start using it.', tokens),
      _actions([
        _ModalButton('Close', kind: _ButtonKind.tertiary, onPressed: onClose),
      ]),
    ],
    UpdaterIdle() ||
    UpdaterChecking() ||
    UpdaterUpToDate() ||
    UpdaterInstalling() => [
      _header('No update information', tokens.foreground),
      _actions([
        _ModalButton('Close', kind: _ButtonKind.tertiary, onPressed: onClose),
      ]),
    ],
  };

  static List<Widget> _collapseMargins(List<_Block> blocks) => [
    if (blocks.first.top > 0) SizedBox(height: blocks.first.top),
    for (final (index, block) in blocks.indexed) ...[
      if (index > 0)
        SizedBox(height: math.max(blocks[index - 1].bottom, block.top)),
      block.child,
    ],
    if (blocks.last.bottom > 0) SizedBox(height: blocks.last.bottom),
  ];

  static _Block _header(String title, Color color) => _Block(
    Semantics(
      header: true,
      child: Text(
        title,
        style: AppText.xl
            .copyWith(fontWeight: FontWeight.w600, color: color)
            .trackingTight,
      ),
    ),
    bottom: 12,
  );

  static _Block _notes(String notes, AppTokens tokens) => _Block(
    Container(
      constraints: const BoxConstraints(maxHeight: UpdateModal.notesMaxHeight),
      decoration: BoxDecoration(
        color: tokens.muted.slashOpacity(40),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Text(
          notes,
          style: AppText.sm.copyWith(
            color: tokens.mutedForeground,
            fontFamily: _monospaceFamily,
            fontFamilyFallback: _monospaceFallback,
          ),
        ),
      ),
    ),
    bottom: 16,
  );

  static _Block _paragraph(String text, AppTokens tokens) => _Block(
    Text(text, style: AppText.base.copyWith(color: tokens.mutedForeground)),
  );

  static _Block _banner(String text, Color tint, Color foreground) => _Block(
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint.slashOpacity(10),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
      ),
      child: Text(text, style: AppText.sm.copyWith(color: foreground)),
    ),
  );

  static _Block _actions(List<Widget> buttons) =>
      _Block(_ActionRow(children: buttons), top: 16);

  static const String _monospaceFamily = '.AppleSystemUIFontMonospaced';
  static const List<String> _monospaceFallback = [
    'Menlo',
    'Monaco',
    'Consolas',
    'Liberation Mono',
    'Courier New',
    'monospace',
  ];
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  static const double height = 8;
  static const Color fill = AppPalette.blue600;

  final int value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Semantics(
      container: true,
      role: SemanticsRole.progressBar,
      value: '$value',
      minValue: '0',
      maxValue: '100',
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(height / 2)),
        child: ColoredBox(
          color: tokens.muted,
          child: SizedBox(
            height: height,
            child: AnimatedFractionallySizedBox(
              duration: AppMotion.cssTransitionDuration,
              curve: AppMotion.cssTransitionCurve,
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0, 100) / 100,
              heightFactor: 1,
              child: const ColoredBox(color: fill),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ButtonKind { primary, secondary, tertiary }

class _ModalButton extends StatefulWidget {
  const _ModalButton(this.label, {required this.kind, required this.onPressed});

  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  );

  final String label;
  final _ButtonKind kind;
  final VoidCallback onPressed;

  @override
  State<_ModalButton> createState() => _ModalButtonState();
}

class _ModalButtonState extends State<_ModalButton> {
  bool _hovered = false;

  void _setHovered(bool hovered) {
    if (hovered != _hovered) {
      setState(() => _hovered = hovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final hovered = _hovered;
    final (background, foreground, border, weight) = switch (widget.kind) {
      _ButtonKind.primary => (
        hovered ? AppPalette.violet700 : AppPalette.violet600,
        AppPalette.white,
        null,
        FontWeight.w500,
      ),
      _ButtonKind.secondary => (
        hovered ? tokens.muted.slashOpacity(40) : tokens.card,
        tokens.foreground,
        Border.all(color: tokens.border),
        FontWeight.w400,
      ),
      _ButtonKind.tertiary => (
        null,
        hovered ? tokens.foreground : tokens.mutedForeground,
        null,
        FontWeight.w400,
      ),
    };
    return Semantics(
      container: true,
      button: true,
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
            child: Container(
              padding: _ModalButton.padding,
              decoration: BoxDecoration(
                color: background,
                border: border,
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadii.md),
                ),
              ),
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  widget.label,
                  style: AppText.sm.copyWith(
                    color: foreground,
                    fontWeight: weight,
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

class _ActionRow extends MultiChildRenderObjectWidget {
  const _ActionRow({required super.children});

  static const double gap = 8;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderActionRow(gap: gap);
}

class _ActionRowParentData extends ContainerBoxParentData<RenderBox> {}

typedef _MeasuredLine = ({List<(RenderBox, Size)> items, double height});

class _RenderActionRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ActionRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ActionRowParentData> {
  _RenderActionRow({required this.gap});

  final double gap;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ActionRowParentData) {
      child.parentData = _ActionRowParentData();
    }
  }

  List<RenderBox> get _children {
    final children = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      children.add(child);
      child = childAfter(child);
    }
    return children;
  }

  List<_MeasuredLine> _measureLines(double maxWidth) {
    final childConstraints = BoxConstraints(maxWidth: maxWidth);
    final lines = <_MeasuredLine>[];
    var items = <(RenderBox, Size)>[];
    var width = 0.0;
    void closeLine() {
      lines.add((
        items: List.unmodifiable(items),
        height: items.fold(
          0.0,
          (tallest, item) => math.max(tallest, item.$2.height),
        ),
      ));
    }

    for (final child in _children) {
      final size = child.getDryLayout(childConstraints);
      final widened = items.isEmpty ? size.width : width + gap + size.width;
      if (items.isNotEmpty && widened > maxWidth) {
        closeLine();
        items = [(child, size)];
        width = size.width;
      } else {
        items = [...items, (child, size)];
        width = widened;
      }
    }
    if (items.isNotEmpty) {
      closeLine();
    }
    return List.unmodifiable(lines);
  }

  double _heightOf(List<_MeasuredLine> lines) => lines.isEmpty
      ? 0
      : lines.fold(0.0, (sum, line) => sum + line.height) +
            gap * (lines.length - 1);

  double _lineWidth(_MeasuredLine line) =>
      line.items.fold(0.0, (sum, item) => sum + item.$2.width) +
      gap * (line.items.length - 1);

  double _widthOf(BoxConstraints constraints, List<_MeasuredLine> lines) =>
      constraints.hasBoundedWidth
      ? constraints.maxWidth
      : lines.fold(0.0, (widest, line) => math.max(widest, _lineWidth(line)));

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final lines = _measureLines(constraints.maxWidth);
    return constraints.constrain(
      Size(_widthOf(constraints, lines), _heightOf(lines)),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) => _children.fold(
    0.0,
    (widest, child) => math.max(widest, child.getMinIntrinsicWidth(height)),
  );

  @override
  double computeMaxIntrinsicWidth(double height) {
    final children = _children;
    if (children.isEmpty) {
      return 0;
    }
    return children.fold(
          0.0,
          (sum, child) => sum + child.getMaxIntrinsicWidth(height),
        ) +
        gap * (children.length - 1);
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _heightOf(_measureLines(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _heightOf(_measureLines(width));

  @override
  void performLayout() {
    final lines = _measureLines(constraints.maxWidth);
    final width = _widthOf(constraints, lines);
    var top = 0.0;
    for (final line in lines) {
      var left = width - _lineWidth(line);
      for (final (child, size) in line.items) {
        child.layout(
          BoxConstraints.tightFor(width: size.width, height: line.height),
        );
        (child.parentData! as _ActionRowParentData).offset = Offset(left, top);
        left += size.width + gap;
      }
      top += line.height + gap;
    }
    size = constraints.constrain(Size(width, _heightOf(lines)));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
