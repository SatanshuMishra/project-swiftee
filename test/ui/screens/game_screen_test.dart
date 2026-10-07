import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/catalog/catalog_error.dart';
import 'package:swiftie_quiz/data/lyrics/danger_zones.dart';
import 'package:swiftie_quiz/domain/engine/clip_selector.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/services/audio/audio_engine.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/misu_controller.dart';
import 'package:swiftie_quiz/state/play_history_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/game/answer_list.dart';
import 'package:swiftie_quiz/ui/game/game_top_bar.dart';
import 'package:swiftie_quiz/ui/game/next_prompt.dart';
import 'package:swiftie_quiz/ui/game/praise_lines.dart';
import 'package:swiftie_quiz/ui/game/quack_burst.dart';
import 'package:swiftie_quiz/ui/game/record_player.dart';
import 'package:swiftie_quiz/ui/game/round_heading.dart';
import 'package:swiftie_quiz/ui/game/transport_bar.dart';
import 'package:swiftie_quiz/ui/kit/modal_stack.dart';
import 'package:swiftie_quiz/ui/screens/game_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

const Size _window = Size(1024, 800);
const double _clipLength = 30;
const int _sampleRate = 8000;

Era _era(String key) => curatedEras.firstWhere((era) => era.key == key);

Track _song(int id, String title, String eraKey, int? position) {
  final era = _era(eraKey);
  return Track(
    id: id,
    title: title,
    titleShort: title,
    duration: 200,
    preview: 'https://cdnt-preview.dzcdn.net/api/1/1/$id.mp3',
    artist: const Artist(id: 12246, name: 'Taylor Swift'),
    album: Album(
      id: era.deezerAlbumId,
      title: "${era.eraName} (Taylor's Version)",
      coverMedium: null,
    ),
    trackPosition: position,
  );
}

final Track _loveStory = _song(1, 'Love Story', 'fearless', 3);
final Track _enchanted = _song(2, 'Enchanted', 'speaknow', 9);

final List<Track> _songs = [
  _loveStory,
  _enchanted,
  _song(3, 'Style', '1989', 3),
  _song(4, 'cardigan', 'folklore', 2),
  _song(5, 'willow', 'evermore', 1),
  _song(6, 'Anti-Hero', 'midnights', 3),
];

final class _ScriptedRandom implements Random {
  @override
  int nextInt(int max) => max == 2 ? 0 : max - 1;

  @override
  double nextDouble() => 0.5;

  @override
  bool nextBool() => false;
}

final class _ScriptedCatalog extends CatalogController {
  _ScriptedCatalog(this._load);

  final Future<CatalogTracks> Function() _load;

  @override
  Future<CatalogTracks> loadTrackPool() => _load();
}

final class _RecordingMisu extends MisuController {
  List<({bool correct, int streak, int missRun, int roundNumber})> answers =
      const [];

  @override
  void afterAnswer({
    required bool correct,
    required int streak,
    required int missRun,
    required int roundNumber,
  }) {
    answers = [
      ...answers,
      (
        correct: correct,
        streak: streak,
        missRun: missRun,
        roundNumber: roundNumber,
      ),
    ];
    super.afterAnswer(
      correct: correct,
      streak: streak,
      missRun: missRun,
      roundNumber: roundNumber,
    );
  }
}

final class _FakeClip implements LoadedClip {
  @override
  double get durationSeconds => _clipLength;

  @override
  Future<ClipAudio> readSamples() async {
    final count = (_clipLength * _sampleRate).ceil();
    return ClipAudio(
      Float32List(count)..fillRange(0, count, 0.5),
      _sampleRate,
      _clipLength,
    );
  }
}

final class _FakeEngine implements AudioEngine {
  List<Completer<void>> decodeGates = const [];
  int decodes = 0;
  List<AudioVoice> voices = const [];
  List<AudioVoice> paused = const [];
  List<AudioVoice> stopped = const [];
  List<double> quacks = const [];
  Map<AudioVoice, double?> _positions = const {};

  void endAll() => _positions = {for (final voice in voices) voice: null};

  @override
  Future<void> init() async {}

