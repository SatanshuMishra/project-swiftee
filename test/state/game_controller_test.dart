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

    test('toggleEra adds and removes', () {
      controller.toggleEra('era1');
      expect(read().selectedEraKeys, ['era1']);
      controller.toggleEra('era2');
      expect(read().selectedEraKeys, ['era1', 'era2']);
      controller.toggleEra('era1');
      expect(read().selectedEraKeys, ['era2']);
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
      expect(state.selectedEraKeys, isEmpty);
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
      expect(state.quickRoundTotal, isNull);
      expect(state.roundNumber, 0);
      expect(state.roundResults, isEmpty);
      expect(state.isLastQuickRound, isFalse);
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
        ..startQuickRound()
        ..setAlbums([album])
        ..setMode(GameMode.album)
        ..setDifficulty(Difficulty.hard)
        ..toggleEra('era100')
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
      expect(state.selectedEraKeys, isEmpty);
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
      expect(state.quickRoundTotal, isNull);
      expect(state.roundNumber, 0);
      expect(state.roundResults, isEmpty);
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

    test(
      'reset clears the shelf and stats but keeps settings and the nickname',
      () {
        final updater = defaultProgress.updater.copyWith(
          autoCheckEnabled: false,
          lastCheckedAt: '2026-10-05T08:00:00.000Z',
          skippedVersions: ['0.2.3'],
        );
        controller
          ..setProgress(read().progress.copyWith(updater: updater))
          ..answerCorrect(makeTrack(1))
          ..incrementLyricsStat(LyricsMode.nameThatSong)
          ..setProgress(
            read().progress.copyWith(
              achievements: {
                'first_meow': const AchievementState(
                  unlocked: true,
                  unlockedAt: '2026-10-05T12:00:00.000Z',
                  song: 'Track 1',
                  albumId: '100',
                  trackId: '1',
                ),
              },
            ),
          )
          ..setTheme(ThemeSetting.light)
          ..setVolume(0.4)
          ..setMediumTimer(25)
          ..setHardTimer(15)
          ..setMisuVisits(MisuVisits.often)
          ..setNickname('Sam');

        controller.resetProgress();

        final progress = read().progress;
        expect(progress.achievements, defaultProgress.achievements);
        expect(progress.stats, defaultProgress.stats);
        expect(progress.settings.theme, ThemeSetting.light);
        expect(progress.settings.volume, 0.4);
        expect(progress.settings.mediumTimer, 25);
        expect(progress.settings.hardTimer, 15);
        expect(progress.settings.misuVisits, MisuVisits.often);
        expect(progress.settings.nickname, 'Sam');
        expect(progress.updater, updater);
        expect(progress.version, defaultProgress.version);
      },
    );

    test('a redrawn round keeps its number until it is answered', () {
      controller
        ..startQuickRound()
        ..startRound(makeTrack(1), const [], const []);
      expect(read().roundNumber, 1);

      controller.startRound(makeTrack(2), const [], const [], redraw: true);
      expect(read().roundNumber, 1);
      expect(read().currentTrack, makeTrack(2));

      controller
        ..answerCorrect(makeTrack(2))
        ..startRound(makeTrack(3), const [], const [], redraw: true);
      expect(read().roundNumber, 2);

      controller.startRound(makeTrack(4), const [], const []);
      expect(read().roundNumber, 3);
      expect(read().roundResults, hasLength(1));
    });

    test('a quick round lasts ten songs and ends on the summary', () {
      controller
        ..setMode(GameMode.album)
        ..setDifficulty(Difficulty.hard)
        ..setQuizType(QuizType.lyrics)
        ..setLyricsMode(LyricsMode.lyricsOrLie)
        ..answerCorrect(makeTrack(99))
        ..answerIncorrect(makeTrack(98))
        ..startQuickRound();

      final started = read();
      expect(started.mode, GameMode.tonight);
      expect(started.quizType, QuizType.sound);
      expect(started.lyricsMode, isNull);
      expect(started.difficulty, Difficulty.medium);
      expect(started.quickRoundTotal, 10);
      expect(started.roundNumber, 0);
      expect(started.roundResults, isEmpty);
      expect(started.streak, 0);
      expect(started.quackCount, 0);
      expect(started.phase, GamePhase.playing);

      for (var round = 1; round <= 10; round++) {
        expect(read().isLastQuickRound, isFalse, reason: 'round $round');
        final track = makeTrack(round);
        controller.startRound(track, const [], [track]);
        if (round.isEven) {
          controller.answerCorrect(track);
        } else {
          controller.answerIncorrect(track);
        }
      }
      expect(read().roundNumber, 10);
      expect(read().isLastQuickRound, isTrue);

      controller.finishQuickRound();

      final finished = read();
      expect(finished.phase, GamePhase.roundSummary);
      expect(finished.quickRoundTotal, 10);
      expect(finished.roundResults, [
        for (var round = 1; round <= 10; round++)
          RoundOutcome(makeTrack(round), correct: round.isEven),
      ]);
    });

    test('nickname is trimmed and capped at twenty characters', () {
      controller.setNickname('     ');
      expect(read().progress.settings.nickname, isNull);
      controller.setNickname('');
      expect(read().progress.settings.nickname, isNull);

      controller.setNickname('  Abcdefghijklmnopqrstuvwxy  ');
      expect(read().progress.settings.nickname, 'Abcdefghijklmnopqrst');

      controller.setNickname('   ');
      expect(read().progress.settings.nickname, 'Abcdefghijklmnopqrst');

      controller.setNickname('Taylor Alison Swift Ana');
      expect(read().progress.settings.nickname, 'Taylor Alison Swift');

      controller.setNickname(' Sam ');
      expect(read().progress.settings.nickname, 'Sam');
    });

    test('setMisuVisits updates settings', () {
      controller.setMisuVisits(MisuVisits.off);
      expect(read().progress.settings.misuVisits, MisuVisits.off);
      expect(read().progress.settings.volume, 0.8);
    });

    test('beginSetup chooses the mode and clears a quick round', () {
      controller
        ..startQuickRound()
        ..startRound(makeTrack(1), const [], [makeTrack(1)])
        ..answerCorrect(makeTrack(1))
        ..beginSetup(GameMode.album);

      final state = read();
      expect(state.mode, GameMode.album);
      expect(state.phase, GamePhase.setup);
      expect(state.quickRoundTotal, isNull);
      expect(state.roundNumber, 0);
      expect(state.roundResults, isEmpty);
      expect(state.isLastQuickRound, isFalse);
    });

    test('rounds count through startRound and nextLyricsTrack', () {
      controller
        ..startRound(makeTrack(1), const [], [makeTrack(1)])
        ..startRound(makeTrack(2), const [], [makeTrack(2)]);
      expect(read().roundNumber, 2);

      expect(controller.nextLyricsTrack(), isNull);
      expect(read().roundNumber, 2);

      controller.setLyricsPool([withLyrics(1)]);
      controller
        ..nextLyricsTrack()
        ..nextLyricsTrack();
      expect(read().roundNumber, 4);
      expect(read().isLastQuickRound, isFalse);
    });

    test('answers record their outcome only when a track is given', () {
      controller
        ..answerCorrect(makeTrack(1))
        ..answerIncorrect()
        ..answerIncorrect(makeTrack(2));

      expect(read().roundResults, [
        RoundOutcome(makeTrack(1), correct: true),
        RoundOutcome(makeTrack(2), correct: false),
      ]);
      expect(read().quackCount, 2);
    });

    test('round outcomes compare by track and result', () {
      expect(
        RoundOutcome(makeTrack(1), correct: true),
        RoundOutcome(makeTrack(1), correct: true),
      );
      expect(
        RoundOutcome(makeTrack(1), correct: true).hashCode,
        RoundOutcome(makeTrack(1), correct: true).hashCode,
      );
      expect(
        RoundOutcome(makeTrack(1), correct: true) ==
            RoundOutcome(makeTrack(1), correct: false),
        isFalse,
      );
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
        ..toggleEra('era9')
        ..clearSelectedEras();

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
      expect(state.selectedEraKeys, isEmpty);

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
        ..toggleEra('era1')
        ..setTrackPool([makeTrack(1)])
        ..addToast('first_meow')
        ..addToDecoyPool(1, withLyrics(1).lyrics)
        ..answerCorrect(makeTrack(1));
      final state = read();

      expect(() => state.selectedEraKeys.add('era2'), throwsUnsupportedError);
      expect(() => state.trackPool.clear(), throwsUnsupportedError);
      expect(() => state.pendingToasts.add('x'), throwsUnsupportedError);
      expect(() => state.decoyPool.remove(1), throwsUnsupportedError);
      expect(() => state.roundResults.clear(), throwsUnsupportedError);
    });
  });
}
