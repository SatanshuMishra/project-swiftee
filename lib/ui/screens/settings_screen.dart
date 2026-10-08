import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:swiftie_quiz/data/together/relay_connection.dart';
import 'package:swiftie_quiz/domain/engine/misu_lines.dart';
import 'package:swiftie_quiz/domain/models/backup_entry.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/domain/together/server_link.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/persistence_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/toast_controller.dart';
import 'package:swiftie_quiz/state/updater_controller.dart';
import 'package:swiftie_quiz/ui/kit/confirm_dialog.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/kit/section_label.dart';
import 'package:swiftie_quiz/ui/kit/segmented.dart';
import 'package:swiftie_quiz/ui/kit/serif_input.dart';
import 'package:swiftie_quiz/ui/kit/text_link.dart';
import 'package:swiftie_quiz/ui/kit/two_pane.dart';
import 'package:swiftie_quiz/ui/kit/whole_word_text.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/ui/widgets/back_link.dart';

final DateFormat _momentFormat = DateFormat("MMM d, y 'at' h:mm a", 'en_US');

String _formatMoment(DateTime moment) => _momentFormat.format(moment.toLocal());

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const String title = 'Settings';
  static const String subtitle = 'Saved as you go.';

  static const String lookAndSoundLabel = 'Look and sound';
  static const String timersLabel = 'Timers';
  static const String togetherLabel = 'Play together';
  static const String updatesLabel = 'Updates';
  static const String storageLabel = 'Storage';
  static const String backupsLabel = 'Backups';
  static const String progressLabel = 'Progress';

  static const String themeTitle = 'Theme';
  static const String themeNote = 'System follows your computer.';
  static const String volumeTitle = 'Volume';
  static const String misuTitle = 'Misu visits';
  static const String misuNote = 'How often he drops by with a word.';
  static const String nicknameTitle = 'Nickname';
  static const String nicknameNote = 'Shown in the app.';
  static const String mediumTitle = 'Medium';
  static const String hardTitle = 'Hard';
  static const String timerNote = 'Seconds to answer each round.';
  static const String serverLinkTitle = 'Server link';
  static const String serverLinkNote =
      'Paste the link from whoever runs your server.';
  static const String notTogetherLink = "That isn't a Play together link.";
  static const String linkRefused = "The server didn't accept that link.";
  static const String serverNeedsUpdate =
      'That server needs a newer Project Swiftie.';
  static const String serverBusy = 'The server is busy. Try again in a minute.';
  static const String serverUnreachable = "Couldn't reach the server.";
  static const String clearLink = 'Clear';
  static const String appName = 'Project Swiftie';
  static const String lastCheckedPrefix = 'Last checked ';
  static const String checkNow = 'Check now';
  static const String checking = 'Checking…';
  static const String upToDate = "You're up to date.";
  static const String autoCheckTitle = 'Check for updates automatically';
  static const String autoCheckNote =
      'Sends only a standard request to GitHub. No analytics or tracking.';
  static const String saveCoversTitle = 'Save album covers';
  static const String saveCoversNote =
      'Keeps covers for new releases on this computer. Turning it off removes '
      'them.';
  static const String backupsNote =
      'The three most recent automatic backups are kept.';
  static const String restore = 'Restore';
  static const String restoreTitle = 'Restore this backup?';
  static const String restoreMessage =
      'Your current save will be replaced with this one.';
  static const String restoreFailurePrefix = 'Could not restore backup: ';
  static const String restored = 'Backup restored';
  static const String progressReset = 'Progress reset';
  static const String resetTitle = 'Reset progress';
  static const String resetNote = 'Clears the record shelf and all stats.';
  static const String resetAction = 'Reset…';
  static const String resetConfirmTitle = 'Reset all progress?';
  static const String resetConfirmLabel = 'Reset progress';
  static const String madeForAna =
      'Made for Ana by Satanshu with ♥️ and lots of ☕';
  static const String madeBy = 'Made by Satanshu';
  static const String appIcon = 'assets/brand/app-icon.svg';

  static const List<(ThemeSetting, String)> themeOptions = [
    (ThemeSetting.dark, 'Dark'),
    (ThemeSetting.light, 'Light'),
    (ThemeSetting.system, 'System'),
  ];
  static const List<(MisuVisits, String)> misuOptions = [
    (MisuVisits.often, 'Often'),
    (MisuVisits.sometimes, 'Now and then'),
    (MisuVisits.off, 'Off'),
  ];

  static const int shownBackups = 3;
  static const double minTimer = 10;
  static const double maxTimer = 40;
  static const int timerDivisions = 6;
  static const int volumeDivisions = 100;
  static const double volumeWidth = 180;
  static const double timerWidth = 150;
  static const double nicknameWidth = 180;
  static const double sectionsTop = 12;
  static const double sectionsBottom = 48;

  static String resetMessage(String name) =>
      'This clears ${name == 'you' ? 'your' : "$name's"} record shelf and '
      'stats. Backups stay available.';

  static String connectedTo(String host) => 'Connected to $host.';

  static String aboutLine(Edition edition) => switch (edition) {
    Edition.ana => madeForAna,
    Edition.open => madeBy,
  };

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  List<BackupEntry> _backups = const [];
  bool _checkRequested = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBackups());
  }

  Future<void> _loadBackups() async {
    List<BackupEntry> backups;
    try {
      final listed = await ref
          .read(persistenceControllerProvider.notifier)
          .listBackups();
      backups = List.unmodifiable(
        listed
            .sorted((a, b) => b.timestamp.compareTo(a.timestamp))
            .take(SettingsScreen.shownBackups),
      );
    } on Object {
      backups = const [];
    }
    if (mounted) {
      setState(() => _backups = backups);
    }
  }

  void _checkNow() {
    if (ref.read(updaterStateProvider) is UpdaterChecking) {
      return;
    }
    setState(() => _checkRequested = true);
    unawaited(ref.read(updaterControllerProvider).check(manual: true));
  }

  void _setSaveCovers(bool enabled) {
    final progress = ref.read(gameControllerProvider).progress;
    ref
        .read(gameControllerProvider.notifier)
        .setProgress(
          progress.copyWith(
            settings: progress.settings.copyWith(saveCovers: enabled),
          ),
        );
  }

  void _setAutoCheck(bool enabled) {
    final progress = ref.read(gameControllerProvider).progress;
    ref
        .read(gameControllerProvider.notifier)
        .setProgress(
          progress.copyWith(
            updater: progress.updater.copyWith(autoCheckEnabled: enabled),
          ),
        );
  }

  Future<void> _confirmReset() async {
    final name = displayName(
      ref.read(editionProvider),
      ref.read(gameControllerProvider).progress.settings.nickname,
    );
    final confirmed = await showConfirmDialog(
      context,
      title: SettingsScreen.resetConfirmTitle,
      message: SettingsScreen.resetMessage(name),
      confirmLabel: SettingsScreen.resetConfirmLabel,
      destructive: true,
    );
    if (confirmed && mounted) {
      ref.read(gameControllerProvider.notifier).resetProgress();
      ref
          .read(toastControllerProvider.notifier)
          .show(SettingsScreen.progressReset);
    }
  }

  Future<void> _restore(BackupEntry backup) async {
    final confirmed = await showConfirmDialog(
      context,
      title: SettingsScreen.restoreTitle,
      message: SettingsScreen.restoreMessage,
      confirmLabel: SettingsScreen.restore,
    );
    if (!confirmed || !mounted) {
      return;
    }
    String outcome;
    try {
      await ref
          .read(persistenceControllerProvider.notifier)
          .restoreBackup(backup.timestamp);
      outcome = SettingsScreen.restored;
    } on Object catch (error) {
      outcome = '${SettingsScreen.restoreFailurePrefix}$error';
    }
    if (mounted) {
      ref.read(toastControllerProvider.notifier).show(outcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.read(gameControllerProvider.notifier);
    final layout = AppLayout.of(context);
    final edition = ref.watch(editionProvider);
    return Material(
      type: MaterialType.transparency,
      child: ScreenEnter(
        child: TwoPane(
          left: FocusTraversalGroup(
            child: _SettingsIntro(onBack: () => game.setPhase(GamePhase.menu)),
          ),
          right: FocusTraversalGroup(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                layout.padX,
                SettingsScreen.sectionsTop,
                layout.padX,
                SettingsScreen.sectionsBottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionHeading(
                    SettingsScreen.lookAndSoundLabel,
                    first: true,
                  ),
                  _LookAndSound(showNickname: edition == Edition.open),
                  const _SectionHeading(SettingsScreen.timersLabel),
                  const _Timers(),
                  const _SectionHeading(SettingsScreen.togetherLabel),
                  const _SettingRow(
                    label: _RowLabel(
                      title: SettingsScreen.serverLinkTitle,
                      note: SettingsScreen.serverLinkNote,
                    ),
                    control: _ServerLinkField(),
                  ),
                  const _SectionHeading(SettingsScreen.updatesLabel),
                  _Updates(
                    checkRequested: _checkRequested,
                    onCheck: _checkNow,
                    onAutoCheck: _setAutoCheck,
                  ),
                  const _SectionHeading(SettingsScreen.storageLabel),
                  _ToggleRow(
                    title: SettingsScreen.saveCoversTitle,
                    note: SettingsScreen.saveCoversNote,
                    enabled: ref.watch(
                      gameControllerProvider.select(
                        (state) => state.progress.settings.saveCovers,
                      ),
                    ),
                    onChanged: _setSaveCovers,
                  ),
                  const _SectionHeading(SettingsScreen.backupsLabel),
                  _Backups(backups: _backups, onRestore: _restore),
                  const _SectionHeading(SettingsScreen.progressLabel),
                  _SettingRow(
                    label: const _RowLabel(
                      title: SettingsScreen.resetTitle,
                      note: SettingsScreen.resetNote,
                    ),
                    control: _LinePill(
                      label: SettingsScreen.resetAction,
                      tone: _PillTone.rose,
                      padding: _LinePill.wide,
                      onPressed: _confirmReset,
                    ),
                  ),
                  _About(line: SettingsScreen.aboutLine(edition)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsIntro extends StatelessWidget {
  const _SettingsIntro({required this.onBack});

  static const double top = 20;
  static const double bottom = 32;
  static const double gap = 14;

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(layout.padX, top, layout.padX, bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: gap,
        children: [
          BackLink(onPressed: onBack, animateEntrance: false),
          Semantics(
            header: true,
            child: WholeWordText(
              SettingsScreen.title,
              style: AppType.display(layout.h1, height: 1, color: tokens.fg),
            ),
          ),
          Text(
            SettingsScreen.subtitle,
            style: AppType.body.copyWith(color: tokens.mut),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text, {this.first = false});

  static const double firstTop = 22;
  static const double top = 30;
  static const double bottom = 4;

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: first ? firstTop : top, bottom: bottom),
    child: Semantics(header: true, child: SectionLabel(text)),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.control});

  static const double padding = 16;
  static const double spacing = 20;
  static const double runSpacing = 12;

  final Widget label;
  final Widget control;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: padding),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: AppTokens.of(context).line)),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: spacing,
      runSpacing: runSpacing,
      children: [label, control],
    ),
  );
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.title, required this.note});

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppType.body.copyWith(color: tokens.fg)),
        Text(note, style: AppType.small.copyWith(color: tokens.mut)),
      ],
    );
  }
}

