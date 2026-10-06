import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/state/updater_controller.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/swiftie_modal.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

class UpdateModal extends ConsumerStatefulWidget {
  const UpdateModal({super.key, required this.isOpen, required this.onClose});

  static const double maxWidth = 480;
  static const double gap = 12;
  static const double actionsTop = 8;
  static const double actionGap = 8;
  static const double titleSize = 32;
  static const double titleLineHeight = 36;
  static const BorderRadius boxRadius = BorderRadius.all(Radius.circular(10));
  static const EdgeInsets notesPadding = EdgeInsets.symmetric(
    vertical: 14,
    horizontal: 16,
  );
  static const EdgeInsets bannerPadding = EdgeInsets.symmetric(
    vertical: 12,
    horizontal: 14,
  );
  static const double progressHeight = 4;
  static const BorderRadius progressRadius = BorderRadius.all(
    Radius.circular(2),
  );
  static const Duration progressShift = Duration(milliseconds: 120);
  static const double restartingLoaderSize = 200;
  static const Duration restartingRise = Duration(milliseconds: 250);
  static const String restartingLabel = 'Restarting Project Swiftie...';
  static const String unreachableMessage = 'Could not reach the update server.';

  final bool isOpen;
  final VoidCallback onClose;

  @override
  ConsumerState<UpdateModal> createState() => _UpdateModalState();

  static _Panel _panelFor(
    UpdaterMachineState state,
    _UpdaterAccess updater,
    VoidCallback close,
  ) {
    VoidCallback closing(void Function(UpdaterController updater) action) =>
        () {
          action(updater());
          close();
        };
    final closeOnly = (label: 'Close', kind: PillKind.quiet, onPressed: close);
    return switch (state) {
      UpdaterAvailable(:final manifest) => _Panel(
        title: 'Version ${manifest.version} is here',
        notes: manifest.notes.trim().isEmpty ? null : manifest.notes,
        actions: [
          (
            label: 'Remind me later',
            kind: PillKind.quiet,
            onPressed: closing((updater) => updater.remindLater()),
          ),
          (
            label: 'Skip this version',
            kind: PillKind.outline,
            onPressed: closing(
              (updater) => updater.skipVersion(manifest.version),
            ),
          ),
          (
            label: 'Download',
            kind: PillKind.coral,
            onPressed: () => unawaited(updater().download()),
          ),
        ],
      ),
      UpdaterDownloading(:final manifest, :final progress) => _Panel(
        title: 'Downloading ${manifest.version}',
        progress: progress,
        paragraph: '$progress%',
        actions: [
          (label: 'Hide', kind: PillKind.quiet, onPressed: close),
          (
            label: 'Cancel download',
            kind: PillKind.outline,
            onPressed: closing((updater) => updater.cancel()),
          ),
        ],
      ),
      UpdaterReady(:final manifest) => _Panel(
        title: '${manifest.version} is ready',
        paragraph:
            'Restart Project Swiftie to finish updating. Your progress is '
            'saved.',
        actions: [
          (label: 'Later', kind: PillKind.quiet, onPressed: close),
          (
            label: 'Restart now',
            kind: PillKind.coral,
            onPressed: () => unawaited(updater().install()),
          ),
        ],
      ),
      UpdaterError(:final subtype, :final message) => _Panel(
        title: 'The update hit a snag',
        banner: message.trim().isEmpty ? unreachableMessage : message,
        actions: [
          (
            label: 'Close',
            kind: PillKind.quiet,
            onPressed: closing((updater) => updater.dismiss()),
          ),
          if (subtype != UpdaterErrorSubtype.signature)
            (
              label: 'Try again',
              kind: PillKind.coral,
              onPressed: () => unawaited(updater().retry()),
            ),
        ],
      ),
      UpdaterInstalled(:final manifest) => _Panel(
        title: '${manifest.version} is installed',
        paragraph: 'Quit and reopen Project Swiftie to start using it.',
        actions: [closeOnly],
      ),
      UpdaterIdle() ||
      UpdaterChecking() ||
      UpdaterUpToDate() ||
      UpdaterInstalling() => _Panel(
        title: 'No updates',
        paragraph: "You're on the latest version.",
        actions: [closeOnly],
      ),
    };
  }
}

class _UpdateModalState extends ConsumerState<UpdateModal> {
  UpdaterMachineState _settled = const UpdaterIdle();

