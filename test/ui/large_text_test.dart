import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/achievements.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/services/window/window_controls.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/misu_controller.dart';
import 'package:swiftie_quiz/ui/chrome/title_bar.dart';
import 'package:swiftie_quiz/ui/screens/album_grid.dart';
import 'package:swiftie_quiz/ui/screens/game_screen.dart' show songTitle;
import 'package:swiftie_quiz/ui/misu/misu_host.dart';
import 'package:swiftie_quiz/ui/overlays/achievement_toasts.dart';
import 'package:swiftie_quiz/ui/overlays/error_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/domain/together/standings.dart';
import 'package:swiftie_quiz/state/together/together_game_state.dart';
import 'package:swiftie_quiz/ui/screens/record_shelf_screen.dart';
import 'package:swiftie_quiz/ui/screens/together/together_nav.dart';
import 'package:together_protocol/together_protocol.dart';

import '../state/together/fake_relay.dart';
import 'large_text.dart';
import 'screens/album_grid_test.dart' as albums;
import 'screens/game_screen_test.dart' as sound;
import 'screens/lyrics_game_screen_test.dart' as lyrics;
import 'screens/lyrics_loading_screen_test.dart' as loading;
import 'screens/main_menu_test.dart' as menu;
import 'screens/navigation_screens_test.dart' as navigation;
import 'screens/nickname_screen_test.dart' as nickname;
import 'screens/round_summary_screen_test.dart' as summary;
import 'screens/settings_screen_test.dart' as settings;
import 'screens/setup_screen_test.dart' as setup;
import 'screens/together/final_standings_screen_test.dart' as standings;
import 'screens/together/join_room_screen_test.dart' as join;
import 'screens/together/lobby_screen_test.dart' as lobby;
import 'screens/together/menu_row_test.dart' as together_menu;
import 'screens/together/together_game_screen_test.dart' as together_game;
import 'overlays/birthday_card_test.dart' as birthday;

const Player _ana = Player(id: 'p-ana', name: 'Ana', avatar: 'seedAna');
const Player _christopher = Player(
  id: 'p-christopher',
  name: 'Christopher',
  avatar: 'seedChristopher',
);

