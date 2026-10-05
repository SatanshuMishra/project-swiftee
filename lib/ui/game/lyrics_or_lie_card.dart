import 'package:flutter/material.dart';
import 'package:swiftie_quiz/ui/game/lyric_snippet_card.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';

class LyricsOrLieCard extends StatelessWidget {
  const LyricsOrLieCard({
    super.key,
    required this.songTitle,
    required this.albumCover,
    required this.showAlbumCover,
    required this.lyricLines,
    required this.onAnswer,
    required this.disabled,
  });

  static const String prompt = 'Is this lyric from...';
  static const String coverLabel = 'Album cover';
  static const Offset promptEntranceOffset = Offset(0, -5);
  static const Offset titleEntranceOffset = Offset(0, -10);
  static const double gap = 24;
  static const double titleGap = 16;
  static const double coverSize = 64;
  static const double buttonsMaxWidth = 384;
  static const double buttonGap = 16;

  final String songTitle;
  final String? albumCover;
  final bool showAlbumCover;
  final List<String> lyricLines;
  final ValueChanged<bool> onAnswer;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final cover = albumCover;
    final showCover = showAlbumCover && cover != null && cover.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Entrance(
          fromOffset: promptEntranceOffset,
          child: Text(
            prompt,
            style: AppText.sm.copyWith(color: tokens.mutedForeground),
          ),
        ),
        const SizedBox(height: gap),
        Entrance(
          fromOffset: titleEntranceOffset,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showCover) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  child: Image.network(
                    cover,
                    width: coverSize,
                    height: coverSize,
                    fit: BoxFit.cover,
                    semanticLabel: coverLabel,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.square(dimension: coverSize),
                  ),
                ),
                const SizedBox(width: titleGap),
              ],
              Flexible(
                child: Text(
                  songTitle,
                  style: AppText.xl2.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tokens.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: gap),
        LyricSnippetCard(lines: lyricLines),
        const SizedBox(height: gap),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: buttonsMaxWidth),
          child: Row(
            children: [
              Expanded(
                child: _VerdictButton(
                  verdict: _Verdict.real,
                  disabled: disabled,
                  onPressed: () => onAnswer(true),
                ),
              ),
              const SizedBox(width: buttonGap),
              Expanded(
                child: _VerdictButton(
                  verdict: _Verdict.fake,
                  disabled: disabled,
                  onPressed: () => onAnswer(false),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _Verdict {
  real('Real', LucideGlyph.check),
  fake('Fake', LucideGlyph.x);

  const _Verdict(this.label, this.glyph);

  final String label;
  final LucideGlyph glyph;
}

class _VerdictButton extends StatefulWidget {
  const _VerdictButton({
    required this.verdict,
    required this.disabled,
    required this.onPressed,
  });

  static const double padding = 16;
  static const double borderWidth = 2;
  static const double iconSize = 20;
  static const double gap = 8;
  static const double hoverScale = 1.03;
  static const double tapScale = 0.97;
  static const double disabledOpacity = 0.5;
  static const int realBorderPercent = 30;
  static const int realHoverBorderPercent = 60;
  static const int realFillPercent = 5;
  static const int realHoverFillPercent = 10;
  static const int fakeHoverBorderPercent = 50;

  final _Verdict verdict;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  State<_VerdictButton> createState() => _VerdictButtonState();
}

class _VerdictButtonState extends State<_VerdictButton>
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

  ({Color border, Color fill, Color hoverBorder, Color hoverFill, Color text})
  _palette(AppTokens tokens) => switch (widget.verdict) {
    _Verdict.real => (
      border: AppPalette.green500.slashOpacity(
        _VerdictButton.realBorderPercent,
      ),
      fill: AppPalette.green500.slashOpacity(_VerdictButton.realFillPercent),
      hoverBorder: AppPalette.green500.slashOpacity(
        _VerdictButton.realHoverBorderPercent,
      ),
      hoverFill: AppPalette.green500.slashOpacity(
        _VerdictButton.realHoverFillPercent,
      ),
      text: AppPalette.green400,
    ),
    _Verdict.fake => (
      border: tokens.border,
      fill: tokens.background,
      hoverBorder: tokens.primary.slashOpacity(
        _VerdictButton.fakeHoverBorderPercent,
      ),
      hoverFill: tokens.card,
      text: tokens.foreground,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final palette = _palette(AppTokens.of(context));
    final enabled = !widget.disabled;
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(
          widget.verdict.glyph,
          size: _VerdictButton.iconSize,
          color: palette.text,
        ),
        const SizedBox(width: _VerdictButton.gap),
        Text(
          widget.verdict.label,
          style: AppText.base.copyWith(
            fontWeight: FontWeight.w500,
            color: palette.text,
          ),
        ),
      ],
    );
    return Entrance(
      fromOpacity: 1,
      spring: AppMotion.defaultScaleSpring,
      hoverScale: _VerdictButton.hoverScale,
      tapScale: _VerdictButton.tapScale,
      gesturesEnabled: enabled,
      child: MouseRegion(
        cursor: enabled
            ? SystemMouseCursors.basic
            : SystemMouseCursors.forbidden,
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
                opacity: enabled ? 1 : _VerdictButton.disabledOpacity,
                duration: AppMotion.cssTransitionDuration,
                curve: AppMotion.cssTransitionCurve,
                child: AnimatedBuilder(
                  animation: _hover,
                  builder: (context, child) => Container(
                    padding: const EdgeInsets.all(_VerdictButton.padding),
                    decoration: BoxDecoration(
                      color: Oklab.mix(
                        palette.fill,
                        palette.hoverFill,
                        _hover.value,
                      ),
                      border: Border.all(
                        color: Oklab.mix(
                          palette.border,
                          palette.hoverBorder,
                          _hover.value,
                        ),
                        width: _VerdictButton.borderWidth,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                    ),
                    child: child,
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