  @override
  void initState() {
    super.initState();
    ref.listenManual(updaterStateProvider, (_, next) {
      if (next is! UpdaterChecking) {
        _settled = next;
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updaterStateProvider);
    if (state is UpdaterInstalling) {
      return const _RestartingCover();
    }
    if (!widget.isOpen) {
      return const SizedBox.shrink();
    }
    return BlockSemantics(
      child: SwiftieModal(
        maxWidth: UpdateModal.maxWidth,
        onDismiss: widget.onClose,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          scopesRoute: true,
          role: SemanticsRole.dialog,
          child: _PanelBody(
            panel: UpdateModal._panelFor(
              state is UpdaterChecking ? _settled : state,
              () => ref.read(updaterControllerProvider),
              widget.onClose,
            ),
          ),
        ),
      ),
    );
  }
}

typedef _UpdaterAccess = UpdaterController Function();

typedef _Action = ({String label, PillKind kind, VoidCallback onPressed});

final class _Panel {
  _Panel({
    required this.title,
    this.notes,
    this.progress,
    this.paragraph,
    this.banner,
    required List<_Action> actions,
  }) : actions = List.unmodifiable(actions);

  final String title;
  final String? notes;
  final int? progress;
  final String? paragraph;
  final String? banner;
  final List<_Action> actions;
}

class _PanelBody extends StatelessWidget {
  const _PanelBody({required this.panel});

  final _Panel panel;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: UpdateModal.gap,
      children: [
        Semantics(
          header: true,
          namesRoute: true,
          child: Text(
            panel.title,
            style: AppType.display(
              UpdateModal.titleSize,
              height: UpdateModal.titleLineHeight / UpdateModal.titleSize,
              color: tokens.fg,
            ),
          ),
        ),
        if (panel.notes case final notes?) Flexible(child: _Notes(notes)),
        if (panel.progress case final progress?) _ProgressBar(value: progress),
        if (panel.paragraph case final paragraph?)
          Text(paragraph, style: AppType.body.copyWith(color: tokens.mut)),
        if (panel.banner case final banner?) _Banner(banner),
        Padding(
          padding: const EdgeInsets.only(top: UpdateModal.actionsTop),
          child: _ActionRow(
            children: [
              for (final action in panel.actions)
                PillButton(
                  key: ValueKey(action.label),
                  label: action.label,
                  kind: action.kind,
                  onPressed: action.onPressed,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes(this.notes);

  final String notes;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.designCard,
        border: Border.all(color: tokens.line),
        borderRadius: UpdateModal.boxRadius,
      ),
      child: SingleChildScrollView(
        padding: UpdateModal.notesPadding,
        child: Text(
          notes,
          style: AppType.sized(14, 22).copyWith(color: tokens.mut),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

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
        borderRadius: UpdateModal.progressRadius,
        child: ColoredBox(
          color: tokens.line,
          child: SizedBox(
            height: UpdateModal.progressHeight,
            child: AnimatedFractionallySizedBox(
              duration: AppMotion.duration(context, UpdateModal.progressShift),
              curve: Curves.linear,
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0, 100) / 100,
              heightFactor: 1,
              child: ColoredBox(color: tokens.coral),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      padding: UpdateModal.bannerPadding,
      decoration: BoxDecoration(
        color: tokens.roseBg,
        borderRadius: UpdateModal.boxRadius,
      ),
      child: Text(
        message,
        style: AppType.sized(14, 20).copyWith(color: tokens.rose),
      ),
    );
  }
}

class _RestartingCover extends StatelessWidget {
  const _RestartingCover();

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return BlockSemantics(
      child: AbsorbPointer(
        child: FocusScope(
          child: Focus(
            autofocus: true,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AppMotion.duration(context, UpdateModal.restartingRise),
              curve: Curves.ease,
              builder: (context, shown, child) => Opacity(
                opacity: shown,
                child: Transform.translate(
                  offset: Offset(0, AppMotion.modalRiseOffset * (1 - shown)),
                  child: child,
                ),
              ),
              child: ColoredBox(
                color: tokens.bg,
                child: Semantics(
                  liveRegion: true,
                  child: Center(
                    child: CatLoader(
                      size: CatLoaderSize.lg,
                      px: UpdateModal.restartingLoaderSize,
                      label: UpdateModal.restartingLabel,
                      labelStyle: CatLoader.defaultLabelStyle.copyWith(
                        color: tokens.mut,
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

class _ActionRow extends MultiChildRenderObjectWidget {
  const _ActionRow({required super.children});

  static const double gap = UpdateModal.actionGap;

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
