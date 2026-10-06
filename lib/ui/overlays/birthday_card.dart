import 'package:flutter/material.dart';
import 'package:swiftie_quiz/ui/cat/cat_icon.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/swiftie_modal.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/ui/widgets/above_app_chrome.dart';

class BirthdayCard extends StatelessWidget {
  const BirthdayCard({super.key, required this.isOpen, required this.onClose});

  static const String dedication = 'For Ana';
  static const String heading = 'Happy Birthday!';
  static const String greeting = 'Dear Ana,';
  static const List<String> message = [
    'Sending you the warmest of wishes for a very Happy Birthday!',
    'Thank you for always being there for me over these past couple of '
        "years. I'm very grateful and lucky to have a friend like you.",
    "I've said it before, and I'll say it again: there is nothing you can't "
        'accomplish once you put your mind to it. As you enter this next '
        'year, which will hopefully be filled with exciting opportunities and '
        'unforgettable memories, I have no doubt in my mind that you will '
        'find success and reach the goals you set for yourself!',
    "I can't wait to see what you accomplish in the year ahead! Know that I "
        'am always rooting for you!',
  ];
  static const String closing = 'Your Best Friend,';
  static const String signature = 'Satanshu :)';
  static const String postscript = 'P.S. Meowwwww Meow Meaaww ~ Clef';
  static const String closeGlyph = '✕';
  static const String closeLabel = 'Close';

  static const double maxWidth = 540;
  static const double blur = 6;
  static const BorderRadius radius = BorderRadius.all(Radius.circular(14));
  static const double shadowOffset = 30;
  static const double shadowBlur = 70;
  static const double headerHeight = 132;
  static const double headerLeft = 28;
  static const double headerTop = 30;
  static const double headerGap = 2;
  static const double catHeight = 108;
  static const double catRight = 40;
  static const double catDrop = 34;
  static const EdgeInsets bodyPadding = EdgeInsets.fromLTRB(34, 28, 34, 34);
  static const double bodyGap = 16;
  static const double signatureTop = 6;
  static const double signatureGap = 2;
  static const double postscriptTop = 12;
  static const double closeInset = 12;
  static const double closeSize = 32;
  static const Duration closeHover = Duration(milliseconds: 150);

  static const Color dedicationColor = Color.from(
    alpha: 0.7,
    red: 26 / 255,
    green: 21 / 255,
    blue: 20 / 255,
  );
  static const Color closeFill = Color.from(
    alpha: 0.14,
    red: 26 / 255,
    green: 21 / 255,
    blue: 20 / 255,
  );
  static const Color closeFillHover = Color.from(
    alpha: 0.24,
    red: 26 / 255,
    green: 21 / 255,
    blue: 20 / 255,
  );
  static const Color ruleColor = Color.from(
    alpha: 0.12,
    red: 59 / 255,
    green: 47 / 255,
    blue: 47 / 255,
  );

  final bool isOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (!isOpen) {
      return const SizedBox.shrink();
    }
    return AboveAppChrome(
      child: SwiftieModal(
        bare: true,
        blur: blur,
        maxWidth: maxWidth,
        onDismiss: onClose,
        child: _Letter(onClose: onClose),
      ),
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.paper,
        borderRadius: BirthdayCard.radius,
        boxShadow: [
          CssBoxShadow(
            color: tokens.shadow,
            offset: const Offset(0, BirthdayCard.shadowOffset),
            blur: BirthdayCard.shadowBlur,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BirthdayCard.radius,
        child: Stack(
          children: [
            const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LetterHeader(),
                Flexible(child: _LetterBody()),
              ],
            ),
            Positioned(
              top: BirthdayCard.closeInset,
              right: BirthdayCard.closeInset,
              child: _CloseButton(onPressed: onClose),
            ),
          ],
        ),
      ),
    );
  }
}

class _LetterHeader extends StatelessWidget {
  const _LetterHeader();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: BirthdayCard.headerHeight,
    child: ColoredBox(
      color: BrandColors.birthdayHeader,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: BirthdayCard.headerLeft,
            top: BirthdayCard.headerTop,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: BirthdayCard.headerGap,
              children: [
                Text(
                  BirthdayCard.dedication,
                  style: AppType.sectionLabel.copyWith(
                    color: BirthdayCard.dedicationColor,
                  ),
                ),
                Text(
                  BirthdayCard.heading,
                  style: AppType.display(
                    44,
                    height: 1,
                    color: BrandColors.birthdayInk,
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            right: BirthdayCard.catRight,
            bottom: -BirthdayCard.catDrop,
            child: CatIcon(height: BirthdayCard.catHeight),
          ),
        ],
      ),
    ),
  );
}

class _LetterBody extends StatelessWidget {
  const _LetterBody();

  @override
  Widget build(BuildContext context) {
    final ink = AppTokens.of(context).paperFg;
    final paragraph = AppType.sized(16, 26).copyWith(color: ink);
    final signature = AppType.display(
      24,
      height: 28 / 24,
      color: BrandColors.letterSignature,
    );
    return ExcludeFocusTraversal(
      child: SelectionArea(
        child: SingleChildScrollView(
          padding: BirthdayCard.bodyPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: BirthdayCard.bodyGap,
            children: [
              Text(
                BirthdayCard.greeting,
                style: AppType.display(28, height: 32 / 28, color: ink),
              ),
              for (final line in BirthdayCard.message)
                Text(line, style: paragraph),
              Padding(
                padding: const EdgeInsets.only(top: BirthdayCard.signatureTop),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: BirthdayCard.signatureGap,
                  children: [
                    Text(BirthdayCard.closing, style: signature),
                    Text(BirthdayCard.signature, style: signature),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.only(top: BirthdayCard.postscriptTop),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: BirthdayCard.ruleColor),
                  ),
                ),
                child: Text(
                  BirthdayCard.postscript,
                  style: AppType.display(
                    20,
                    italic: true,
                    height: 26 / 20,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  static const BorderRadius focusRadius = BorderRadius.all(
    Radius.circular(BirthdayCard.closeSize / 2),
  );

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    onPressed: onPressed,
    focusRadius: focusRadius,
    semanticLabel: BirthdayCard.closeLabel,
    builder: (context, state) => AnimatedContainer(
      duration: AppMotion.duration(context, BirthdayCard.closeHover),
      curve: AppMotion.colorShiftCurve,
      width: BirthdayCard.closeSize,
      height: BirthdayCard.closeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: state.hovered
            ? BirthdayCard.closeFillHover
            : BirthdayCard.closeFill,
      ),
      child: ExcludeSemantics(
        child: Text(
          BirthdayCard.closeGlyph,
          style: AppType.sized(14, 20).copyWith(color: BrandColors.birthdayInk),
        ),
      ),
    ),
  );
}