  @override
  Future<LoadedClip> loadClip(Uint8List mp3Bytes) async {
    final decode = decodes;
    decodes += 1;
    if (decode < decodeGates.length) {
      await decodeGates[decode].future;
    }
    return _FakeClip();
  }

  @override
  Future<void> unloadClip(LoadedClip clip) async {}

  @override
  AudioVoice playSlice(
    LoadedClip clip,
    double offsetSeconds,
    double durationSeconds,
    double volume,
  ) {
    final voice = AudioVoice(voices.length + 1);
    voices = [...voices, voice];
    _positions = {..._positions, voice: offsetSeconds};
    return voice;
  }

  @override
  void pause(AudioVoice voice) => paused = [...paused, voice];

  @override
  void resume(AudioVoice voice) {}

  @override
  Future<void> stop(AudioVoice voice) async {
    stopped = [...stopped, voice];
    _positions = {..._positions, voice: null};
  }

  @override
  double? positionOf(AudioVoice voice) => _positions[voice];

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

final class _NoDangerZones implements DangerZoneService {
  @override
  Future<List<DangerZone>> fetchDangerZones(
    String trackTitle,
    String artistName,
    String titleShort,
    num songDurationSeconds,
  ) async => const [];

  @override
  void clearDangerZoneCache() {}
}

final class _Harness {
  _Harness(
    this.tester, {
    List<Track>? pool,
    Future<CatalogTracks> Function()? load,
  }) : engine = _FakeEngine(),
       misu = _RecordingMisu() {
    final order = pool ?? _songs;
    _load = load ?? () async => (allTracks: _songs, pool: order);
  }

  final WidgetTester tester;
  final _FakeEngine engine;
  final _RecordingMisu misu;
  late Future<CatalogTracks> Function() _load;
  int previewStatus = 200;
  Set<int> withdrawn = const {};
  List<String> deezerRequests = const [];

  set load(Future<CatalogTracks> Function() next) => _load = next;

  late final List<Override> _overrides = [
    appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
    clockProvider.overrideWithValue(() => tester.binding.clock.now()),
    randomProvider.overrideWithValue(_ScriptedRandom()),
    audioEngineProvider.overrideWithValue(engine),
    dangerZoneServiceProvider.overrideWithValue(AsyncData(_NoDangerZones())),
    httpClientProvider.overrideWithValue(
      MockClient((request) async {
        if (request.url.host == 'cdnt-preview.dzcdn.net') {
          return http.Response.bytes([1, 2, 3], previewStatus);
        }
        final id = int.tryParse(request.url.pathSegments.lastOrNull ?? '');
        if (request.url.host == 'api.deezer.com' && id != null) {
          deezerRequests = [...deezerRequests, request.url.path];
          return http.Response(
            withdrawn.contains(id)
                ? '{"error":{"type":"DataException","message":"no data","code":800}}'
                : '{"id":$id,"title":"Song $id","duration":200,'
                      '"preview":"https://cdnt-preview.dzcdn.net/api/1/1/$id.mp3",'
                      '"artist":{"id":12246,"name":"Taylor Swift"}}',
            200,
          );
        }
        return http.Response('', 404);
      }),
    ),
    catalogControllerProvider.overrideWith(
      () => _ScriptedCatalog(() => _load()),
    ),
    misuControllerProvider.overrideWith(() => misu),
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

  GameController get game => container.read(gameControllerProvider.notifier);

  GameState get state => container.read(gameControllerProvider);

  Track get current => state.currentTrack!;

  int get rightIndex => state.options.indexOf(current);

  Future<void> open({
    Difficulty difficulty = Difficulty.easy,
    int? mediumTimer,
    int? hardTimer,
    bool quickRound = false,
  }) async {
    tester.view.physicalSize = _window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const SizedBox()));
    if (mediumTimer != null) {
      game.setMediumTimer(mediumTimer);
    }
    if (hardTimer != null) {
      game.setHardTimer(hardTimer);
    }
    if (quickRound) {
      game.startQuickRound();
    } else {
      game
        ..setMode(GameMode.random)
        ..setQuizType(QuizType.sound)
        ..setDifficulty(difficulty)
        ..setPhase(GamePhase.playing);
    }
    await tester.pumpWidget(_app(const GameScreen()));
    await settle();
    await tester.pump(GameScreen.roundLoaderMinimum);
  }

