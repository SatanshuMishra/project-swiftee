import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/backup_entry.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/persistence_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/updater_controller.dart';
import 'package:swiftie_quiz/ui/screens/main_menu.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';
import 'package:swiftie_quiz/ui/widgets/swiftie_logo.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const double padding = 32;
  static const double gap = 32;
  static const double sectionPadding = 24;
  static const double indent = 44;
  static const Offset cardEntranceOffset = Offset(0, 20);
  static const Duration settingsCardDelay = Duration(milliseconds: 100);
  static const Duration updatesCardDelay = Duration(milliseconds: 200);
  static const Duration backupsCardDelay = Duration(milliseconds: 250);
  static const double volumeSliderWidth = 128;
  static const double timerSliderWidth = 96;
  static const double timerValueWidth = 32;
  static const double minTimer = 10;
  static const double maxTimer = 40;
  static const int timerDivisions = 6;
  static const int volumeDivisions = 100;
  static const double logoSize = 32;
  static const double checkboxOffset = 4;
  static const double finePrintSize = 11;
  static const String monospaceFont = 'Consolas';
  static const List<String> monospaceFallbacks = [
    'Menlo',
    'Monaco',
    'Liberation Mono',
    'Courier New',
    'monospace',
  ];

  static const String restorePrompt =
      'Restore this backup? Your current save will be replaced.';
  static const String restoreFailurePrefix = 'Could not restore backup: ';
  static const String neverChecked = 'Never';
  static const String telemetryNote =
      'Sends only the standard HTTP request to GitHub. No analytics, no '
      'install identifiers, no telemetry.';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  List<BackupEntry> _backups = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadBackups());
  }

  Future<void> _loadBackups() async {
    List<BackupEntry> backups;
    try {
      backups = List.unmodifiable(
        await ref.read(persistenceControllerProvider.notifier).listBackups(),
      );
    } on Object {
      backups = const [];
    }
    if (mounted) {
      setState(() => _backups = backups);
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await _showSettingsDialog(
      context,
      title: 'Reset Progress',
      message: 'Erase all achievements',
      actions: const [
        _DialogAction('Cancel', _DialogActionStyle.quiet, result: false),
        _DialogAction(
          'Confirm Reset',
          _DialogActionStyle.destructive,
          result: true,
        ),
      ],
    );
    if (confirmed ?? false) {
      ref.read(gameControllerProvider.notifier).resetProgress();
    }
  }

  Future<void> _restore(int timestamp) async {
    final confirmed = await _showSettingsDialog(
      context,
      message: SettingsScreen.restorePrompt,
      actions: const [
        _DialogAction('Cancel', _DialogActionStyle.quiet, result: false),
        _DialogAction('OK', _DialogActionStyle.outlined, result: true),
      ],
    );
    if (!(confirmed ?? false) || !mounted) {
      return;
    }
    try {
      await ref
          .read(persistenceControllerProvider.notifier)
          .restoreBackup(timestamp);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      await _showSettingsDialog(
        context,
        message: '${SettingsScreen.restoreFailurePrefix}$error',
        actions: const [
          _DialogAction('OK', _DialogActionStyle.outlined, result: true),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.read(gameControllerProvider.notifier);
    return ScreenScaffold(
      body: Padding(
        padding: const EdgeInsets.all(SettingsScreen.padding),
        child: Column(
          children: spacedVertically([
            BackHeader(
              maxWidth: TailwindContainers.md,
              onBack: () => game.setPhase(GamePhase.menu),
            ),
            const ScreenHeading(
              title: 'Settings',
              subtitle: 'Customize your experience',
            ),
            _SettingsCard(
              delay: SettingsScreen.settingsCardDelay,
              child: _PreferencesSection(onReset: _confirmReset),
            ),
            const _SettingsCard(
              delay: SettingsScreen.updatesCardDelay,
              child: _UpdatesSection(),
            ),
            _SettingsCard(
              delay: SettingsScreen.backupsCardDelay,
              child: _BackupsSection(backups: _backups, onRestore: _restore),
            ),
          ], SettingsScreen.gap),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Entrance(
      fromOffset: SettingsScreen.cardEntranceOffset,
      delay: delay,
      child: MaxWidthBox(
        maxWidth: TailwindContainers.md,
        child: Container(
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(AppRadii.xl2),
            border: Border.all(color: tokens.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.xl2 - 1),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PreferencesSection extends ConsumerWidget {
  const _PreferencesSection({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final game = ref.read(gameControllerProvider.notifier);
    final settings = ref.watch(
      gameControllerProvider.select((state) => state.progress.settings),
    );
    final divider = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SettingsScreen.sectionPadding,
      ),
      child: SizedBox(height: 1, child: ColoredBox(color: tokens.border)),
    );
    const sectionPadding = EdgeInsets.all(SettingsScreen.sectionPadding);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: sectionPadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: _SectionLabel(
                  glyph: LucideGlyph.moon,
                  title: 'Appearance',
                  subtitle: 'Choose your theme',
                ),
              ),
              _ThemePicker(selected: settings.theme, onSelect: game.setTheme),
            ],
          ),
        ),
        divider,
        Padding(
          padding: sectionPadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 16,
            children: [
              Flexible(
                child: _SectionLabel(
                  glyph: LucideGlyph.volume2,
                  title: 'Volume',
                  subtitle: '${(settings.volume * 100).round()}%',
                ),
              ),
              SizedBox(
                width: SettingsScreen.volumeSliderWidth,
                child: Slider(
                  value: settings.volume.clamp(0.0, 1.0),
                  divisions: SettingsScreen.volumeDivisions,
                  onChanged: (value) => game.setVolume(
                    (value * SettingsScreen.volumeDivisions).round() /
                        SettingsScreen.volumeDivisions,
                  ),
                ),
              ),
            ],
          ),
        ),
        divider,
        Padding(
          padding: sectionPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              const _SectionLabel(
                glyph: LucideGlyph.clock,
                title: 'Timers',
                subtitle: 'Adjust time limits for timed modes',
              ),
              _TimerRow(
                label: 'Medium',
                seconds: settings.mediumTimer,
                onChanged: game.setMediumTimer,
              ),
              _TimerRow(
                label: 'Hard',
                seconds: settings.hardTimer,
                onChanged: game.setHardTimer,
              ),
            ],
          ),
        ),
        divider,
        Padding(
          padding: sectionPadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: _SectionLabel(
                  glyph: LucideGlyph.trash2,
                  title: 'Reset Progress',
                  subtitle: 'Erase all achievements',
                ),
              ),
              _ResetButton(onPressed: onReset),
            ],
          ),
        ),
        divider,
        const Padding(
          padding: sectionPadding,
          child: Row(
            spacing: 12,
            children: [
              SwiftieLogo(size: SettingsScreen.logoSize),
              _TitledText(title: 'Swiftie Quiz', subtitle: 'Made by Satanshu'),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.glyph,
    required this.title,
    required this.subtitle,
  });

  final LucideGlyph glyph;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 12,
    children: [
      _IconChip(glyph: glyph),
      Flexible(
        child: _TitledText(title: title, subtitle: subtitle),
      ),
    ],
  );
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.glyph});

  static const double padding = 8;
  static const double iconSize = 16;

  final LucideGlyph glyph;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.muted,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(padding),
        child: AppIcon(glyph, size: iconSize, color: tokens.mutedForeground),
      ),
    );
  }
}

