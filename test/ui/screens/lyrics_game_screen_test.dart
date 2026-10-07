import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/domain/engine/lyric_processor.dart';
import 'package:swiftie_quiz/domain/engine/play_order.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/services/audio/audio_engine.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/play_history_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/game/answer_list.dart';
import 'package:swiftie_quiz/ui/game/game_top_bar.dart';
import 'package:swiftie_quiz/ui/game/lyric_paper.dart';
import 'package:swiftie_quiz/ui/game/praise_lines.dart';
import 'package:swiftie_quiz/ui/game/quack_burst.dart';
import 'package:swiftie_quiz/ui/game/record_player.dart';
import 'package:swiftie_quiz/ui/game/round_heading.dart';
import 'package:swiftie_quiz/ui/screens/lyrics_game_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';

const Size _window = Size(1024, 800);
const double _realLyric = 0.1;
const double _decoyLyric = 0.9;

const List<({int id, String title, String era, int position})> _songs = [
  (id: 1, title: 'Love Story', era: 'fearless', position: 3),
  (id: 2, title: 'Enchanted', era: 'speaknow', position: 9),
  (id: 3, title: 'Style', era: '1989', position: 3),
  (id: 4, title: 'cardigan', era: 'folklore', position: 2),
  (id: 5, title: 'willow', era: 'evermore', position: 1),
  (id: 6, title: 'Anti-Hero', era: 'midnights', position: 3),
];

Era _era(String key) => curatedEras.firstWhere((era) => era.key == key);

Track _track(({int id, String title, String era, int position}) song) => Track(
  id: song.id,
  title: song.title,
  titleShort: song.title,
  duration: 200,
  preview: 'https://cdnt-preview.dzcdn.net/api/1/1/${song.id}.mp3',
  artist: const Artist(id: 12246, name: 'Taylor Swift'),
  album: Album(
    id: _era(song.era).deezerAlbumId,
    title: _era(song.era).eraName,
    coverMedium: null,
  ),
  trackPosition: song.position,
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

TrackLyrics _lyricsOf(
  ({int id, String title, String era, int position}) song,
) => TrackLyrics(
  lrclibId: 1000 + song.id,
  lines: [
    for (var line = 0; line < 12; line++)
      'we walked the ${_words[line]} road number ${song.id} again',
  ],
  lineCount: 12,
  sourceTrack: song.title,
  sourceAlbum: _era(song.era).eraName,
);

final List<TrackWithLyrics> _pool = [
  for (final song in _songs)
    TrackWithLyrics(track: _track(song), lyrics: _lyricsOf(song)),
];

Track get _first => _pool.first.track;

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

  @override
  Future<void> shutdown() async {}
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
    key: ObjectKey(this),
    overrides: _overrides,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Material(child: child),
    ),
  );

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

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
    await tester.pump();
  }

  Future<void> press(LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  Future<void> pressAnswer(int index) => press(
    const [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
    ][index],
  );

  int get rightIndex => [
    for (final button in tester.widgetList<AnswerButton>(
      find.byType(AnswerButton),
    ))
      button.label,
  ].indexOf(_first.title);

  LyricPaper get paper => tester.widget<LyricPaper>(find.byType(LyricPaper));

  AnswerState verdict(String label) => tester
      .widget<RealFakeButton>(find.widgetWithText(RealFakeButton, label))
      .state;
}

Finder _heading(String text) =>
    find.descendant(of: find.byType(RoundHeading), matching: find.text(text));

Finder get _lyricsPraise => find.byWidgetPredicate(
  (widget) => widget is Text && lyricsPositiveMessages.contains(widget.data),
);

Future<void> openLyricsGame(
  WidgetTester tester, {
  required LyricsMode mode,
  required Difficulty difficulty,
  bool answer = false,
}) async {
  final harness = _Harness(tester);
  await harness.open(mode: mode, difficulty: difficulty);
  await harness.startFirstRound();
  if (answer) {
    await harness.pressAnswer(harness.rightIndex == 0 ? 1 : 0);
  }
}

