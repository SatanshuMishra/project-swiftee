import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';

class LyricSnippetCard extends StatelessWidget {
  const LyricSnippetCard({super.key, required this.lines});

  static const Offset entranceOffset = Offset(0, 10);
  static const double padding = 24;
  static const double radius = AppRadii.xl2;
  static const double lineGap = 12;
  static const double lineHeight = 1.8;

  final List<String> lines;

  static String quoted(String line) => '“$line”';

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final style = AppText.lg.copyWith(
      fontStyle: FontStyle.italic,
      height: lineHeight,
      color: tokens.foreground,
    );
    return Entrance(
      fromOffset: entranceOffset,
      child: Container(
        padding: const EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: tokens.card,
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, line) in lines.indexed) ...[
              if (index > 0) const SizedBox(height: lineGap),
              Text(quoted(line), textAlign: TextAlign.center, style: style),
            ],
          ],
        ),
      ),
    );
  }
}
