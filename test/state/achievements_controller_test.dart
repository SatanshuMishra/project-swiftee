import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/domain/engine/achievements.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/achievements_controller.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/providers.dart';

final DateTime _now = DateTime.utc(2026, 10, 5, 12, 0, 0, 123, 456);
const String _nowIso = '2026-10-05T12:00:00.123Z';

const Album _lover = Album(id: 10, title: 'Lover', coverMedium: null);

Track _track(int id, {Album album = _lover}) => Track(
  id: id,
  title: 'Song $id',
  titleShort: 'Song $id',
  duration: 200,
  preview: 'https://cdnt-preview.dzcdn.net/api/1/1/$id.mp3',
  artist: const Artist(id: 12246, name: 'Taylor Swift'),
  album: album,
);

GameProgress _progressWith({
  int totalCorrect = 0,
  List<String> albumsPlayed = const [],
  Map<String, List<String>> tracksGuessedPerAlbum = const {},
  int totalLyricsCorrect = 0,
  int nameThaSongCorrect = 0,
  int lyricsOrLieCorrect = 0,
}) => defaultProgress.copyWith(
  stats: defaultProgress.stats.copyWith(
    totalCorrect: totalCorrect,
    albumsPlayed: albumsPlayed,
    tracksGuessedPerAlbum: tracksGuessedPerAlbum,
    totalLyricsCorrect: totalLyricsCorrect,
    nameThaSongCorrect: nameThaSongCorrect,
    lyricsOrLieCorrect: lyricsOrLieCorrect,
  ),
);

AchievementContext _context({
  bool correct = true,
  int streak = 0,
  int quackCount = 0,
  Difficulty difficulty = Difficulty.easy,
  Duration timeElapsed = const Duration(seconds: 10),
  bool usedFullClip = false,
  GameProgress? progress,
  Map<int, int> albumTrackTotals = const {},
  QuizType? quizType,
  int sessionSoundCorrect = 0,
  int sessionLyricsCorrect = 0,
  Track? track,
}) => (
  correct: correct,
  streak: streak,
  quackCount: quackCount,
  difficulty: difficulty,
  timeElapsed: timeElapsed,
  usedFullClip: usedFullClip,
  progress: progress ?? defaultProgress,
  albumTrackTotals: albumTrackTotals,
  quizType: quizType,
  lyricsMode: null,
  sessionSoundCorrect: sessionSoundCorrect,
  sessionLyricsCorrect: sessionLyricsCorrect,
  track: track,
);