void main() {
  group('lyrics rounds', () {
    testWidgets('lyrics or lie reveals where a fake line came from', (
      tester,
    ) async {
      final harness = _Harness(tester, realOrDecoy: _decoyLyric);
      await harness.open(
        mode: LyricsMode.lyricsOrLie,
        difficulty: Difficulty.medium,
      );
      await harness.startFirstRound();

      expect(find.text('Lyrics or Lie · Medium'), findsOneWidget);
      expect(_heading('Is this lyric from'), findsOneWidget);
      expect(_heading('Love Story?'), findsOneWidget);
      expect(harness.paper.kind, LyricPaperKind.quote);
      expect(harness.paper.lines, hasLength(2));
      expect(harness.paper.lines.first, contains('number 2'));
      expect(find.text('Real'), findsOneWidget);
      expect(find.text('Fake'), findsOneWidget);

      await harness.press(LogicalKeyboardKey.keyF);

      expect(_heading('Right.'), findsOneWidget);
      expect(
        _heading("It's a fake. That line is from Enchanted."),
        findsOneWidget,
      );
      expect(harness.verdict('Fake'), AnswerState.right);
      expect(harness.verdict('Real'), AnswerState.dim);
      expect(harness.state.streak, 1);
      expect(harness.state.progress.stats.lyricsOrLieCorrect, 1);

      final easy = _Harness(tester);
      await easy.open(
        mode: LyricsMode.nameThatSong,
        difficulty: Difficulty.easy,
      );
      await easy.startFirstRound();

      expect(find.text('From Fearless'), findsOneWidget);
      expect(easy.paper.showHint, isTrue);
      expect(easy.paper.revealed, isFalse);
    });

    testWidgets('each lyric round remembers its song and the lines shown', (
      tester,
    ) async {
      final harness = _Harness(tester, realOrDecoy: _decoyLyric);
      await harness.open(
        mode: LyricsMode.lyricsOrLie,
        difficulty: Difficulty.medium,
      );
      await harness.startFirstRound();

      final history = harness.container.read(playHistoryProvider);
      expect(history.read, [songKey(_pool.first.track)]);
      expect(history.lines, [
        for (final line in harness.paper.lines) lyricLineKey(line),
      ]);
    });

    testWidgets('shows the cat loader until the deferred first round', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await harness.open(
        mode: LyricsMode.nameThatSong,
        difficulty: Difficulty.easy,
      );

      expect(find.text('Loading tracks...'), findsOneWidget);
      expect(harness.state.lyricsPoolIndex, 0);

      await harness.startFirstRound();

      expect(find.text('Loading tracks...'), findsNothing);
      expect(find.byType(LyricPaper), findsOneWidget);
      expect(harness.state.lyricsPoolIndex, 1);
      expect(harness.state.roundNumber, 1);
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

          expect(
            find.text('Lyrics · Name That Song · ${difficulty.label}'),
            findsOneWidget,
          );
          expect(_heading('Name that song.'), findsOneWidget);
          expect(harness.paper.kind, LyricPaperKind.liner);
          expect(harness.paper.lines, hasLength(lines));
          expect(
            find.text('From Fearless'),
            difficulty == Difficulty.easy ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(TextField),
            difficulty == Difficulty.hard ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(AnswerButton),
            difficulty == Difficulty.hard ? findsNothing : findsNWidgets(4),
          );
          expect(
            tester.widget<GameTopBar>(find.byType(GameTopBar)).timeFraction,
            difficulty == Difficulty.easy ? isNull : 1,
          );
          expect(find.byType(RecordPlayer), findsNothing);
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

          expect(harness.paper.lines, hasLength(lines));
          expect(find.text('“${harness.paper.lines.first}”'), findsOneWidget);
          expect(
            tester.widget<RecordPlayer>(find.byType(RecordPlayer)).revealed,
            difficulty == Difficulty.easy,
          );
          expect(_heading('Love Story?'), findsOneWidget);
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

      await harness.pressAnswer(harness.rightIndex);

      final stats = harness.state.progress.stats;
      expect(harness.state.streak, 1);
      expect(stats.totalCorrect, 1);
      expect(stats.totalLyricsCorrect, 1);
      expect(stats.nameThaSongCorrect, 1);
      expect(stats.lyricsOrLieCorrect, 0);
      expect(harness.state.sessionLyricsCorrect, 1);
      expect(harness.engine.quacks, isEmpty);
      expect(_heading('It was Love Story.'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(RoundHeading), matching: _lyricsPraise),
        findsOneWidget,
      );
      expect(harness.paper.revealed, isTrue);
      expect(find.text('Love Story'), findsWidgets);
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
      await tester.pump();

      expect(harness.state.streak, 1);
      expect(harness.state.progress.stats.nameThaSongCorrect, 1);
      expect(find.text('You typed “love  story”.'), findsOneWidget);
    });

    testWidgets('a wrong song name quacks and names the era and track', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await harness.open(
        mode: LyricsMode.nameThatSong,
        difficulty: Difficulty.medium,
      );
      await harness.startFirstRound();

      await harness.pressAnswer((harness.rightIndex + 1) % 4);

      expect(harness.state.streak, 0);
      expect(harness.state.quackCount, 1);
      expect(harness.engine.quacks, [0.8]);
      expect(harness.state.progress.stats.totalLyricsCorrect, 0);
      expect(harness.state.roundResults, [
        RoundOutcome(_first, correct: false),
      ]);
      expect(_heading('It was Love Story.'), findsOneWidget);
      expect(_heading('Fearless · track 3'), findsOneWidget);
      expect(tester.widget<QuackBurst>(find.byType(QuackBurst)).level, 1);
    });

    testWidgets('calling a real lyric real is right', (tester) async {
      final harness = _Harness(tester);
      await harness.open(
        mode: LyricsMode.lyricsOrLie,
        difficulty: Difficulty.medium,
      );
      await harness.startFirstRound();
      expect(harness.paper.lines.first, contains('number 1'));

      await harness.press(LogicalKeyboardKey.keyR);

      expect(harness.state.streak, 1);
      expect(harness.state.progress.stats.lyricsOrLieCorrect, 1);
      expect(harness.state.progress.stats.nameThaSongCorrect, 0);
      expect(_heading('Right.'), findsOneWidget);
      expect(_heading("It's a real line from Love Story."), findsOneWidget);
      expect(harness.verdict('Real'), AnswerState.right);
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

      await tester.tap(find.text('Real'));
      await tester.pump();

      expect(harness.state.streak, 0);
      expect(harness.engine.quacks, [0.8]);
      expect(_heading('Not this time.'), findsOneWidget);
      expect(
        _heading("It's a fake. That line is from Enchanted."),
        findsOneWidget,
      );
      expect(harness.verdict('Real'), AnswerState.wrong);
      expect(harness.verdict('Fake'), AnswerState.right);
    });

    testWidgets('a timeout is wrong in name that song', (tester) async {
      final harness = _Harness(tester);
      await harness.open(
        mode: LyricsMode.nameThatSong,
        difficulty: Difficulty.medium,
        mediumTimer: 10,
      );
      await harness.startFirstRound();
      expect(_heading('10 seconds left.'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 9900));
      expect(harness.engine.quacks, isEmpty);
      await tester.pump(const Duration(milliseconds: 100));

      expect(harness.state.quackCount, 1);
      expect(harness.engine.quacks, [0.8]);
      expect(_heading("Time's up. It was Love Story."), findsOneWidget);
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

      expect(harness.state.streak, 0);
      expect(harness.engine.quacks, [0.8]);
      expect(harness.state.progress.stats.lyricsOrLieCorrect, 0);
      expect(_heading("Time's up."), findsOneWidget);
      expect(harness.verdict('Fake'), AnswerState.right);
      expect(harness.verdict('Real'), AnswerState.dim);
    });

    testWidgets('next deals the next song from the pool', (tester) async {
      final harness = _Harness(tester);
      await harness.open(
        mode: LyricsMode.nameThatSong,
        difficulty: Difficulty.easy,
      );
      await harness.startFirstRound();
      await harness.pressAnswer(harness.rightIndex);
      await harness.press(LogicalKeyboardKey.enter);
      expect(harness.state.lyricsPoolIndex, 1);

      await tester.pump(const Duration(seconds: 2));
      await harness.press(LogicalKeyboardKey.enter);

      expect(harness.state.lyricsPoolIndex, 2);
      expect(harness.state.roundNumber, 2);
      expect(find.text('From Speak Now'), findsOneWidget);
      expect(harness.paper.lines.first, contains('number 2'));
      expect(harness.paper.revealed, isFalse);
      expect(_heading('Name that song.'), findsOneWidget);
    });

    testWidgets('exit returns to the menu', (tester) async {
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

extension on Difficulty {
  String get label => switch (this) {
    Difficulty.easy => 'Easy',
    Difficulty.medium => 'Medium',
    Difficulty.hard => 'Hard',
  };
}
