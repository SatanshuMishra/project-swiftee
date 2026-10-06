import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

enum AnswerState {
  idle,
  right,
  wrong,
  dim;

  static AnswerState of({
    required bool answered,
    required bool isRight,
    required bool isPicked,
  }) {
    if (!answered) {
      return AnswerState.idle;
    }
    if (isRight) {
      return AnswerState.right;
    }
    return isPicked ? AnswerState.wrong : AnswerState.dim;
  }
}

typedef AnswerLook = ({
  Color fill,
  Color border,
  Color ink,
  Color chipFill,
  Color chipInk,
});

AnswerLook answerLook(AnswerState state, AppTokens tokens, bool hovered) {
  final clear = tokens.designCard.withValues(alpha: 0);
  return switch (state) {
    AnswerState.idle => (
      fill: hovered ? tokens.designCard : clear,
      border: hovered ? tokens.coral : tokens.line2,
      ink: tokens.fg,
      chipFill: tokens.hover,
      chipInk: tokens.mut,
    ),
    AnswerState.right => (
      fill: tokens.coral,
      border: tokens.coral,
      ink: tokens.onCoral,
      chipFill: AnswerButton.rightChip,
      chipInk: tokens.onCoral,
    ),
    AnswerState.wrong => (
      fill: tokens.roseBg,
      border: tokens.rose,
      ink: tokens.rose,
      chipFill: clear,
      chipInk: tokens.rose,
    ),
    AnswerState.dim => (
      fill: clear,
      border: tokens.line,
      ink: tokens.faint,
      chipFill: clear,
      chipInk: tokens.faint,
    ),
  };
}

const _answerRadius = BorderRadius.all(Radius.circular(12));
const _colorMotion = Duration(milliseconds: 200);
const _pressMotion = Duration(milliseconds: 150);

class AnswerList extends StatelessWidget {
  const AnswerList({
    super.key,
    required this.labels,
    required this.onPick,
    this.answered = false,
    this.rightIndex,
    this.pickedIndex,
  });

  static const double gap = 10;

  final List<String> labels;
  final ValueChanged<int> onPick;
  final bool answered;
  final int? rightIndex;
  final int? pickedIndex;

  AnswerState stateAt(int index) => AnswerState.of(
    answered: answered,
    isRight: index == rightIndex,
    isPicked: index == pickedIndex,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          if (index > 0) const SizedBox(height: gap),
          AnswerButton(
            number: index + 1,
            label: labels[index],
            state: stateAt(index),
            onPressed: answered ? null : () => onPick(index),
          ),
        ],
      ],
    );
  }
}

class AnswerButton extends StatelessWidget {
  const AnswerButton({
    super.key,
    required this.number,
    required this.label,
    required this.state,
    required this.onPressed,
  });

  static const double minHeight = 56;
  static const padding = EdgeInsets.symmetric(vertical: 12, horizontal: 16);
  static const double gap = 14;
  static const double chipSize = 24;
  static const chipRadius = BorderRadius.all(Radius.circular(6));
  static const double dimOpacity = 0.55;
  static const double pressScale = 0.99;
  static const opacityMotion = Duration(milliseconds: 300);
  static const String rightMark = '✓';
  static const String wrongMark = '✕';
  static const rightChip = Color.from(
    alpha: 0.14,
    red: 26 / 255,
    green: 21 / 255,
    blue: 20 / 255,
  );

  final int number;
  final String label;
  final AnswerState state;
  final VoidCallback? onPressed;

