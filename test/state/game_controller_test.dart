import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/providers.dart';

final DateTime _now = DateTime.utc(2026, 10, 5, 12);

Track makeTrack(int id, {int albumId = 100}) => Track(
  id: id,
  title: 'Track $id',
  titleShort: 'Track $id',
  duration: 30,
  preview: 'https://example.com/p.mp3',
  artist: const Artist(id: 12246, name: 'Taylor Swift'),
  album: Album(id: albumId, title: 'Album', coverMedium: null),
);

TrackWithLyrics withLyrics(int id) => TrackWithLyrics(
  track: makeTrack(id),
  lyrics: TrackLyrics(
    lrclibId: id,
    lines: ['Line of $id'],
    lineCount: 1,
    sourceTrack: 'Track $id',
    sourceAlbum: 'Album',
  ),
);

void main() {
  group('game controller parity', () {
    late ProviderContainer container;
    late GameController controller;

    GameState read() => container.read(gameControllerProvider);

    setUp(() {
      container = ProviderContainer.test(
        overrides: [clockProvider.overrideWithValue(() => _now)],
      );
      controller = container.read(gameControllerProvider.notifier);
    });

    test('starts with menu phase', () {
      expect(read().phase, GamePhase.menu);
    });

    test('setPhase updates phase', () {
      controller.setPhase(GamePhase.settings);
      expect(read().phase, GamePhase.settings);
    });

    test('toggleAlbum adds and removes', () {
      controller.toggleAlbum(1);
      expect(read().selectedAlbumIds, [1]);
      controller.toggleAlbum(2);
      expect(read().selectedAlbumIds, [1, 2]);
      controller.toggleAlbum(1);
      expect(read().selectedAlbumIds, [2]);
    });

    test('answerCorrect increments streak and resets quackCount', () {
      controller
        ..answerIncorrect()
        ..answerIncorrect();
      expect(read().quackCount, 2);

      controller.answerCorrect(makeTrack(1));

      final state = read();
      expect(state.streak, 1);
      expect(state.quackCount, 0);
      expect(state.progress.stats.totalCorrect, 1);
    });

    test('answerIncorrect resets streak and increments quackCount', () {
      controller
        ..answerCorrect(makeTrack(1))
        ..answerIncorrect();

      final state = read();
      expect(state.streak, 0);
      expect(state.quackCount, 1);
    });

    test('resetGame returns to menu', () {
      controller
        ..setPhase(GamePhase.playing)
        ..resetGame();
      expect(read().phase, GamePhase.menu);
      expect(read().streak, 0);
    });

    test('setTheme updates settings immutably', () {
      final before = read().progress;
      controller.setTheme(ThemeSetting.light);
      final after = read().progress;

      expect(after.settings.theme, ThemeSetting.light);
      expect(before.settings.theme, ThemeSetting.dark);
    });

    test('setVolume updates settings', () {
      controller.setVolume(0.5);
      expect(read().progress.settings.volume, 0.5);
    });

    test('tracks albums played in progress', () {
      controller.answerCorrect(makeTrack(1));

      final stats = read().progress.stats;
      expect(stats.albumsPlayed, contains('100'));
      expect(stats.tracksGuessedPerAlbum['100'], contains('1'));
    });

    test('initial state matches the store initial values', () {
      final state = read();
      expect(state.phase, GamePhase.menu);
      expect(state.mode, GameMode.random);
      expect(state.difficulty, Difficulty.easy);
      expect(state.quizType, isNull);
      expect(state.lyricsMode, isNull);
      expect(state.selectedAlbumIds, isEmpty);
      expect(state.currentTrack, isNull);
      expect(state.trackPool, isEmpty);
      expect(state.options, isEmpty);
      expect(state.streak, 0);
      expect(state.quackCount, 0);
      expect(state.relistenCount, 0);
      expect(state.roundStartTime, 0);
      expect(state.lyricsPool, isEmpty);
      expect(state.lyricsPoolIndex, 0);
      expect(state.decoyPool, isEmpty);
      expect(state.lyricsFetchProgress, isNull);
      expect(state.lyricsAvailableTracks, isEmpty);
      expect(state.sessionSoundCorrect, 0);
      expect(state.sessionLyricsCorrect, 0);
      expect(state.albums, isEmpty);
      expect(state.progress, defaultProgress);
      expect(state.updaterState, const UpdaterIdle());
      expect(state.pendingToasts, isEmpty);
    });

    test('answerCorrect keeps per-album guessed tracks unique', () {
      controller
        ..answerCorrect(makeTrack(1))
        ..answerCorrect(makeTrack(1))
        ..answerCorrect(makeTrack(2))
        ..answerCorrect(makeTrack(7, albumId: 200));

      final stats = read().progress.stats;
      expect(stats.totalCorrect, 4);
      expect(stats.albumsPlayed, ['100', '200']);
      expect(stats.tracksGuessedPerAlbum, {
        '100': ['1', '2'],
        '200': ['7'],
      });
    });

    test('answerCorrect counts sound and lyrics answers separately', () {
      controller.answerCorrect(makeTrack(1));
      expect(read().sessionSoundCorrect, 1);
      expect(read().sessionLyricsCorrect, 0);
      expect(read().progress.stats.totalLyricsCorrect, 0);

      controller
        ..setQuizType(QuizType.lyrics)
        ..answerCorrect(makeTrack(2));
      final state = read();
      expect(state.sessionSoundCorrect, 1);
      expect(state.sessionLyricsCorrect, 1);
      expect(state.progress.stats.totalLyricsCorrect, 1);
      expect(state.progress.stats.totalCorrect, 2);
      expect(state.progress.stats.nameThaSongCorrect, 0);
      expect(state.progress.stats.lyricsOrLieCorrect, 0);
    });

    test('resetGame keeps the session counters, progress and albums', () {
      const album = Album(id: 100, title: 'Album', coverMedium: null);
      controller
        ..setAlbums([album])
        ..setMode(GameMode.album)
        ..setDifficulty(Difficulty.hard)
        ..toggleAlbum(100)
        ..answerCorrect(makeTrack(1))
        ..setQuizType(QuizType.lyrics)
        ..setLyricsMode(LyricsMode.lyricsOrLie)
        ..answerCorrect(makeTrack(2))
        ..answerIncorrect()
        ..startRound(makeTrack(3), [makeTrack(4)], [makeTrack(3)])
        ..incrementRelisten()
        ..setLyricsPool([withLyrics(5)])
        ..nextLyricsTrack()
        ..addToDecoyPool(5, withLyrics(5).lyrics)
        ..setLyricsFetchProgress((fetched: 1, total: 8))
        ..setLyricsAvailableTracks([makeTrack(5)])
        ..setPhase(GamePhase.playing);
      final progressBefore = read().progress;

      controller.resetGame();

      final state = read();
      expect(state.phase, GamePhase.menu);
      expect(state.currentTrack, isNull);
      expect(state.trackPool, isEmpty);
      expect(state.options, isEmpty);
      expect(state.streak, 0);
      expect(state.quackCount, 0);
      expect(state.relistenCount, 0);
      expect(state.selectedAlbumIds, isEmpty);
      expect(state.quizType, isNull);
      expect(state.lyricsMode, isNull);
      expect(state.lyricsPool, isEmpty);
      expect(state.lyricsPoolIndex, 0);
      expect(state.decoyPool, isEmpty);
      expect(state.lyricsFetchProgress, isNull);
      expect(state.lyricsAvailableTracks, isEmpty);
      expect(state.sessionSoundCorrect, 1);
      expect(state.sessionLyricsCorrect, 1);
      expect(state.progress, progressBefore);
      expect(state.albums, [album]);
      expect(state.mode, GameMode.album);
      expect(state.difficulty, Difficulty.hard);
    });

    test('startRound sets the round and stamps the clock time', () {
      controller
        ..incrementRelisten()
        ..incrementRelisten();
      expect(read().relistenCount, 2);

      controller.startRound(
        makeTrack(1),
        [makeTrack(2), makeTrack(3)],
        [makeTrack(1), makeTrack(2)],
      );

      final state = read();
      expect(state.currentTrack, makeTrack(1));
      expect(state.trackPool, [makeTrack(2), makeTrack(3)]);
      expect(state.options, [makeTrack(1), makeTrack(2)]);
      expect(state.relistenCount, 0);
      expect(state.roundStartTime, _now.millisecondsSinceEpoch);
    });

    test('nextLyricsTrack walks the pool and wraps to the first track', () {
      expect(controller.nextLyricsTrack(), isNull);
      expect(read().lyricsPoolIndex, 0);

      controller.setLyricsPool([withLyrics(1), withLyrics(2), withLyrics(3)]);
      expect(controller.nextLyricsTrack(), withLyrics(1));
      expect(controller.nextLyricsTrack(), withLyrics(2));
      expect(controller.nextLyricsTrack(), withLyrics(3));
      expect(read().lyricsPoolIndex, 3);

      expect(controller.nextLyricsTrack(), withLyrics(1));
      expect(read().lyricsPoolIndex, 1);
      expect(controller.nextLyricsTrack(), withLyrics(2));
      expect(read().lyricsPoolIndex, 2);
    });

    test('setLyricsPool resets the pool index', () {
      controller
        ..setLyricsPool([withLyrics(1), withLyrics(2)])
        ..nextLyricsTrack()
        ..nextLyricsTrack();
      expect(read().lyricsPoolIndex, 2);

      controller.setLyricsPool([withLyrics(1), withLyrics(2), withLyrics(3)]);
      expect(read().lyricsPoolIndex, 0);
      expect(read().lyricsPool, hasLength(3));
    });

    test('incrementLyricsStat counts each lyrics mode', () {
      controller
        ..incrementLyricsStat(LyricsMode.nameThatSong)
        ..incrementLyricsStat(LyricsMode.nameThatSong)
        ..incrementLyricsStat(LyricsMode.lyricsOrLie);

      final stats = read().progress.stats;
      expect(stats.nameThaSongCorrect, 2);
      expect(stats.lyricsOrLieCorrect, 1);
      expect(stats.totalCorrect, 0);
    });

    test('timer setters update settings', () {
      controller
        ..setMediumTimer(25)
        ..setHardTimer(15);

      final settings = read().progress.settings;
      expect(settings.mediumTimer, 25);
      expect(settings.hardTimer, 15);
      expect(settings.volume, 0.8);
      expect(settings.theme, ThemeSetting.dark);
    });

    test('addToast queues ids and dismissToast removes them', () {
      controller
        ..addToast('first_meow')
        ..addToast('speed_demon')
        ..addToast('all_ears');
      expect(read().pendingToasts, ['first_meow', 'speed_demon', 'all_ears']);

      controller.dismissToast('speed_demon');
      expect(read().pendingToasts, ['first_meow', 'all_ears']);
    });

    test('addToDecoyPool builds a new map each time', () {
      final lyrics = withLyrics(1).lyrics;
      controller.addToDecoyPool(1, lyrics);
      final first = read().decoyPool;

      controller.addToDecoyPool(2, withLyrics(2).lyrics);

      expect(first.keys, [1]);
      expect(read().decoyPool.keys, [1, 2]);
      expect(read().decoyPool[1], lyrics);
    });

    test('resetProgress restores the default progress', () {
      controller
        ..answerCorrect(makeTrack(1))
        ..setVolume(0.2)
        ..resetProgress();
      expect(read().progress, defaultProgress);
    });

    test('simple setters store their values', () {
      const album = Album(id: 9, title: 'Lover', coverMedium: null);
      const manifest = UpdateManifest(
        version: '0.3.0',
        notes: 'Notes',
        pubDate: '2026-10-05T00:00:00Z',
      );
      final progress = defaultProgress.copyWith(version: 3);
      controller
        ..setMode(GameMode.album)
        ..setDifficulty(Difficulty.medium)
        ..setQuizType(QuizType.lyrics)
        ..setLyricsMode(LyricsMode.nameThatSong)
        ..setAlbums([album])
        ..setTrackPool([makeTrack(1)])
        ..setLyricsFetchProgress((fetched: 2, total: 8))
        ..setLyricsAvailableTracks([makeTrack(2)])
        ..setUpdaterState(const UpdaterAvailable(manifest: manifest))
        ..setProgress(progress)
        ..toggleAlbum(9)
        ..clearSelectedAlbums();

      final state = read();
      expect(state.mode, GameMode.album);
      expect(state.difficulty, Difficulty.medium);
      expect(state.quizType, QuizType.lyrics);
      expect(state.lyricsMode, LyricsMode.nameThatSong);
      expect(state.albums, [album]);
      expect(state.trackPool, [makeTrack(1)]);
      expect(state.lyricsFetchProgress, (fetched: 2, total: 8));
      expect(state.lyricsAvailableTracks, [makeTrack(2)]);
      expect(state.updaterState, const UpdaterAvailable(manifest: manifest));
      expect(state.progress, same(progress));
      expect(state.selectedAlbumIds, isEmpty);

      controller.setLyricsFetchProgress(null);
      expect(read().lyricsFetchProgress, isNull);
    });

    test('every action publishes a new state and leaves the old intact', () {
      final initial = read();
      controller.answerCorrect(makeTrack(1));
      final afterAnswer = read();

      expect(identical(initial, afterAnswer), isFalse);
      expect(initial.streak, 0);
      expect(initial.progress.stats.totalCorrect, 0);
      expect(initial.progress.stats.albumsPlayed, isEmpty);
      expect(afterAnswer.streak, 1);
    });

    test('selecting an unchanged collection does not notify', () {
      controller.setTrackPool([makeTrack(1)]);
      var notifications = 0;
      container.listen(
        gameControllerProvider.select((state) => state.trackPool),
        (_, _) => notifications++,
      );

      controller
        ..setPhase(GamePhase.playing)
        ..setDifficulty(Difficulty.hard)
        ..incrementRelisten()
        ..answerIncorrect();
      expect(notifications, 0);
      expect(identical(read().trackPool, read().trackPool), isTrue);

      controller.setTrackPool([makeTrack(2)]);
      expect(notifications, 1);
    });

    test('state collections cannot be modified in place', () {
      controller
        ..toggleAlbum(1)
        ..setTrackPool([makeTrack(1)])
        ..addToast('first_meow')
        ..addToDecoyPool(1, withLyrics(1).lyrics);
      final state = read();

      expect(() => state.selectedAlbumIds.add(2), throwsUnsupportedError);
      expect(() => state.trackPool.clear(), throwsUnsupportedError);
      expect(() => state.pendingToasts.add('x'), throwsUnsupportedError);
      expect(() => state.decoyPool.remove(1), throwsUnsupportedError);
    });
  });
}
