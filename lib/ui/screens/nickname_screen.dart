import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/misu_controller.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/kit/serif_input.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

class NicknameScreen extends ConsumerStatefulWidget {
  const NicknameScreen({super.key});

  static const String heading = 'Hi. What should we call you?';
  static const String explanation =
      "It's only used in the app. You can change it in Settings.";
  static const String placeholder = 'Your nickname';
  static const String submitLabel = "Let's go →";

  static const Duration focusDelay = Duration(milliseconds: 400);
  static const Duration introduceDelay = Duration(milliseconds: 800);

  static const double top = 48;
  static const double bottom = 120;
  static const double gap = 40;
  static const double maxWidth = 640;
  static const double headingGap = 14;
  static const double headingLineHeight = 1.02;
  static const double inputFontSize = 44;
  static const double inputLineHeight = 52;
  static const double inputMinWidth = 240;
  static const double entryGap = 20;

  @override
  ConsumerState<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends ConsumerState<NicknameScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final Timer _focus;
  late final Timer _introduce;

  @override
  void initState() {
    super.initState();
    _focus = Timer(NicknameScreen.focusDelay, _focusNode.requestFocus);
    _introduce = Timer(
      NicknameScreen.introduceDelay,
      () => ref.read(misuControllerProvider.notifier).introduce(),
    );
  }

  @override
  void dispose() {
    _focus.cancel();
    _introduce.cancel();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    ref.read(gameControllerProvider.notifier)
      ..setNickname(_controller.text)
      ..setPhase(GamePhase.menu);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    return ScreenEnter(
      child: LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: viewport.hasBoundedHeight ? viewport.maxHeight : 0,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                layout.padX,
                NicknameScreen.top,
                layout.padX,
                NicknameScreen.bottom,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: NicknameScreen.gap,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: NicknameScreen.maxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: NicknameScreen.headingGap,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            NicknameScreen.heading,
                            style: AppType.display(
                              layout.h1,
                              height: NicknameScreen.headingLineHeight,
                              color: tokens.fg,
                            ),
                          ),
                        ),
                        Text(
                          NicknameScreen.explanation,
                          style: AppType.bodyLarge.copyWith(color: tokens.mut),
                        ),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: NicknameScreen.maxWidth,
                    ),
                    child: _EntryRow(
                      gap: NicknameScreen.entryGap,
                      minFieldWidth: NicknameScreen.inputMinWidth,
                      children: [
                        SerifInput(
                          controller: _controller,
                          focusNode: _focusNode,
                          placeholder: NicknameScreen.placeholder,
                          fontSize: NicknameScreen.inputFontSize,
                          lineHeight: NicknameScreen.inputLineHeight,
                          maxLength: nicknameMaxLength,
                          onSubmitted: (_) => _submit(),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, value, _) => PillButton(
                            label: NicknameScreen.submitLabel,
                            size: PillSize.large,
                            enabled: value.text.trim().isNotEmpty,
                            onPressed: _submit,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryRow extends MultiChildRenderObjectWidget {
  const _EntryRow({
    required this.gap,
    required this.minFieldWidth,
    required super.children,
  });

  final double gap;
  final double minFieldWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderEntryRow(gap: gap, minFieldWidth: minFieldWidth);

  @override
  void updateRenderObject(BuildContext context, _RenderEntryRow renderObject) {
    renderObject
      ..gap = gap
      ..minFieldWidth = minFieldWidth;
  }
}

class _EntryRowParentData extends ContainerBoxParentData<RenderBox> {}

typedef _Arrangement = ({Size size, Offset field, Offset action});

class _RenderEntryRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EntryRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EntryRowParentData> {
  _RenderEntryRow({required this._gap, required this._minFieldWidth});

  double _gap;
  double _minFieldWidth;

  set gap(double value) {
    if (value != _gap) {
      _gap = value;
      markNeedsLayout();
    }
  }

  set minFieldWidth(double value) {
    if (value != _minFieldWidth) {
      _minFieldWidth = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _EntryRowParentData) {
      child.parentData = _EntryRowParentData();
    }
  }

  RenderBox get _field => firstChild!;

  RenderBox get _action => childAfter(_field)!;

  bool _fitsBeside(double width, double actionWidth) =>
      width - _gap - actionWidth >= _minFieldWidth;

  _Arrangement _arrange(BoxConstraints constraints, ChildLayouter layoutChild) {
    final width = constraints.maxWidth;
    final action = layoutChild(_action, BoxConstraints(maxWidth: width));
    if (_fitsBeside(width, action.width)) {
      final field = layoutChild(
        _field,
        BoxConstraints.tightFor(width: width - _gap - action.width),
      );
      final height = math.max(field.height, action.height);
      return (
        size: constraints.constrain(Size(width, height)),
        field: Offset(0, height - field.height),
        action: Offset(width - action.width, height - action.height),
      );
    }
    final field = layoutChild(_field, BoxConstraints.tightFor(width: width));
    return (
      size: constraints.constrain(
        Size(width, field.height + _gap + action.height),
      ),
      field: Offset.zero,
      action: Offset(0, field.height + _gap),
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _arrange(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  void performLayout() {
    final arrangement = _arrange(constraints, ChildLayoutHelper.layoutChild);
    (_field.parentData! as _EntryRowParentData).offset = arrangement.field;
    (_action.parentData! as _EntryRowParentData).offset = arrangement.action;
    size = arrangement.size;
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    math.max(_minFieldWidth, _field.getMinIntrinsicWidth(height)),
    _action.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      math.max(_minFieldWidth, _field.getMaxIntrinsicWidth(height)) +
      _gap +
      _action.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(
    width,
    (child, width) => child.getMinIntrinsicHeight(width),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(
    width,
    (child, width) => child.getMaxIntrinsicHeight(width),
  );

  double _intrinsicHeight(
    double width,
    double Function(RenderBox child, double width) heightOf,
  ) {
    final actionWidth = math.min(
      _action.getMaxIntrinsicWidth(double.infinity),
      width,
    );
    if (_fitsBeside(width, actionWidth)) {
      return math.max(
        heightOf(_field, width - _gap - actionWidth),
        heightOf(_action, actionWidth),
      );
    }
    return heightOf(_field, width) + _gap + heightOf(_action, actionWidth);
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
