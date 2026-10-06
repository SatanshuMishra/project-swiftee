import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/lyrics/danger_zones.dart';
import 'package:swiftie_quiz/domain/engine/clip_selector.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/services/audio/audio_engine.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/cat/loading_gate.dart';
import 'package:swiftie_quiz/ui/game/audio_player.dart';
import 'package:swiftie_quiz/ui/game/quiz_card.dart';
import 'package:swiftie_quiz/ui/game/result_feedback.dart';
import 'package:swiftie_quiz/ui/widgets/motion.dart';
import 'package:swiftie_quiz/ui/game/streak_badge.dart';
import 'package:swiftie_quiz/ui/game/timer_bar.dart';
import 'package:swiftie_quiz/ui/screens/game_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';

const Size _window = Size(1024, 1400);
const double _clipLength = 30;
const int _sampleRate = 8000;

const List<({int id, String title, int album, String albumTitle})> _songs = [
  (id: 1, title: 'Love Story', album: 100, albumTitle: 'Fearless'),
  (id: 2, title: 'Enchanted', album: 200, albumTitle: 'Speak Now'),
  (id: 3, title: 'Style', album: 300, albumTitle: '1989'),
  (id: 4, title: 'Cardigan', album: 400, albumTitle: 'folklore'),
  (id: 5, title: 'Willow', album: 500, albumTitle: 'evermore'),
  (id: 6, title: 'Anti-Hero', album: 600, albumTitle: 'Midnights'),
];

String _previewOf(int id) => 'https://cdnt-preview.dzcdn.net/api/1/1/$id.mp3';

