import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/kit/whole_word_text.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

class RoundHeading extends StatelessWidget {
  const RoundHeading({
    super.key,
    this.pre = '',
    this.song = '',
    this.post = '',
    this.subline = '',
    this.urgent = false,
  }) : kicker = null;

  const RoundHeading.question({
    super.key,
    required String this.kicker,
    required this.song,
    this.subline = '',
    this.urgent = false,
  }) : pre = '',
       post = '';

  static const double titleHeight = 1.02;
  static const double gap = 8;
  static const double questionGap = 6;

  final String? kicker;
  final String pre;
  final String song;
  final String post;
  final String subline;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final size = AppLayout.of(context).h1;
    final sublineColor = urgent ? tokens.rose : tokens.mut;
    final kicker = this.kicker;
    if (kicker != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kicker, style: AppType.body.copyWith(color: tokens.mut)),
          const SizedBox(height: questionGap),
          WholeWordText(
            '$song?',
            style: AppType.display(
              size,
              italic: true,
              height: titleHeight,
              color: tokens.coralT,
            ),
          ),
          const SizedBox(height: questionGap),
          _line(subline, AppType.body.copyWith(color: sublineColor)),
        ],
      );
    }
    final hasTitle = pre.isNotEmpty || song.isNotEmpty || post.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTitle)
          WholeWordText.rich(
            TextSpan(
              children: [
                if (pre.isNotEmpty) TextSpan(text: pre),
                if (song.isNotEmpty)
                  TextSpan(
                    text: song,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: tokens.coralT,
                    ),
                  ),
                if (post.isNotEmpty) TextSpan(text: post),
              ],
            ),
            style: AppType.display(size, height: titleHeight, color: tokens.fg),
          ),
        const SizedBox(height: gap),
        _line(subline, AppType.bodyLarge.copyWith(color: sublineColor)),
      ],
    );
  }

  Widget _line(String text, TextStyle style) =>
      text.isEmpty ? const SizedBox.shrink() : Text(text, style: style);
}