class _TitledText extends StatelessWidget {
  const _TitledText({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppText.sm.copyWith(
            fontWeight: FontWeight.w500,
            color: tokens.foreground,
          ),
        ),
        Text(
          subtitle,
          style: AppText.xs.copyWith(color: tokens.mutedForeground),
        ),
      ],
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.selected, required this.onSelect});

  static const List<(ThemeSetting, String, LucideGlyph)> options = [
    (ThemeSetting.dark, 'Dark', LucideGlyph.moon),
    (ThemeSetting.light, 'Light', LucideGlyph.sun),
    (ThemeSetting.system, 'System', LucideGlyph.monitor),
  ];
  static const double padding = 4;
  static const double gap = 4;

  final ThemeSetting selected;
  final ValueChanged<ThemeSetting> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.muted,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(padding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: gap,
          children: [
            for (final (theme, label, glyph) in options)
              _ThemeOption(
                label: label,
                glyph: glyph,
                selected: theme == selected,
                onPressed: () => onSelect(theme),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.glyph,
    required this.selected,
    required this.onPressed,
  });

  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 6,
  );
  static const double iconSize = 16;
  static const double gap = 6;

  final String label;
  final LucideGlyph glyph;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return PlainButton(
      onPressed: onPressed,
      builder: (context, hover) => TweenAnimationBuilder<double>(
        tween: Tween(end: selected ? 1 : 0),
        duration: AppMotion.cssTransitionDuration,
        curve: AppMotion.cssTransitionCurve,
        builder: (context, selection, _) {
          final idle = Oklab.mix(
            tokens.mutedForeground,
            tokens.foreground,
            hover,
          );
          final color = Oklab.mix(idle, tokens.primaryForeground, selection);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.primary.withValues(
                alpha: tokens.primary.a * selection,
              ),
              borderRadius: BorderRadius.circular(AppRadii.md),
              boxShadow: BoxShadow.lerpList(
                AppShadows.hidden(AppShadows.sm),
                AppShadows.sm,
                selection,
              ),
            ),
            child: Padding(
              padding: padding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: gap,
                children: [
                  AppIcon(glyph, size: iconSize, color: color),
                  Text(
                    label,
                    style: AppText.xs.copyWith(
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimerRow extends StatelessWidget {
  const _TimerRow({
    required this.label,
    required this.seconds,
    required this.onChanged,
  });

  final String label;
  final int seconds;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: SettingsScreen.indent),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 16,
        children: [
          Flexible(
            child: Text(
              label,
              style: AppText.sm.copyWith(color: tokens.mutedForeground),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              SizedBox(
                width: SettingsScreen.timerSliderWidth,
                child: Slider(
                  value: seconds.toDouble().clamp(
                    SettingsScreen.minTimer,
                    SettingsScreen.maxTimer,
                  ),
                  min: SettingsScreen.minTimer,
                  max: SettingsScreen.maxTimer,
                  divisions: SettingsScreen.timerDivisions,
                  onChanged: (value) => onChanged(value.round()),
                ),
              ),
              SizedBox(
                width: SettingsScreen.timerValueWidth,
                child: Text(
                  '${seconds}s',
                  textAlign: TextAlign.right,
                  style: AppText.sm.copyWith(color: tokens.foreground),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return PlainButton(
      onPressed: onPressed,
      builder: (context, hover) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: tokens.destructive.withValues(alpha: 0.1 * hover),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: tokens.destructive.slashOpacity(50)),
        ),
        child: Text(
          'Reset',
          style: AppText.xs.copyWith(
            fontWeight: FontWeight.w500,
            color: tokens.destructive,
          ),
        ),
      ),
    );
  }
}

class _UpdatesSection extends ConsumerWidget {
  const _UpdatesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final version = ref.watch(appVersionProvider).value;
    final updater = ref.watch(
      gameControllerProvider.select((state) => state.progress.updater),
    );
    final lastCheckedAt = updater.lastCheckedAt;
    final lastChecked = lastCheckedAt == null || lastCheckedAt.isEmpty
        ? SettingsScreen.neverChecked
        : LocalDates.isoDateTime(
            lastCheckedAt,
            LocalDates.systemLocale(context),
          );
    final mutedStyle = AppText.xs.copyWith(color: tokens.mutedForeground);
    void setAutoCheck(bool enabled) {
      final progress = ref.read(gameControllerProvider).progress;
      ref
          .read(gameControllerProvider.notifier)
          .setProgress(
            progress.copyWith(
              updater: progress.updater.copyWith(autoCheckEnabled: enabled),
            ),
          );
    }

    return Padding(
      padding: const EdgeInsets.all(SettingsScreen.sectionPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              const _IconChip(glyph: LucideGlyph.bell),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Updates',
                      style: AppText.sm.copyWith(
                        fontWeight: FontWeight.w500,
                        color: tokens.foreground,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        text: 'Current version: ',
                        children: [
                          TextSpan(
                            text: version == null ? '' : 'v$version',
                            style: const TextStyle(
                              fontFamily: SettingsScreen.monospaceFont,
                              fontFamilyFallback:
                                  SettingsScreen.monospaceFallbacks,
                            ),
                          ),
                        ],
                      ),
                      style: mutedStyle,
                    ),
                    const SizedBox(height: 4),
                    Text('Last checked: $lastChecked', style: mutedStyle),
                  ],
                ),
              ),
              _OutlinedButton(
                label: 'Check now',
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                onPressed: () => unawaited(
                  ref.read(updaterControllerProvider).check(manual: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AutoCheckToggle(
            enabled: updater.autoCheckEnabled,
            onChanged: setAutoCheck,
          ),
        ],
      ),
    );
  }
}

class _AutoCheckToggle extends StatelessWidget {
  const _AutoCheckToggle({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final labelStyle = AppText.xs.copyWith(color: tokens.foreground);
    return Padding(
      padding: const EdgeInsets.only(left: SettingsScreen.indent),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!enabled),
          child: MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: SettingsScreen.checkboxOffset,
                  ),
                  child: _ChromiumCheckbox(
                    value: enabled,
                    onChanged: onChanged,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Automatically check for updates',
                        style: labelStyle,
                      ),
                      Text(
                        SettingsScreen.telemetryNote,
                        style: labelStyle.copyWith(
                          fontSize: SettingsScreen.finePrintSize,
                          color: tokens.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChromiumCheckbox extends StatelessWidget {
  const _ChromiumCheckbox({required this.value, required this.onChanged});

  static const double size = 13;
  static const double radius = 2;
  static const double borderWidth = 1;
  static const double scale = size / Checkbox.width;

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final themeSide = CheckboxTheme.of(context).side;
    return SizedBox.square(
      dimension: size,
      child: FittedBox(
        child: SizedBox.square(
          dimension: Checkbox.width,
          child: Checkbox(
            value: value,
            onChanged: (next) => onChanged(next ?? false),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(radius / scale)),
            ),
            side: WidgetStateBorderSide.resolveWith((states) {
              final side = WidgetStateProperty.resolveAs<BorderSide?>(
                themeSide,
                states,
              );
              return side == null || side.style == BorderStyle.none
                  ? side
                  : side.copyWith(width: borderWidth / scale);
            }),
          ),
        ),
      ),
    );
  }
}

class _BackupsSection extends StatelessWidget {
  const _BackupsSection({required this.backups, required this.onRestore});

  final List<BackupEntry> backups;
  final ValueChanged<int> onRestore;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final locale = LocalDates.systemLocale(context);
    final textStyle = AppText.xs.copyWith(color: tokens.foreground);
    return Padding(
      padding: const EdgeInsets.all(SettingsScreen.sectionPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: _SectionLabel(
              glyph: LucideGlyph.archive,
              title: 'Backups',
              subtitle: 'The 3 most recent automatic save backups are kept.',
            ),
          ),
          const SizedBox(height: 16),
          if (backups.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: SettingsScreen.indent),
              child: Text(
                'No backups yet.',
                style: AppText.xs.copyWith(color: tokens.mutedForeground),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                for (final backup in backups)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.card,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: tokens.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocalDates.dateTime(
                                  DateTime.fromMillisecondsSinceEpoch(
                                    backup.timestamp *
                                        Duration.millisecondsPerSecond,
                                  ),
                                  locale,
                                ),
                                style: textStyle,
                              ),
                              Text(
                                '${(backup.sizeBytes / 1024).toStringAsFixed(1)} KB',
                                style: textStyle.copyWith(
                                  fontSize: SettingsScreen.finePrintSize,
                                  color: tokens.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _OutlinedButton(
                          label: 'Restore',
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          onPressed: () => onRestore(backup.timestamp),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  const _OutlinedButton({
    required this.label,
    required this.padding,
    required this.onPressed,
  });

  final String label;
  final EdgeInsets padding;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return PlainButton(
      onPressed: onPressed,
      duration: Duration.zero,
      builder: (context, hover) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: tokens.muted.withValues(alpha: tokens.muted.a * 0.4 * hover),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: tokens.border),
        ),
        child: Text(
          label,
          style: AppText.xs.copyWith(color: tokens.foreground),
        ),
      ),
    );
  }
}

enum _DialogActionStyle { quiet, outlined, destructive }

@immutable
class _DialogAction {
  const _DialogAction(this.label, this.style, {required this.result});

  final String label;
  final _DialogActionStyle style;
  final bool result;
}

Future<bool?> _showSettingsDialog(
  BuildContext context, {
  String? title,
  required String message,
  required List<_DialogAction> actions,
}) {
  final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: _SettingsDialog.backdropColor,
    transitionDuration: reduceMotion
        ? Duration.zero
        : AppMotion.defaultOpacityDuration,
    pageBuilder: (context, _, _) =>
        _SettingsDialog(title: title, message: message, actions: actions),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.defaultOpacityCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: _SettingsDialog.hiddenScale,
            end: 1,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog({
    required this.title,
    required this.message,
    required this.actions,
  });

  static const Color backdropColor = Color.from(
    alpha: 0.6,
    red: 0,
    green: 0,
    blue: 0,
  );
  static const double hiddenScale = 0.95;
  static const double padding = 24;
  static const double titleGap = 12;
  static const double actionsGap = 16;

  final String? title;
  final String message;
  final List<_DialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: padding),
          child: MaxWidthBox(
            maxWidth: TailwindContainers.lg,
            child: Container(
              padding: const EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: tokens.card,
                borderRadius: BorderRadius.circular(AppRadii.xl2),
                border: Border.all(color: tokens.border),
                boxShadow: AppShadows.xl2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title case final title?) ...[
                    Text(
                      title,
                      style: AppText.xl.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tokens.foreground,
                      ),
                    ),
                    const SizedBox(height: titleGap),
                  ],
                  Text(
                    message,
                    style: AppText.base.copyWith(color: tokens.mutedForeground),
                  ),
                  const SizedBox(height: actionsGap),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final action in actions)
                        _DialogButton(
                          action: action,
                          autofocus: action == actions.last,
                        ),
                    ],
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

class _DialogButton extends StatelessWidget {
  const _DialogButton({required this.action, required this.autofocus});

  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  );

  final _DialogAction action;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    void close() => Navigator.of(context).pop(action.result);
    return PlainButton(
      onPressed: close,
      autofocus: autofocus,
      duration: Duration.zero,
      builder: (context, hover) => switch (action.style) {
        _DialogActionStyle.quiet => Padding(
          padding: padding,
          child: Text(
            action.label,
            style: AppText.xs.copyWith(
              color: Oklab.mix(
                tokens.mutedForeground,
                tokens.foreground,
                hover,
              ),
            ),
          ),
        ),
        _DialogActionStyle.outlined => Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Oklab.mix(tokens.card, tokens.muted.slashOpacity(40), hover),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: tokens.border),
          ),
          child: Text(
            action.label,
            style: AppText.xs.copyWith(color: tokens.foreground),
          ),
        ),
        _DialogActionStyle.destructive => Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tokens.destructive,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Text(
            action.label,
            style: AppText.xs.copyWith(
              fontWeight: FontWeight.w500,
              color: AppPalette.white,
            ),
          ),
        ),
      },
    );
  }
}
