import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/backup_entry.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/persistence_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/cat/cat_icon_button.dart';
import 'package:swiftie_quiz/ui/overlays/birthday_card.dart';
import 'package:swiftie_quiz/ui/screens/album_grid.dart';
import 'package:swiftie_quiz/ui/screens/cat_gallery.dart';
import 'package:swiftie_quiz/ui/screens/difficulty_select.dart';
import 'package:swiftie_quiz/ui/screens/lyrics_mode_select.dart';
import 'package:swiftie_quiz/ui/screens/main_menu.dart';
import 'package:swiftie_quiz/ui/screens/quiz_type_select.dart';
import 'package:swiftie_quiz/ui/screens/settings_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/widgets/selection_card.dart';

final DateTime afterBirthdayPeriod = DateTime(2026, 10, 5, 12);
final DateTime duringBirthdayPeriod = DateTime(2026, 2, 19, 12);

class IdleCatalog extends CatalogController {
  @override
  CatalogState build() => CatalogState.initial;

  @override
  Future<void> loadAlbums() async {}
}

class NoBackups extends PersistenceController {
  @override
  PersistenceStatus build() => PersistenceStatus.loaded;

  @override
  Future<List<BackupEntry>> listBackups() async => const [];
}

typedef Setup = void Function(GameController game);

Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Setup? setup,
  DateTime? now,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer.test(
    overrides: [
      clockProvider.overrideWithValue(() => now ?? afterBirthdayPeriod),
      catalogControllerProvider.overrideWith(IdleCatalog.new),
      persistenceControllerProvider.overrideWith(NoBackups.new),
      appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
    ],
  );
  setup?.call(container.read(gameControllerProvider.notifier));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      key: ObjectKey(container),
      container: container,
      child: MaterialApp(theme: AppTheme.dark, home: screen),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
  return container;
}

GameState gameOf(ProviderContainer container) =>
    container.read(gameControllerProvider);

Finder card(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(SelectionCard));

Finder featureOf(String difficulty, String feature) =>
    find.descendant(of: card(difficulty), matching: find.text(feature));

Future<void> tapBack(WidgetTester tester) async {
  await tester.tap(find.text('Back'));
  await tester.pump();
}