Map<String, Object?> _trackJson(
  ({int id, String title, int album, String albumTitle}) song,
) => {
  'id': song.id,
  'title': song.title,
  'title_short': song.title,
  'title_version': '',
  'duration': 200,
  'preview': _previewOf(song.id),
  'artist': {'id': 12246, 'name': 'Taylor Swift'},
  'album': {'id': song.album, 'title': song.albumTitle, 'cover_medium': null},
};

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

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
  List<AudioVoice> stopped = const [];
  List<double> quacks = const [];
  Map<AudioVoice, double?> _positions = const {};

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
  void pause(AudioVoice voice) {}

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
  _Harness(this.tester) : engine = _FakeEngine();

  final WidgetTester tester;
  final _FakeEngine engine;
  http.Response Function() topTracks = () => _json({
    'data': [for (final song in _songs) _trackJson(song)],
    'total': _songs.length,
  });
  int previewStatus = 200;
  List<Uri> requests = const [];

  late final List<Override> _overrides = [
    appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
    clockProvider.overrideWithValue(() => tester.binding.clock.now()),
    randomProvider.overrideWithValue(Random(7)),
    audioEngineProvider.overrideWithValue(engine),
    dangerZoneServiceProvider.overrideWithValue(AsyncData(_NoDangerZones())),
    httpClientProvider.overrideWithValue(MockClient(_respond)),
  ];

  Future<http.Response> _respond(http.Request request) async {
    requests = [...requests, request.url];
    final url = request.url;
    if (url.host == 'cdnt-preview.dzcdn.net') {
      return http.Response.bytes([1, 2, 3], previewStatus);
    }
    if (url.host == 'api.deezer.com' && url.path == '/artist/12246/top') {
      return topTracks();
    }
    if (url.host == 'api.deezer.com' && url.path.startsWith('/track/')) {
      final id = int.parse(url.pathSegments.last);
      return _json(_trackJson(_songs.firstWhere((song) => song.id == id)));
    }
    return http.Response('', 404);
  }

  Widget _app(Widget child) => ProviderScope(
    overrides: _overrides,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    ),
  );

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold)));

  GameController get game => container.read(gameControllerProvider.notifier);

  GameState get state => container.read(gameControllerProvider);

  Future<void> open({
    Difficulty difficulty = Difficulty.easy,
    int? mediumTimer,
    int? hardTimer,
  }) async {
    tester.view.physicalSize = _window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const SizedBox()));
    game
      ..setMode(GameMode.random)
      ..setQuizType(QuizType.sound)
      ..setDifficulty(difficulty)
      ..setPhase(GamePhase.playing);
    if (mediumTimer != null) {
      game.setMediumTimer(mediumTimer);
    }
    if (hardTimer != null) {
      game.setHardTimer(hardTimer);
    }
    await tester.pumpWidget(_app(const GameScreen()));
  }

  Future<void> settle() async {
    for (var i = 0; i < 12; i++) {
      await tester.pump();
    }
  }

  Future<void> reachFirstRound() async {
    await settle();
    await tester.pump(LoadingGate.transition);
    await tester.pump(LoadingGate.transition);
    await settle();
    await tester.pump(const Duration(milliseconds: 500));
    await settle();
  }

  Track get current => state.currentTrack!;

  Finder optionFor(Track track) => find.descendant(
    of: find.byType(QuizCard),
    matching: find.text(track.titleShort),
  );

  Finder get wrongOption => find.descendant(
    of: find.byType(QuizCard),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          state.options.any(
            (option) =>
                option.id != current.id && option.titleShort == widget.data,
          ),
    ),
  );

  Future<void> answerAndShowResult(Finder option) async {
    await tester.tap(option.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> next() async {
    await tester.pump(ResultFeedback.nextDelay);
    await tester.tap(find.text('Next'));
    await tester.pump();
  }
}

Finder _catLoader(CatLoaderSize size) => find.byWidgetPredicate(
  (widget) => widget is CatLoader && widget.size == size,
);

void main() {
  group('sound round flow', () {
    testWidgets(
      'easy: the small cat loads the clip, options carry the album hint, no timer',
      (tester) async {
        final harness = _Harness(tester);
        final decode = Completer<void>();
        harness.engine.decodeGates = [decode];
        await harness.open();

        expect(_catLoader(CatLoaderSize.lg), findsOneWidget);
        expect(find.text('Loading tracks...'), findsOneWidget);

        await harness.reachFirstRound();

        expect(find.text('Loading tracks...'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(AudioPlayer),
            matching: _catLoader(CatLoaderSize.sm),
          ),
          findsOneWidget,
        );
        expect(
          find.text('Album: ${harness.current.album.title}'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(QuizCard),
            matching: find.byType(Motion),
          ),
          findsNWidgets(4),
        );
        expect(harness.optionFor(harness.current), findsOneWidget);
        expect(find.byType(TimerBar), findsNothing);
        expect(find.byType(TextField), findsNothing);

        decode.complete();
        await harness.settle();

        expect(_catLoader(CatLoaderSize.sm), findsNothing);
        expect(harness.engine.voices, hasLength(1));
      },
    );

    testWidgets('a right answer adds one to the streak', (tester) async {
      final harness = _Harness(tester);
      await harness.open();
      await harness.reachFirstRound();

      await harness.answerAndShowResult(harness.optionFor(harness.current));

      expect(harness.state.streak, 1);
      expect(harness.state.progress.stats.totalCorrect, 1);
      expect(harness.engine.quacks, isEmpty);
      expect(find.byType(QuizCard), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && positiveMessages.contains(widget.data),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(StreakBadge), matching: find.text('1')),
        findsOneWidget,
      );
      expect(harness.engine.stopped, contains(harness.engine.voices.first));
    });

    testWidgets('a wrong answer resets the streak with a quack', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await harness.open();
      await harness.reachFirstRound();
      await harness.answerAndShowResult(harness.optionFor(harness.current));
      await harness.next();
      await harness.settle();
      await tester.pump(GameScreen.roundLoaderMinimum);
      await tester.pump(const Duration(milliseconds: 600));
      expect(harness.state.streak, 1);

      final missed = harness.current;
      await harness.answerAndShowResult(harness.wrongOption);

      expect(harness.state.streak, 0);
      expect(harness.state.quackCount, 1);
      expect(harness.engine.quacks, [0.8]);
      expect(find.text('It was “${missed.titleShort}”'), findsOneWidget);
      expect(find.text('by Taylor Swift'), findsOneWidget);
    });

    testWidgets(
      'between rounds the large loader shows "Loading next track..." for at least 400 ms',
      (tester) async {
        final harness = _Harness(tester);
        await harness.open();
        await harness.reachFirstRound();
        await harness.answerAndShowResult(harness.optionFor(harness.current));
        final first = harness.current;

        await harness.next();
        await harness.settle();

        expect(harness.current, isNot(first));
        expect(harness.engine.voices, hasLength(2));
        expect(find.text('Loading next track...'), findsOneWidget);
        expect(
          find.ancestor(
            of: find.text('Loading next track...'),
            matching: _catLoader(CatLoaderSize.lg),
          ),
          findsOneWidget,
        );
        expect(find.byType(QuizCard), findsNothing);

        await tester.pump(
          GameScreen.roundLoaderMinimum - const Duration(milliseconds: 1),
        );
        expect(find.byType(QuizCard), findsNothing);

        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(GameScreen.overlayFade);
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Loading next track...'), findsNothing);
        expect(harness.optionFor(harness.current), findsOneWidget);
      },
    );

    testWidgets('the between-round loader gives up after 8 s', (tester) async {
      final harness = _Harness(tester);
      final secondDecode = Completer<void>();
      harness.engine.decodeGates = [
        Completer<void>()..complete(),
        secondDecode,
      ];
      await harness.open();
      await harness.reachFirstRound();
      await harness.answerAndShowResult(harness.optionFor(harness.current));

      await harness.next();
      await harness.settle();
      await tester.pump(
        GameScreen.roundLoaderTimeout - const Duration(milliseconds: 1),
      );

      expect(find.text('Loading next track...'), findsOneWidget);
      expect(find.byType(QuizCard), findsNothing);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(GameScreen.overlayFade);
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Loading next track...'), findsNothing);
      expect(find.byType(QuizCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AudioPlayer),
          matching: _catLoader(CatLoaderSize.sm),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'medium: the timer waits for the first clip and a timeout quacks',
      (tester) async {
        final harness = _Harness(tester);
        final decode = Completer<void>();
        harness.engine.decodeGates = [decode];
        await harness.open(difficulty: Difficulty.medium, mediumTimer: 10);
        await harness.reachFirstRound();

        expect(
          find.text('Album: ${harness.current.album.title}'),
          findsNothing,
        );
        expect(harness.optionFor(harness.current), findsOneWidget);
        expect(find.text('10s remaining'), findsOneWidget);

        await tester.pump(const Duration(seconds: 5));
        expect(find.text('10s remaining'), findsOneWidget);

        decode.complete();
        await harness.settle();
        await tester.pump(const Duration(seconds: 10));
        expect(harness.engine.quacks, isEmpty);

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byType(TimerBar), findsNothing);
        expect(harness.state.streak, 0);
        expect(harness.state.quackCount, 1);
        expect(harness.engine.quacks, [0.8]);
        expect(
          find.text('It was “${harness.current.titleShort}”'),
          findsOneWidget,
        );
      },
    );

    testWidgets('hard: a text box takes the typed title', (tester) async {
      final harness = _Harness(tester);
      await harness.open(difficulty: Difficulty.hard);
      await harness.reachFirstRound();

      expect(find.byType(TextField), findsOneWidget);
      expect(harness.optionFor(harness.current), findsNothing);
      expect(find.text('Album: ${harness.current.album.title}'), findsNothing);
      expect(find.text('20s remaining'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        harness.current.title.toLowerCase(),
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(harness.state.streak, 1);
      expect(find.byType(ResultFeedback), findsOneWidget);
    });

    testWidgets('Exit returns to the menu', (tester) async {
      final harness = _Harness(tester);
      await harness.open();
      await harness.reachFirstRound();

      await tester.tap(find.text('Exit'));
      await tester.pump();

      expect(harness.state.phase, GamePhase.menu);
    });

    testWidgets('a failed track load shows the error with Back to Menu', (
      tester,
    ) async {
      final harness = _Harness(tester)
        ..topTracks = () => http.Response('', 500);
      await harness.open();
      await harness.settle();

      expect(find.text('Failed to load tracks.'), findsOneWidget);
      await tester.tap(find.text('Back to Menu'));
      await tester.pump();

      expect(harness.state.phase, GamePhase.menu);
    });

    testWidgets('a Deezer quota error asks for a breather', (tester) async {
      final harness = _Harness(tester)
        ..topTracks = () => _json({
          'error': {
            'type': 'Exception',
            'message': 'Quota limit exceeded',
            'code': 4,
          },
        });
      await harness.open();
      await harness.settle();

      expect(
        find.text('Taking a breather — try again in a moment.'),
        findsOneWidget,
      );
      expect(find.text('Back to Menu'), findsOneWidget);
    });

    testWidgets(
      'a preview still forbidden after one refresh shows the round error',
      (tester) async {
        final harness = _Harness(tester)..previewStatus = 403;
        await harness.open();
        await harness.reachFirstRound();
        await harness.settle();

        final refreshes = harness.requests.where(
          (url) => url.path.startsWith('/track/'),
        );
        expect(refreshes, hasLength(1));
        expect(find.text('Preview download failed: HTTP 403'), findsOneWidget);
        expect(find.text('Back to Menu'), findsOneWidget);
        expect(find.byType(QuizCard), findsNothing);
      },
    );
  });
}