String get _widestWordTitle =>
    maxBy(albums.bundled.allTracks.map(songTitle), (title) {
      final painter = TextPainter(
        text: TextSpan(
          text: title,
          style: const TextStyle(
            fontFamily: AppType.serifFamily,
            fontStyle: FontStyle.italic,
            fontSize: _revealSize,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final width = painter.minIntrinsicWidth;
      painter.dispose();
      return width;
    })!;

const double _revealSize = 56;

PlayerScore _score(Player player, int score) => PlayerScore(
  id: player.id,
  score: score,
  streak: 0,
  best: 4,
  wins: 4,
  fastest: const FastestAnswer(seconds: 1.42, song: 'Daylight'),
  left: false,
);

final class _StillWindow implements WindowControls {
  @override
  Future<bool> isMaximized() async => false;

  @override
  Stream<bool> get maximizedChanges => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

Future<ProviderContainer> _pumpInApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  final container = ProviderContainer.test(overrides: overrides);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Material(child: child),
      ),
    ),
  );
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 30; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _choose(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await _settle(tester);
}

void main() {
  setUpAll(loadRealFonts);

  for (final window in largeTextWindows) {
    group('at twice the text size in a $window window', () {
      Future<List<String>> faultsOf(
        WidgetTester tester,
        Future<void> Function() open, {
        Future<void> Function()? then,
      }) => layoutFaults(tester, () async {
        await tester.pumpWidget(const SizedBox.shrink());
        useLargeText(tester, window);
        await open();
        useLargeText(tester, window);
        await _settle(tester);
        await then?.call();
      });

      testWidgets('every menu greeting fits', (tester) async {
        var faults = const <String>[];
        for (final (edition, name) in const [
          (Edition.ana, null),
          (Edition.open, 'Christopher'),
          (Edition.open, 'Bartholomewsworthing'),
        ]) {
          for (final now in [
            DateTime(2026, 10, 6, 8),
            DateTime(2026, 10, 6, 15),
            DateTime(2026, 10, 6, 20),
            DateTime(2026, 10, 6, 2),
          ]) {
            final found = await faultsOf(
              tester,
              () => menu.pumpMenu(
                tester,
                edition: edition,
                now: now,
                nickname: name,
              ),
            );
            faults = [
              ...faults,
              for (final fault in found) '$edition at ${now.hour}h: $fault',
            ];
          }
        }
        expect(faults, isEmpty);
      });

      testWidgets('the nickname screen fits', (tester) async {
        expect(
          await faultsOf(tester, () => nickname.pumpNickname(tester)),
          isEmpty,
        );
      });

      testWidgets('the era picker fits', (tester) async {
        expect(
          await faultsOf(tester, () => albums.pumpAlbumGrid(tester)),
          isEmpty,
        );
      });

      testWidgets('the sound setup fits', (tester) async {
        expect(await faultsOf(tester, () => setup.pumpSetup(tester)), isEmpty);
      });

      testWidgets('the lyrics setup fits', (tester) async {
        expect(
          await faultsOf(
            tester,
            () => setup.pumpSetup(tester),
            then: () => _choose(tester, 'Lyrics'),
          ),
          isEmpty,
        );
      });

      testWidgets('the round summary fits', (tester) async {
        expect(
          await faultsOf(
            tester,
            () => summary.pumpSummary(tester, summary.roundOf(7)),
          ),
          isEmpty,
        );
      });

      testWidgets('the record shelf fits', (tester) async {
        expect(
          await faultsOf(
            tester,
            () => navigation.pumpScreen(tester, const RecordShelfScreen()),
          ),
          isEmpty,
        );
      });

      testWidgets('lyrics loading and its lost sheets fit', (tester) async {
        var faults = const <String>[];
        for (final lost in [false, true]) {
          final found = await faultsOf(
            tester,
            () => loading.openLyricsLoading(tester, lost: lost),
          );
          faults = [...faults, for (final fault in found) 'lost $lost: $fault'];
        }
        expect(faults, isEmpty);
      });

      testWidgets('every sound game round and reveal fits', (tester) async {
        var faults = const <String>[];
        for (final difficulty in Difficulty.values) {
          for (final answer in [false, true]) {
            final found = await faultsOf(
              tester,
              () => sound.openSoundGame(
                tester,
                difficulty: difficulty,
                answer: answer,
              ),
            );
            faults = [
              ...faults,
              for (final fault in found) '$difficulty answer $answer: $fault',
            ];
          }
        }
        expect(faults, isEmpty);
      });

      testWidgets('a reveal of the widest-worded song fits', (tester) async {
        expect(
          await faultsOf(
            tester,
            () => sound.openSoundGame(
              tester,
              difficulty: Difficulty.easy,
              answer: true,
              title: _widestWordTitle,
            ),
          ),
          isEmpty,
        );
      });

      testWidgets('the releases tab fits', (tester) async {
        expect(
          await faultsOf(
            tester,
            () => albums.pumpAlbumGrid(tester),
            then: () => _choose(tester, AlbumGrid.releasesTab),
          ),
          isEmpty,
        );
      });

      testWidgets('every lyrics game round and reveal fits', (tester) async {
        var faults = const <String>[];
        for (final mode in LyricsMode.values) {
          for (final difficulty in Difficulty.values) {
            for (final answer in [false, true]) {
              final found = await faultsOf(
                tester,
                () => lyrics.openLyricsGame(
                  tester,
                  mode: mode,
                  difficulty: difficulty,
                  answer: answer,
                ),
              );
              faults = [
                ...faults,
                for (final fault in found)
                  '$mode $difficulty answer $answer: $fault',
              ];
            }
          }
        }
        expect(faults, isEmpty);
      });

      testWidgets('the menu with Play together fits', (tester) async {
        expect(
          await faultsOf(
            tester,
            () => together_menu.pumpMenu(
              tester,
              togetherLink: 'https://swiftie.satanshu.tech/#${'Ab0-_' * 8}xyz',
            ),
          ),
          isEmpty,
        );
      });

      testWidgets('the Play together hub and host screens fit', (tester) async {
        var faults = const <String>[];
        for (final screen in [TogetherScreen.hub, TogetherScreen.host]) {
          final found = await faultsOf(
            tester,
            () => lobby.pumpTogether(tester, FakeRelay(), screen: screen),
          );
          faults = [...faults, for (final fault in found) '$screen: $fault'];
        }
        expect(faults, isEmpty);
      });

      testWidgets('the join screen fits', (tester) async {
        expect(
          await faultsOf(tester, () => join.pumpJoin(tester, FakeRelay())),
          isEmpty,
        );
      });

      testWidgets('both lobbies fit', (tester) async {
        var faults = const <String>[];
        for (final hosting in [true, false]) {
          final found = await faultsOf(
            tester,
            () => hosting
                ? lobby.hostLobby(tester, FakeRelay())
                : lobby.guestLobby(tester, FakeRelay()),
          );
          faults = [
            ...faults,
            for (final fault in found) 'hosting $hosting: $fault',
          ];
        }
        expect(faults, isEmpty);
      });

      testWidgets('every Play together round fits', (tester) async {
        var faults = const <String>[];
        for (final (name, state) in [
          for (final mode in [TogetherMode.classic, TogetherMode.quickDraw])
            for (final stage in [
              TogetherStage.countdown,
              TogetherStage.round,
              TogetherStage.reveal,
            ])
              (
                '$mode $stage',
                together_game.soundState(mode: mode, stage: stage),
              ),
          for (final stage in [TogetherStage.round, TogetherStage.reveal])
            ('lie $stage', together_game.lieState(stage: stage)),
        ]) {
          final found = await faultsOf(
            tester,
            () => together_game.pumpGame(tester, state),
          );
          faults = [...faults, for (final fault in found) '$name: $fault'];
        }
        expect(faults, isEmpty);
      });

      testWidgets('the final standings fit', (tester) async {
        var faults = const <String>[];
        for (final (edition, viewer, hosting) in const [
          (Edition.ana, _ana, true),
          (Edition.open, _christopher, false),
        ]) {
          final found = await faultsOf(
            tester,
            () => standings.pumpEnd(
              tester,
              edition: edition,
              viewer: viewer,
              hosting: hosting,
              standings: [_score(_ana, 375), _score(_christopher, 289)],
            ),
          );
          faults = [...faults, for (final fault in found) '$edition: $fault'];
        }
        expect(faults, isEmpty);
      });

      testWidgets('the error screen fits', (tester) async {
        expect(
          await faultsOf(
            tester,
            () => tester.pumpWidget(
              ErrorScreen(error: StateError('layout failed'), onRestart: () {}),
            ),
          ),
          isEmpty,
        );
      });

      testWidgets('the birthday card fits', (tester) async {
        expect(
          await faultsOf(
            tester,
            () => birthday.pumpCard(tester, isOpen: true, size: window),
          ),
          isEmpty,
        );
      });

      testWidgets('the title bar and its update badge fit', (tester) async {
        var faults = const <String>[];
        for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
          final found = await faultsOf(tester, () async {
            final container = await _pumpInApp(
              tester,
              const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTitleBar(),
                  Expanded(child: SizedBox()),
                ],
              ),
              overrides: [
                titleBarPlatformProvider.overrideWithValue(platform),
                windowControlsProvider.overrideWithValue(_StillWindow()),
              ],
            );
            container
                .read(gameControllerProvider.notifier)
                .setUpdaterState(
                  const UpdaterAvailable(
                    manifest: UpdateManifest(
                      version: '0.5.2',
                      notes: '',
                      pubDate: '',
                    ),
                  ),
                );
          });
          faults = [...faults, for (final fault in found) '$platform: $fault'];
        }
        expect(faults, isEmpty);
      });

      testWidgets('an achievement toast fits', (tester) async {
        final longest = maxBy(
          achievementDefs,
          (definition) => definition.name.length,
        )!;
        expect(
          await faultsOf(tester, () async {
            final container = await _pumpInApp(
              tester,
              const Stack(children: [AchievementToasts()]),
            );
            final game = container.read(gameControllerProvider.notifier);
            game
              ..setProgress(
                game.state.progress.copyWith(
                  achievements: {
                    longest.id: const AchievementState(
                      unlocked: true,
                      unlockedAt: '2026-10-06T20:15:00.000Z',
                    ),
                  },
                ),
              )
              ..addToast(longest.id);
          }),
          isEmpty,
        );
      });

      testWidgets("Misu's speech bubble fits", (tester) async {
        final faults = await faultsOf(tester, () async {
          final container = await _pumpInApp(
            tester,
            const Stack(children: [MisuHost()]),
          );
          container.read(misuControllerProvider.notifier).introduce();
        });
        await tester.pump(const Duration(seconds: 10));

        expect(faults, isEmpty);
      });

      testWidgets('settings fit in both editions', (tester) async {
        var faults = const <String>[];
        for (final edition in Edition.values) {
          final found = await faultsOf(
            tester,
            () => settings.pumpSettings(tester, edition: edition),
          );
          faults = [...faults, for (final fault in found) '$edition: $fault'];
        }
        expect(faults, isEmpty);
      });
    });
  }
}