class _LookAndSound extends ConsumerWidget {
  const _LookAndSound({required this.showNickname});

  final bool showNickname;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.read(gameControllerProvider.notifier);
    final settings = ref.watch(
      gameControllerProvider.select((state) => state.progress.settings),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingRow(
          label: const _RowLabel(
            title: SettingsScreen.themeTitle,
            note: SettingsScreen.themeNote,
          ),
          control: Segmented<ThemeSetting>(
            options: SettingsScreen.themeOptions,
            value: settings.theme,
            onChanged: game.setTheme,
          ),
        ),
        _SettingRow(
          label: _RowLabel(
            title: SettingsScreen.volumeTitle,
            note: '${(settings.volume * 100).round()}%',
          ),
          control: _CoralSlider(
            label: SettingsScreen.volumeTitle,
            width: SettingsScreen.volumeWidth,
            value: settings.volume,
            min: 0,
            max: 1,
            divisions: SettingsScreen.volumeDivisions,
            describe: (value) => '${(value * 100).round()}%',
            onChanged: (value) => game.setVolume(
              (value * SettingsScreen.volumeDivisions).round() /
                  SettingsScreen.volumeDivisions,
            ),
          ),
        ),
        _SettingRow(
          label: const _RowLabel(
            title: SettingsScreen.misuTitle,
            note: SettingsScreen.misuNote,
          ),
          control: Segmented<MisuVisits>(
            options: SettingsScreen.misuOptions,
            value: settings.misuVisits,
            onChanged: game.setMisuVisits,
          ),
        ),
        if (showNickname)
          const _SettingRow(
            label: _RowLabel(
              title: SettingsScreen.nicknameTitle,
              note: SettingsScreen.nicknameNote,
            ),
            control: _NicknameField(),
          ),
      ],
    );
  }
}

