import 'package:flutter/material.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/ui/widgets/motion.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/primary_button.dart';

class QuizCard extends StatelessWidget {
  const QuizCard({
    super.key,
    required this.difficulty,
    required this.options,
    required this.albumHint,
    required this.onAnswer,
    required this.disabled,
  });

  static const double maxWidth = 512;
  static const double gap = 16;
  static const double optionGap = 12;
  static const Duration optionStagger = Duration(milliseconds: 50);
  static const Offset optionEntranceOffset = Offset(-10, 0);

  final Difficulty difficulty;
  final List<Track> options;
  final String? albumHint;
  final ValueChanged<Object> onAnswer;
  final bool disabled;

  static String optionLabel(Track track) =>
      track.titleShort.isNotEmpty ? track.titleShort : track.title;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final hint = albumHint;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (difficulty == Difficulty.easy && hint != null && hint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: gap),
            child: Text(
              'Album: $hint',
              style: AppText.sm.copyWith(color: tokens.mutedForeground),
            ),
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: difficulty == Difficulty.hard
              ? _AnswerForm(onAnswer: onAnswer, disabled: disabled)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, track) in options.indexed) ...[
                      if (index > 0) const SizedBox(height: optionGap),
                      Motion(
                        key: ValueKey(track.id),
                        initial: const MotionPose(
                          opacity: 0,
                          offset: optionEntranceOffset,
                        ),
                        delay: optionStagger * index,
                        child: _OptionButton(
                          label: optionLabel(track),
                          disabled: disabled,
                          onPressed: () => onAnswer(track.id),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _OptionButton extends StatefulWidget {
  const _OptionButton({
    required this.label,
    required this.disabled,
    required this.onPressed,
  });

  static const double padding = 16;
  static const double borderWidth = 2;
  static const int hoverBorderPercent = 50;
  static const double disabledOpacity = 0.5;

  final String label;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  State<_OptionButton> createState() => _OptionButtonState();
}

class _OptionButtonState extends State<_OptionButton>
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
    _hover.animateTo(hovered ? 1 : 0, curve: AppMotion.cssTransitionCurve);
  }

  void _activate() {
    if (!widget.disabled) {
      widget.onPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final enabled = !widget.disabled;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.basic : SystemMouseCursors.forbidden,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: FocusableActionDetector(
        enabled: enabled,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: Semantics(
          button: true,
          enabled: enabled,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? widget.onPressed : null,
            child: AnimatedOpacity(
              opacity: enabled ? 1 : _OptionButton.disabledOpacity,
              duration: AppMotion.cssTransitionDuration,
              curve: AppMotion.cssTransitionCurve,
              child: AnimatedBuilder(
                animation: _hover,
                builder: (context, child) => Container(
                  padding: const EdgeInsets.all(_OptionButton.padding),
                  decoration: BoxDecoration(
                    color: Oklab.mix(
                      tokens.background,
                      tokens.card,
                      _hover.value,
                    ),
                    border: Border.all(
                      color: Oklab.mix(
                        tokens.border,
                        tokens.primary.slashOpacity(
                          _OptionButton.hoverBorderPercent,
                        ),
                        _hover.value,
                      ),
                      width: _OptionButton.borderWidth,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                  ),
                  child: child,
                ),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.start,
                  style: AppText.base.copyWith(
                    fontWeight: FontWeight.w500,
                    color: tokens.foreground,
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

class _AnswerForm extends StatefulWidget {
  const _AnswerForm({required this.onAnswer, required this.disabled});

  static const String placeholder = 'Type your answer...';
  static const double gap = 12;
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );
  static const int fillPercent = 30;
  static const int focusBorderPercent = 50;
  static const int ringPercent = 20;
  static const double ringWidth = 2;
  static const int placeholderPercent = 50;

  final ValueChanged<Object> onAnswer;
  final bool disabled;

  @override
  State<_AnswerForm> createState() => _AnswerFormState();
}

class _AnswerFormState extends State<_AnswerForm>
    with SingleTickerProviderStateMixin {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  late final AnimationController _focusRing = AnimationController(
    vsync: this,
    duration: AppMotion.cssTransitionDuration,
  );

  @override
  void initState() {
    super.initState();
    _text.addListener(_onTextChanged);
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _focusRing.dispose();
    super.dispose();
  }

  String get _answer => _text.text.trim();

  void _onTextChanged() => setState(() {});

  void _onFocusChanged() => _focusRing.animateTo(
    _focus.hasFocus ? 1 : 0,
    curve: AppMotion.cssTransitionCurve,
  );

  void _submit() {
    final answer = _answer;
    if (answer.isNotEmpty) {
      widget.onAnswer(answer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final canSubmit = !widget.disabled && _answer.isNotEmpty;
    final textStyle = AppText.lg.copyWith(color: tokens.foreground);
    final ring = tokens.primary.slashOpacity(_AnswerForm.ringPercent);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _focusRing,
          builder: (context, child) => Container(
            width: double.infinity,
            padding: _AnswerForm.padding,
            decoration: BoxDecoration(
              color: tokens.muted.slashOpacity(_AnswerForm.fillPercent),
              border: Border.all(
                color: Oklab.mix(
                  tokens.border,
                  tokens.primary.slashOpacity(_AnswerForm.focusBorderPercent),
                  _focusRing.value,
                ),
              ),
              borderRadius: BorderRadius.circular(AppRadii.xl),
              boxShadow: [
                BoxShadow(
                  color: Oklab.mix(
                    ring.withValues(alpha: 0),
                    ring,
                    _focusRing.value,
                  ),
                  spreadRadius: _AnswerForm.ringWidth * _focusRing.value,
                ),
              ],
            ),
            child: child,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: TextField(
              controller: _text,
              focusNode: _focus,
              autofocus: true,
              enabled: !widget.disabled,
              textAlign: TextAlign.center,
              style: textStyle,
              cursorColor: tokens.foreground,
              cursorWidth: 1,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration.collapsed(
                hintText: _AnswerForm.placeholder,
                hintStyle: textStyle.copyWith(
                  color: tokens.foreground.slashOpacity(
                    _AnswerForm.placeholderPercent,
                  ),
                ),
              ),
              onEditingComplete: _submit,
            ),
          ),
        ),
        const SizedBox(height: _AnswerForm.gap),
        PrimaryButton(label: 'Submit', onPressed: canSubmit ? _submit : null),
      ],
    );
  }
}