  String get chipText => switch (state) {
    AnswerState.right => rightMark,
    AnswerState.wrong => wrongMark,
    AnswerState.idle || AnswerState.dim => '$number',
  };

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final colorShift = AppMotion.duration(context, _colorMotion);
    return AnimatedOpacity(
      opacity: state == AnswerState.dim ? dimOpacity : 1,
      duration: AppMotion.duration(context, opacityMotion),
      curve: Curves.ease,
      child: Pressable(
        onPressed: onPressed,
        focusRadius: _answerRadius,
        builder: (context, press) {
          final look = answerLook(state, tokens, press.hovered);
          final weight = state == AnswerState.right
              ? FontWeight.w600
              : FontWeight.w400;
          return AnimatedScale(
            scale: press.pressed ? pressScale : 1,
            duration: AppMotion.duration(context, _pressMotion),
            curve: Curves.ease,
            child: AnimatedContainer(
              duration: colorShift,
              curve: Curves.ease,
              constraints: const BoxConstraints(minHeight: minHeight),
              padding: padding,
              decoration: BoxDecoration(
                color: look.fill,
                borderRadius: _answerRadius,
                border: Border.all(color: look.border),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: colorShift,
                    curve: Curves.ease,
                    width: chipSize,
                    height: chipSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: look.chipFill,
                      borderRadius: chipRadius,
                    ),
                    child: Text(
                      chipText,
                      textAlign: TextAlign.center,
                      style: AppType.sized(
                        12,
                        24,
                        weight: FontWeight.w600,
                      ).copyWith(color: look.chipInk),
                    ),
                  ),
                  const SizedBox(width: gap),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: colorShift,
                      curve: Curves.ease,
                      style: AppType.sized(
                        18,
                        24,
                        weight: weight,
                      ).copyWith(color: look.ink),
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class RealFakeButtons extends StatelessWidget {
  const RealFakeButtons({
    super.key,
    required this.onPick,
    this.answered = false,
    this.isReal,
    this.picked,
  });

  static const String realLabel = 'Real';
  static const String fakeLabel = 'Fake';
  static const String realKey = 'R';
  static const String fakeKey = 'F';
  static const double gap = 12;

  final ValueChanged<bool> onPick;
  final bool answered;
  final bool? isReal;
  final bool? picked;

  AnswerState stateFor(bool value) => AnswerState.of(
    answered: answered,
    isRight: isReal == value,
    isPicked: picked == value,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RealFakeButton(
            label: realLabel,
            keyHint: realKey,
            state: stateFor(true),
            onPressed: answered ? null : () => onPick(true),
          ),
        ),
        const SizedBox(width: gap),
        Expanded(
          child: RealFakeButton(
            label: fakeLabel,
            keyHint: fakeKey,
            state: stateFor(false),
            onPressed: answered ? null : () => onPick(false),
          ),
        ),
      ],
    );
  }
}

class RealFakeButton extends StatelessWidget {
  const RealFakeButton({
    super.key,
    required this.label,
    required this.keyHint,
    required this.state,
    required this.onPressed,
  });

  static const double gap = 10;
  static const double borderWidth = 1;
  static const double minHeight = AnswerButton.minHeight + 2 * borderWidth;
  static const double hintOpacity = 0.55;
  static const hintPadding = EdgeInsets.symmetric(horizontal: 6);
  static const hintRadius = BorderRadius.all(Radius.circular(4));
  static const double pressScale = 0.98;

  final String label;
  final String keyHint;
  final AnswerState state;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final colorShift = AppMotion.duration(context, _colorMotion);
    return Pressable(
      onPressed: onPressed,
      focusRadius: _answerRadius,
      semanticLabel: label,
      builder: (context, press) {
        final look = answerLook(state, tokens, false);
        final border = state == AnswerState.idle && press.hovered
            ? tokens.coral
            : look.border;
        return AnimatedScale(
          scale: press.pressed ? pressScale : 1,
          duration: AppMotion.duration(context, _pressMotion),
          curve: Curves.ease,
          child: AnimatedContainer(
            duration: colorShift,
            curve: Curves.ease,
            constraints: const BoxConstraints(minHeight: minHeight),
            decoration: BoxDecoration(
              color: look.fill,
              borderRadius: _answerRadius,
              border: Border.all(color: border),
            ),
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: look.ink),
              duration: colorShift,
              curve: Curves.ease,
              builder: (context, ink, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: AppType.display(26, height: 30 / 26, color: ink),
                  ),
                  const SizedBox(width: gap),
                  Opacity(
                    opacity: hintOpacity,
                    child: Container(
                      padding: hintPadding,
                      decoration: BoxDecoration(
                        borderRadius: hintRadius,
                        border: Border.all(color: ink ?? look.ink),
                      ),
                      child: Text(
                        keyHint,
                        style: AppType.sized(11, 18).copyWith(color: ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
