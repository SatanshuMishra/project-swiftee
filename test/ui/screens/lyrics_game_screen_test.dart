import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/services/audio/audio_engine.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/game/lyric_snippet_card.dart';
import 'package:swiftie_quiz/ui/game/lyrics_or_lie_card.dart';
import 'package:swiftie_quiz/ui/game/quiz_card.dart';
import 'package:swiftie_quiz/ui/game/result_feedback.dart';
import 'package:swiftie_quiz/ui/game/timer_bar.dart';
import 'package:swiftie_quiz/ui/screens/lyrics_game_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';

const Size _window = Size(1024, 1600);
const double _realLyric = 0.1;
const double _decoyLyric = 0.9;

const List<({int id, String title, String album})> _songs = [
  (id: 1, title: 'Love Story', album: 'Fearless'),
  (id: 2, title: 'Enchanted', album: 'Speak Now'),
  (id: 3, title: 'Style', album: '1989'),
  (id: 4, title: 'Cardigan', album: 'folklore'),
  (id: 5, title: 'Willow', album: 'evermore'),
  (id: 6, title: 'Anti-Hero', album: 'Midnights'),
];

Track _track(({int id, String title, String album}) song) => Track(
  id: song.id,
  title: song.title,
  titleShort: song.title,
  duration: 200,
  preview: 'https://cdnt-preview.dzcdn.net/api/1/1/${song.id}.mp3',
  artist: const Artist(id: 12246, name: 'Taylor Swift'),
  album: Album(id: song.id * 100, title: song.album, coverMedium: null),
);

const List<String> _words = [
  'midnight',
  'rain',
  'golden',
  'river',
  'paper',
  'window',
  'silver',
  'garden',
  'thunder',
  'velvet',
  'harbor',
  'lantern',
];

TrackLyrics _lyricsOf(({int id, String title, String album}) song) =>
    TrackLyrics(
      lrclibId: 1000 + song.id,
      lines: [
        for (var line = 0; line < 12; line++)
          'we walked the ${_words[line]} road number ${song.id} again',
      ],
      lineCount: 12,
      sourceTrack: song.title,
      sourceAlbum: song.album,
    );

final List<TrackWithLyrics> _pool = [
  for (final song in _songs)
    TrackWithLyrics(track: _track(song), lyrics: _lyricsOf(song)),
];

final class _ScriptedRandom implements Random {
  _ScriptedRandom(this.realOrDecoy);

  final double realOrDecoy;

  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => realOrDecoy;

  @override
  bool nextBool() => false;
}

final class _QuackOnlyEngine implements AudioEngine {
  List<double> quacks = const [];

  @override
  Future<void> init() async {}

  @override
  Future<LoadedClip> loadClip(Uint8List mp3Bytes) =>
      throw UnsupportedError('lyrics rounds play no clips');

  @override
  Future<void> unloadClip(LoadedClip clip) async {}

  @override
  AudioVoice playSlice(
    LoadedClip clip,
    double offsetSeconds,
    double durationSeconds,
    double volume,
  ) => throw UnsupportedError('lyrics rounds play no clips');

  @override
  void pause(AudioVoice voice) {}

  @override
  void resume(AudioVoice voice) {}

  @override
  Future<void> stop(AudioVoice voice) async {}

  @override
  double? positionOf(AudioVoice voice) => null;

  @override
  void setVolume(AudioVoice voice, double volume) {}

  @override
  Future<void> playQuack(double volume) async {
    quacks = [...quacks, volume];
  }

  @override
  Future<void> dispose() async {}
}

final class _Harness {
  _Harness(this.tester, {double realOrDecoy = _realLyric})
    : random = _ScriptedRandom(realOrDecoy),
      engine = _QuackOnlyEngine();

  final WidgetTester tester;
  final _ScriptedRandom random;
  final _QuackOnlyEngine engine;

  late final List<Override> _overrides = [
    appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
    clockProvider.overrideWithValue(() => tester.binding.clock.now()),
    randomProvider.overrideWithValue(random),
    audioEngineProvider.overrideWithValue(engine),
    httpClientProvider.overrideWithValue(
      MockClient((request) async => http.Response('', 404)),
    ),
  ];

  Widget _app(Widget child) => ProviderScope(
    overrides: _overrides,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    ),
  );

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold)));

  GameState get state => container.read(gameControllerProvider);

  Future<void> open({
    required LyricsMode mode,
    required Difficulty difficulty,
    int? mediumTimer,
  }) async {
    tester.view.physicalSize = _window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const SizedBox()));
    final game = container.read(gameControllerProvider.notifier)
      ..setMode(GameMode.random)
      ..setQuizType(QuizType.lyrics)
      ..setLyricsMode(mode)
      ..setDifficulty(difficulty)
      ..setLyricsAvailableTracks([for (final entry in _pool) entry.track])
      ..setLyricsPool(_pool)
      ..setPhase(GamePhase.playing);
    for (final entry in _pool.skip(1)) {
      game.addToDecoyPool(entry.track.id, entry.lyrics);
    }
    if (mediumTimer != null) {
      game.setMediumTimer(mediumTimer);
    }
    await tester.pumpWidget(_app(const LyricsGameScreen()));
  }

  Future<void> startFirstRound() async {
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> showResult() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  List<String> get snippetLines => [
    for (final text in tester.widgetList<Text>(
      find.descendant(
        of: find.byType(LyricSnippetCard),
        matching: find.byType(Text),
      ),
    ))
      text.data!,
  ];
}