class _NicknameField extends ConsumerStatefulWidget {
  const _NicknameField();

  static const double top = 6;
  static const double fontSize = 22;
  static const double lineHeight = 28;

  @override
  ConsumerState<_NicknameField> createState() => _NicknameFieldState();
}

class _NicknameFieldState extends ConsumerState<_NicknameField> {
  late final TextEditingController _controller = TextEditingController(
    text: _stored,
  );
  final FocusNode _focus = FocusNode(debugLabel: 'Nickname');

  String get _stored =>
      ref.read(gameControllerProvider).progress.settings.nickname ?? '';

  @override
  void initState() {
    super.initState();
    _focus.addListener(_showStoredOnBlur);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_showStoredOnBlur)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _showStoredOnBlur() {
    if (!_focus.hasFocus && _controller.text != _stored) {
      _controller.text = _stored;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      gameControllerProvider.select(
        (state) => state.progress.settings.nickname,
      ),
      (_, next) {
        if ((next ?? '') != _controller.text.trim()) {
          _controller.text = next ?? '';
        }
      },
    );
    return SizedBox(
      width: SettingsScreen.nicknameWidth,
      child: Padding(
        padding: const EdgeInsets.only(top: _NicknameField.top),
        child: SerifInput(
          controller: _controller,
          focusNode: _focus,
          fontSize: _NicknameField.fontSize,
          lineHeight: _NicknameField.lineHeight,
          maxLength: nicknameMaxLength,
          textAlign: TextAlign.right,
          semanticLabel: SettingsScreen.nicknameTitle,
          onChanged: ref.read(gameControllerProvider.notifier).setNickname,
        ),
      ),
    );
  }
}

