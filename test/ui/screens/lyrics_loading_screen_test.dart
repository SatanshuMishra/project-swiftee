import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/lyrics_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/screens/lyrics_loading_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';

const int _songCount = 8;

Map<String, Object?> _deezerTrack(int id) => {
  'id': id,
  'title': 'Song $id',
  'title_short': 'Song $id',
  'title_version': '',
  'duration': 200,
  'preview': 'https://cdnt-preview.dzcdn.net/api/1/1/$id.mp3',
  'artist': {'id': 12246, 'name': 'Taylor Swift'},
  'album': {'id': 10, 'title': 'Lover', 'cover_medium': null},
};

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
  _HeldLyrics(super.ref, {required this.holdSource});

  final bool holdSource;

  @override
  Future<List<Track>> loadSourceTracks() =>
      holdSource ? Completer<List<Track>>().future : super.loadSourceTracks();

  @override
  Future<List<TrackWithLyrics>> preFetchInitial(
    List<Track> tracks, {
    void Function(int fetched, int total)? onProgress,
  }) => Completer<List<TrackWithLyrics>>().future;
}

final class _Harness {
  _Harness(this.tester);

  final WidgetTester tester;
  Set<int> songsWithLyrics = {1, 2, 3, 4, 5};
  http.Response Function() topTracks = () => _json({
    'data': [for (var id = 1; id <= _songCount; id++) _deezerTrack(id)],
    'total': _songCount,
  });
  int albumStatus = 200;
  bool? holdSource;

  List<Override> get _overrides => [
    appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
    clockProvider.overrideWithValue(() => tester.binding.clock.now()),
    randomProvider.overrideWithValue(Random(3)),
    httpClientProvider.overrideWithValue(MockClient(_respond)),
    if (holdSource case final hold?)
      lyricsControllerProvider.overrideWith(
        (ref) => _HeldLyrics(ref, holdSource: hold),
      ),
  ];

  Future<http.Response> _respond(http.Request request) async {
    final url = request.url;
    if (url.host == 'api.deezer.com' && url.path == '/artist/12246/top') {
      return topTracks();
    }
    if (url.host == 'api.deezer.com' && url.path.startsWith('/album/')) {
      return http.Response('', albumStatus);
    }
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
      home: Scaffold(body: child),
    ),
  );

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold)));

  GameState get state => container.read(gameControllerProvider);

  Future<void> open({
    GameMode mode = GameMode.random,
    List<int> albums = const [],
  }) async {
    await tester.pumpWidget(_app(const SizedBox()));
    final game = container.read(gameControllerProvider.notifier)
      ..setMode(mode)
      ..setQuizType(QuizType.lyrics)
      ..setLyricsMode(LyricsMode.nameThatSong)
      ..setPhase(GamePhase.lyricsLoading);
    for (final album in albums) {
      game.toggleAlbum(album);
    }
    await tester.pumpWidget(_app(const LyricsLoadingScreen()));
  }

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await tester.pump();
    }
  }
}

void main() {
  group('lyrics loading screen', () {
    testWidgets('rotates the ten messages every 3 s under the large cat', (
      tester,
    ) async {
      final harness = _Harness(tester)..holdSource = true;
      await harness.open();
      const messages = LyricsLoadingScreen.loadingMessages;

      expect(messages, hasLength(10));
      expect(find.text(messages.first), findsOneWidget);
      final loader = tester.widget<CatLoader>(find.byType(CatLoader));
      expect(loader.size, CatLoaderSize.lg);
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
      expect(
        find.text(
          'Not enough songs with lyrics available. Try a different mode or add more albums.',
        ),
        findsOneWidget,
      );
      expect(find.byType(CatLoader), findsNothing);

      await tester.tap(find.text('Back to Mode Select'));
      await tester.pump();

      expect(harness.state.phase, GamePhase.lyricsModeSelect);
    });

    testWidgets('gives up after 30 s', (tester) async {
      final harness = _Harness(tester)..holdSource = false;
      await harness.open();
      await harness.settle();

      await tester.pump(
        LyricsLoadingScreen.fetchTimeout - const Duration(milliseconds: 1),
      );
      expect(find.byType(CatLoader), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(
        find.text('Lyrics loading timed out. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Back to Mode Select'), findsOneWidget);
    });

    testWidgets('albums that all fail show the album error', (tester) async {
      final harness = _Harness(tester)..albumStatus = 500;
      await harness.open(mode: GameMode.album, albums: const [10, 20]);
      await harness.settle();

      expect(
        find.text(
          'Could not load tracks for the selected albums. Please try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a failed catalog shows the generic lyrics error', (
      tester,
    ) async {
      final harness = _Harness(tester)
        ..topTracks = () => http.Response('', 500);
      await harness.open();
      await harness.settle();

      expect(
        find.text('Failed to load lyrics. Please try again.'),
        findsOneWidget,
      );
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
    });

    testWidgets('Back to Menu resets the game', (tester) async {
      final harness = _Harness(tester)..holdSource = true;
      await harness.open();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Back to Menu'));
      await tester.pump();

      expect(harness.state.phase, GamePhase.menu);
      expect(harness.state.quizType, isNull);
    });
  });
}