Track get _first => _pool.first.track;

Finder _option(Track track) => find.descendant(
  of: find.byType(QuizCard),
  matching: find.text(track.titleShort),
);

void main() {
  group('lyrics round flow', () {
    testWidgets('shows Preparing round... until the deferred first round', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await harness.open(
        mode: LyricsMode.nameThatSong,
        difficulty: Difficulty.easy,
      );

      expect(find.text('Preparing round...'), findsOneWidget);
      expect(harness.state.lyricsPoolIndex, 0);

      await harness.startFirstRound();

      expect(find.text('Preparing round...'), findsNothing);
      expect(find.byType(LyricSnippetCard), findsOneWidget);
      expect(harness.state.lyricsPoolIndex, 1);
    });

    for (final (difficulty, lines) in const [
      (Difficulty.easy, 4),
      (Difficulty.medium, 3),
      (Difficulty.hard, 2),
    ]) {
      testWidgets(
        'name that song shows $lines lines on ${difficulty.wireName}',
        (tester) async {
          final harness = _Harness(tester);
          await harness.open(
            mode: LyricsMode.nameThatSong,
            difficulty: difficulty,
          );
          await harness.startFirstRound();

          expect(harness.snippetLines, hasLength(lines));
          expect(
            harness.snippetLines,
            everyElement(allOf(startsWith('“'), endsWith('”'))),
          );
          expect(
            find.text('Album: ${_first.album.title}'),
            difficulty == Difficulty.easy ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(TextField),
            difficulty == Difficulty.hard ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(TimerBar),
            difficulty == Difficulty.easy ? findsNothing : findsOneWidget,
          );
          expect(
            _option(_first),
            difficulty == Difficulty.hard ? findsNothing : findsOneWidget,
          );
        },
      );
    }

    for (final (difficulty, lines) in const [
      (Difficulty.easy, 3),
      (Difficulty.medium, 2),
      (Difficulty.hard, 1),
    ]) {
      testWidgets(
        'lyrics or lie shows $lines lines on ${difficulty.wireName}',
        (tester) async {
          final harness = _Harness(tester);
          await harness.open(
            mode: LyricsMode.lyricsOrLie,
            difficulty: difficulty,
          );
          await harness.startFirstRound();

          expect(harness.snippetLines, hasLength(lines));
          final card = tester.widget<LyricsOrLieCard>(
            find.byType(LyricsOrLieCard),
          );
          expect(card.songTitle, _first.titleShort);
          expect(card.showAlbumCover, difficulty == Difficulty.easy);
          expect(find.text('Is this lyric from...'), findsOneWidget);
          expect(find.text('Real'), findsOneWidget);
          expect(find.text('Fake'), findsOneWidget);
        },
      );
    }

    testWidgets('a right song name adds to the streak and lyrics stats', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await harness.open(
        mode: LyricsMode.nameThatSong,
        difficulty: Difficulty.easy,
      );
      await harness.startFirstRound();

      await tester.tap(_option(_first));
      await harness.showResult();

      final stats = harness.state.progress.stats;
      expect(harness.state.streak, 1);
      expect(stats.totalCorrect, 1);
      expect(stats.totalLyricsCorrect, 1);
      expect(stats.nameThaSongCorrect, 1);
      expect(stats.lyricsOrLieCorrect, 0);
      expect(harness.state.sessionLyricsCorrect, 1);
      expect(harness.engine.quacks, isEmpty);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text && lyricsPositiveMessages.contains(widget.data),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a typed hard answer is matched loosely', (tester) async {
      final harness = _Harness(tester);
      await harness.open(
        mode: LyricsMode.nameThatSong,
        difficulty: Difficulty.hard,
      );
      await harness.startFirstRound();

      await tester.enterText(find.byType(TextField), 'love  story');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await harness.showResult();

      expect(harness.state.streak, 1);
      expect(harness.state.progress.stats.nameThaSongCorrect, 1);
    });

    testWidgets('a wrong song name resets the streak with a quack', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await harness.open(
        mode: LyricsMode.nameThatSong,
        difficulty: Difficulty.medium,
      );
      await harness.startFirstRound();
      final wrong = harness.state.lyricsAvailableTracks.firstWhere(
        (track) =>
            track.id != _first.id && _option(track).evaluate().isNotEmpty,
      );

      await tester.tap(_option(wrong));
      await harness.showResult();

      expect(harness.state.streak, 0);
      expect(harness.state.quackCount, 1);
      expect(harness.engine.quacks, [0.8]);
      expect(harness.state.progress.stats.totalLyricsCorrect, 0);
      expect(find.text('It was “${_first.titleShort}”'), findsOneWidget);
    });

    testWidgets('calling a real lyric real is right', (tester) async {
      final harness = _Harness(tester);
      await harness.open(
        mode: LyricsMode.lyricsOrLie,
        difficulty: Difficulty.medium,
      );
      await harness.startFirstRound();
      expect(harness.snippetLines.first, contains('number 1'));

      await tester.tap(find.text('Real'));
      await harness.showResult();

      expect(harness.state.streak, 1);
      expect(harness.state.progress.stats.lyricsOrLieCorrect, 1);
      expect(harness.state.progress.stats.nameThaSongCorrect, 0);
    });

    testWidgets('calling a decoy real is wrong and names its song', (
      tester,
    ) async {
      final harness = _Harness(tester, realOrDecoy: _decoyLyric);
      await harness.open(
        mode: LyricsMode.lyricsOrLie,
        difficulty: Difficulty.medium,
      );
      await harness.startFirstRound();
      expect(harness.snippetLines.first, contains('number 2'));

      await tester.tap(find.text('Real'));
      await harness.showResult();

      expect(harness.state.streak, 0);
      expect(harness.engine.quacks, [0.8]);
      expect(
        find.text("That's actually from “${_pool[1].lyrics.sourceTrack}”."),
        findsOneWidget,
      );
    });

    testWidgets('calling a decoy fake is right', (tester) async {
      final harness = _Harness(tester, realOrDecoy: _decoyLyric);
      await harness.open(
        mode: LyricsMode.lyricsOrLie,
        difficulty: Difficulty.medium,
      );
      await harness.startFirstRound();

      await tester.tap(find.text('Fake'));
      await harness.showResult();

      expect(harness.state.streak, 1);
      expect(harness.state.progress.stats.lyricsOrLieCorrect, 1);
    });

    testWidgets('a timeout is wrong in name that song', (tester) async {
      final harness = _Harness(tester);
      await harness.open(
        mode: LyricsMode.nameThatSong,
        difficulty: Difficulty.medium,
        mediumTimer: 10,
      );
      await harness.startFirstRound();

      await tester.pump(const Duration(seconds: 9));
      expect(harness.engine.quacks, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      await harness.showResult();

      expect(harness.state.quackCount, 1);
      expect(harness.engine.quacks, [0.8]);
      expect(find.text('It was “${_first.titleShort}”'), findsOneWidget);
    });

    testWidgets('a timeout is wrong in lyrics or lie, even on a decoy', (
      tester,
    ) async {
      final harness = _Harness(tester, realOrDecoy: _decoyLyric);
      await harness.open(
        mode: LyricsMode.lyricsOrLie,
        difficulty: Difficulty.medium,
        mediumTimer: 10,
      );
      await harness.startFirstRound();

      await tester.pump(const Duration(seconds: 10));
      await harness.showResult();

      expect(harness.state.streak, 0);
      expect(harness.engine.quacks, [0.8]);
      expect(harness.state.progress.stats.lyricsOrLieCorrect, 0);
      expect(find.byType(TimerBar), findsNothing);
    });

    testWidgets('Next deals the next song from the pool', (tester) async {
      final harness = _Harness(tester);
      await harness.open(
        mode: LyricsMode.nameThatSong,
        difficulty: Difficulty.easy,
      );
      await harness.startFirstRound();
      await tester.tap(_option(_first));
      await harness.showResult();

      await tester.pump(ResultFeedback.nextDelay);
      await tester.tap(find.text('Next'));
      await harness.showResult();

      expect(harness.state.lyricsPoolIndex, 2);
      expect(find.text('Album: ${_pool[1].track.album.title}'), findsOneWidget);
      expect(harness.snippetLines.first, contains('number 2'));
      expect(find.byType(ResultFeedback), findsNothing);
    });

    testWidgets('Exit returns to the menu', (tester) async {
      final harness = _Harness(tester);
      await harness.open(
        mode: LyricsMode.nameThatSong,
        difficulty: Difficulty.easy,
      );
      await harness.startFirstRound();

      await tester.tap(find.text('Exit'));
      await tester.pump();

      expect(harness.state.phase, GamePhase.menu);
      expect(harness.state.lyricsPool, isEmpty);
    });

    test('line counts per mode and difficulty match LyricsGameScreen.tsx', () {
      expect(
        [
          for (final mode in [...LyricsMode.values, null])
            for (final difficulty in Difficulty.values)
              lyricsLineCount(mode, difficulty),
        ],
        [4, 3, 2, 3, 2, 1, 1, 1, 1],
      );
    });
  });
}