  Future<void> settle() async {
    for (var i = 0; i < 12; i++) {
      await tester.pump();
    }
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

  Future<void> nextSong() async {
    await tester.pump(const Duration(seconds: 2));
    await press(LogicalKeyboardKey.enter);
    await settle();
    await tester.pump(GameScreen.roundLoaderMinimum);
    await settle();
  }

  double get nextOpacity => tester
      .widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(NextPrompt),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  List<AnswerState> get answerStates => [
    for (final button in tester.widgetList<AnswerButton>(
      find.byType(AnswerButton),
    ))
      button.state,
  ];

  TransportStatus get transport =>
      tester.widget<TransportBar>(find.byType(TransportBar)).status;
}

Finder _heading(String text) =>
    find.descendant(of: find.byType(RoundHeading), matching: find.text(text));

Finder _catLoader(double px) =>
    find.byWidgetPredicate((widget) => widget is CatLoader && widget.px == px);

Finder get _praise => find.byWidgetPredicate(
  (widget) => widget is Text && positiveMessages.contains(widget.data),
);

void main() {
  group('sound rounds', () {
    testWidgets(
      'a right answer reads it was the song and next arrives after two seconds',
      (tester) async {
        final harness = _Harness(tester);
        await harness.open(difficulty: Difficulty.medium, mediumTimer: 20);
        await harness.settle();

        expect(harness.current, _loveStory);
        expect(harness.rightIndex, 1);
        expect(_heading("What's playing?"), findsOneWidget);
        expect(_heading('20 seconds left.'), findsOneWidget);

        await harness.press(LogicalKeyboardKey.digit2);

        expect(_heading('It was Love Story.'), findsOneWidget);
        expect(
          find.descendant(of: find.byType(RoundHeading), matching: _praise),
          findsOneWidget,
        );
        expect(harness.state.streak, 1);
        expect(harness.answerStates, [
          AnswerState.dim,
          AnswerState.right,
          AnswerState.dim,
          AnswerState.dim,
        ]);
        expect(find.text('Next song →'), findsOneWidget);
        expect(harness.nextOpacity, NextPrompt.waitingOpacity);

        await tester.pump(const Duration(milliseconds: 1999));
        expect(harness.nextOpacity, NextPrompt.waitingOpacity);
        await harness.press(LogicalKeyboardKey.enter);
        expect(harness.state.roundNumber, 1);
        expect(find.text('Loading next track...'), findsNothing);

        await tester.pump(const Duration(milliseconds: 1));
        expect(harness.nextOpacity, 1);
        await harness.press(LogicalKeyboardKey.enter);

        expect(harness.state.roundNumber, 2);
        expect(harness.current, isNot(_loveStory));
        expect(find.text('Loading next track...'), findsOneWidget);
      },
    );

    testWidgets('every song played is remembered for the session', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await harness.open(difficulty: Difficulty.medium);
      await harness.settle();
      final first = harness.current;

      await harness.press(LogicalKeyboardKey.digit1);
      await tester.pump(const Duration(seconds: 2));
      await harness.press(LogicalKeyboardKey.enter);

      expect(harness.container.read(playHistoryProvider).heard, [
        first,
        harness.current,
      ]);
    });

    testWidgets('a wrong answer shows the era and track and quacks', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await harness.open(difficulty: Difficulty.medium);
      await harness.settle();
      expect(harness.rightIndex, 1);

      await harness.pressAnswer(0);

      expect(_heading('It was Love Story.'), findsOneWidget);
      expect(_heading('Fearless · track 3'), findsOneWidget);
      expect(_praise, findsNothing);
      expect(harness.answerStates, [
        AnswerState.wrong,
        AnswerState.right,
        AnswerState.dim,
        AnswerState.dim,
      ]);
      expect(harness.state.roundResults, [
        RoundOutcome(_loveStory, correct: false),
      ]);
      expect(harness.state.streak, 0);
      expect(harness.state.quackCount, 1);
      expect(harness.engine.quacks, [0.8]);
      expect(tester.widget<QuackBurst>(find.byType(QuackBurst)).level, 1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(QuackBurst.word), findsOneWidget);
    });

    testWidgets('hard mode accepts a typo and says how it is spelled', (
      tester,
    ) async {
      final harness = _Harness(
        tester,
        pool: [_enchanted, ..._songs.where((song) => song != _enchanted)],
      );
      await harness.open(difficulty: Difficulty.hard);
      await harness.settle();

      expect(harness.current, _enchanted);
      expect(find.byType(AnswerButton), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style?.fontFamily, AppType.serifFamily);
      expect(field.style?.fontStyle, FontStyle.italic);
      expect(field.focusNode?.hasFocus, isTrue);
      expect(find.text('Type the song title'), findsOneWidget);
      expect(
        find.text('Small typos are fine. Press Enter to submit.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'Enchented');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(harness.state.streak, 1);
      expect(harness.state.progress.stats.totalCorrect, 1);
      expect(_heading('It was Enchanted.'), findsOneWidget);
      expect(
        _heading("Close enough. It's spelled “Enchanted”."),
        findsOneWidget,
      );
      expect(find.text('You typed “Enchented”.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('the tenth song leads to the round summary', (tester) async {
      final harness = _Harness(tester);
      await harness.open(quickRound: true);
      await harness.settle();

      for (var round = 1; round < 10; round++) {
        expect(find.text('· Round $round of 10'), findsOneWidget);
        await harness.pressAnswer(harness.rightIndex);
        expect(find.text('Next song →'), findsOneWidget);
        await harness.nextSong();
      }

      expect(harness.state.roundNumber, 10);
      expect(find.text('Name That Song · Medium'), findsOneWidget);
      expect(find.text('· Round 10 of 10'), findsOneWidget);
      await harness.pressAnswer(harness.rightIndex);
      expect(find.text('See your round →'), findsOneWidget);
      expect(find.text('Next song →'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('See your round →'));
      await tester.pump();

      expect(harness.state.phase, GamePhase.roundSummary);
      expect(harness.state.roundResults, hasLength(10));
      expect(
        harness.state.roundResults.every((outcome) => outcome.correct),
        isTrue,
      );
    });

    testWidgets('a song Deezer no longer has is skipped for another', (
      tester,
    ) async {
      final gone = _song(7, 'Gone Song', 'red', 4).copyWith(preview: '');
      final harness = _Harness(tester, pool: [gone, ..._songs])
        ..withdrawn = {7};
      await harness.open();
      await harness.settle();
      await tester.pump(GameScreen.roundLoaderMinimum);
      await harness.settle();

      expect(find.text("The needle won't drop."), findsNothing);
      expect(harness.current, _loveStory);
      expect(harness.state.roundNumber, 1);
      expect(harness.deezerRequests, contains('/track/7'));
    });

    testWidgets('a song that could not play is not remembered as heard', (
      tester,
    ) async {
      final gone = _song(7, 'Gone Song', 'red', 4).copyWith(preview: '');
      final harness = _Harness(tester, pool: [gone, ..._songs])
        ..withdrawn = {7};
      await harness.open();
      await harness.settle();
      await tester.pump(GameScreen.roundLoaderMinimum);
      await harness.settle();

      expect(harness.container.read(playHistoryProvider).heard, [_loveStory]);
    });

    testWidgets("the next pass's first song is fetched while the last plays", (
      tester,
    ) async {
      final unlinked = [
        for (final song in _songs.skip(1)) song.copyWith(preview: ''),
      ];
      final harness = _Harness(
        tester,
        load: () async =>
            (allTracks: [_loveStory, ...unlinked], pool: [_loveStory]),
      );
      await harness.open();
      await harness.settle();

      final upcoming = harness.state.trackPool;
      expect(upcoming, isNotEmpty);
      expect(upcoming.first, isNot(_loveStory));
      expect(harness.deezerRequests, ['/track/${upcoming.first.id}']);
    });

    testWidgets('after three missing songs in a row the round gives up', (
      tester,
    ) async {
      final gone = [
        for (var id = 7; id <= 10; id++)
          _song(id, 'Gone $id', 'red', id).copyWith(preview: ''),
      ];
      final harness = _Harness(tester, pool: [...gone, ..._songs])
        ..withdrawn = {7, 8, 9, 10};
      await harness.open();
      for (var round = 0; round < 4; round++) {
        await harness.settle();
        await tester.pump(GameScreen.roundLoaderMinimum);
      }
      await harness.settle();

      expect(find.text("The needle won't drop."), findsOneWidget);
    });

    testWidgets("the next song's link is fetched while this one plays", (
      tester,
    ) async {
      final next = _song(8, 'Next Song', 'red', 5).copyWith(preview: '');
      final harness = _Harness(tester, pool: [_loveStory, next, ..._songs]);
      await harness.open();
      await harness.settle();

      expect(harness.deezerRequests, ['/track/8']);
      await tester.tap(find.text('Love Story'));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Next song →'));
      await harness.settle();
      await tester.pump(GameScreen.roundLoaderMinimum);
      await harness.settle();

      expect(harness.current.id, 8);
      expect(
        harness.deezerRequests.where((path) => path == '/track/8'),
        hasLength(1),
      );
    });

    testWidgets('between songs the loader shows for at least 450 ms', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await harness.open();
      await harness.settle();
      await tester.tap(find.text('Love Story'));
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Next song →'));
      await harness.settle();

      expect(harness.engine.voices, hasLength(2));
      expect(find.text('Loading next track...'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Loading next track...'),
          matching: _catLoader(200),
        ),
        findsOneWidget,
      );

      await tester.pump(
        GameScreen.roundLoaderMinimum - const Duration(milliseconds: 1),
      );
      expect(find.text('Loading next track...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Loading next track...'), findsNothing);
      expect(_heading("What's playing?"), findsOneWidget);

      final failing = _Harness(
        tester,
        load: () async => throw const NetworkError('offline'),
      );
      await failing.open();
      await failing.settle();

      expect(find.text("The needle won't drop."), findsOneWidget);
      expect(
        find.text(
          "We couldn't load the tracks from Deezer. "
          'Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Back to menu'));
      await tester.pump();

      expect(failing.state.phase, GamePhase.menu);
    });

    testWidgets(
      'the first load keeps the cat loader until the first clip is ready, '
      'then easy shows the cover and its caption',
      (tester) async {
        final tracks = Completer<CatalogTracks>();
        final decode = Completer<void>();
        final harness = _Harness(tester, load: () => tracks.future);
        harness.engine.decodeGates = [decode];
        await harness.open();
        await harness.settle();

        expect(find.text('Loading tracks...'), findsOneWidget);
        expect(
          find.ancestor(
            of: find.text('Loading tracks...'),
            matching: _catLoader(220),
          ),
          findsOneWidget,
        );
        expect(find.text('← Back to menu'), findsOneWidget);

        tracks.complete((allTracks: _songs, pool: _songs));
        await harness.settle();
        await tester.pump(GameScreen.roundLoaderMinimum);

        expect(find.text('Loading tracks...'), findsOneWidget);
        expect(find.text('← Back to menu'), findsOneWidget);
        expect(find.byType(AnswerList), findsNothing);
        expect(find.byType(BetweenSongsCover), findsNothing);

        decode.complete();
        await harness.settle();

        expect(find.text('Loading tracks...'), findsNothing);
        expect(harness.transport, TransportStatus.playing);
        expect(harness.engine.voices, hasLength(1));
        expect(
          tester.widget<RecordPlayer>(find.byType(RecordPlayer)).revealed,
          isTrue,
        );
        expect(
          tester.widget<RecordPlayer>(find.byType(RecordPlayer)).spinning,
          isTrue,
        );
        expect(find.text('Fearless · track 3'), findsOneWidget);
        expect(
          _heading('Take your time. The cover is your hint.'),
          findsOneWidget,
        );
        expect(
          tester.widget<GameTopBar>(find.byType(GameTopBar)).timeFraction,
          isNull,
        );
      },
    );

    testWidgets(
      'medium waits for the first clip before the timer runs, then times out',
      (tester) async {
        final decode = Completer<void>();
        final harness = _Harness(tester);
        harness.engine.decodeGates = [decode];
        await harness.open(difficulty: Difficulty.medium, mediumTimer: 10);
        await harness.settle();

        expect(find.text('Loading tracks...'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        expect(find.text('Loading tracks...'), findsOneWidget);

        decode.complete();
        await harness.settle();
        expect(
          tester.widget<RecordPlayer>(find.byType(RecordPlayer)).revealed,
          isFalse,
        );
        expect(find.text('Fearless · track 3'), findsNothing);
        expect(_heading('10 seconds left.'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 7100));
        expect(_heading('3 seconds left.'), findsOneWidget);
        final urgent = tester.widget<RoundHeading>(find.byType(RoundHeading));
        expect(urgent.urgent, isTrue);
        expect(
          tester.widget<GameTopBar>(find.byType(GameTopBar)).timeFraction,
          closeTo(0.29, 0.001),
        );
        await tester.pump(const Duration(milliseconds: 2800));
        expect(harness.engine.quacks, isEmpty);

        await tester.pump(const Duration(milliseconds: 100));

        expect(_heading("Time's up. It was Love Story."), findsOneWidget);
        expect(_heading('Fearless · track 3'), findsOneWidget);
        expect(harness.state.quackCount, 1);
        expect(harness.engine.quacks, [0.8]);
        expect(harness.state.roundResults, [
          RoundOutcome(_loveStory, correct: false),
        ]);
      },
    );

    testWidgets('the first round also stops waiting for its clip after 8 s', (
      tester,
    ) async {
      final harness = _Harness(tester);
      harness.engine.decodeGates = [Completer<void>()];
      await harness.open();
      await harness.settle();
      expect(find.text('Loading tracks...'), findsOneWidget);

      await tester.pump(GameScreen.roundLoaderTimeout);
      await harness.settle();

      expect(find.text('Loading tracks...'), findsNothing);
      expect(_heading("What's playing?"), findsOneWidget);
      expect(harness.transport, TransportStatus.loading);
    });

    testWidgets('the between-songs cover gives up after 8 s', (tester) async {
      final harness = _Harness(tester);
      harness.engine.decodeGates = [
        Completer<void>()..complete(),
        Completer<void>(),
      ];
      await harness.open();
      await harness.settle();
      await harness.pressAnswer(harness.rightIndex);
      await tester.pump(const Duration(seconds: 2));
      await harness.press(LogicalKeyboardKey.enter);
      await harness.settle();

      await tester.pump(
        GameScreen.roundLoaderTimeout - const Duration(milliseconds: 1),
      );
      expect(find.text('Loading next track...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('Loading next track...'), findsNothing);
      expect(harness.transport, TransportStatus.loading);
    });

    testWidgets('space pauses, resumes and replays an ended clip', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await harness.open();
      await harness.settle();
      expect(harness.transport, TransportStatus.playing);

      await harness.press(LogicalKeyboardKey.space);
      expect(harness.transport, TransportStatus.paused);
      expect(harness.engine.paused, hasLength(1));

      await harness.press(LogicalKeyboardKey.space);
      expect(harness.transport, TransportStatus.playing);

      harness.engine.endAll();
      await tester.pump(progressPollInterval);
      await tester.pump();
      expect(harness.transport, TransportStatus.ended);
      expect(find.text('Listen again (10s)'), findsOneWidget);

      await harness.press(LogicalKeyboardKey.space);

      expect(harness.state.relistenCount, 1);
      expect(harness.engine.voices, hasLength(2));
      expect(harness.transport, TransportStatus.playing);
    });

    testWidgets(
      'keys wait while a dialog is open and never fire while typing',
      (tester) async {
        final harness = _Harness(tester);
        await harness.open(difficulty: Difficulty.medium);
        await harness.settle();
        final dialog = Object();
        harness.container.read(modalStackProvider.notifier).push(dialog);
        await tester.pump();

        await harness.pressAnswer(harness.rightIndex);
        await harness.press(LogicalKeyboardKey.space);
        expect(harness.state.streak, 0);
        expect(harness.transport, TransportStatus.playing);

        harness.container.read(modalStackProvider.notifier).remove(dialog);
        await tester.pump();
        await harness.pressAnswer(harness.rightIndex);
        expect(harness.state.streak, 1);

        final typing = _Harness(tester);
        await typing.open(difficulty: Difficulty.hard);
        await typing.settle();
        await tester.enterText(find.byType(TextField), 'Love');
        await typing.press(LogicalKeyboardKey.space);

        expect(typing.transport, TransportStatus.playing);
        expect(typing.state.roundResults, isEmpty);
        expect(find.byType(TextField), findsOneWidget);

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await typing.press(LogicalKeyboardKey.space);

        expect(typing.transport, TransportStatus.paused);
      },
    );

    testWidgets('enter on a focused control activates it, not the next song', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await harness.open(difficulty: Difficulty.medium);
      await harness.settle();
      await harness.pressAnswer(harness.rightIndex);
      await tester.pump(const Duration(seconds: 2));

      Focus.of(tester.element(find.text('Exit'))).requestFocus();
      await tester.pump();
      await harness.press(LogicalKeyboardKey.enter);

      expect(harness.state.phase, GamePhase.menu);
      expect(harness.state.roundNumber, 0);
    });

    testWidgets('leaving the screen stops the clip', (tester) async {
      final harness = _Harness(tester);
      await harness.open();
      await harness.settle();
      expect(harness.transport, TransportStatus.playing);
      final voice = harness.engine.voices.single;

      await tester.pumpWidget(harness._app(const SizedBox()));
      await tester.pump();

      expect(harness.engine.stopped, contains(voice));
      expect(harness.container.read(audioControllerProvider).playing, isFalse);

      await tester.pumpWidget(harness._app(const GameScreen()));
      await harness.settle();
      expect(harness.engine.voices, hasLength(2));

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('each answer tells misu the streak, misses and round', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await harness.open(difficulty: Difficulty.medium);
      await harness.settle();

      await harness.pressAnswer(harness.rightIndex);
      await harness.nextSong();
      await harness.pressAnswer((harness.rightIndex + 1) % 4);

      expect(harness.misu.answers, [
        (correct: true, streak: 1, missRun: 0, roundNumber: 1),
        (correct: false, streak: 0, missRun: 1, roundNumber: 2),
      ]);
    });

    testWidgets('a rate limit keeps its message and try again reloads', (
      tester,
    ) async {
      final harness = _Harness(
        tester,
        load: () async => throw const RateLimited(),
      );
      await harness.open();
      await harness.settle();

      expect(find.text("The needle won't drop."), findsOneWidget);
      expect(
        find.text('Taking a breather — try again in a moment.'),
        findsOneWidget,
      );

      harness.load = () async => (allTracks: _songs, pool: _songs);
      await tester.tap(find.text('Try again'));
      await harness.settle();
      await tester.pump(GameScreen.roundLoaderMinimum);

      expect(find.text("The needle won't drop."), findsNothing);
      expect(_heading("What's playing?"), findsOneWidget);
      expect(harness.current, _loveStory);
    });

    testWidgets('a clip that cannot download drops the needle', (tester) async {
      final harness = _Harness(tester)..previewStatus = 500;
      await harness.open();
      await harness.settle();

      expect(find.text("The needle won't drop."), findsOneWidget);
      expect(find.text('Back to menu'), findsOneWidget);
      expect(find.byType(AnswerButton), findsNothing);
    });

    testWidgets('exit returns to the menu', (tester) async {
      final harness = _Harness(tester);
      await harness.open();
      await harness.settle();

      await tester.tap(find.text('Exit'));
      await tester.pump();

      expect(harness.state.phase, GamePhase.menu);
    });
  });

  group('praise lines', () {
    test('never returns the same message twice in a row', () {
      var previous = drawNextMessage();
      for (var i = 0; i < 100; i++) {
        final next = drawNextMessage();
        expect(next, isNot(previous));
        previous = next;
      }
    });

    test('cycles through all 22 messages within two full cycles', () {
      final seen = <String>{for (var i = 0; i < 44; i++) drawNextMessage()};

      expect(seen, hasLength(22));
      expect(seen, positiveMessages.toSet());
    });

    test('cycles through all 30 lyrics messages within two full cycles', () {
      final seen = <String>{
        for (var i = 0; i < 60; i++) drawNextMessage(QuizType.lyrics),
      };

      expect(seen, hasLength(30));
      expect(seen, lyricsPositiveMessages.toSet());
    });
  });
}