void main() {
  group('menu and selection navigation', () {
    testWidgets('Random Mode picks random mode and opens quiz type', (
      tester,
    ) async {
      final container = await pumpScreen(
        tester,
        const MainMenu(),
        setup: (game) => game.setMode(GameMode.album),
      );

      await tester.tap(find.text('Random Mode'));

      expect(gameOf(container).mode, GameMode.random);
      expect(gameOf(container).phase, GamePhase.quizTypeSelect);
    });

    testWidgets('Pick Albums picks album mode and opens album select', (
      tester,
    ) async {
      final container = await pumpScreen(tester, const MainMenu());

      await tester.tap(find.text('Pick Albums'));

      expect(gameOf(container).mode, GameMode.album);
      expect(gameOf(container).phase, GamePhase.albumSelect);
    });

    testWidgets('Cat Gallery and Settings cards open their screens', (
      tester,
    ) async {
      final container = await pumpScreen(tester, const MainMenu());

      await tester.tap(find.text('Cat Gallery'));
      expect(gameOf(container).phase, GamePhase.catGallery);

      await tester.tap(find.text('Settings'));
      expect(gameOf(container).phase, GamePhase.settings);
    });

    testWidgets('main menu shows the title, subtitle and four cards', (
      tester,
    ) async {
      await pumpScreen(tester, const MainMenu());

      expect(find.text('Swiftie Quiz'), findsOneWidget);
      expect(find.text("How well do you know Taylor's music?"), findsOneWidget);
      for (final (title, description) in [
        ('Random Mode', 'All songs, shuffled randomly'),
        ('Pick Albums', 'Choose your favorite albums'),
        ('Cat Gallery', 'View your achievements'),
        ('Settings', 'Theme, volume & more'),
      ]) {
        expect(
          find.descendant(of: card(title), matching: find.text(description)),
          findsOneWidget,
        );
      }
    });

    testWidgets('sound goes to difficulty and lyrics to lyrics mode', (
      tester,
    ) async {
      final container = await pumpScreen(tester, const QuizTypeSelect());

      await tester.tap(find.text('Sound'));
      expect(gameOf(container).quizType, QuizType.sound);
      expect(gameOf(container).phase, GamePhase.difficultySelect);

      await tester.tap(find.text('Lyrics'));
      expect(gameOf(container).quizType, QuizType.lyrics);
      expect(gameOf(container).phase, GamePhase.lyricsModeSelect);
    });

    testWidgets('quiz type back returns to album select in album mode', (
      tester,
    ) async {
      final container = await pumpScreen(
        tester,
        const QuizTypeSelect(),
        setup: (game) => game.setMode(GameMode.album),
      );

      await tapBack(tester);

      expect(gameOf(container).phase, GamePhase.albumSelect);
    });

    testWidgets('quiz type back returns to the menu in random mode', (
      tester,
    ) async {
      final container = await pumpScreen(
        tester,
        const QuizTypeSelect(),
        setup: (game) => game
          ..setMode(GameMode.random)
          ..setPhase(GamePhase.quizTypeSelect),
      );

      await tapBack(tester);

      expect(gameOf(container).phase, GamePhase.menu);
    });

    testWidgets('lyrics modes set the mode and open difficulty', (
      tester,
    ) async {
      for (final (title, mode) in [
        ('Name That Song', LyricsMode.nameThatSong),
        ('Lyrics or Lie', LyricsMode.lyricsOrLie),
      ]) {
        final container = await pumpScreen(
          tester,
          const LyricsModeSelect(),
          setup: (game) => game.setPhase(GamePhase.lyricsModeSelect),
        );

        await tester.tap(find.text(title));

        expect(gameOf(container).lyricsMode, mode, reason: title);
        expect(gameOf(container).phase, GamePhase.difficultySelect);
      }
    });

    testWidgets('lyrics mode back returns to quiz type', (tester) async {
      final container = await pumpScreen(tester, const LyricsModeSelect());

      await tapBack(tester);

      expect(gameOf(container).phase, GamePhase.quizTypeSelect);
    });

    testWidgets('sound difficulty cards list their features and timers', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const DifficultySelect(),
        setup: (game) => game
          ..setQuizType(QuizType.sound)
          ..setMediumTimer(25)
          ..setHardTimer(15),
      );

      for (final (difficulty, description, features) in [
        (
          'Easy',
          'Quick warm-up round',
          ['Multiple choice', 'Album hint shown', 'No time limit'],
        ),
        (
          'Medium',
          'The real thing',
          ['Multiple choice', 'No album hint', '25-second timer'],
        ),
        (
          'Hard',
          'A challenge worthy of a true Swiftie',
          ['Type your answer', 'No hints', '15-second timer'],
        ),
      ]) {
        expect(featureOf(difficulty, description), findsOneWidget);
        for (final feature in features) {
          expect(featureOf(difficulty, feature), findsOneWidget);
        }
      }
    });

    testWidgets('name-that-song difficulty cards list their features', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const DifficultySelect(),
        setup: (game) => game
          ..setQuizType(QuizType.lyrics)
          ..setLyricsMode(LyricsMode.nameThatSong)
          ..setMediumTimer(35)
          ..setHardTimer(10),
      );

      for (final (difficulty, features) in [
        (
          'Easy',
          ['4 lyric lines from chorus', 'Album hint', 'Multiple choice'],
        ),
        ('Medium', ['3 lyric lines', 'Multiple choice', '35-second timer']),
        (
          'Hard',
          ['2 lyric lines, no chorus', 'Type your answer', '10-second timer'],
        ),
      ]) {
        for (final feature in features) {
          expect(featureOf(difficulty, feature), findsOneWidget);
        }
      }
    });

    testWidgets('lyrics-or-lie difficulty cards list their features', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const DifficultySelect(),
        setup: (game) => game
          ..setQuizType(QuizType.lyrics)
          ..setLyricsMode(LyricsMode.lyricsOrLie),
      );

      for (final (difficulty, features) in [
        (
          'Easy',
          [
            '3 lyric lines shown',
            'Album cover shown',
            'Fakes from different eras',
            'No time limit',
          ],
        ),
        (
          'Medium',
          [
            '2 lyric lines shown',
            'No hints',
            'Fakes from similar albums',
            '30-second timer',
          ],
        ),
        (
          'Hard',
          [
            '1 lyric line shown',
            'No hints',
            'Fakes from same album',
            '20-second timer',
          ],
        ),
      ]) {
        for (final feature in features) {
          expect(featureOf(difficulty, feature), findsOneWidget);
        }
      }
    });

    testWidgets('choosing a sound difficulty starts playing', (tester) async {
      final container = await pumpScreen(
        tester,
        const DifficultySelect(),
        setup: (game) => game.setQuizType(QuizType.sound),
      );

      await tester.tap(find.text('Hard'));

      expect(gameOf(container).difficulty, Difficulty.hard);
      expect(gameOf(container).phase, GamePhase.playing);
    });

    testWidgets('choosing a lyrics difficulty opens lyrics loading', (
      tester,
    ) async {
      final container = await pumpScreen(
        tester,
        const DifficultySelect(),
        setup: (game) => game
          ..setQuizType(QuizType.lyrics)
          ..setLyricsMode(LyricsMode.nameThatSong)
          ..setDifficulty(Difficulty.hard),
      );

      await tester.tap(find.text('Easy'));

      expect(gameOf(container).difficulty, Difficulty.easy);
      expect(gameOf(container).phase, GamePhase.lyricsLoading);
    });

    testWidgets('difficulty back follows the quiz type', (tester) async {
      for (final (quizType, expected) in [
        (QuizType.lyrics, GamePhase.lyricsModeSelect),
        (QuizType.sound, GamePhase.quizTypeSelect),
        (null, GamePhase.menu),
      ]) {
        final container = await pumpScreen(
          tester,
          DifficultySelect(key: ValueKey(quizType)),
          setup: (game) {
            if (quizType != null) {
              game.setQuizType(quizType);
            }
          },
        );

        await tapBack(tester);

        expect(gameOf(container).phase, expected, reason: '$quizType');
      }
    });

    testWidgets('album select, gallery and settings go back to the menu', (
      tester,
    ) async {
      for (final screen in const [
        AlbumGrid(),
        CatGallery(),
        SettingsScreen(),
      ]) {
        final container = await pumpScreen(
          tester,
          screen,
          setup: (game) => game.setPhase(GamePhase.settings),
        );
        expect(gameOf(container).phase, GamePhase.settings);

        await tapBack(tester);

        expect(
          gameOf(container).phase,
          GamePhase.menu,
          reason: '${screen.runtimeType}',
        );
      }
    });
  });

  group('main menu birthday card', () {
    testWidgets('opens one second after the menu during the birthday period', (
      tester,
    ) async {
      final container = await pumpScreen(
        tester,
        const MainMenu(),
        now: duringBirthdayPeriod,
        settle: false,
      );

      await tester.pump(const Duration(milliseconds: 999));
      expect(find.text('Happy Birthday!'), findsNothing);
      expect(container.read(birthdayCardSessionProvider), isFalse);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Happy Birthday!'), findsOneWidget);
      expect(container.read(birthdayCardSessionProvider), isTrue);
    });

    testWidgets('does not open again once shown this session', (tester) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer.test(
        overrides: [
          clockProvider.overrideWithValue(() => duringBirthdayPeriod),
        ],
      );
      container.read(birthdayCardSessionProvider.notifier).markShown();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.dark, home: const MainMenu()),
        ),
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Happy Birthday!'), findsNothing);
    });

    testWidgets('does not open after the birthday period', (tester) async {
      final container = await pumpScreen(tester, const MainMenu());

      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Happy Birthday!'), findsNothing);
      expect(container.read(birthdayCardSessionProvider), isFalse);
    });

    testWidgets(
      'the cat button opens the card and its close button closes it',
      (tester) async {
        await pumpScreen(tester, const MainMenu());

        await tester.tap(find.byType(CatIconButton));
        await tester.pumpAndSettle();
        expect(find.text('Happy Birthday!'), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(BirthdayCard),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && (widget.properties.button ?? false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Happy Birthday!'), findsNothing);
      },
    );

    testWidgets('the cat sits 24 px from the top right at 64 px', (
      tester,
    ) async {
      await pumpScreen(tester, const MainMenu());

      final cat = tester.getRect(find.byType(CatIconButton));
      expect(cat.top, 24);
      expect(cat.right, 1024 - 24);
      expect(cat.height, 64);
    });

    testWidgets('hovering the cat fades the Birthday Card tooltip in', (
      tester,
    ) async {
      await pumpScreen(tester, const MainMenu());
      double tooltipOpacity() => tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.text('Birthday Card'),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;
      expect(tooltipOpacity(), 0);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(CatIconButton)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(tooltipOpacity(), inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 75));
      expect(tooltipOpacity(), 1);
    });
  });
}
