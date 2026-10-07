import 'package:flutter/widgets.dart';

class WholeWordText extends StatelessWidget {
  const WholeWordText(String this.data, {super.key, this.style, this.textAlign})
    : textSpan = null;

  const WholeWordText.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.textAlign,
  }) : data = null;

  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scaler = _fittedScaler(context, constraints.maxWidth);
      return switch ((data, textSpan)) {
        (final String data, _) => Text(
          data,
          style: style,
          textAlign: textAlign,
          textScaler: scaler,
        ),
        (_, final InlineSpan span) => Text.rich(
          span,
          style: style,
          textAlign: textAlign,
          textScaler: scaler,
        ),
        _ => const SizedBox.shrink(),
      };
    },
  );

  TextScaler _fittedScaler(BuildContext context, double maxWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    if (!maxWidth.isFinite) {
      return scaler;
    }
    final scaled = _longestWord(context, scaler);
    if (scaled <= maxWidth) {
      return scaler;
    }
    final unscaled = _longestWord(context, TextScaler.noScaling);
    final fits = (maxWidth / unscaled * 100).floorToDouble() / 100;
    return scaler.clamp(maxScaleFactor: fits);
  }

  double _longestWord(BuildContext context, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.merge(style),
        text: data,
        children: [?textSpan],
      ),
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
      textScaler: scaler,
    )..layout();
    final width = painter.minIntrinsicWidth;
    painter.dispose();
    return width;
  }
}
