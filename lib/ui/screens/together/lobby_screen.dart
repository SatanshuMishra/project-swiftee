import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/state/together/room_controller.dart';
import 'package:swiftie_quiz/state/together/room_state.dart';
import 'package:swiftie_quiz/state/together/together_game_controller.dart';
import 'package:swiftie_quiz/ui/kit/confirm_dialog.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/kit/section_label.dart';
import 'package:swiftie_quiz/ui/kit/text_link.dart';
import 'package:swiftie_quiz/ui/kit/two_pane.dart';
import 'package:swiftie_quiz/ui/kit/whole_word_text.dart';
import 'package:swiftie_quiz/ui/screens/record_shelf_screen.dart'
    show DashedOutlinePainter;
import 'package:swiftie_quiz/ui/screens/together/together_nav.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/ui/together/player_avatar.dart';
import 'package:swiftie_quiz/ui/together/together_copy.dart';
import 'package:swiftie_quiz/ui/widgets/back_link.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';
import 'package:together_protocol/together_protocol.dart';

Future<void> confirmLeaveRoom(BuildContext context, WidgetRef ref) async {
  final room = ref.read(roomControllerProvider);
  final leave = leaveAction(ref);
  if (room.status != RoomStatus.open) {
    leave();
    return;
  }
  final hosting = room.role == RoomRole.host;
  final confirmed = await showConfirmDialog(
    context,
    title: hosting ? LobbyScreen.hostLeaveTitle : LobbyScreen.guestLeaveTitle,
    message: hosting
        ? LobbyScreen.hostLeaveMessage
        : LobbyScreen.guestLeaveMessage,
    confirmLabel: hosting
        ? LobbyScreen.hostLeaveConfirm
        : LobbyScreen.guestLeaveConfirm,
    destructive: true,
  );
  if (confirmed) {
    leave();
  }
}

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  static const String leaveLabel = 'Leave room';
  static const String guestLeaveTitle = 'Leave the room?';
  static const String guestLeaveMessage =
      'You can join again with the same code while the room is open.';
  static const String guestLeaveConfirm = 'Leave';
  static const String hostLeaveTitle = 'Close the room?';
  static const String hostLeaveMessage =
      'Everyone in it goes back to the menu.';
  static const String hostLeaveConfirm = 'Close room';
  static const String codeLabel = 'Room code';
  static const String copyLabel = 'Copy code';
  static const String copiedLabel = 'Copied';
  static const String changeGameLabel = 'Change game';
  static const String playersTitle = 'Players';
  static const String youSuffix = ' (you)';
  static const String hostTag = 'Host';
  static const String waitingForFriends = 'Waiting for friends to join…';
  static const String startLabel = 'Start game →';
  static const String needsPlayers = 'Needs at least 2 players';
  static const String startFailed = "Couldn't get the songs ready. Try again.";

  static const Duration copiedFor = Duration(milliseconds: 1600);
  static const int minPlayers = 2;

  static String roomLabel(String code) => 'Room $code';
  static String hostsRoom(String host) => "$host's room";
  static String playerCount(int players) => '$players of $maxPlayers players';
  static String waitingForHost(String host) => 'Waiting for $host to start…';

  static const double leftTop = 20;
  static const double leftBottom = 32;
  static const double leftGap = 22;
  static const double codeGap = 12;
  static const double guestGap = 8;
  static const double summaryTop = 16;
  static const double summaryGap = 6;
  static const double rightTop = 32;
  static const double rightBottom = 40;
  static const double rightGap = 20;
  static const double startGap = 14;
  static const double failureRise = 8;

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  Timer? _copied;

  @override
  void dispose() {
    _copied?.cancel();
    super.dispose();
  }

  void _copy(String code) {
    unawaited(Clipboard.setData(ClipboardData(text: code)));
    _copied?.cancel();
    setState(() => _copied = Timer(LobbyScreen.copiedFor, _uncopy));
  }

  void _uncopy() {
    if (mounted) {
      setState(() => _copied = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomControllerProvider);
    final failure = room.failure;
    if (room.status == RoomStatus.closed && failure != null) {
      return RoomClosedPanel(
        failure: failure,
        host: room.closedBy ?? room.hostName ?? '',
      );
    }
    final hosting = room.role == RoomRole.host;
    return ScreenEnter(
      child: TwoPane(
        left: FocusTraversalGroup(
          child: _LobbyIntro(
            room: room,
            hosting: hosting,
            copied: _copied != null,
            onCopy: _copy,
          ),
        ),
        right: FocusTraversalGroup(
          child: _LobbyPlayers(room: room, hosting: hosting),
        ),
      ),
    );
  }
}