typedef _LinkCheck = ({ServerLink link, bool done, RelayFailure? failure});

class _ServerLinkField extends ConsumerStatefulWidget {
  const _ServerLinkField();

  @override
  ConsumerState<_ServerLinkField> createState() => _ServerLinkFieldState();
}

class _ServerLinkFieldState extends ConsumerState<_ServerLinkField> {
  late final TextEditingController _controller = TextEditingController(
    text: _stored,
  );
  final FocusNode _focus = FocusNode(debugLabel: 'Server link');
  _LinkCheck? _check;
  int _checks = 0;
  bool _editing = false;

  String get _stored =>
      ref.read(gameControllerProvider).progress.settings.togetherLink ?? '';

  @override
  void initState() {
    super.initState();
    _focus.addListener(_syncFocus);
    if (ServerLink.parse(_stored) case final link?) {
      _check = _startCheck(link);
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_syncFocus)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _syncFocus() {
    if (!_focus.hasFocus && _controller.text != _stored) {
      _controller.text = _stored;
    }
    if (_editing != _focus.hasFocus) {
      setState(() => _editing = _focus.hasFocus);
    }
  }

  void _clear() {
    _controller.clear();
    ref.read(gameControllerProvider.notifier).setTogetherLink('');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
      }
    });
  }

  _LinkCheck _startCheck(ServerLink link) {
    final check = ++_checks;
    unawaited(_finishCheck(check, link));
    return (link: link, done: false, failure: null);
  }

  Future<void> _finishCheck(int check, ServerLink link) async {
    RelayFailure? failure;
    try {
      await ref.read(relayConnectorProvider).check(link);
    } on RelayRefused catch (refused) {
      failure = refused.failure;
    } on Object {
      failure = RelayFailure.unreachable;
    }
    if (mounted && check == _checks) {
      setState(() => _check = (link: link, done: true, failure: failure));
    }
  }

  void _saved(String? next) {
    if (next != ServerLink.parse(_controller.text)?.text) {
      _controller.text = next ?? '';
    }
    if (ServerLink.parse(next ?? '') case final link?) {
      setState(() => _check = _startCheck(link));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      gameControllerProvider.select(
        (state) => state.progress.settings.togetherLink,
      ),
      (_, next) => _saved(next),
    );
    final locked =
        !_editing &&
        ref.watch(
          gameControllerProvider.select(
            (state) => state.progress.settings.togetherLink != null,
          ),
        );
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: _NicknameField.top),
            child: SerifInput(
              controller: _controller,
              focusNode: _focus,
              fontSize: _NicknameField.fontSize,
              lineHeight: _NicknameField.lineHeight,
              enabled: !locked,
              obscured: locked,
              semanticLabel: SettingsScreen.serverLinkTitle,
              onChanged: ref
                  .read(gameControllerProvider.notifier)
                  .setTogetherLink,
              trailing: locked
                  ? SizedBox(
                      height: _NicknameField.lineHeight,
                      child: OverflowBox(
                        fit: OverflowBoxFit.deferToChild,
                        maxHeight: TextLink.minHeight,
                        child: TextLink(
                          label: SettingsScreen.clearLink,
                          onTap: _clear,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) =>
                _LinkStatus(text: value.text, check: _check),
          ),
        ],
      ),
    );
  }
}

