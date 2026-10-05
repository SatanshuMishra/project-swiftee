import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/save/save_error.dart';
import 'package:swiftie_quiz/domain/models/backup_entry.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/persistence_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/updater_controller.dart';
import 'package:swiftie_quiz/ui/screens/settings_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';

const String restorePrompt =
    'Restore this backup? Your current save will be replaced.';

class FakePersistence extends PersistenceController {
  FakePersistence({this.backups = const [], this.listError, this.restoreError});

  final List<BackupEntry> backups;
  final Object? listError;
  final Object? restoreError;
  final List<int> restored = [];

  @override
  PersistenceStatus build() => PersistenceStatus.loaded;

  @override
  Future<List<BackupEntry>> listBackups() async {
    if (listError case final error?) {
      throw error;
    }
    return backups;
  }

  @override
  Future<void> restoreBackup(int timestamp) async {
    restored.add(timestamp);
    if (restoreError case final error?) {
      throw error;
    }
  }
}

class FakeUpdater extends UpdaterController {
  FakeUpdater(super.ref);

  final List<bool> checks = [];

  @override
  Future<void> check({bool manual = false}) async => checks.add(manual);
}

typedef SettingsHarness = ({
  ProviderContainer container,
  FakePersistence persistence,
  FakeUpdater updater,
});

Future<SettingsHarness> pumpSettings(
  WidgetTester tester, {
  FakePersistence? persistence,
  GameProgress Function(GameProgress progress)? progress,
  Locale locale = const Locale('en', 'US'),
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localeTestValue = locale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  final fakePersistence = persistence ?? FakePersistence();
  late final FakeUpdater fakeUpdater;
  final container = ProviderContainer.test(
    overrides: [
      persistenceControllerProvider.overrideWith(() => fakePersistence),
      updaterControllerProvider.overrideWith(
        (ref) => fakeUpdater = FakeUpdater(ref),
      ),
      appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
    ],
  );
  if (progress != null) {
    final game = container.read(gameControllerProvider.notifier);
    game.setProgress(progress(container.read(gameControllerProvider).progress));
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      key: ObjectKey(container),
      container: container,
      child: MaterialApp(theme: AppTheme.dark, home: const SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  container.read(updaterControllerProvider);
  return (
    container: container,
    persistence: fakePersistence,
    updater: fakeUpdater,
  );
}

GameProgress progressOf(ProviderContainer container) =>
    container.read(gameControllerProvider).progress;

GameSettings settingsOf(ProviderContainer container) =>
    progressOf(container).settings;

Finder sliderInRowOf(String label) => find
    .descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Row)),
      matching: find.byType(Slider),
    )
    .first;

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> dragAndSettle(
  WidgetTester tester,
  Finder finder,
  Offset offset,
) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.drag(finder, offset);
  await tester.pumpAndSettle();
}

String twoDigits(int value) => value.toString().padLeft(2, '0');

String usDate(DateTime local) => '${local.month}/${local.day}/${local.year}';

String usDateTime(DateTime local) {
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${usDate(local)}, $hour:${twoDigits(local.minute)}:'
      '${twoDigits(local.second)} $period';
}

