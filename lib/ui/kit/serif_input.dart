import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

class SerifInput extends StatefulWidget {
  const SerifInput({
    super.key,
    required this.controller,
    this.placeholder,
    required this.fontSize,
    required this.lineHeight,
    this.maxLength,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
    this.enabled = true,
    this.obscured = false,
    this.semanticLabel,
    this.fieldKey,
    this.focusNode,
    this.textAlign = TextAlign.start,
    this.trailing,
  });

  static const double underlineWidth = 1;
  static const double bottomPadding = 6;
  static const double trailingGap = 12;
  static const String obscuringCharacter = '*';

  final TextEditingController controller;
  final String? placeholder;
  final double fontSize;
  final double lineHeight;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool enabled;
  final bool obscured;
  final String? semanticLabel;
  final Key? fieldKey;
  final FocusNode? focusNode;
  final TextAlign textAlign;
  final Widget? trailing;

  @override
  State<SerifInput> createState() => _SerifInputState();
}

class _SerifInputState extends State<SerifInput> {
  FocusNode? _ownFocusNode;
  bool _focused = false;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_syncFocus);
  }

  @override
  void didUpdateWidget(SerifInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.focusNode ?? _ownFocusNode;
    if (previous != _focusNode) {
      previous?.removeListener(_syncFocus);
      _focusNode.addListener(_syncFocus);
      _syncFocus();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_syncFocus);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _syncFocus() {
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final style = AppType.display(
      widget.fontSize,
      italic: true,
      height: widget.lineHeight / widget.fontSize,
      color: tokens.fg,
    );
    final maxLength = widget.maxLength;
    return AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.selectionShift),
      curve: Curves.ease,
      padding: const EdgeInsets.only(bottom: SerifInput.bottomPadding),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _focused ? tokens.coral : tokens.line2,
            width: SerifInput.underlineWidth,
          ),
        ),
      ),
      child: Row(
        spacing: SerifInput.trailingGap,
        children: [
          Expanded(child: _field(style, maxLength)),
          ?widget.trailing,
        ],
      ),
    );
  }

  Widget _field(TextStyle style, int? maxLength) {
    final tokens = AppTokens.of(context);
    final field = TextField(
      key: widget.fieldKey,
      controller: widget.controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      obscureText: widget.obscured,
      obscuringCharacter: SerifInput.obscuringCharacter,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      textAlign: widget.textAlign,
      style: style,
      cursorColor: tokens.coral,
      cursorHeight: widget.fontSize,
      inputFormatters: [
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      decoration: InputDecoration.collapsed(
        hintText: widget.placeholder,
        hintStyle: style.copyWith(color: tokens.faint),
      ),
    );
    return switch (widget.semanticLabel) {
      final label? => MergeSemantics(
        child: Semantics(label: label, child: field),
      ),
      null => field,
    };
  }
}