class _LinkStatus extends StatelessWidget {
  const _LinkStatus({required this.text, required this.check});

  static const double top = 6;

  final String text;
  final _LinkCheck? check;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final link = ServerLink.parse(text);
    final check = this.check;
    final (String, Color)? line = switch (link) {
      _ when text.trim().isEmpty => null,
      null => (SettingsScreen.notTogetherLink, tokens.rose),
      _ when check == null || check.link != link => null,
      _ when !check.done => (SettingsScreen.checking, tokens.mut),
      _ => switch (check.failure) {
        null => (SettingsScreen.connectedTo(link.host), tokens.mut),
        RelayFailure.badLink => (SettingsScreen.linkRefused, tokens.rose),
        RelayFailure.needsUpdate => (
          SettingsScreen.serverNeedsUpdate,
          tokens.rose,
        ),
        RelayFailure.busy => (SettingsScreen.serverBusy, tokens.rose),
        RelayFailure.unreachable => (
          SettingsScreen.serverUnreachable,
          tokens.rose,
        ),
      },
    };
    if (line == null) {
      return const SizedBox.shrink();
    }
    final (message, color) = line;
    return Padding(
      padding: const EdgeInsets.only(top: top),
      child: _RiseIn(
        key: ValueKey(message),
        child: Text(message, style: AppType.small.copyWith(color: color)),
      ),
    );
  }
}

class _Timers extends ConsumerWidget {
  const _Timers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.read(gameControllerProvider.notifier);
    final (medium, hard) = ref.watch(
      gameControllerProvider.select(
        (state) => (
          state.progress.settings.mediumTimer,
          state.progress.settings.hardTimer,
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TimerRow(
          title: SettingsScreen.mediumTitle,
          seconds: medium,
          onChanged: game.setMediumTimer,
        ),
        _TimerRow(
          title: SettingsScreen.hardTitle,
          seconds: hard,
          onChanged: game.setHardTimer,
        ),
      ],
    );
  }
}

class _TimerRow extends StatelessWidget {
  const _TimerRow({
    required this.title,
    required this.seconds,
    required this.onChanged,
  });

