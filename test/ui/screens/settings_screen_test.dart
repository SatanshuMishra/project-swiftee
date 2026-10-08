import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/save/save_error.dart';
import 'package:swiftie_quiz/domain/models/backup_entry.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/state/covers.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/persistence_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/toast_controller.dart';
import 'package:swiftie_quiz/state/updater_controller.dart';
import 'package:swiftie_quiz/ui/kit/confirm_dialog.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/screens/settings_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

class FakePersistence extends PersistenceController {
  FakePersistence({this.backups = const [], this.restoreError});

  final List<BackupEntry> backups;
  final Object? restoreError;
  final List<int> restored = [];

  @override
  PersistenceStatus build() => PersistenceStatus.loaded;

  @override
  Future<List<BackupEntry>> listBackups() async => backups;

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
  Edition edition = Edition.open,
  FakePersistence? persistence,
  Directory? coversFolder,
  void Function(ProviderContainer container)? setup,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fakePersistence = persistence ?? FakePersistence();
  late final FakeUpdater fakeUpdater;
  final container = ProviderContainer.test(
    overrides: [
      editionProvider.overrideWithValue(edition),
      persistenceControllerProvider.overrideWith(() => fakePersistence),
      updaterControllerProvider.overrideWith(
        (ref) => fakeUpdater = FakeUpdater(ref),
      ),
      appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
      coversFolderProvider.overrideWithValue(
        () =>
            coversFolder ??
            Directory('${Directory.systemTemp.path}/no-covers-kept'),
      ),
    ],
  );
  setup?.call(container);
  container.listen(coverCleanupProvider, (_, _) {});
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

GameController gameOf(ProviderContainer container) =>
    container.read(gameControllerProvider.notifier);

void withStats(ProviderContainer container) {
  final progress = progressOf(container);
  gameOf(container).setProgress(
    progress.copyWith(
      stats: progress.stats.copyWith(totalCorrect: 7),
      achievements: {
        ...progress.achievements,
        'first_meow': const AchievementState(
          unlocked: true,
          unlockedAt: '2026-10-01T12:00:00.000Z',
        ),
      },
    ),
  );
}

int unixSeconds(DateTime local) => local.millisecondsSinceEpoch ~/ 1000;

final DateTime newest = DateTime(2026, 10, 5, 15, 24, 31);
final DateTime middle = DateTime(2026, 10, 4, 21, 10, 2);
final DateTime oldest = DateTime(2026, 10, 2, 18, 47, 55);
final DateTime oldestOfAll = DateTime(2026, 9, 30, 9, 5, 12);

List<BackupEntry> fourBackups() => [
  BackupEntry(timestamp: unixSeconds(middle), path: '/b', sizeBytes: 4608),
  BackupEntry(timestamp: unixSeconds(oldestOfAll), path: '/d', sizeBytes: 1),
  BackupEntry(timestamp: unixSeconds(newest), path: '/a', sizeBytes: 4710),
  BackupEntry(timestamp: unixSeconds(oldest), path: '/c', sizeBytes: 4300),
];

Finder sliderInRow(String title) => find
    .descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(Wrap)),
      matching: find.byType(Slider),
    )
    .first;

Finder inDialog(String text) =>
    find.descendant(of: find.byType(ConfirmDialog), matching: find.text(text));

Finder restoreFor(String date) => find.descendant(
  of: find.ancestor(of: find.text(date), matching: find.byType(Row)).first,
  matching: find.text('Restore'),
);

Finder spinnerBeside(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
  matching: find.byType(RotationTransition),
);

Color? switchColor(WidgetTester tester) {
  final track = find.descendant(
    of: find.ancestor(
      of: find.text('Check for updates automatically'),
      matching: find.byType(Pressable),
    ),
    matching: find.byType(AnimatedContainer),
  );
  return (tester.widget<AnimatedContainer>(track).decoration! as BoxDecoration)
      .color;
}

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