void main() {
  group('achievements controller parity', () {
    late ProviderContainer container;

    AchievementsController achievements() =>
        container.read(achievementsControllerProvider);

    GameController game() => container.read(gameControllerProvider.notifier);

    GameState read() => container.read(gameControllerProvider);

    List<String> answer({
      required bool correct,
      Track? track,
      Duration timeElapsed = const Duration(seconds: 10),
      bool usedFullClip = false,
    }) {
      if (correct) {
        game().answerCorrect(track ?? _track(1));
      } else {
        game().answerIncorrect();
      }
      return achievements().checkAfterAnswer(
        correct: correct,
        timeElapsed: timeElapsed,
        usedFullClip: usedFullClip,
      );
    }

    setUp(() {
      container = ProviderContainer.test(
        overrides: [
          appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
          clockProvider.overrideWithValue(() => _now),
          httpClientProvider.overrideWithValue(
            MockClient((request) async => http.Response('', 500)),
          ),
        ],
      );
    });

    test('a first correct answer unlocks first_meow with a toast', () {
      final unlocked = answer(correct: true);

      expect(unlocked, ['first_meow']);
      expect(
        read().progress.achievements['first_meow'],
        const AchievementState(unlocked: true, unlockedAt: _nowIso),
      );
      expect(read().pendingToasts, ['first_meow']);
    });

    test('an unlock records the song it was earned on', () {
      const folklore = Album(id: 1234, title: 'folklore', coverMedium: null);
      final cardigan = _track(
        5678,
        album: folklore,
      ).copyWith(title: 'cardigan');
      game().answerCorrect(cardigan);

      final unlocked = achievements().checkAfterAnswer(
        correct: true,
        timeElapsed: const Duration(seconds: 10),
        usedFullClip: false,
        track: cardigan,
      );

      expect(unlocked, ['first_meow']);
      expect(
        read().progress.achievements['first_meow'],
        const AchievementState(
          unlocked: true,
          unlockedAt: _nowIso,
          song: 'cardigan',
          albumId: '1234',
          trackId: '5678',
        ),
      );
    });

    test('every record unlocked together carries the same song', () {
      final track = _track(3).copyWith(title: 'Cruel Summer');
      game().answerCorrect(track);

      final unlocked = achievements().checkAfterAnswer(
        correct: true,
        timeElapsed: const Duration(seconds: 2),
        usedFullClip: true,
        track: track,
      );

      expect(unlocked, ['first_meow', 'speed_demon', 'persistent_listener']);
      for (final id in unlocked) {
        final record = read().progress.achievements[id]!;
        expect(record.song, 'Cruel Summer', reason: id);
        expect(record.albumId, '10', reason: id);
        expect(record.trackId, '3', reason: id);
      }
    });

    test('an unlock without a track leaves the song empty', () {
      final unlocked = achievements().checkAndUnlock(
        _context(progress: _progressWith(totalCorrect: 1)),
      );

      expect(unlocked, ['first_meow']);
      final record = read().progress.achievements['first_meow']!;
      expect(record.song, isNull);
      expect(record.albumId, isNull);
      expect(record.trackId, isNull);
    });

    test('unlockedAt is an ISO 8601 UTC time with milliseconds', () {
      answer(correct: true);

      final unlockedAt =
          read().progress.achievements['first_meow']!.unlockedAt!;
      expect(
        unlockedAt,
        matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$')),
      );
      expect(
        DateTime.parse(unlockedAt),
        _now.subtract(const Duration(microseconds: 456)),
      );
    });

    test('never unlocks an achievement twice', () {
      answer(correct: true);
      final first = read().progress.achievements['first_meow'];

      final again = answer(correct: true, track: _track(2));

      expect(again, isEmpty);
      expect(read().progress.achievements['first_meow'], first);
      expect(read().pendingToasts, ['first_meow']);
    });

    test(
      'an already unlocked achievement in the save is not unlocked again',
      () {
        game().setProgress(
          defaultProgress.copyWith(
            achievements: {
              'first_meow': const AchievementState(
                unlocked: true,
                unlockedAt: '2025-01-01T00:00:00.000Z',
              ),
            },
          ),
        );

        final unlocked = answer(correct: true);

        expect(unlocked, isEmpty);
        expect(
          read().progress.achievements['first_meow']!.unlockedAt,
          '2025-01-01T00:00:00.000Z',
        );
        expect(read().pendingToasts, isEmpty);
      },
    );

    test('several unlocks toast in definition order with one time', () {
      final unlocked = answer(
        correct: true,
        timeElapsed: const Duration(seconds: 2),
        usedFullClip: true,
      );

      expect(unlocked, ['first_meow', 'speed_demon', 'persistent_listener']);
      expect(read().pendingToasts, unlocked);
      for (final id in unlocked) {
        expect(read().progress.achievements[id]!.unlockedAt, _nowIso);
      }
    });

    test('a wrong answer unlocks only quack_collector, at five quacks', () {
      for (var quack = 1; quack < 5; quack++) {
        expect(
          answer(
            correct: false,
            usedFullClip: true,
            timeElapsed: Duration.zero,
          ),
          isEmpty,
        );
      }

      expect(answer(correct: false), ['quack_collector']);
      expect(read().pendingToasts, ['quack_collector']);
      expect(read().progress.stats.totalCorrect, 0);
    });

    test('unlocking keeps the stats the answer recorded', () {
      game()
        ..setQuizType(QuizType.lyrics)
        ..answerCorrect(_track(7))
        ..incrementLyricsStat(LyricsMode.nameThatSong);

      final unlocked = achievements().checkAfterAnswer(
        correct: true,
        timeElapsed: const Duration(seconds: 10),
        usedFullClip: false,
      );

      expect(unlocked, ['first_meow', 'lyric_lover']);
      final stats = read().progress.stats;
      expect(stats.totalCorrect, 1);
      expect(stats.totalLyricsCorrect, 1);
      expect(stats.nameThaSongCorrect, 1);
      expect(stats.albumsPlayed, ['10']);
      expect(stats.tracksGuessedPerAlbum, {
        '10': ['7'],
      });
    });

    test('dual_threat needs a sound and a lyrics answer this session', () {
      expect(answer(correct: true), ['first_meow']);

      game().setQuizType(QuizType.lyrics);
      final unlocked = answer(correct: true, track: _track(2));

      expect(unlocked, ['lyric_lover', 'dual_threat']);
    });

    test(
      'album_completionist unlocks once a loaded album is fully guessed',
      () async {
        container = ProviderContainer.test(
          overrides: [
            appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
            clockProvider.overrideWithValue(() => _now),
            httpClientProvider.overrideWithValue(
              MockClient(
                (request) async => http.Response.bytes(
                  utf8.encode(
                    jsonEncode({
                      'id': 10,
                      'title': 'Lover',
                      'cover_medium': null,
                      'nb_tracks': 2,
                      'tracks': {
                        'data': [
                          for (final id in [1, 2])
                            {
                              'id': id,
                              'title': 'Song $id',
                              'title_short': 'Song $id',
                              'duration': 200,
                              'preview':
                                  'https://cdnt-preview.dzcdn.net/$id.mp3',
                              'artist': {'id': 12246, 'name': 'Taylor Swift'},
                            },
                        ],
                      },
                    }),
                  ),
                  200,
                ),
              ),
            ),
          ],
        );
        await container
            .read(catalogControllerProvider.notifier)
            .fetchAlbumTracks(10);

        expect(answer(correct: true), ['first_meow']);
        expect(answer(correct: true, track: _track(2)), [
          'album_completionist',
        ]);
        expect(read().pendingToasts, ['first_meow', 'album_completionist']);
      },
    );

    test('unlock conditions match useAchievements', () {
      final cases = <(String, AchievementContext, bool)>[
        (
          'first_meow',
          _context(progress: _progressWith(totalCorrect: 1)),
          true,
        ),
        ('first_meow', _context(), false),
        (
          'getting_warmed_up',
          _context(progress: _progressWith(totalCorrect: 9)),
          false,
        ),
        (
          'getting_warmed_up',
          _context(progress: _progressWith(totalCorrect: 10)),
          true,
        ),
        ('purrfect_streak', _context(streak: 9), false),
        ('purrfect_streak', _context(streak: 10), true),
        (
          'album_explorer',
          _context(progress: _progressWith(albumsPlayed: ['1', '2', '3', '4'])),
          false,
        ),
        (
          'album_explorer',
          _context(
            progress: _progressWith(albumsPlayed: ['1', '2', '3', '4', '5']),
          ),
          true,
        ),
        (
          'hard_mode_hero',
          _context(
            difficulty: Difficulty.hard,
            progress: _progressWith(totalCorrect: 5),
          ),
          true,
        ),
        (
          'hard_mode_hero',
          _context(
            difficulty: Difficulty.hard,
            progress: _progressWith(totalCorrect: 4),
          ),
          false,
        ),
        (
          'hard_mode_hero',
          _context(
            difficulty: Difficulty.medium,
            progress: _progressWith(totalCorrect: 50),
          ),
          false,
        ),
        (
          'speed_demon',
          _context(timeElapsed: const Duration(milliseconds: 3000)),
          true,
        ),
        (
          'speed_demon',
          _context(timeElapsed: const Duration(milliseconds: 3001)),
          false,
        ),
        ('persistent_listener', _context(usedFullClip: true), true),
        ('persistent_listener', _context(), false),
        ('quack_collector', _context(correct: false, quackCount: 5), true),
        ('quack_collector', _context(correct: false, quackCount: 4), false),
        ('quack_collector', _context(quackCount: 5), false),
        (
          'all_ears',
          _context(progress: _progressWith(totalCorrect: 49)),
          false,
        ),
        ('all_ears', _context(progress: _progressWith(totalCorrect: 50)), true),
        (
          'lyric_lover',
          _context(progress: _progressWith(totalLyricsCorrect: 1)),
          true,
        ),
        ('lyric_lover', _context(), false),
        (
          'poet_laureate',
          _context(progress: _progressWith(nameThaSongCorrect: 19)),
          false,
        ),
        (
          'poet_laureate',
          _context(progress: _progressWith(nameThaSongCorrect: 20)),
          true,
        ),
        (
          'lie_detector',
          _context(progress: _progressWith(lyricsOrLieCorrect: 14)),
          false,
        ),
        (
          'lie_detector',
          _context(progress: _progressWith(lyricsOrLieCorrect: 15)),
          true,
        ),
        ('dual_threat', _context(sessionSoundCorrect: 1), false),
        (
          'dual_threat',
          _context(sessionSoundCorrect: 1, sessionLyricsCorrect: 1),
          true,
        ),
        ('lyric_streak', _context(quizType: QuizType.lyrics, streak: 10), true),
        ('lyric_streak', _context(quizType: QuizType.lyrics, streak: 9), false),
        ('lyric_streak', _context(quizType: QuizType.sound, streak: 10), false),
        ('lyric_streak', _context(streak: 10), false),
        (
          'album_completionist',
          _context(
            albumTrackTotals: {10: 3},
            progress: _progressWith(
              tracksGuessedPerAlbum: {
                '10': ['1', '2', '3'],
              },
            ),
          ),
          true,
        ),
        (
          'album_completionist',
          _context(
            albumTrackTotals: {10: 3},
            progress: _progressWith(
              tracksGuessedPerAlbum: {
                '10': ['1', '2'],
              },
            ),
          ),
          false,
        ),
        (
          'album_completionist',
          _context(
            albumTrackTotals: {20: 5},
            progress: _progressWith(
              tracksGuessedPerAlbum: {
                '10': ['1', '2', '3'],
              },
            ),
          ),
          false,
        ),
        (
          'album_completionist',
          _context(
            albumTrackTotals: {10: 0},
            progress: _progressWith(tracksGuessedPerAlbum: {'10': <String>[]}),
          ),
          false,
        ),
        (
          'album_completionist',
          _context(
            progress: _progressWith(
              tracksGuessedPerAlbum: {
                '10': ['1'],
              },
            ),
          ),
          false,
        ),
        (
          'unknown_achievement',
          _context(progress: _progressWith(totalCorrect: 99)),
          false,
        ),
      ];

      for (final (id, context, expected) in cases) {
        expect(
          achievementConditionMet(id, context),
          expected,
          reason: '$id $context',
        );
      }
    });

    test('a wrong answer blocks every achievement but quack_collector', () {
      final context = _context(
        correct: false,
        streak: 10,
        quackCount: 5,
        difficulty: Difficulty.hard,
        timeElapsed: Duration.zero,
        usedFullClip: true,
        progress: _progressWith(
          totalCorrect: 50,
          albumsPlayed: ['1', '2', '3', '4', '5'],
          totalLyricsCorrect: 20,
          nameThaSongCorrect: 20,
          lyricsOrLieCorrect: 15,
        ),
        quizType: QuizType.lyrics,
        sessionSoundCorrect: 1,
        sessionLyricsCorrect: 1,
      );

      expect(
        [
          for (final def in achievementDefs)
            if (achievementConditionMet(def.id, context)) def.id,
        ],
        ['quack_collector'],
      );
    });
  });
}