  static const double gap = 12;
  static const double valueWidth = 32;
  static const double valueSize = 14;

  final String title;
  final int seconds;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return _SettingRow(
      label: _RowLabel(title: title, note: SettingsScreen.timerNote),
      control: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: gap,
        children: [
          _CoralSlider(
            label: title,
            width: SettingsScreen.timerWidth,
            value: seconds.toDouble(),
            min: SettingsScreen.minTimer,
            max: SettingsScreen.maxTimer,
            divisions: SettingsScreen.timerDivisions,
            describe: (value) => '${value.round()} seconds',
            onChanged: (value) => onChanged(value.round()),
          ),
          SizedBox(
            width:
                valueWidth *
                MediaQuery.textScalerOf(context).scale(valueSize) /
                valueSize,
            child: Text(
              '${seconds}s',
              textAlign: TextAlign.right,
              style: AppType.sized(valueSize, 20).copyWith(
                color: tokens.fg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoralSlider extends StatelessWidget {
  const _CoralSlider({
    required this.label,
    required this.width,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.describe,
    required this.onChanged,
  });

  static const double height = 24;
  static const BorderRadius focusRadius = BorderRadius.all(
    Radius.circular(999),
  );

  final String label;
  final double width;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double value) describe;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return _FocusRing(
      radius: focusRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: tokens.coral,
            thumbColor: tokens.coral,
            thumbShape: const _CoralThumbShape(),
          ),
          child: MergeSemantics(
            child: Semantics(
              label: label,
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                semanticFormatterCallback: describe,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoralThumbShape extends ChromiumSliderThumbShape {
  const _CoralThumbShape();

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final fill = Color.lerp(
      sliderTheme.disabledThumbColor,
      sliderTheme.thumbColor,
      enableAnimation.value,
    )!;
    const radius = ChromiumSliderThumbShape.diameter / 2;
    context.canvas
      ..drawCircle(
        center,
        radius,
        Paint()..color = ChromiumControlColors.background,
      )
      ..drawCircle(
        center,
        radius - ChromiumSliderThumbShape.borderWidth,
        Paint()..color = fill,
      );
  }
}

class _FocusRing extends StatefulWidget {
  const _FocusRing({required this.child, required this.radius});

  final Widget child;
  final BorderRadius radius;

  @override
  State<_FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<_FocusRing> {
  bool _focused = false;
  FocusHighlightMode _mode = FocusManager.instance.highlightMode;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_setMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_setMode);
    super.dispose();
  }

  void _setMode(FocusHighlightMode mode) {
    if (mounted && mode != _mode) {
      setState(() => _mode = mode);
    }
  }

  void _setFocused(bool focused) {
    if (focused != _focused) {
      setState(() => _focused = focused);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _focused && _mode == FocusHighlightMode.traditional;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _setFocused,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: visible
            ? BoxDecoration(
                borderRadius: widget.radius,
                border: Border.all(
                  color: AppTokens.of(context).coral,
                  width: Pressable.focusRingWidth,
                  strokeAlign:
                      BorderSide.strokeAlignOutside +
                      2 * Pressable.focusRingGap / Pressable.focusRingWidth,
                ),
              )
            : const BoxDecoration(),
        child: widget.child,
      ),
    );
  }
}

class _Updates extends ConsumerWidget {
  const _Updates({
    required this.checkRequested,
    required this.onCheck,
    required this.onAutoCheck,
  });

  static const double monoSize = 13;
  static const String monoFamily = 'Menlo';
  static const List<String> monoFallbacks = ['Consolas', 'monospace'];

  final bool checkRequested;
  final VoidCallback onCheck;
  final ValueChanged<bool> onAutoCheck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final version = ref.watch(appVersionProvider).value;
    final (lastCheckedAt, autoCheck) = ref.watch(
      gameControllerProvider.select(
        (state) => (
          state.progress.updater.lastCheckedAt,
          state.progress.updater.autoCheckEnabled,
        ),
      ),
    );
    final updater = ref.watch(updaterStateProvider);
    final checking = updater is UpdaterChecking;
    final lastChecked = DateTime.tryParse(lastCheckedAt ?? '');
    final result = checkRequested
        ? switch (updater) {
            UpdaterUpToDate() => SettingsScreen.upToDate,
            UpdaterError(subtype: UpdaterErrorSubtype.check, :final message) =>
              message,
            _ => null,
          }
        : null;
    final muted = AppType.small.copyWith(color: tokens.mut);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingRow(
          label: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: version == null
                      ? SettingsScreen.appName
                      : '${SettingsScreen.appName} ',
                  children: [
                    if (version != null)
                      TextSpan(
                        text: 'v$version',
                        style: TextStyle(
                          fontFamily: monoFamily,
                          fontFamilyFallback: monoFallbacks,
                          fontSize: monoSize,
                          color: tokens.mut,
                        ),
                      ),
                  ],
                ),
                style: AppType.body.copyWith(color: tokens.fg),
              ),
              if (lastChecked != null)
                Text(
                  '${SettingsScreen.lastCheckedPrefix}'
                  '${_formatMoment(lastChecked)}',
                  style: muted,
                ),
              if (result != null)
                _RiseIn(
                  key: ValueKey(result),
                  child: Text(
                    result,
                    style: AppType.small.copyWith(color: tokens.coralT),
                  ),
                ),
            ],
          ),
          control: _LinePill(
            label: checking ? SettingsScreen.checking : SettingsScreen.checkNow,
            leading: checking ? const Spinner() : null,
            padding: _LinePill.wide,
            onPressed: onCheck,
          ),
        ),
        _ToggleRow(
          title: SettingsScreen.autoCheckTitle,
          note: SettingsScreen.autoCheckNote,
          enabled: autoCheck,
          onChanged: onAutoCheck,
        ),
      ],
    );
  }
}

