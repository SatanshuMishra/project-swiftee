import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/together/server_link.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/together/room_controller.dart';
import 'package:swiftie_quiz/state/together/room_state.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/kit/serif_input.dart';
import 'package:swiftie_quiz/ui/screens/settings_screen.dart' show Spinner;
import 'package:swiftie_quiz/ui/screens/together/together_nav.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/ui/together/together_copy.dart';
import 'package:swiftie_quiz/ui/widgets/back_link.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';
import 'package:together_protocol/together_protocol.dart';

final RegExp _notLetters = RegExp('[^A-Za-z]');

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  static const String title = 'Join a room';
  static const String subtitle = 'Ask the host for their 4-letter code.';
  static const String placeholder = 'ABCD';
  static const String joinLabel = 'Join →';
  static const String joiningLabel = 'Joining…';

  static const double top = 20;
  static const double bottom = 100;
  static const double gap = 32;
  static const double headingGap = 12;
  static const double entryGap = 20;
  static const double inputWidth = 280;
  static const double inputFontSize = 64;
  static const double inputLineHeight = 72;
  static const double failureRise = 8;
  static const double spinnerTrackAlpha = 0.25;

  static String cleanCode(String text) {
    final letters = text.replaceAll(_notLetters, '').toUpperCase();
    return letters.length > roomCodeLength
        ? letters.substring(0, roomCodeLength)
        : letters;
  }

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clean(String text) {
    final code = JoinRoomScreen.cleanCode(text);
    if (code != text) {
      _controller.value = TextEditingValue(
        text: code,
        selection: TextSelection.collapsed(offset: code.length),
      );
    }
  }

  void _join() {
    final link = ServerLink.parse(
      ref.read(gameControllerProvider).progress.settings.togetherLink ?? '',
    );
    if (link != null) {
      unawaited(
        ref.read(roomControllerProvider.notifier).join(link, _controller.text),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    final (status, roomFailure) = ref.watch(
      roomControllerProvider.select((room) => (room.status, room.failure)),
    );
    final joining = status == RoomStatus.connecting;
    final failure = status == RoomStatus.idle ? roomFailure : null;
    return ScreenEnter(
      child: LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: viewport.hasBoundedHeight ? viewport.maxHeight : 0,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                layout.padX,
                JoinRoomScreen.top,
                layout.padX,
                JoinRoomScreen.bottom,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: JoinRoomScreen.gap,
                children: [
                  BackLink(onPressed: () => backToHub(ref)),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: JoinRoomScreen.headingGap,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          JoinRoomScreen.title,
                          style: AppType.display(
                            layout.h1,
                            height: 1,
                            color: tokens.fg,
                          ),
                        ),
                      ),
                      Text(
                        JoinRoomScreen.subtitle,
                        style: AppType.bodyLarge.copyWith(color: tokens.mut),
                      ),
                    ],
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: JoinRoomScreen.entryGap,
                    runSpacing: JoinRoomScreen.entryGap,
                    children: [
                      SizedBox(
                        width: JoinRoomScreen.inputWidth,
                        child: SerifInput(
                          controller: _controller,
                          placeholder: JoinRoomScreen.placeholder,
                          fontSize: JoinRoomScreen.inputFontSize,
                          lineHeight: JoinRoomScreen.inputLineHeight,
                          autofocus: true,
                          onChanged: _clean,
                          onSubmitted: (_) => _join(),
                        ),
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _controller,
                        builder: (context, value, _) => PillButton(
                          label: joining
                              ? JoinRoomScreen.joiningLabel
                              : JoinRoomScreen.joinLabel,
                          size: PillSize.large,
                          enabled: value.text.length == roomCodeLength,
                          leading: joining
                              ? Spinner(
                                  track: tokens.onCoral.withValues(
                                    alpha: JoinRoomScreen.spinnerTrackAlpha,
                                  ),
                                  arc: tokens.onCoral,
                                )
                              : null,
                          onPressed: _join,
                        ),
                      ),
                    ],
                  ),
                  if (failure != null)
                    Entrance(
                      key: ValueKey(failure),
                      fromOffset: const Offset(0, JoinRoomScreen.failureRise),
                      child: Text(
                        failureLine(failure),
                        style: AppType.sized(
                          14,
                          20,
                        ).copyWith(color: tokens.rose),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