class _LobbyIntro extends ConsumerWidget {
  const _LobbyIntro({
    required this.room,
    required this.hosting,
    required this.copied,
    required this.onCopy,
  });

  final RoomState room;
  final bool hosting;
  final bool copied;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    final code = room.code ?? '';
    final settings = room.settings;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.padX,
        LobbyScreen.leftTop,
        layout.padX,
        LobbyScreen.leftBottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: LobbyScreen.leftGap,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: BackLink(
              label: LobbyScreen.leaveLabel,
              onPressed: () => unawaited(confirmLeaveRoom(context, ref)),
            ),
          ),
          if (hosting)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: LobbyScreen.codeGap,
              children: [
                const SectionLabel(LobbyScreen.codeLabel),
                _CodeTiles(code: code),
                PillButton(
                  label: copied
                      ? LobbyScreen.copiedLabel
                      : LobbyScreen.copyLabel,
                  kind: PillKind.outline,
                  onPressed: () => onCopy(code),
                ),
              ],
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: LobbyScreen.guestGap,
              children: [
                SectionLabel(LobbyScreen.roomLabel(code)),
                Semantics(
                  header: true,
                  child: WholeWordText(
                    LobbyScreen.hostsRoom(room.hostName ?? ''),
                    style: AppType.display(
                      layout.h1,
                      height: 1,
                      color: tokens.fg,
                    ),
                  ),
                ),
              ],
            ),
          Container(
            padding: const EdgeInsets.only(top: LobbyScreen.summaryTop),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: tokens.line)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: LobbyScreen.summaryGap,
              children: [
                Text(
                  settings.mode.title,
                  style: AppType.display(28, height: 32 / 28, color: tokens.fg),
                ),
                Text(
                  settings.mode.description,
                  style: AppType.sized(14, 20).copyWith(color: tokens.mut),
                ),
                Text(
                  roomMeta(settings, room.scopeLabel),
                  style: AppType.small.copyWith(color: tokens.fg),
                ),
                if (hosting)
                  TextLink(
                    label: LobbyScreen.changeGameLabel,
                    onTap: () => ref
                        .read(togetherNavProvider.notifier)
                        .show(TogetherScreen.host),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeTiles extends StatelessWidget {
  const _CodeTiles({required this.code});

  static const double width = 58;
  static const double height = 72;
  static const double gap = 8;
  static const BorderRadius radius = BorderRadius.all(Radius.circular(10));

  final String code;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Semantics(
      label: code,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: gap,
          children: [
            for (final letter in code.split(''))
              Container(
                width: width,
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.card,
                  borderRadius: radius,
                  border: Border.all(color: tokens.line2),
                ),
                child: Text(
                  letter,
                  style: AppType.display(48, height: 1, color: tokens.fg),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LobbyPlayers extends ConsumerWidget {
  const _LobbyPlayers({required this.room, required this.hosting});

  final RoomState room;
  final bool hosting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    final startFailed = ref.watch(
      togetherGameControllerProvider.select((game) => game.startFailed),
    );
    final players = room.players;
    final reduced = AppMotion.reduced(context);
    final canStart = players.length >= LobbyScreen.minPlayers;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.padX,
        LobbyScreen.rightTop,
        layout.padX,
        LobbyScreen.rightBottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: LobbyScreen.rightGap,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: _PlayerRow.gap,
            children: [
              Expanded(
                child: Text(
                  LobbyScreen.playersTitle,
                  style: AppType.display(36, height: 40 / 36, color: tokens.fg),
                ),
              ),
              Text(
                LobbyScreen.playerCount(players.length),
                style: AppType.small.copyWith(color: tokens.mut),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final player in players)
                reduced
                    ? _PlayerRow(
                        key: ValueKey(player.id),
                        player: player,
                        you: player.id == room.you?.id,
                        host: player.id == room.hostId,
                      )
                    : Entrance(
                        key: ValueKey(player.id),
                        fromOffset: const Offset(0, _PlayerRow.rise),
                        child: _PlayerRow(
                          player: player,
                          you: player.id == room.you?.id,
                          host: player.id == room.hostId,
                        ),
                      ),
              _WaitingRow(
                label: hosting
                    ? LobbyScreen.waitingForFriends
                    : LobbyScreen.waitingForHost(room.hostName ?? ''),
              ),
            ],
          ),
          if (hosting)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: LobbyScreen.startGap,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: LobbyScreen.startGap,
                  runSpacing: LobbyScreen.startGap,
                  children: [
                    PillButton(
                      label: LobbyScreen.startLabel,
                      size: PillSize.large,
                      enabled: canStart,
                      onPressed: () => unawaited(
                        ref
                            .read(togetherGameControllerProvider.notifier)
                            .start(),
                      ),
                    ),
                    Text(
                      LobbyScreen.needsPlayers,
                      style: AppType.small.copyWith(color: tokens.faint),
                    ),
                  ],
                ),
                if (startFailed)
                  Entrance(
                    fromOffset: const Offset(0, LobbyScreen.failureRise),
                    child: Text(
                      LobbyScreen.startFailed,
                      style: AppType.sized(14, 20).copyWith(color: tokens.rose),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    super.key,
    required this.player,
    required this.you,
    required this.host,
  });

  static const double padding = 14;
  static const double gap = 14;
  static const double avatarSize = 32;
  static const double rise = 10;

  final Player player;
  final bool you;
  final bool host;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: padding),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Row(
        spacing: gap,
        children: [
          PlayerAvatar(
            seed: player.avatar,
            name: player.name,
            size: avatarSize,
          ),
          Expanded(
            child: Text(
              you ? '${player.name}${LobbyScreen.youSuffix}' : player.name,
              style: AppType.bodyLarge.copyWith(
                height: 22 / 16,
                color: tokens.fg,
              ),
            ),
          ),
          if (host)
            Text(
              LobbyScreen.hostTag,
              style: AppType.caption.copyWith(color: tokens.mut),
            ),
        ],
      ),
    );
  }
}

class _WaitingRow extends StatelessWidget {
  const _WaitingRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _PlayerRow.padding),
      child: Row(
        spacing: _PlayerRow.gap,
        children: [
          CustomPaint(
            painter: DashedOutlinePainter(
              color: tokens.line2,
              radius: _PlayerRow.avatarSize / 2,
            ),
            child: const SizedBox.square(
              dimension: _PlayerRow.avatarSize,
              child: Center(child: _PulsingDot()),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: AppType.sized(14, 20).copyWith(color: tokens.faint),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  static const double size = 8;
  static const double dimmest = 0.3;
  static const Duration period = Duration(milliseconds: 1200);

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _PulsingDot.period,
    lowerBound: _PulsingDot.dimmest,
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _pulse
        ..stop()
        ..value = 1;
    } else if (!_pulse.isAnimating) {
      unawaited(_pulse.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _pulse,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTokens.of(context).faint,
      ),
      child: const SizedBox.square(dimension: _PulsingDot.size),
    ),
  );
}

class RoomClosedPanel extends ConsumerWidget {
  const RoomClosedPanel({super.key, required this.failure, required this.host});

  static const String backToMenuLabel = 'Back to menu';
  static const double padBottom = 60;
  static const double gap = 20;
  static const double messageMaxWidth = 520;

  final RoomFailure failure;
  final String host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    return ScreenEnter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(layout.padX, 0, layout.padX, padBottom),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: gap,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: messageMaxWidth),
                child: Text(
                  failureLine(failure, host: host),
                  textAlign: TextAlign.center,
                  style: AppType.display(36, height: 40 / 36, color: tokens.fg),
                ),
              ),
              PillButton(
                label: backToMenuLabel,
                kind: PillKind.outline,
                size: PillSize.large,
                onPressed: () => leavePlayTogether(ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