class _RiseIn extends StatelessWidget {
  const _RiseIn({super.key, required this.child});

  static const Duration duration = Duration(milliseconds: 300);
  static const double offset = 8;

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.duration(context, duration),
    curve: Curves.ease,
    builder: (context, progress, child) => Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, offset * (1 - progress)),
        child: child,
      ),
    ),
    child: child,
  );
}

class Spinner extends StatefulWidget {
  const Spinner({super.key, this.track, this.arc});

  static const double size = 12;
  static const double stroke = 2;
  static const Duration period = Duration(milliseconds: 800);

  final Color? track;
  final Color? arc;

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _turns = AnimationController(
    vsync: this,
    duration: Spinner.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _turns.stop();
    } else if (!_turns.isAnimating) {
      unawaited(_turns.repeat());
    }
  }

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return RotationTransition(
      turns: _turns,
      child: CustomPaint(
        size: const Size.square(Spinner.size),
        painter: _SpinnerPainter(
          track: widget.track ?? tokens.line2,
          arc: widget.arc ?? tokens.coral,
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  const _SpinnerPainter({required this.track, required this.arc});

  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(Spinner.stroke / 2);
    Paint stroke(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = Spinner.stroke
      ..color = color;
    canvas
      ..drawOval(rect, stroke(track))
      ..drawArc(rect, -3 * math.pi / 4, math.pi / 2, false, stroke(arc));
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) =>
      oldDelegate.track != track || oldDelegate.arc != arc;
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.note,
    required this.enabled,
    required this.onChanged,
  });

  static const double gap = 20;
  static const BorderRadius focusRadius = BorderRadius.all(Radius.circular(4));

  final String title;
  final String note;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return MergeSemantics(
      child: Pressable(
        onPressed: () => onChanged(!enabled),
        focusRadius: focusRadius,
        builder: (context, _) => Container(
          padding: const EdgeInsets.symmetric(vertical: _SettingRow.padding),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.line)),
          ),
          child: Row(
            spacing: gap,
            children: [
              Expanded(
                child: _RowLabel(title: title, note: note),
              ),
              Semantics(
                toggled: enabled,
                child: _Switch(on: enabled),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.on});

  static const Size trackSize = Size(36, 20);
  static const double inset = 2;
  static const double knob = 16;
  static const Color knobColor = Color(0xFFFFFFFF);
  static const Color knobShadow = Color.from(
    alpha: 0.25,
    red: 0,
    green: 0,
    blue: 0,
  );
  static const BorderRadius radius = BorderRadius.all(Radius.circular(999));

  final bool on;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final shift = AppMotion.duration(context, AppMotion.selectionShift);
    return AnimatedContainer(
      duration: shift,
      curve: Curves.ease,
      width: trackSize.width,
      height: trackSize.height,
      padding: const EdgeInsets.all(inset),
      decoration: BoxDecoration(
        color: on ? tokens.coral : tokens.line2,
        borderRadius: radius,
      ),
      child: AnimatedAlign(
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        duration: shift,
        curve: AppMotion.hoverLiftCurve,
        child: const SizedBox.square(
          dimension: knob,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: knobColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: knobShadow,
                  offset: Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Backups extends StatelessWidget {
  const _Backups({required this.backups, required this.onRestore});

  static const EdgeInsets notePadding = EdgeInsets.only(top: 12, bottom: 6);
  static const double rowPadding = 12;
  static const double gap = 16;

  final List<BackupEntry> backups;
  final ValueChanged<BackupEntry> onRestore;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: notePadding,
          child: Text(
            SettingsScreen.backupsNote,
            style: AppType.small.copyWith(color: tokens.mut),
          ),
        ),
        for (final backup in backups)
          Container(
            padding: const EdgeInsets.symmetric(vertical: rowPadding),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.line)),
            ),
            child: Row(
              spacing: gap,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatMoment(
                          DateTime.fromMillisecondsSinceEpoch(
                            backup.timestamp * Duration.millisecondsPerSecond,
                          ),
                        ),
                        style: AppType.sized(14, 20).copyWith(color: tokens.fg),
                      ),
                      Text(
                        '${(backup.sizeBytes / 1024).toStringAsFixed(1)} KB',
                        style: AppType.caption.copyWith(color: tokens.mut),
                      ),
                    ],
                  ),
                ),
                _LinePill(
                  label: SettingsScreen.restore,
                  padding: _LinePill.compact,
                  onPressed: () => onRestore(backup),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _About extends StatelessWidget {
  const _About({required this.line});

  static const double top = 28;
  static const double gap = 12;
  static const double iconSize = 40;
  static const BorderRadius iconRadius = BorderRadius.all(Radius.circular(9));

  final String line;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: top),
      child: Row(
        spacing: gap,
        children: [
          ClipRRect(
            borderRadius: iconRadius,
            child: SvgPicture.asset(
              SettingsScreen.appIcon,
              width: iconSize,
              height: iconSize,
              excludeFromSemantics: true,
            ),
          ),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SettingsScreen.appName,
                  style: AppType.sized(14, 20).copyWith(color: tokens.fg),
                ),
                Text(line, style: AppType.caption.copyWith(color: tokens.mut)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _PillTone { neutral, rose }

class _LinePill extends StatelessWidget {
  const _LinePill({
    required this.label,
    required this.padding,
    required this.onPressed,
    this.tone = _PillTone.neutral,
    this.leading,
  });

  static const EdgeInsets wide = EdgeInsets.symmetric(
    vertical: 8,
    horizontal: 16,
  );
  static const EdgeInsets compact = EdgeInsets.symmetric(
    vertical: 6,
    horizontal: 14,
  );
  static const double leadingGap = 8;

  final String label;
  final EdgeInsets padding;
  final VoidCallback onPressed;
  final _PillTone tone;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final (border, ink, hoverFill) = switch (tone) {
      _PillTone.neutral => (tokens.line2, tokens.fg, tokens.hover),
      _PillTone.rose => (tokens.rose, tokens.rose, tokens.roseBg),
    };
    return Pressable(
      onPressed: onPressed,
      focusRadius: PillButton.radius,
      builder: (context, state) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: state.hovered ? hoverFill : null,
          borderRadius: PillButton.radius,
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: leadingGap,
          children: [
            ?leading,
            Text(label, style: AppType.small.copyWith(color: ink)),
          ],
        ),
      ),
    );
  }
}
