import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/game/next_prompt.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

enum LyricPaperKind { liner, quote }

class LyricPaper extends StatelessWidget {
  const LyricPaper({
    super.key,
    required this.lines,
    this.song,
    this.era,
    this.coverUrl,
    this.placeholder,
    this.revealed = false,
    this.showHint = false,
  }) : kind = LyricPaperKind.liner;

  const LyricPaper.quote({super.key, required this.lines})
    : kind = LyricPaperKind.quote,
      song = null,
      era = null,
      coverUrl = null,
      placeholder = null,
      revealed = false,
      showHint = false;

  static const double maxWidth = 440;
  static const double gap = 14;
  static const double tiltDegrees = -1;
  static const linerPadding = EdgeInsets.fromLTRB(30, 28, 30, 20);
  static const quotePadding = EdgeInsets.fromLTRB(26, 24, 26, 18);
  static const double quoteGap = 12;
  static const radius = BorderRadius.all(Radius.circular(6));
  static const double hintCover = 44;
  static const double headerCover = 36;
  static const double hintGap = 12;
  static const double headerGap = 10;
  static const double headerPadding = 12;
  static const headerRise = Duration(milliseconds: 350);
  static const headerRule = Color.from(
    alpha: 0.12,
    red: 59 / 255,
    green: 47 / 255,
    blue: 47 / 255,
  );
  static const eraInk = Color.from(
    alpha: 0.6,
    red: 59 / 255,
    green: 47 / 255,
    blue: 47 / 255,
  );

  final LyricPaperKind kind;
  final List<String> lines;
  final String? song;
  final String? era;
  final String? coverUrl;
  final Color? placeholder;
  final bool revealed;
  final bool showHint;

  String? get hintText => switch (era) {
    final era? when showHint => 'From $era',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final lineStyle = AppType.display(
      24,
      italic: true,
      height: 32 / 24,
      color: tokens.paperFg,
    );
    if (kind == LyricPaperKind.quote) {
      return _Paper(
        tokens: tokens,
        padding: quotePadding,
        shadowOffset: 14,
        shadowBlur: 32,
        children: [
          for (final (index, line) in lines.indexed) ...[
            if (index > 0) const SizedBox(height: quoteGap),
            Text('“$line”', style: lineStyle),
          ],
        ],
      );
    }
    final hint = hintText;
    final title = song;
    final paper = Transform.rotate(
      angle: tiltDegrees * math.pi / 180,
      child: _Paper(
        tokens: tokens,
        padding: linerPadding,
        shadowOffset: 18,
        shadowBlur: 40,
        children: [
          if (revealed && title != null) ...[
            RiseIn(
              duration: headerRise,
              child: Container(
                padding: const EdgeInsets.only(bottom: headerPadding),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: headerRule)),
                ),
                child: Row(
                  children: [
                    _Cover(
                      size: headerCover,
                      url: coverUrl,
                      placeholder: placeholder ?? tokens.designCard,
                    ),
                    const SizedBox(width: headerGap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppType.display(
                              22,
                              italic: true,
                              height: 24 / 22,
                              color: BrandColors.letterSignature,
                            ),
                          ),
                          if (era case final era?)
                            Text(
                              era,
                              style: AppType.caption.copyWith(color: eraInk),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: gap),
          ],
          for (final (index, line) in lines.indexed) ...[
            if (index > 0) const SizedBox(height: gap),
            Text(line, style: lineStyle),
          ],
        ],
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hint != null) ...[
            Row(
              children: [
                _Cover(
                  size: hintCover,
                  url: coverUrl,
                  placeholder: placeholder ?? tokens.designCard,
                  shadow: CssBoxShadow(
                    color: tokens.shadow,
                    offset: const Offset(0, 6),
                    blur: 14,
                  ),
                ),
                const SizedBox(width: hintGap),
                Flexible(
                  child: Text(
                    hint,
                    style: AppType.sized(14, 20).copyWith(color: tokens.mut),
                  ),
                ),
              ],
            ),
            const SizedBox(height: gap),
          ],
          paper,
        ],
      ),
    );
  }
}

class _Paper extends StatelessWidget {
  const _Paper({
    required this.tokens,
    required this.padding,
    required this.shadowOffset,
    required this.shadowBlur,
    required this.children,
  });

  final AppTokens tokens;
  final EdgeInsets padding;
  final double shadowOffset;
  final double shadowBlur;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.paper,
        borderRadius: LyricPaper.radius,
        boxShadow: [
          CssBoxShadow(
            color: tokens.shadow,
            offset: Offset(0, shadowOffset),
            blur: shadowBlur,
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({
    required this.size,
    required this.url,
    required this.placeholder,
    this.shadow,
  });

  static const radius = BorderRadius.all(Radius.circular(3));

  final double size;
  final String? url;
  final Color placeholder;
  final BoxShadow? shadow;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final shadow = this.shadow;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadow == null ? null : [shadow],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: placeholder),
              if (url != null)
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
