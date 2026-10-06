import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/ui/kit/choice_row.dart';
import 'package:swiftie_quiz/ui/kit/option_tile.dart';
import 'package:swiftie_quiz/ui/kit/vinyl.dart';
import 'package:swiftie_quiz/ui/screens/setup_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';

const int mediumTimer = 25;
const int hardTimer = 15;

final List<Album> eraAlbums = List.unmodifiable([
  for (final era in curatedEras)
    Album(
      id: era.deezerAlbumId,
      title: era.eraName,
      coverMedium: 'https://covers.test/${era.key}.jpg',
    ),
]);

int albumIdOf(String eraKey) =>
    curatedEras.firstWhere((era) => era.key == eraKey).deezerAlbumId;

typedef TopTracks = Future<List<Track>> Function();

class FakeCatalog extends CatalogController {
  FakeCatalog({required this.topTracks, required this.albumSongs});

  final TopTracks topTracks;
  final Map<int, int> albumSongs;

  @override
  CatalogState build() => CatalogState.initial;

  @override
  Future<void> loadAlbums() async {}

  @override
  Future<List<Track>> fetchTopTracks() => topTracks();

  @override
  Future<AlbumTracks> fetchAlbumTracks(int albumId) async {
    final songs = albumSongs[albumId];
    if (songs == null) {
      return Completer<AlbumTracks>().future;
    }
    state = state.copyWith(
      albumTrackTotals: {...state.albumTrackTotals, albumId: songs},
    );
    return AlbumTracks(tracks: const [], totalTracks: songs);
  }
}

typedef Prepare = void Function(GameController game);

Future<ProviderContainer> pumpSetup(
  WidgetTester tester, {
  GameMode mode = GameMode.random,
  List<String> eraKeys = const [],
  Prepare? prepare,
  TopTracks? topTracks,
  Size size = const Size(1024, 800),
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer.test(
    overrides: [
      catalogControllerProvider.overrideWith(
        () => FakeCatalog(
          topTracks: topTracks ?? () async => const [],
          albumSongs: {
            albumIdOf('red'): 30,
            albumIdOf('folklore'): 17,
            albumIdOf('1989'): 21,
          },
        ),
      ),
    ],
  );
  final game = container.read(gameControllerProvider.notifier)
    ..setAlbums(eraAlbums)
    ..setMediumTimer(mediumTimer)
    ..setHardTimer(hardTimer);
  eraKeys.map(albumIdOf).forEach(game.toggleAlbum);
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
      final topTracks = Completer<List<Track>>();
      await pumpSetup(tester, topTracks: () => topTracks.future, settle: false);
      expect(find.text('Shuffle everything'), findsOneWidget);
      expect(find.text('Every song, every era'), findsOneWidget);

      topTracks.complete(
        List.filled(
          87,
          Track(
            id: 1,
            title: 'Love Story',
            titleShort: 'Love Story',
            duration: 235,
            preview: 'https://previews.test/1.mp3',
            artist: const Artist(id: 12246, name: 'Taylor Swift'),
            album: eraAlbums[1],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('87 songs, every era'), findsOneWidget);
      expect(fanCovers(tester), [
        for (final album in eraAlbums.take(5).toList().reversed)
          album.coverMedium,
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
      expect(find.text('17 songs'), findsOneWidget);
      expect(fanCovers(tester), [eraAlbums[7].coverMedium]);
      expect(fanAngles(tester), [moreOrLessEquals(radians(-6))]);

      await pumpSetup(
        tester,
        mode: GameMode.album,
        eraKeys: ['red', 'folklore', '1989'],
      );
      expect(find.text('Your 3 eras'), findsOneWidget);
      expect(find.text('68 songs'), findsOneWidget);
      expect(find.byType(AlbumSleeve), findsNWidgets(3));

      await pumpSetup(tester, mode: GameMode.album, eraKeys: ['lover']);
      expect(find.text('Lover'), findsOneWidget);
      expect(find.text('— songs'), findsOneWidget);

      await pumpSetup(
        tester,
        topTracks: () => Future.error(StateError('offline')),
      );
      expect(find.text('Every song, every era'), findsOneWidget);

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
}
