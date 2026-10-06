import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/catalog/catalogue_json.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/lyrics_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/screens/lyrics_loading_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

import '../../fixtures/catalogue_fixture.dart';

const int _songCount = 8;
const String _lostTitle = 'The lyric sheets got lost.';

final List<RawRelease> _lover = [
  rawRelease(10, 'Lover', '2019-08-23', [
    for (var id = 1; id <= _songCount; id++) rawTrack(id, 'Song $id'),
  ]),
];

Map<String, Object?> _lrclibRecord(int id) => {
  'id': 1000 + id,
  'trackName': 'Song $id',
  'artistName': 'Taylor Swift',
  'albumName': 'Lover',
  'duration': 200,
  'instrumental': false,
  'plainLyrics': 'First line of song $id\nSecond line of song $id\n',
  'syncedLyrics': null,
};

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

final class _HeldLyrics extends LyricsController {
  _HeldLyrics(super.ref, {required this.source});

  final Completer<List<Track>>? source;

  @override
  Future<List<Track>> loadSourceTracks() =>
      source?.future ?? super.loadSourceTracks();

  @override
  Future<List<TrackWithLyrics>> preFetchInitial(
    List<Track> tracks, {
    void Function(int fetched, int total)? onProgress,
  }) => Completer<List<TrackWithLyrics>>().future;
}

final class _Harness {
  _Harness(this.tester);

  final WidgetTester tester;
  final Completer<List<Track>> source = Completer<List<Track>>();
  Set<int> songsWithLyrics = {1, 2, 3, 4, 5};
  Duration catalogueDelay = Duration.zero;
  bool catalogueFails = false;
  bool? holdSource;
  bool reducedMotion = false;

  List<Override> get _overrides => [
    appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
    clockProvider.overrideWithValue(() => tester.binding.clock.now()),
    randomProvider.overrideWithValue(Random(3)),
    httpClientProvider.overrideWithValue(MockClient(_respond)),
    catalogueStoreProvider.overrideWithValue(
      fixtureCatalogueStore(
        loadBundled: () async {
          if (catalogueDelay > Duration.zero) {
            await Future<void>.delayed(catalogueDelay);
          }
          if (catalogueFails) {
            throw const FileSystemException('catalogue unavailable');
          }
          return encodeCatalogue(_lover, fetchedAt: '2026-10-06T00:00:00Z');
        },
      ),
    ),
    if (holdSource case final hold?)
      lyricsControllerProvider.overrideWith(
        (ref) => _HeldLyrics(ref, source: hold ? source : null),
      ),
  ];

  Future<http.Response> _respond(http.Request request) async {
    final url = request.url;
    if (url.host == 'lrclib.net' && url.path == '/api/get') {
      final id = int.tryParse(
        (url.queryParameters['track_name'] ?? '').replaceFirst('Song ', ''),
      );
      return id != null && songsWithLyrics.contains(id)
          ? _json(_lrclibRecord(id))
          : _json({'statusCode': 404}, 404);
    }
    if (url.host == 'lrclib.net') {
      return _json(<Object?>[]);
    }
    return http.Response('', 404);
  }

  Widget _app(Widget child) => ProviderScope(
    overrides: _overrides,
    child: MaterialApp(
      theme: AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold)));

  GameState get state => container.read(gameControllerProvider);

  GameController get game => container.read(gameControllerProvider.notifier);

  Size get bar =>
      tester.getSize(find.byKey(LyricsLoadingScreen.progressBarKey));

  Size get fill =>
      tester.getSize(find.byKey(LyricsLoadingScreen.progressFillKey));

  Future<void> open({
    GameMode mode = GameMode.random,
    List<String> eras = const [],
    LyricsFetchProgress? progress,
  }) async {
    await tester.pumpWidget(_app(const SizedBox()));
    game
      ..setMode(mode)
      ..setQuizType(QuizType.lyrics)
      ..setLyricsMode(LyricsMode.nameThatSong)
      ..setPhase(GamePhase.lyricsLoading)
      ..setLyricsFetchProgress(progress);
    for (final era in eras) {
      game.toggleEra(era);
    }
    await tester.pumpWidget(_app(const LyricsLoadingScreen()));
  }

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await tester.pump();
    }
  }

  void expectLost(String message) {
    expect(find.text(_lostTitle), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    expect(find.widgetWithText(PillButton, 'Try again'), findsOneWidget);
    expect(find.widgetWithText(PillButton, 'Back to menu'), findsOneWidget);
    expect(find.byType(CatLoader), findsNothing);
  }
}