void main() {
  group('settings parity', () {
    testWidgets('appearance buttons set dark, light and system themes', (
      tester,
    ) async {
      final harness = await pumpSettings(tester);
      expect(settingsOf(harness.container).theme, ThemeSetting.dark);

      await tapAndSettle(tester, find.text('Light'));
      expect(settingsOf(harness.container).theme, ThemeSetting.light);

      await tapAndSettle(tester, find.text('System'));
      expect(settingsOf(harness.container).theme, ThemeSetting.system);

      await tapAndSettle(tester, find.text('Dark'));
      expect(settingsOf(harness.container).theme, ThemeSetting.dark);
    });

    testWidgets('volume slider runs from 0 to 1 in steps of 0.01', (
      tester,
    ) async {
      final harness = await pumpSettings(tester);
      final volume = sliderInRowOf('Volume');
      final slider = tester.widget<Slider>(volume);
      expect((slider.min, slider.max, slider.divisions), (0.0, 1.0, 100));
      expect(find.text('80%'), findsOneWidget);

      await tapAndSettle(tester, volume);
      expect(settingsOf(harness.container).volume, 0.5);
      expect(find.text('50%'), findsOneWidget);

      await dragAndSettle(tester, volume, const Offset(500, 0));
      expect(settingsOf(harness.container).volume, 1.0);
      expect(find.text('100%'), findsOneWidget);

      await dragAndSettle(tester, volume, const Offset(-500, 0));
      expect(settingsOf(harness.container).volume, 0.0);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('medium and hard timers run from 10 to 40 s in steps of 5', (
      tester,
    ) async {
      final harness = await pumpSettings(tester);
      expect(find.text('30s'), findsOneWidget);
      expect(find.text('20s'), findsOneWidget);

      for (final label in ['Medium', 'Hard']) {
        final slider = tester.widget<Slider>(sliderInRowOf(label));
        expect((slider.min, slider.max, slider.divisions), (10.0, 40.0, 6));
      }

      await tapAndSettle(tester, sliderInRowOf('Medium'));
      expect(settingsOf(harness.container).mediumTimer, 25);
      expect(find.text('25s'), findsOneWidget);

      await dragAndSettle(tester, sliderInRowOf('Hard'), const Offset(500, 0));
      expect(settingsOf(harness.container).hardTimer, 40);
      expect(find.text('40s'), findsOneWidget);

      await dragAndSettle(
        tester,
        sliderInRowOf('Medium'),
        const Offset(-500, 0),
      );
      expect(settingsOf(harness.container).mediumTimer, 10);
      expect(find.text('10s'), findsOneWidget);
    });

    testWidgets('reset needs a second confirming step', (tester) async {
      final harness = await pumpSettings(
        tester,
        progress: (progress) =>
            progress.copyWith(stats: progress.stats.copyWith(totalCorrect: 7)),
      );

      await tapAndSettle(tester, find.text('Reset'));
      expect(progressOf(harness.container).stats.totalCorrect, 7);
      expect(find.text('Confirm Reset'), findsOneWidget);

      await tapAndSettle(tester, find.text('Confirm Reset'));
      expect(progressOf(harness.container), defaultProgress);
      expect(find.text('Confirm Reset'), findsNothing);
    });

    testWidgets('cancelling the reset keeps progress', (tester) async {
      final harness = await pumpSettings(
        tester,
        progress: (progress) =>
            progress.copyWith(stats: progress.stats.copyWith(totalCorrect: 7)),
      );

      await tapAndSettle(tester, find.text('Reset'));
      await tapAndSettle(tester, find.text('Cancel'));

      expect(find.text('Confirm Reset'), findsNothing);
      expect(progressOf(harness.container).stats.totalCorrect, 7);
    });

    testWidgets('updates card shows the build version and never checked', (
      tester,
    ) async {
      await pumpSettings(tester);

      expect(
        find.text('Current version: v0.3.0', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Last checked: Never'), findsOneWidget);
    });

    testWidgets('last checked shows the local date and time', (tester) async {
      const checkedAt = '2026-10-05T14:30:15.000Z';
      await pumpSettings(
        tester,
        progress: (progress) => progress.copyWith(
          updater: progress.updater.copyWith(lastCheckedAt: checkedAt),
        ),
      );

      final local = DateTime.parse(checkedAt).toLocal();
      expect(find.text('Last checked: ${usDateTime(local)}'), findsOneWidget);
    });

    testWidgets('Check now runs a manual update check', (tester) async {
      final harness = await pumpSettings(tester);

      await tapAndSettle(tester, find.text('Check now'));

      expect(harness.updater.checks, [true]);
    });

    testWidgets('the auto-check box toggles autoCheckEnabled', (tester) async {
      final harness = await pumpSettings(tester);
      bool autoCheck() =>
          progressOf(harness.container).updater.autoCheckEnabled;
      expect(autoCheck(), isTrue);
      expect(
        find.text(
          'Sends only the standard HTTP request to GitHub. No analytics, no '
          'install identifiers, no telemetry.',
        ),
        findsOneWidget,
      );

      await tapAndSettle(tester, find.text('Automatically check for updates'));
      expect(autoCheck(), isFalse);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

      await tapAndSettle(tester, find.byType(Checkbox));
      expect(autoCheck(), isTrue);
    });

    testWidgets('lists backups with their time and size', (tester) async {
      const timestamp = 1759674615;
      await pumpSettings(
        tester,
        persistence: FakePersistence(
          backups: const [
            BackupEntry(timestamp: timestamp, path: '/a', sizeBytes: 2048),
            BackupEntry(timestamp: 1759588215, path: '/b', sizeBytes: 1587),
          ],
        ),
      );

      final local = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      expect(find.text(usDateTime(local)), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);
      expect(find.text('1.5 KB'), findsOneWidget);
      expect(find.text('Restore'), findsNWidgets(2));
      expect(find.text('No backups yet.'), findsNothing);
    });

    testWidgets('shows no backups when there are none or listing fails', (
      tester,
    ) async {
      await pumpSettings(tester);
      expect(find.text('No backups yet.'), findsOneWidget);

      await pumpSettings(
        tester,
        persistence: FakePersistence(listError: const SaveFileError('denied')),
      );
      expect(find.text('No backups yet.'), findsOneWidget);
    });

    testWidgets('restore asks first, then restores through the store', (
      tester,
    ) async {
      final harness = await pumpSettings(
        tester,
        persistence: FakePersistence(
          backups: const [
            BackupEntry(timestamp: 1759674615, path: '/a', sizeBytes: 2048),
          ],
        ),
      );

      await tapAndSettle(tester, find.text('Restore'));
      expect(find.text(restorePrompt), findsOneWidget);
      expect(harness.persistence.restored, isEmpty);

      await tapAndSettle(tester, find.text('OK'));
      expect(harness.persistence.restored, [1759674615]);
      expect(find.text(restorePrompt), findsNothing);
    });

    testWidgets('restore prompt confirms with Enter', (tester) async {
      final harness = await pumpSettings(
        tester,
        persistence: FakePersistence(
          backups: const [
            BackupEntry(timestamp: 1759674615, path: '/a', sizeBytes: 2048),
          ],
        ),
      );

      await tapAndSettle(tester, find.text('Restore'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(harness.persistence.restored, [1759674615]);
      expect(find.text(restorePrompt), findsNothing);
    });

    testWidgets('declining the restore prompt restores nothing', (
      tester,
    ) async {
      final harness = await pumpSettings(
        tester,
        persistence: FakePersistence(
          backups: const [
            BackupEntry(timestamp: 1759674615, path: '/a', sizeBytes: 2048),
          ],
        ),
      );

      await tapAndSettle(tester, find.text('Restore'));
      await tapAndSettle(tester, find.text('Cancel'));

      expect(harness.persistence.restored, isEmpty);
      expect(find.text(restorePrompt), findsNothing);
    });

    testWidgets('a failed restore shows the error message in the app', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        persistence: FakePersistence(
          backups: const [
            BackupEntry(timestamp: 1759674615, path: '/a', sizeBytes: 2048),
          ],
          restoreError: const SaveFileError('backup file does not exist'),
        ),
      );

      await tapAndSettle(tester, find.text('Restore'));
      await tapAndSettle(tester, find.text('OK'));

      const failure =
          'Could not restore backup: File error: backup file does not exist';
      expect(find.text(failure), findsOneWidget);

      await tapAndSettle(tester, find.text('OK'));
      expect(find.text(failure), findsNothing);
    });

    testWidgets('dates follow the system locale', (tester) async {
      const timestamp = 1759674615;
      await pumpSettings(
        tester,
        locale: const Locale('de', 'DE'),
        persistence: FakePersistence(
          backups: const [
            BackupEntry(timestamp: timestamp, path: '/a', sizeBytes: 2048),
          ],
        ),
      );

      final local = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      expect(
        find.text(
          '${local.day}.${local.month}.${local.year}, '
          '${twoDigits(local.hour)}:${twoDigits(local.minute)}:'
          '${twoDigits(local.second)}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('about shows the app name and author', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Swiftie Quiz'), findsOneWidget);
      expect(find.text('Made by Satanshu'), findsOneWidget);
      expect(
        find.text('The 3 most recent automatic save backups are kept.'),
        findsOneWidget,
      );
    });
  });
}
