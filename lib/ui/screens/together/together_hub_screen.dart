import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/state/together/room_controller.dart';
import 'package:swiftie_quiz/ui/kit/arrow_row.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/kit/two_pane.dart';
import 'package:swiftie_quiz/ui/kit/whole_word_text.dart';
import 'package:swiftie_quiz/ui/screens/together/together_nav.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/ui/widgets/back_link.dart';

class TogetherHubScreen extends ConsumerWidget {
  const TogetherHubScreen({super.key});

  static const String title = 'Play together';
  static const String subtitle =
      'Same room or far apart. One person hosts, everyone else joins with a '
      'code. No accounts.';
  static const String hostTitle = 'Host a room';
  static const String hostDescription = 'Pick a game, then share the code.';
  static const String joinTitle = 'Join a room';
  static const String joinDescription = 'Got a code from a friend? Pop it in.';

  static const double leftTop = 20;
  static const double leftBottom = 32;
  static const double leftGap = 14;
  static const double subtitleMaxWidth = 320;
  static const double rightTop = 24;
  static const double rightBottom = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    void open(TogetherScreen screen) {
      ref.read(roomControllerProvider.notifier).clearFailure();
      ref.read(togetherNavProvider.notifier).show(screen);
    }

    return ScreenEnter(
      child: TwoPane(
        left: FocusTraversalGroup(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              layout.padX,
              leftTop,
              layout.padX,
              leftBottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: leftGap,
              children: [
                BackLink(onPressed: () => leavePlayTogether(ref)),
                Semantics(
                  header: true,
                  child: WholeWordText(
                    title,
                    style: AppType.display(
                      layout.h1,
                      height: 1,
                      color: tokens.fg,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: subtitleMaxWidth),
                  child: Text(
                    subtitle,
                    style: AppType.body.copyWith(color: tokens.mut),
                  ),
                ),
              ],
            ),
          ),
        ),
        right: FocusTraversalGroup(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              layout.padX,
              rightTop,
              layout.padX,
              rightBottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ArrowRow(
                  title: hostTitle,
                  description: hostDescription,
                  primary: true,
                  onTap: () => open(TogetherScreen.host),
                ),
                ArrowRow(
                  title: joinTitle,
                  description: joinDescription,
                  onTap: () => open(TogetherScreen.join),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