void expectSections() {
  for (final label in [
    'Look and sound',
    'Theme',
    'System follows your computer.',
    'Volume',
    'Misu visits',
    'Timers',
    'Medium',
    'Hard',
    'Updates',
    'Check now',
    'Check for updates automatically',
    'Sends only a standard request to GitHub. No analytics or tracking.',
    'Storage',
    'Save album covers',
    'Keeps covers for new releases on this computer. Turning it off removes '
        'them.',
    'Backups',
    'The three most recent automatic backups are kept.',
    'Progress',
    'Reset…',
    'Project Swiftie',
    'Settings',
    'Saved as you go.',
  ]) {
    expect(find.text(label), findsOneWidget, reason: label);
  }
  for (final option in ['Dark', 'Light', 'System']) {
    expect(find.text(option), findsOneWidget, reason: option);
  }
  for (final option in ['Often', 'Now and then', 'Off']) {
    expect(find.text(option), findsOneWidget, reason: option);
  }
  final icon = find.byType(SvgPicture);
  expect(icon, findsOneWidget);
  final svg = icon.evaluate().single.widget as SvgPicture;
  expect((svg.width, svg.height), (40.0, 40.0));
}

void main() {
  group('settings screen', () {
    testWidgets("settings shows every section with the edition's rows", (
      tester,
    ) async {
      await pumpSettings(tester, edition: Edition.ana);
      expectSections();
      expect(find.text('Nickname'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text('Made for Ana by Satanshu with ♥️ and lots of ☕'),
        findsOneWidget,
      );
      expect(find.text('Made by Satanshu'), findsNothing);

      final open = await pumpSettings(
        tester,
        setup: (container) => gameOf(container).setNickname('Sam'),
      );
      expectSections();
      expect(find.text('Nickname'), findsOneWidget);
      expect(find.text('Made by Satanshu'), findsOneWidget);
      expect(
        find.text('Made for Ana by Satanshu with ♥️ and lots of ☕'),
        findsNothing,
      );
      expect(find.byType(TextField), findsNWidgets(2));
      final field = find.byType(TextField).first;
      expect(
        find.descendant(of: field, matching: find.text('Sam')),
        findsOneWidget,
      );

      await tester.ensureVisible(field);
      await tester.enterText(field, 'Taylor');
      await tester.pumpAndSettle();
      expect(settingsOf(open.container).nickname, 'Taylor');

      await tester.enterText(field, 'Taylor Alison Swift Ana');
      await tester.pumpAndSettle();
      expect(settingsOf(open.container).nickname, 'Taylor Alison Swift');
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Taylor Alison Swift ',
      );

      await tapAndSettle(tester, find.text('Light'));
      expect(settingsOf(open.container).theme, ThemeSetting.light);
      await tapAndSettle(tester, find.text('System'));
      expect(settingsOf(open.container).theme, ThemeSetting.system);
      await tapAndSettle(tester, find.text('Dark'));
      expect(settingsOf(open.container).theme, ThemeSetting.dark);

      expect(settingsOf(open.container).misuVisits, MisuVisits.sometimes);
      await tapAndSettle(tester, find.text('Often'));
      expect(settingsOf(open.container).misuVisits, MisuVisits.often);
      await tapAndSettle(tester, find.text('Off'));
      expect(settingsOf(open.container).misuVisits, MisuVisits.off);
      await tapAndSettle(tester, find.text('Now and then'));
      expect(settingsOf(open.container).misuVisits, MisuVisits.sometimes);

      final volume = sliderInRow('Volume');
      final volumeSlider = tester.widget<Slider>(volume);
      expect(
        (volumeSlider.min, volumeSlider.max, volumeSlider.divisions),
        (0.0, 1.0, 100),
      );
      expect(find.text('80%'), findsOneWidget);
      await tapAndSettle(tester, volume);
      expect(settingsOf(open.container).volume, 0.5);
      expect(find.text('50%'), findsOneWidget);
      await dragAndSettle(tester, volume, const Offset(500, 0));
      expect(settingsOf(open.container).volume, 1.0);
      expect(find.text('100%'), findsOneWidget);

      for (final title in ['Medium', 'Hard']) {
        final slider = tester.widget<Slider>(sliderInRow(title));
        expect((slider.min, slider.max, slider.divisions), (10.0, 40.0, 6));
      }
      expect(find.text('30s'), findsOneWidget);
      expect(find.text('20s'), findsOneWidget);
      await tapAndSettle(tester, sliderInRow('Medium'));
      expect(settingsOf(open.container).mediumTimer, 25);
      expect(find.text('25s'), findsOneWidget);
      await dragAndSettle(tester, sliderInRow('Hard'), const Offset(500, 0));
      expect(settingsOf(open.container).hardTimer, 40);
      expect(find.text('40s'), findsOneWidget);
      await dragAndSettle(tester, sliderInRow('Medium'), const Offset(-500, 0));
      expect(settingsOf(open.container).mediumTimer, 10);
      expect(find.text('10s'), findsOneWidget);
    });

    testWidgets('reset and restore ask before acting', (tester) async {
      final harness = await pumpSettings(
        tester,
        edition: Edition.ana,
        persistence: FakePersistence(backups: fourBackups()),
        setup: (container) {
          withStats(container);
          gameOf(container).setVolume(0.4);
        },
      );
      final before = progressOf(harness.container);

      await tapAndSettle(tester, find.text('Reset…'));
      expect(inDialog('Reset all progress?'), findsOneWidget);
      expect(
        inDialog(
          "This clears Ana's record shelf and stats. Backups stay available.",
        ),
        findsOneWidget,
      );
      await tapAndSettle(tester, inDialog('Cancel'));
      expect(find.byType(ConfirmDialog), findsNothing);
      expect(progressOf(harness.container), before);

      await tapAndSettle(tester, find.text('Reset…'));
      await tapAndSettle(tester, inDialog('Reset progress'));
      expect(find.byType(ConfirmDialog), findsNothing);
      final reset = progressOf(harness.container);
      expect(reset.stats, defaultProgress.stats);
      expect(reset.achievements, defaultProgress.achievements);
      expect(reset.settings, before.settings);

      final restore = restoreFor('Oct 4, 2026 at 9:10 PM');
      await tapAndSettle(tester, restore);
      expect(inDialog('Restore this backup?'), findsOneWidget);
      expect(
        inDialog('Your current save will be replaced with this one.'),
        findsOneWidget,
      );
      await tapAndSettle(tester, inDialog('Cancel'));
      expect(find.byType(ConfirmDialog), findsNothing);
      expect(harness.persistence.restored, isEmpty);
      expect(progressOf(harness.container), reset);

      await tapAndSettle(tester, restore);
      await tapAndSettle(tester, inDialog('Restore'));
      expect(find.byType(ConfirmDialog), findsNothing);
      expect(harness.persistence.restored, [unixSeconds(middle)]);
      await tester.pump(ToastController.displayDuration);
    });

    testWidgets('a confirmed reset or restore says so in a toast', (
      tester,
    ) async {
      final harness = await pumpSettings(
        tester,
        persistence: FakePersistence(backups: fourBackups()),
      );
      String? toast() => harness.container.read(toastControllerProvider);

      await tapAndSettle(tester, find.text('Reset…'));
      await tapAndSettle(tester, inDialog('Cancel'));
      expect(toast(), isNull);

      await tapAndSettle(tester, find.text('Reset…'));
      await tapAndSettle(tester, inDialog('Reset progress'));
      expect(toast(), 'Progress reset');

      await tapAndSettle(tester, restoreFor('Oct 5, 2026 at 3:24 PM'));
      await tapAndSettle(tester, inDialog('Restore'));
      expect(toast(), 'Backup restored');

      await tester.pump(ToastController.displayDuration);
      expect(toast(), isNull);
    });

    testWidgets('the nickname field shows the stored name', (tester) async {
      final harness = await pumpSettings(
        tester,
        setup: (container) => gameOf(container).setNickname('Sam'),
      );
      final field = find.byType(TextField).first;
      String shown() => tester.widget<TextField>(field).controller!.text;

      await tester.ensureVisible(field);
      await tester.enterText(field, '   ');
      await tester.pumpAndSettle();
      expect(settingsOf(harness.container).nickname, 'Sam');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(shown(), 'Sam');

      final progress = progressOf(harness.container);
      gameOf(harness.container).setProgress(
        progress.copyWith(
          settings: progress.settings.copyWith(nickname: 'Robin'),
        ),
      );
      await tester.pumpAndSettle();
      expect(shown(), 'Robin');
    });

    testWidgets('sliders and the nickname field carry their row names', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpSettings(tester);

      for (final (title, value) in [
        ('Volume', '80%'),
        ('Medium', '30 seconds'),
        ('Hard', '20 seconds'),
      ]) {
        expect(
          tester.getSemantics(sliderInRow(title)),
          isSemantics(label: title, value: value, isSlider: true),
          reason: title,
        );
      }
      expect(
        tester.getSemantics(find.byType(TextField).first),
        isSemantics(label: 'Nickname', isTextField: true),
      );
      semantics.dispose();
    });

    testWidgets('reset names the player or says your', (tester) async {
      await pumpSettings(
        tester,
        setup: (container) => gameOf(container).setNickname('Sam'),
      );
      await tapAndSettle(tester, find.text('Reset…'));
      expect(
        inDialog(
          "This clears Sam's record shelf and stats. Backups stay available.",
        ),
        findsOneWidget,
      );
      await tapAndSettle(tester, inDialog('Cancel'));

      await pumpSettings(tester);
      await tapAndSettle(tester, find.text('Reset…'));
      expect(
        inDialog(
          'This clears your record shelf and stats. Backups stay available.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('backups list the newest three with their date and size', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        persistence: FakePersistence(backups: fourBackups()),
      );

      for (final (date, size) in [
        ('Oct 5, 2026 at 3:24 PM', '4.6 KB'),
        ('Oct 4, 2026 at 9:10 PM', '4.5 KB'),
        ('Oct 2, 2026 at 6:47 PM', '4.2 KB'),
      ]) {
        expect(find.text(date), findsOneWidget, reason: date);
        expect(find.text(size), findsOneWidget, reason: size);
      }
      expect(find.text('Sep 30, 2026 at 9:05 AM'), findsNothing);
      expect(find.text('Restore'), findsNWidgets(3));
      final dates = [
        for (final date in [
          'Oct 5, 2026 at 3:24 PM',
          'Oct 4, 2026 at 9:10 PM',
          'Oct 2, 2026 at 6:47 PM',
        ])
          tester.getTopLeft(find.text(date)).dy,
      ];
      expect(dates, orderedEquals([...dates]..sort()));
    });

    testWidgets('no backups shows only the note', (tester) async {
      await pumpSettings(tester);

      expect(
        find.text('The three most recent automatic backups are kept.'),
        findsOneWidget,
      );
      expect(find.text('Restore'), findsNothing);
    });

    testWidgets('a failed restore shows the error', (tester) async {
      final harness = await pumpSettings(
        tester,
        persistence: FakePersistence(
          backups: [
            BackupEntry(
              timestamp: unixSeconds(newest),
              path: '/a',
              sizeBytes: 2048,
            ),
          ],
          restoreError: const SaveFileError('backup file does not exist'),
        ),
      );

      await tapAndSettle(tester, find.text('Restore'));
      await tapAndSettle(tester, inDialog('Restore'));

      expect(
        harness.container.read(toastControllerProvider),
        'Could not restore backup: File error: backup file does not exist',
      );

      await tester.pump(ToastController.displayDuration);
      expect(harness.container.read(toastControllerProvider), isNull);
    });

    testWidgets('updates show the version and when it last checked', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        setup: (container) {
          final progress = progressOf(container);
          gameOf(container).setProgress(
            progress.copyWith(
              updater: progress.updater.copyWith(
                lastCheckedAt: DateTime(
                  2026,
                  10,
                  5,
                  14,
                  30,
                ).toUtc().toIso8601String(),
              ),
            ),
          );
        },
      );

      expect(
        find.text('Project Swiftie v0.3.0', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Last checked Oct 5, 2026 at 2:30 PM'), findsOneWidget);
    });

    testWidgets('Check now spins while checking and then shows the result', (
      tester,
    ) async {
      final harness = await pumpSettings(tester);
      final game = gameOf(harness.container);
      game.setUpdaterState(const UpdaterUpToDate());
      await tester.pumpAndSettle();
      expect(find.text("You're up to date."), findsNothing);

      await tester.ensureVisible(find.text('Check now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check now'));
      game.setUpdaterState(const UpdaterChecking());
      await tester.pump();
      expect(harness.updater.checks, [true]);
      expect(find.text('Checking…'), findsOneWidget);
      expect(find.text('Check now'), findsNothing);
      expect(spinnerBeside('Checking…'), findsOneWidget);

      await tester.tap(find.text('Checking…'));
      await tester.pump();
      expect(harness.updater.checks, [true]);

      game.setUpdaterState(const UpdaterUpToDate());
      await tester.pumpAndSettle();
      expect(find.text('Check now'), findsOneWidget);
      expect(spinnerBeside('Check now'), findsNothing);
      expect(find.text("You're up to date."), findsOneWidget);

      await tester.tap(find.text('Check now'));
      game.setUpdaterState(const UpdaterChecking());
      await tester.pump();
      expect(find.text("You're up to date."), findsNothing);

      game.setUpdaterState(
        const UpdaterError(
          subtype: UpdaterErrorSubtype.check,
          message: 'Could not reach the update server.',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not reach the update server.'), findsOneWidget);
      expect(harness.updater.checks, [true, true]);
    });

    testWidgets('the automatic check row toggles autoCheckEnabled', (
      tester,
    ) async {
      final harness = await pumpSettings(tester);
      bool autoCheck() =>
          progressOf(harness.container).updater.autoCheckEnabled;
      expect(autoCheck(), isTrue);
      expect(switchColor(tester), AppTokens.dark.coral);

      await tapAndSettle(tester, find.text('Check for updates automatically'));
      expect(autoCheck(), isFalse);
      expect(switchColor(tester), AppTokens.dark.line2);

      await tapAndSettle(
        tester,
        find.text(
          'Sends only a standard request to GitHub. No analytics or tracking.',
        ),
      );
      expect(autoCheck(), isTrue);
      expect(switchColor(tester), AppTokens.dark.coral);
    });

    testWidgets('saving album covers starts off, and turning it off removes '
        'the covers it kept', (tester) async {
      final home = Directory.systemTemp.createTempSync('settings_covers');
      addTearDown(() => home.deleteSync(recursive: true));
      final covers = Directory('${home.path}/covers');
      Future<void> letFilesSettle({bool until = false}) async {
        for (
          var step = 0;
          step < 20 && (!until || covers.existsSync());
          step++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
      }

      final harness = await pumpSettings(tester, coversFolder: covers);
      await letFilesSettle();
      bool saving() => settingsOf(harness.container).saveCovers;
      expect(saving(), isFalse);

      await tapAndSettle(tester, find.text('Save album covers'));
      expect(saving(), isTrue);
      covers.createSync();
      File('${covers.path}/kept.jpg').writeAsBytesSync([0xFF, 0xD8]);
      await letFilesSettle();
      expect(covers.existsSync(), isTrue);

      await tapAndSettle(tester, find.text('Save album covers'));
      await letFilesSettle(until: true);
      expect(saving(), isFalse);
      expect(covers.existsSync(), isFalse);
    });

    testWidgets('Back returns to the menu', (tester) async {
      final harness = await pumpSettings(
        tester,
        setup: (container) => gameOf(container).setPhase(GamePhase.settings),
      );

      await tapAndSettle(tester, find.text('Back'));

      expect(
        harness.container.read(gameControllerProvider).phase,
        GamePhase.menu,
      );
    });

    testWidgets('reduced motion makes every change instant', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer.test(
        overrides: [
          editionProvider.overrideWithValue(Edition.open),
          persistenceControllerProvider.overrideWith(FakePersistence.new),
          appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
        ],
      );
      gameOf(container).setUpdaterState(const UpdaterChecking());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('Checking…'), findsOneWidget);
      expect(spinnerBeside('Checking…'), findsOneWidget);

      for (final target in [
        find.text('Light'),
        sliderInRow('Medium'),
        find.text('Check for updates automatically'),
      ]) {
        await tester.ensureVisible(target);
        await tester.pump();
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.hasRunningAnimations, isFalse);
      }
      expect(settingsOf(container).theme, ThemeSetting.light);
      expect(settingsOf(container).mediumTimer, 25);
      expect(progressOf(container).updater.autoCheckEnabled, isFalse);
    });
  });
}