void main() {
  group('lyrics loading screen', () {
    testWidgets('lyrics loading shows progress and the lost sheets error', (
      tester,
    ) async {
      final harness = _Harness(tester)..holdSource = true;
      await harness.open(progress: (fetched: 3, total: 40));
      const messages = LyricsLoadingScreen.loadingMessages;

      expect(find.text('3 of 40 songs'), findsOneWidget);
      expect(harness.bar, const Size(220, 2));
      expect(harness.fill.height, 2);
      expect(harness.fill.width, moreOrLessEquals(220 * 0.075));
      expect(
        tester
            .widget<ColoredBox>(find.byKey(LyricsLoadingScreen.progressFillKey))
            .color,
        AppTokens.dark.coral,
      );
      expect(find.text(messages.first), findsOneWidget);

      await tester.pump(LyricsLoadingScreen.messageInterval);
      expect(find.text(messages.first), findsNothing);
      expect(find.text(messages[1]), findsOneWidget);

      harness.source.completeError(StateError('offline'));
      await tester.pump();
      await tester.pump();

      harness.expectLost(
        "We couldn't fetch lyrics from LRCLIB. "
        'Check your connection and try again.',
      );
      expect(find.text('3 of 40 songs'), findsNothing);
    });

    testWidgets('rotates the ten design messages every 3 s under the cat', (
      tester,
    ) async {
      final harness = _Harness(tester)..holdSource = true;
      await harness.open();
      const messages = LyricsLoadingScreen.loadingMessages;

      expect(messages, const [
        'Fetching lyrics...',
        'Digging through the vault...',
        'Long story short, almost ready...',
        'Shaking it off...',
        'Gathering all the easter eggs...',
        'In your wildest dreams...',
        'This is me trying...',
        'Almost out of the woods...',
        "It's a love story, just wait...",
        'Finding the bridge...',
      ]);
      final loader = tester.widget<CatLoader>(find.byType(CatLoader));
      expect(loader.size, CatLoaderSize.lg);
      expect(loader.px, 220);
      expect(loader.label, messages.first);

      await tester.pump(const Duration(milliseconds: 2999));
      expect(find.text(messages.first), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text(messages[1]), findsOneWidget);

      for (var index = 2; index < messages.length; index++) {
        await tester.pump(LyricsLoadingScreen.messageInterval);
        expect(find.text(messages[index]), findsOneWidget);
      }

      await tester.pump(LyricsLoadingScreen.messageInterval);
      expect(find.text(messages.first), findsOneWidget);
    });

    testWidgets('reads Getting the songs ready… until the total is known', (
      tester,
    ) async {
      final harness = _Harness(tester)..holdSource = true;
      await harness.open();

      expect(find.text('Getting the songs ready…'), findsOneWidget);
      expect(harness.fill.width, 0);

      harness.game.setLyricsFetchProgress((fetched: 0, total: 8));
      await tester.pump();

      expect(find.text('0 of 8 songs'), findsOneWidget);
      expect(find.text('Getting the songs ready…'), findsNothing);
    });

    testWidgets('the bar eases to a new count over 300 ms', (tester) async {
      final harness = _Harness(tester)..holdSource = true;
      await harness.open(progress: (fetched: 0, total: 8));

      harness.game.setLyricsFetchProgress((fetched: 4, total: 8));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(harness.fill.width, inExclusiveRange(0, 110));

      await tester.pump(const Duration(milliseconds: 150));
      expect(harness.fill.width, moreOrLessEquals(110));
    });

    testWidgets('the bar fills instantly under reduced motion', (tester) async {
      final harness = _Harness(tester)
        ..holdSource = true
        ..reducedMotion = true;
      await harness.open(progress: (fetched: 0, total: 8));

      harness.game.setLyricsFetchProgress((fetched: 4, total: 8));
      await tester.pump();

      expect(harness.fill.width, moreOrLessEquals(110));
    });

    testWidgets('starts the game once five songs have lyrics', (tester) async {
      final harness = _Harness(tester);
      await harness.open();
      await harness.settle();

      expect(harness.state.phase, GamePhase.playing);
      expect(harness.state.lyricsPool, hasLength(5));
      expect(harness.state.lyricsAvailableTracks, hasLength(_songCount));
      expect(harness.state.decoyPool, hasLength(5));
    });

    testWidgets('four songs with lyrics is not enough', (tester) async {
      final harness = _Harness(tester)..songsWithLyrics = {1, 2, 3, 4};
      await harness.open();
      await harness.settle();

      expect(harness.state.phase, GamePhase.lyricsLoading);
      harness.expectLost(
        'Not enough songs with lyrics available. Try a different mode or add more albums.',
      );

      await tester.tap(find.text('Back to menu'));
      await tester.pump();

      expect(harness.state.phase, GamePhase.menu);
    });

    testWidgets('gives up after 30 s', (tester) async {
      final harness = _Harness(tester)..holdSource = false;
      await harness.open();
      await harness.settle();
      harness.game.setLyricsFetchProgress((fetched: 0, total: 8));

      await tester.pump(
        LyricsLoadingScreen.fetchTimeout - const Duration(milliseconds: 1),
      );
      expect(find.byType(CatLoader), findsOneWidget);
      expect(find.text('0 of 8 songs'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      harness.expectLost('Lyrics loading timed out. Please try again.');

      await tester.tap(find.text('Back to menu'));
      await tester.pump();

      expect(harness.state.phase, GamePhase.menu);
      expect(harness.state.lyricsFetchProgress, isNull);
    });

    testWidgets('eras with no recordings show the album error', (tester) async {
      final harness = _Harness(tester);
      await harness.open(mode: GameMode.album, eras: const ['folklore']);
      await harness.settle();

      harness.expectLost(
        'Could not load tracks for the selected eras. Please try again.',
      );
    });

    testWidgets('Try again restarts loading from the first message', (
      tester,
    ) async {
      final harness = _Harness(tester)
        ..catalogueDelay = const Duration(seconds: 4)
        ..catalogueFails = true;
      const messages = LyricsLoadingScreen.loadingMessages;
      await harness.open();
      harness.game.setLyricsFetchProgress((fetched: 3, total: 8));
      await tester.pump(LyricsLoadingScreen.messageInterval);
      expect(find.text(messages[1]), findsOneWidget);
      expect(find.text('3 of 8 songs'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await harness.settle();
      harness.expectLost('Could not load the song list. Please try again.');

      harness
        ..catalogueDelay = const Duration(seconds: 1)
        ..catalogueFails = false;
      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(find.text(_lostTitle), findsNothing);
      expect(find.text(messages.first), findsOneWidget);
      expect(find.text('Getting the songs ready…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await harness.settle();
      expect(harness.state.phase, GamePhase.playing);
      expect(harness.state.lyricsPool, hasLength(5));
    });

    testWidgets('Back to menu while loading resets the game', (tester) async {
      final harness = _Harness(tester)..holdSource = true;
      await harness.open();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('← Back to menu'));
      await tester.pump();

      expect(harness.state.phase, GamePhase.menu);
      expect(harness.state.quizType, isNull);
    });
  });
}
