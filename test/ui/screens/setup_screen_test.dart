import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_store.dart';
import 'package:swiftie_quiz/domain/engine/catalogue_rules.dart';
import 'package:swiftie_quiz/domain/engine/play_order.dart';
import 'package:swiftie_quiz/domain/engine/version_filter.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/ui/kit/choice_row.dart';
import 'package:swiftie_quiz/ui/kit/option_tile.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/toggle_card.dart';
import 'package:swiftie_quiz/ui/kit/vinyl.dart';
import 'package:swiftie_quiz/ui/screens/setup_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';

const int mediumTimer = 25;
const int hardTimer = 15;

final Catalogue bundled = buildCatalogue(
  decodeCatalogue(File(bundledCataloguePath).readAsStringSync()),
);

class FakeCatalog extends CatalogController {
  FakeCatalog(this.catalogue);

  final Catalogue catalogue;

  @override
  CatalogState build() => CatalogState.initial.copyWith(catalogue: catalogue);

  @override
  Future<void> loadCatalogue() async {}
}

typedef Prepare = void Function(GameController game);

Future<ProviderContainer> pumpSetup(
  WidgetTester tester, {
  GameMode mode = GameMode.random,
  List<String> eraKeys = const [],
  Prepare? prepare,
  Catalogue? catalogue,
  Size size = const Size(1024, 800),
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer.test(
    overrides: [
      catalogControllerProvider.overrideWith(
        () => FakeCatalog(catalogue ?? bundled),
      ),
    ],
  );
  final game = container.read(gameControllerProvider.notifier)
    ..setAlbums((catalogue ?? bundled).albums)
    ..setMediumTimer(mediumTimer)
    ..setHardTimer(hardTimer);
  eraKeys.forEach(game.toggleEra);
  prepare?.call(game);
  game.beginSetup(mode);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      key: ObjectKey(container),
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Material(
          type: MaterialType.transparency,
          child: SetupScreen(),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return container;
}

GameState gameOf(ProviderContainer container) =>
    container.read(gameControllerProvider);

List<String> featureList(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(
    find.descendant(of: find.byType(Wrap), matching: find.byType(Text)),
  ))
    text.data!,
];

bool choiceSelected(WidgetTester tester, String title) =>
    tester.widget<ChoiceRow>(find.widgetWithText(ChoiceRow, title)).selected;

bool tileSelected(WidgetTester tester, String title) =>
    tester.widget<OptionTile>(find.widgetWithText(OptionTile, title)).selected;

bool cardChecked(WidgetTester tester, String title) =>
    tester.widget<ToggleCard>(find.widgetWithText(ToggleCard, title)).checked;

Future<void> choose(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

double rotationOf(WidgetTester tester, AlbumSleeve sleeve) {
  final rotation = tester
      .widget<Transform>(
        find
            .ancestor(
              of: find.byWidget(sleeve),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform;
  return math.atan2(rotation.entry(1, 0), rotation.entry(0, 0));
}

List<double> fanAngles(WidgetTester tester) => [
  for (final sleeve in tester.widgetList<AlbumSleeve>(find.byType(AlbumSleeve)))
    rotationOf(tester, sleeve),
];

List<double> fanOffsets(WidgetTester tester) => [
  for (final sleeve in tester.widgetList<AlbumSleeve>(find.byType(AlbumSleeve)))
    tester
        .widget<Positioned>(
          find.ancestor(
            of: find.byWidget(sleeve),
            matching: find.byType(Positioned),
          ),
        )
        .left!,
];

List<String?> fanCovers(WidgetTester tester) => [
  for (final sleeve in tester.widgetList<AlbumSleeve>(find.byType(AlbumSleeve)))
    sleeve.coverUrl,
];

double radians(double degrees) => degrees * math.pi / 180;

void main() {
  group('set up', () {
    testWidgets(
      'set up shows the feature list for the chosen mode and difficulty',
      (tester) async {
        await pumpSetup(tester);

        expect(find.text("You're playing"), findsOneWidget);
        expect(find.text('Listen or read'), findsOneWidget);
        expect(find.text('Difficulty'), findsOneWidget);
        expect(find.text('Which lyrics game'), findsNothing);
        expect(find.text('Name That Song'), findsNothing);
        expect(find.text('Lyrics or Lie'), findsNothing);
        expect(find.text('Hear a clip, name the song.'), findsOneWidget);
        expect(
          find.text('Read the words, test what you know.'),
          findsOneWidget,
        );
        expect(find.text('Quick warm-up'), findsOneWidget);
        expect(find.text('The real thing'), findsOneWidget);
        expect(find.text('For true Swifties'), findsOneWidget);
        expect(featureList(tester), [
          'Multiple choice',
          'No album hint',
          '$mediumTimer-second timer',
        ]);

        await choose(tester, 'Hard');
        expect(featureList(tester), [
          'Type your answer',
          'No hints',
          '$hardTimer-second timer',
        ]);
        expect(find.text('Which lyrics game'), findsNothing);

        await choose(tester, 'Lyrics');
        expect(find.text('Which lyrics game'), findsOneWidget);
        expect(find.text('Name That Song'), findsOneWidget);
        expect(find.text('Lyrics or Lie'), findsOneWidget);
        expect(find.text('Read the lyrics, guess the title.'), findsOneWidget);
        expect(find.text('See a lyric, decide if it’s real.'), findsOneWidget);
        expect(featureList(tester), [
          '2 lyric lines, no chorus',
          'Type your answer',
          '$hardTimer-second timer',
        ]);

        await choose(tester, 'Easy');
        expect(featureList(tester), [
          '4 lyric lines from the chorus',
          'Album hint',
          'Multiple choice',
        ]);

        await choose(tester, 'Medium');
        expect(featureList(tester), [
          '3 lyric lines',
          'Multiple choice',
          '$mediumTimer-second timer',
        ]);

        await choose(tester, 'Lyrics or Lie');
        expect(featureList(tester), [
          '2 lyric lines',
          'No hints',
          'Fakes from similar albums',
          '$mediumTimer-second timer',
        ]);

        await choose(tester, 'Easy');
        expect(featureList(tester), [
          '3 lyric lines',
          'Album cover shown',
          'Fakes from different eras',
          'No time limit',
        ]);

        await choose(tester, 'Hard');
        expect(featureList(tester), [
          '1 lyric line',
          'No hints',
          'Fakes from the same album',
          '$hardTimer-second timer',
        ]);

        await choose(tester, 'Easy');
        await choose(tester, 'Sound');
        expect(find.text('Which lyrics game'), findsNothing);
        expect(find.text('Lyrics or Lie'), findsNothing);
        expect(featureList(tester), [
          'Multiple choice',
          'Album cover shown',
          'No time limit',
        ]);
      },
    );

    testWidgets('start opens the game or the lyrics loader', (tester) async {
      var container = await pumpSetup(tester);
      await tester.tap(find.text('Start →'));
      await tester.pump();
      expect(gameOf(container).quizType, QuizType.sound);
      expect(gameOf(container).difficulty, Difficulty.medium);
      expect(gameOf(container).phase, GamePhase.playing);

      container = await pumpSetup(tester);
      await choose(tester, 'Lyrics');
      await choose(tester, 'Lyrics or Lie');
      await choose(tester, 'Hard');
      await tester.tap(find.text('Start →'));
      await tester.pump();
      expect(gameOf(container).quizType, QuizType.lyrics);
      expect(gameOf(container).lyricsMode, LyricsMode.lyricsOrLie);
      expect(gameOf(container).difficulty, Difficulty.hard);
      expect(gameOf(container).phase, GamePhase.lyricsLoading);

      container = await pumpSetup(
        tester,
        mode: GameMode.album,
        eraKeys: ['red'],
      );
      await tester.tap(find.text('Back'));
      await tester.pump();
      expect(gameOf(container).phase, GamePhase.albumSelect);

      container = await pumpSetup(tester);
      await tester.tap(find.text('Back'));
      await tester.pump();
      expect(gameOf(container).phase, GamePhase.menu);
    });

    testWidgets('set up names the source and fans up to five covers', (
      tester,
    ) async {
      await pumpSetup(tester, catalogue: Catalogue.empty);
      expect(find.text('Shuffle everything'), findsOneWidget);
      expect(find.text('Every song, every era'), findsOneWidget);

      await pumpSetup(tester);
      expect(
        find.text('${bundled.allTracks.length} tracks, every era'),
        findsOneWidget,
      );
      expect(fanCovers(tester), [
        for (final era in curatedEras.take(5).toList().reversed)
          bundled.coverFor(era.key),
      ]);
      expect(fanAngles(tester), [
        for (final step in [2, 1, 0, -1, -2])
          moreOrLessEquals(radians(step * 3.0)),
      ]);
      expect(fanOffsets(tester), [136, 102, 68, 34, 0]);
      expect(
        tester
            .widgetList<AlbumSleeve>(find.byType(AlbumSleeve))
            .map((sleeve) => sleeve.size),
        everyElement(170),
      );

      await pumpSetup(tester, mode: GameMode.album, eraKeys: ['folklore']);
      expect(find.text('folklore'), findsOneWidget);
      expect(
        find.text('${bundled.trackCount('folklore')} tracks'),
        findsOneWidget,
      );
      expect(fanCovers(tester), [bundled.coverFor('folklore')]);
      expect(fanAngles(tester), [moreOrLessEquals(radians(-6))]);

      await pumpSetup(
        tester,
        mode: GameMode.album,
        eraKeys: ['red', 'folklore', '1989'],
      );
      expect(find.text('Your 3 eras'), findsOneWidget);
      expect(
        find.text(
          '${bundled.tracksFor(['red', 'folklore', '1989']).length} tracks',
        ),
        findsOneWidget,
      );
      expect(find.byType(AlbumSleeve), findsNWidgets(3));

      await pumpSetup(
        tester,
        mode: GameMode.album,
        eraKeys: ['lover'],
        catalogue: Catalogue.empty,
      );
      expect(find.text('Lover'), findsOneWidget);
      expect(find.text('— tracks'), findsOneWidget);

      await pumpSetup(tester, size: const Size(800, 800));
      expect(find.text('Shuffle everything'), findsOneWidget);
      expect(find.byType(AlbumSleeve), findsNothing);
    });

    testWidgets('set up opens on the previous choices', (tester) async {
      await pumpSetup(tester);
      expect(choiceSelected(tester, 'Sound'), isTrue);
      expect(choiceSelected(tester, 'Lyrics'), isFalse);
      expect(tileSelected(tester, 'Medium'), isTrue);

      await pumpSetup(
        tester,
        prepare: (game) => game
          ..setQuizType(QuizType.lyrics)
          ..setLyricsMode(LyricsMode.lyricsOrLie)
          ..setDifficulty(Difficulty.hard),
      );
      expect(choiceSelected(tester, 'Lyrics'), isTrue);
      expect(choiceSelected(tester, 'Lyrics or Lie'), isTrue);
      expect(choiceSelected(tester, 'Name That Song'), isFalse);
      expect(tileSelected(tester, 'Hard'), isTrue);
      expect(tileSelected(tester, 'Medium'), isFalse);

      await pumpSetup(
        tester,
        prepare: (game) => game
          ..setQuizType(QuizType.lyrics)
          ..setDifficulty(Difficulty.hard)
          ..resetGame(),
      );
      expect(choiceSelected(tester, 'Sound'), isTrue);
      expect(tileSelected(tester, 'Hard'), isTrue);
    });
  });

  group('releases and versions', () {
    CatalogueRelease release(String title) =>
        bundled.releases.firstWhere((release) => release.title == title);
    Prepare releases(List<String> titles, {List<String> eras = const []}) =>
        (game) {
          eras.forEach(game.toggleEra);
          for (final title in titles) {
            game.toggleRelease(release(title).id);
          }
        };

    test('names releases, eras or both as the source', () {
      final red = Catalogue.empty.eraByKey('red')!;
      final folklore = release('folklore');
      final lover = release('Lover');

      expect(SetupScreen.sourceTitle(const [], [folklore]), 'folklore');
      expect(
        SetupScreen.sourceTitle(const [], [folklore, lover]),
        'Your 2 releases',
      );
      expect(SetupScreen.sourceTitle([red], [folklore]), 'Your picks');
      expect(SetupScreen.sourceTitle([red]), 'Red');
    });

    testWidgets('a release pick shows its title and covers', (tester) async {
      await pumpSetup(
        tester,
        mode: GameMode.album,
        prepare: releases(['folklore (deluxe version)']),
      );

      expect(find.text('folklore (deluxe version)'), findsOneWidget);
      expect(
        find.text(
          '${release('folklore (deluxe version)').tracks.length} tracks',
        ),
        findsOneWidget,
      );
      expect(fanCovers(tester), [
        release('folklore (deluxe version)').coverMedium,
      ]);
    });

    testWidgets('a sound game over re-recorded eras offers every version, '
        'all selected, and lyrics hide them', (tester) async {
      await pumpSetup(tester, mode: GameMode.album, eraKeys: ['red']);

      expect(find.text('Recordings'), findsOneWidget);
      expect(find.text('Also play'), findsOneWidget);
      for (final title in [
        'Taylor’s Version',
        'Originals',
        'Live takes',
        'Acoustic & other takes',
      ]) {
        expect(cardChecked(tester, title), isTrue, reason: title);
      }
      expect(
        tester.getSemantics(find.text('Originals')),
        isSemantics(hasCheckedState: true, isChecked: true),
      );

      await choose(tester, 'Lyrics');
      expect(find.text('Recordings'), findsNothing);
      expect(find.text('Also play'), findsNothing);
    });

    testWidgets('start stays in view at 1024 by 800 with every version '
        'section showing', (tester) async {
      await pumpSetup(tester);

      expect(find.text('Recordings'), findsOneWidget);
      expect(find.text('Also play'), findsOneWidget);
      final start = find.ancestor(
        of: find.text('Start →'),
        matching: find.byType(PillButton),
      );
      expect(tester.getBottomLeft(start).dy, lessThanOrEqualTo(800));
    });

    testWidgets('an era with no re-recordings or other takes asks nothing', (
      tester,
    ) async {
      await pumpSetup(tester, mode: GameMode.album, eraKeys: ['rep']);

      expect(find.text('Recordings'), findsNothing);
      expect(find.text('Also play'), findsNothing);
    });

    testWidgets('an era shows only the takes it has', (tester) async {
      await pumpSetup(tester, mode: GameMode.album, eraKeys: ['evermore']);

      expect(find.text('Recordings'), findsNothing);
      expect(find.text('Live takes'), findsNothing);
      expect(find.text('Acoustic & other takes'), findsOneWidget);
    });

    testWidgets('cards turn on and off together, recount the tracks and '
        'start with the choice', (tester) async {
      final container = await pumpSetup(
        tester,
        mode: GameMode.album,
        eraKeys: ['red'],
      );
      final red = bundled.tracksFor(['red']);
      expect(find.text('${red.length} tracks'), findsOneWidget);

      await choose(tester, 'Originals');
      await choose(tester, 'Live takes');
      final choice = VersionChoice.all.copyWith(
        originals: false,
        liveTakes: false,
      );
      final kept = keepVersions(red, choice).length;
      expect(kept, lessThan(red.length));
      expect(find.text('$kept tracks'), findsOneWidget);
      expect(cardChecked(tester, 'Originals'), isFalse);
      expect(cardChecked(tester, 'Taylor’s Version'), isTrue);
      expect(cardChecked(tester, 'Live takes'), isFalse);

      await tester.tap(find.text('Start →'));
      await tester.pump();
      expect(gameOf(container).versions, choice);
      expect(gameOf(container).phase, GamePhase.playing);
    });

    testWidgets('the last recording kind cannot be turned off', (tester) async {
      await pumpSetup(tester, mode: GameMode.album, eraKeys: ['red']);

      await choose(tester, 'Originals');
      await choose(tester, 'Taylor’s Version');

      expect(cardChecked(tester, 'Taylor’s Version'), isTrue);
      expect(cardChecked(tester, 'Originals'), isFalse);
      expect(
        tester.getSemantics(find.text('Taylor’s Version')),
        isSemantics(hasEnabledState: true, isEnabled: false),
      );
    });

    testWidgets('lyrics count songs, not recordings', (tester) async {
      await pumpSetup(tester, mode: GameMode.album, eraKeys: ['red']);

      await choose(tester, 'Lyrics');

      final songs = {
        for (final track in bundled.tracksFor(['red'])) songKey(track),
      }.length;
      expect(find.text('$songs songs'), findsOneWidget);
    });

    testWidgets('an all-live pick cannot leave out live takes', (tester) async {
      final container = await pumpSetup(
        tester,
        mode: GameMode.album,
        prepare: (game) {
          releases(['Speak Now World Tour Live'])(game);
          game.setVersions(VersionChoice.all.copyWith(liveTakes: false));
        },
      );

      expect(cardChecked(tester, 'Live takes'), isTrue);
      await choose(tester, 'Live takes');
      expect(cardChecked(tester, 'Live takes'), isTrue);

      await tester.tap(find.text('Start →'));
      await tester.pump();
      expect(gameOf(container).versions, VersionChoice.all);
    });
  });
}
