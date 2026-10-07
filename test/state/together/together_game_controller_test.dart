import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/lyrics/danger_zones.dart';
import 'package:swiftie_quiz/data/together/game_wire.dart';
import 'package:swiftie_quiz/domain/engine/clip_selector.dart';
import 'package:swiftie_quiz/domain/engine/play_order.dart';
import 'package:swiftie_quiz/domain/models/catalogue.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/play_history.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/together/game_messages.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/domain/together/scoring.dart';
import 'package:swiftie_quiz/domain/together/server_link.dart';
import 'package:swiftie_quiz/domain/together/standings.dart';
import 'package:swiftie_quiz/services/audio/audio_engine.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/misu_controller.dart';
import 'package:swiftie_quiz/state/play_history_controller.dart';
import 'package:swiftie_quiz/state/lyrics_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/together/room_controller.dart';
import 'package:swiftie_quiz/state/together/together_game_controller.dart';
import 'package:swiftie_quiz/state/together/together_game_state.dart';
import 'package:together_protocol/together_protocol.dart';

import '../../fixtures/catalogue_fixture.dart';
import 'fake_relay.dart';

final ServerLink _link = ServerLink.parse(
  'https://swiftie.satanshu.tech/#${'Ab0-_' * 8}xyz',
)!;

const Player _sam = Player(id: 'host1', name: 'Sam', avatar: 'seedSam');
const Player _maya = Player(id: 'guest1', name: 'Maya', avatar: 'seedMaya');
const Player _lee = Player(id: 'guest2', name: 'Lee', avatar: 'seedLee');

const Map<int, String> _loverSongs = {
  101: 'Cruel Summer',
  102: 'Lover',
  103: 'The Man',
  104: 'The Archer',
  105: 'Daylight',
  111: "Cruel Summer (Taylor's Version)",
  112: "Lover (Taylor's Version)",
  113: "The Man (Taylor's Version)",
  114: "The Archer (Taylor's Version)",
  115: "Daylight (Taylor's Version)",
};
const Map<int, String> _midnightsSongs = {
  201: 'Anti-Hero',
  202: 'Lavender Haze',
  203: 'Maroon',
  204: 'Karma',
};
const Map<int, String> _songs = {..._loverSongs, ..._midnightsSongs};

const double _clipLength = 30;
const int _sampleRate = 8000;
const Duration _instant = Duration(milliseconds: 1);

final DateTime _epoch = DateTime.utc(2026, 10, 7, 20);

final List<RawRelease> _releases = [
  rawRelease(108447472, 'Lover', '2019-08-23', [
    for (final MapEntry(key: id, value: title) in _loverSongs.entries)
      rawTrack(id, title),
  ]),
  rawRelease(1203001, 'Midnights', '2022-10-21', [
    for (final MapEntry(key: id, value: title) in _midnightsSongs.entries)
      rawTrack(id, title),
  ]),
];

String _albumOf(int id) => _loverSongs.containsKey(id) ? 'Lover' : 'Midnights';

Track _track(int id) => Track(
  id: id,
  title: _songs[id]!,
  titleShort: _songs[id]!,
  duration: 200,
  preview: '',
  artist: const Artist(id: taylor, name: 'Taylor Swift'),
  album: Album(id: 1, title: _albumOf(id), coverMedium: null),
);

String _previewOf(int id) => 'https://cdnt-preview.dzcdn.net/api/1/1/$id.mp3';

Uint8List _bytesOf(int id) => Uint8List.fromList(utf8.encode('$id'));

ClipAudio _quietMiddle(double durationSeconds) => ClipAudio(
  Float32List.fromList(
    List<double>.generate(
      (durationSeconds * _sampleRate).ceil(),
      (index) =>
          index >= 5 * _sampleRate && index < 25 * _sampleRate ? 0.1 : 0.5,
    ),
  ),
  _sampleRate,
  durationSeconds,
);

final double _smartStart = selectClipStartWithFallback(
  _quietMiddle(_clipLength),
  const [],
);

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> _deezerTrack(int id) => {
  'id': id,
  'title': _songs[id],
  'title_short': _songs[id],
  'title_version': '',
  'duration': 200,
  'preview': _previewOf(id),
  'artist': {'id': taylor, 'name': 'Taylor Swift'},
  'album': {'id': 1, 'title': _albumOf(id), 'cover_medium': null},
};

Map<String, Object?> _lrclibRecord(int id) => {
  'id': 1000 + id,
  'trackName': _songs[id],
  'artistName': 'Taylor Swift',
  'albumName': _albumOf(id),
  'duration': 200,
  'instrumental': false,
  'plainLyrics': [
    for (var line = 1; line <= 8; line++)
      'Verse line $line from record $id keeps going',
  ].join('\n'),
  'syncedLyrics': null,
};

final class _FakeClip implements LoadedClip {
  _FakeClip(this.bytes);

  final Uint8List bytes;
  int sampleReads = 0;

  @override
  double get durationSeconds => _clipLength;

  @override
  Future<ClipAudio> readSamples() async {
    sampleReads += 1;
    return _quietMiddle(durationSeconds);
  }
}

typedef _Slice = ({AudioVoice voice, LoadedClip clip, double offset});

final class _FakeEngine implements AudioEngine {
  List<_FakeClip> loaded = const [];
  List<_Slice> slices = const [];
  List<AudioVoice> stopped = const [];
  List<AudioVoice> finished = const [];
  List<LoadedClip> unloaded = const [];
  int _nextVoice = 1;

  @override
  Future<void> init() async {}

  @override
  Future<LoadedClip> loadClip(Uint8List mp3Bytes) async {
    final clip = _FakeClip(mp3Bytes);
    loaded = [...loaded, clip];
    return clip;
  }

  @override
  Future<void> unloadClip(LoadedClip clip) async {
    unloaded = [...unloaded, clip];
  }

  @override
  AudioVoice playSlice(
    LoadedClip clip,
    double offsetSeconds,
    double durationSeconds,
    double volume,
  ) {
    final voice = AudioVoice(_nextVoice);
    _nextVoice += 1;
    slices = [...slices, (voice: voice, clip: clip, offset: offsetSeconds)];
    return voice;
  }

  @override
  void pause(AudioVoice voice) {}

  @override
  void resume(AudioVoice voice) {}

  @override
  Future<void> stop(AudioVoice voice) async {
    stopped = [...stopped, voice];
  }

  @override
  double? positionOf(AudioVoice voice) => stopped.contains(voice)
      ? null
      : slices[voice.id - 1].offset + (finished.contains(voice) ? 1000 : 0);

  @override
  void setVolume(AudioVoice voice, double volume) {}

  @override
  Future<void> playQuack(double volume) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> shutdown() async {}
}

final class _FakeDangerZones implements DangerZoneService {
  List<String> calls = const [];

  @override
  Future<List<DangerZone>> fetchDangerZones(
    String trackTitle,
    String artistName,
    String titleShort,
    num songDurationSeconds,
  ) async {
    calls = [...calls, trackTitle];
    return const [];
  }

  @override
  void clearDangerZoneCache() {}
}

final class _Harness {
  _Harness(
    this.async, {
    String nickname = 'Sam',
    MisuVisits misuVisits = MisuVisits.often,
  }) : relay = FakeRelay(),
       engine = _FakeEngine(),
       zones = _FakeDangerZones() {
    container = ProviderContainer.test(
      overrides: [
        relayConnectorProvider.overrideWithValue(relay),
        editionProvider.overrideWithValue(Edition.open),
        appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
        clockProvider.overrideWithValue(() => _epoch.add(async.elapsed)),
        randomProvider.overrideWithValue(Random(5)),
        audioEngineProvider.overrideWithValue(engine),
        dangerZoneServiceProvider.overrideWithValue(AsyncData(zones)),
        catalogueStoreProvider.overrideWithValue(
          fixtureCatalogueStore(releases: _releases),
        ),
        httpClientProvider.overrideWithValue(MockClient(_respond)),
      ],
    );
    game.setProgress(
      defaultProgress.copyWith(
        settings: defaultProgress.settings.copyWith(
          nickname: nickname,
          misuVisits: misuVisits,
        ),
      ),
    );
    container
      ..listen(audioControllerProvider, (_, _) {})
      ..listen(togetherGameControllerProvider, (_, next) {
        states = [...states, next];
      })
      ..listen(gameControllerProvider.select((game) => game.phase), (_, phase) {
        phases = [...phases, phase];
      })
      ..listen(misuControllerProvider, (previous, next) {
        if (next.visit case final visit? when visit != previous?.visit) {
          visits = [...visits, visit];
        }
      });
  }

  final FakeAsync async;
  final FakeRelay relay;
  final _FakeEngine engine;
  final _FakeDangerZones zones;
  late final ProviderContainer container;
  List<TogetherGameState> states = const [];
  List<GamePhase> phases = const [];
  List<MisuVisit> visits = const [];
  Map<int, Completer<void>> held = const {};
  Duration lrclibLag = Duration.zero;

  TogetherGameController get together =>
      container.read(togetherGameControllerProvider.notifier);

  TogetherGameState get state => container.read(togetherGameControllerProvider);

  RoomController get room => container.read(roomControllerProvider.notifier);

  GameController get game => container.read(gameControllerProvider.notifier);

  GameState get single => container.read(gameControllerProvider);

  List<RoundStart> get rounds => [
    for (final body in relay.bodies)
      if (body.message case final RoundStart start) start,
  ];

  RoundRevealed get revealed => [
    for (final body in relay.bodies)
      if (body.message case final RoundRevealed revealed) revealed,
  ].last;

  int get rightId => state.track!.id;

  int get wrongId =>
      state.options.firstWhere((option) => option.id != rightId).id;

  Future<http.Response> _respond(http.Request request) async {
    final url = request.url;
    switch (url.host) {
      case 'api.deezer.com':
        return _json(_deezerTrack(int.parse(url.pathSegments.last)));
      case 'cdnt-preview.dzcdn.net':
        final id = int.parse(url.pathSegments.last.replaceAll('.mp3', ''));
        await held[id]?.future;
        return http.Response.bytes(_bytesOf(id), 200);
      case 'lrclib.net' when lrclibLag > Duration.zero:
        await Future<void>.delayed(lrclibLag);
        return http.Response('', 404);
      case 'lrclib.net' when url.path == '/api/get':
        final title = url.queryParameters['track_name'];
        final id = _songs.entries.firstWhere((song) => song.value == title).key;
        return _json(_lrclibRecord(id));
      case _:
        return _json(<Object?>[]);
    }
  }

  void hold(int id) => held = {...held, id: Completer<void>()};

  void release(int id) {
    held[id]?.complete();
    async.flushMicrotasks();
  }

  void hostRoom(
    RoomSettings settings, {
    List<Player> guests = const [_maya, _lee],
  }) {
    room.setSettings(settings, 'Shuffle everything');
    unawaited(room.open(_link));
    async.flushMicrotasks();
    relay.push(const RoomOpened(code: 'BCDF', you: _sam));
    for (final guest in guests) {
      relay.push(PeerJoined(guest));
    }
    async.flushMicrotasks();
  }

  void joinRoom({List<Player> players = const [_sam, _maya]}) {
    unawaited(room.join(_link, 'BCDF'));
    async.flushMicrotasks();
    relay.push(
      RoomJoined(code: 'BCDF', you: _maya, hostId: _sam.id, players: players),
    );
    async.flushMicrotasks();
  }

  void start() {
    unawaited(together.start());
    async.flushMicrotasks();
  }

  void countdown() => async.elapse(countdownStep * countdownFrom);

  void fromHost(GameMessage message) {
    relay.pushGame(_sam.id, message);
    async.flushMicrotasks();
  }

  void guestAnswers(Player guest, {int? trackId, bool? real, double at = 1}) {
    relay.pushGame(
      guest.id,
      AnswerSent(number: state.number, trackId: trackId, real: real, at: at),
    );
    async.flushMicrotasks();
  }

  void playRound({
    required bool hostRight,
    bool mayaRight = true,
    bool leeRight = false,
  }) {
    countdown();
    together.answer(trackId: hostRight ? rightId : wrongId);
    guestAnswers(_maya, trackId: mayaRight ? rightId : wrongId, at: 2);
    guestAnswers(_lee, trackId: leeRight ? rightId : wrongId, at: 3);
    async.elapse(allAnsweredDelay);
  }

  void playLyricsRound({required bool real}) {
    countdown();
    together.answer(real: real);
    guestAnswers(_maya, real: true, at: 2);
    guestAnswers(_lee, real: false, at: 3);
    async.elapse(allAnsweredDelay);
  }
}

void main() {
  group('play together game', () {
    test('a round ends when everyone has answered, when quick draw is won, or on time', () {
      fakeAsync((async) {
        final classic = _Harness(async)
          ..hostRoom(const RoomSettings(rounds: 2), guests: const [_maya])
          ..start();
        expect(classic.state.stage, TogetherStage.countdown);
        classic.countdown();
        expect(classic.state.stage, TogetherStage.round);

        async.elapse(const Duration(seconds: 3));
        classic.together.answer(trackId: classic.rightId);
        expect(classic.state.myStatus, AnswerStatus.answered);
        async.elapse(const Duration(seconds: 1));
        final wrong = classic.wrongId;
        classic.guestAnswers(_maya, trackId: wrong, at: 3.9);
        expect(classic.state.statuses, {
          _sam.id: AnswerStatus.answered,
          _maya.id: AnswerStatus.answered,
        });
        async.elapse(allAnsweredDelay - _instant);
        expect(classic.state.stage, TogetherStage.round);
        async.elapse(_instant);
        expect(classic.state.stage, TogetherStage.reveal);
        expect(classic.revealed.results, [
          RoundResult(
            playerId: _sam.id,
            pickTrackId: classic.rounds.first.track.id,
            pickReal: null,
            right: true,
            at: 3,
            gain: 185,
          ),
          RoundResult(
            playerId: _maya.id,
            pickTrackId: wrong,
            pickReal: null,
            right: false,
            at: 3.9,
            gain: 0,
          ),
        ]);

        async.elapse(const Duration(seconds: revealSeconds));
        expect(classic.state.stage, TogetherStage.countdown);
        expect(classic.state.number, 2);
        classic.countdown();
        async.elapse(
          Duration(seconds: roundSeconds(Difficulty.medium)) +
              timeUpGrace -
              _instant,
        );
        expect(classic.state.stage, TogetherStage.round);
        async.elapse(_instant);
        expect(classic.state.stage, TogetherStage.reveal);
        expect(classic.revealed.number, 2);
        expect(classic.revealed.results, isEmpty);
      });

      fakeAsync((async) {
        final quick = _Harness(async)
          ..hostRoom(
            const RoomSettings(mode: TogetherMode.quickDraw, rounds: 1),
          )
          ..start()
          ..countdown();
        quick.together.answer(trackId: quick.wrongId);
        expect(quick.state.myStatus, AnswerStatus.out);
        async.elapse(const Duration(seconds: 2));
        quick.guestAnswers(_maya, trackId: quick.rightId, at: 2.1);
        async.elapse(const Duration(milliseconds: 300));
        quick.guestAnswers(_lee, trackId: quick.rightId, at: 1.4);
        expect(quick.state.statuses, {
          _sam.id: AnswerStatus.out,
          _maya.id: AnswerStatus.answered,
          _lee.id: AnswerStatus.answered,
        });
        async.elapse(
          quickDrawWindow - const Duration(milliseconds: 300) - _instant,
        );
        expect(quick.state.stage, TogetherStage.round);
        async.elapse(_instant);
        expect(quick.state.stage, TogetherStage.reveal);
        expect(quick.state.winnerId, _lee.id);
        expect(
          {
            for (final result in quick.revealed.results)
              result.playerId: result.gain,
          },
          {_sam.id: 0, _maya.id: 0, _lee.id: 100},
        );
      });
    });

    test('rounds carry four options or the right number of lines', () {
      fakeAsync((async) {
        final hard = _Harness(async)
          ..hostRoom(const RoomSettings(rounds: 1, difficulty: Difficulty.hard))
          ..start();
        final round = hard.rounds.single;
        expect(round.options, hasLength(4));
        expect(round.options, contains(round.track));
        expect(round.lines, isEmpty);
        expect(round.clipStart, _smartStart);
      });

      for (final (difficulty, lines) in [
        (Difficulty.easy, 3),
        (Difficulty.medium, 2),
        (Difficulty.hard, 1),
      ]) {
        fakeAsync((async) {
          final lyrics = _Harness(async)
            ..hostRoom(
              RoomSettings(
                mode: TogetherMode.lyricsOrLie,
                rounds: 1,
                difficulty: difficulty,
              ),
            )
            ..start();
          final round = lyrics.rounds.single;
          expect(round.lines, hasLength(lines), reason: difficulty.name);
          expect(round.options, isEmpty);
          expect(round.clipStart, 0);
          expect(lyrics.state.lines, round.lines);
          expect(lyrics.engine.loaded, isEmpty);
        });
      }
    });

    test('a host whose lyrics load takes over 30 s gives up and can try '
        'again', () {
      fakeAsync((async) {
        final host = _Harness(async)..lrclibLag = const Duration(seconds: 9);
        host
          ..hostRoom(
            const RoomSettings(mode: TogetherMode.lyricsOrLie, rounds: 5),
          )
          ..start();

        async.elapse(lyricsLoadLimit - const Duration(milliseconds: 1));
        expect(host.state.startFailed, isFalse);

        async.elapse(const Duration(milliseconds: 1));
        expect(host.state.startFailed, isTrue);
      });
    });

    test('the host plays a whole game and can play again', () {
      fakeAsync((async) {
        final host = _Harness(async);
        host.game.setVersions(const VersionChoice(live: false));
        host
          ..hostRoom(
            RoomSettings(
              rounds: 5,
              scope: RoomScope.picked(
                eraKeys: const ['lover'],
                releaseIds: const [],
              ),
            ),
          )
          ..start();

        final sent = host.relay.sent;
        final lockAt = sent.indexWhere((message) => message is LockRoom);
        final startingAt = sent.indexWhere(
          (message) =>
              message is SendBody &&
              decodeGameMessage(message.body) is GameStarting,
        );
        expect(lockAt, greaterThanOrEqualTo(0));
        expect(lockAt, lessThan(startingAt));
        expect(
          host.relay.bodies.where((body) => body.to == null).first.message,
          GameStarting(
            settings: RoomSettings(
              rounds: 5,
              scope: RoomScope.picked(
                eraKeys: const ['lover'],
                releaseIds: const [],
              ),
            ),
          ),
        );
        expect(host.states.first.stage, TogetherStage.starting);
        expect(host.states.first.roster, [_sam, _maya, _lee]);
        expect(host.single.versions, VersionChoice.all);

        for (var number = 1; number <= 5; number++) {
          expect(host.state.stage, TogetherStage.countdown);
          expect(host.state.number, number);
          host.playRound(hostRight: true);
          expect(host.state.stage, TogetherStage.reveal);
          switch (number) {
            case 1:
              final counted = [host.state.revealLeft];
              for (var second = 1; second < revealSeconds; second++) {
                async.elapse(const Duration(seconds: 1));
                counted.add(host.state.revealLeft);
              }
              expect(counted, [6, 5, 4, 3, 2, 1]);
              expect(host.state.stage, TogetherStage.reveal);
              async.elapse(const Duration(seconds: 1));
            case 2:
              host.together.nextNow();
              async.flushMicrotasks();
              expect(host.state.stage, TogetherStage.countdown);
              expect(host.state.number, 3);
            case _:
              async.elapse(const Duration(seconds: revealSeconds));
          }
        }

        final rounds = host.rounds;
        expect([for (final round in rounds) round.number], [1, 2, 3, 4, 5]);
        expect({for (final round in rounds) round.track.id}, hasLength(5));
        expect({
          for (final round in rounds) songKey(round.track),
        }, hasLength(5));
        expect({
          for (final round in rounds) round.track.id,
        }, everyElement(isIn(_loverSongs.keys)));
        expect(rounds.every((round) => round.total == 5), isTrue);
        expect(rounds.every((round) => round.options.length == 4), isTrue);
        expect(rounds.every((round) => round.clipStart == _smartStart), isTrue);

        expect(host.state.stage, TogetherStage.ended);
        final ended = host.relay.bodies.last.message as GameEnded;
        expect(host.state.standings, ended.standings);
        expect(
          [for (final score in ended.standings) (score.id, score.score)],
          [(_sam.id, 1000), (_maya.id, 950), (_lee.id, 0)],
        );

        host.together.playAgain();
        expect(host.relay.bodies.last, (
          to: null,
          message: const BackToLobby(),
        ));
        expect(host.relay.sent.last, const UnlockRoom());
        expect(host.state, TogetherGameState.initial);
        expect(host.container.read(roomControllerProvider).code, 'BCDF');
        expect(host.relay.connections, 1);

        host.start();
        expect(host.state.standings, [
          for (final player in [_sam, _maya, _lee])
            PlayerScore.start(player.id),
        ]);
      });
    });

    test(
      'a guest follows the host from starting to the end and back to the lobby',
      () {
        fakeAsync((async) {
          final guest = _Harness(async, nickname: 'Maya')..joinRoom();
          final phase = guest.single.phase;
          guest.fromHost(
            const SettingsChanged(
              settings: RoomSettings(mode: TogetherMode.lyricsOrLie, rounds: 5),
              scopeLabel: 'Shuffle everything',
            ),
          );

          guest.fromHost(
            const GameStarting(
              settings: RoomSettings(mode: TogetherMode.lyricsOrLie, rounds: 5),
            ),
          );
          expect(guest.state.stage, TogetherStage.starting);
          expect(guest.state.mode, TogetherMode.lyricsOrLie);
          expect(guest.state.total, 5);
          expect(guest.state.roster, [_sam, _maya]);
          expect(guest.state.standings, [
            PlayerScore.start(_sam.id),
            PlayerScore.start(_maya.id),
          ]);

          guest.fromHost(
            RoundStart(
              number: 1,
              total: 5,
              track: _track(204),
              lines: const ['Verse line 3 from record 201 keeps going'],
            ),
          );
          expect(guest.state.stage, TogetherStage.countdown);
          expect(guest.state.count, 3);
          guest.countdown();
          expect(guest.state.stage, TogetherStage.round);
          expect(guest.engine.loaded, isEmpty);
          async.elapse(const Duration(milliseconds: 1500));
          guest.together.answer(real: true);
          guest.together.answer(real: false);
          expect(guest.state.myRealPick, isTrue);
          expect(guest.state.myStatus, AnswerStatus.answered);
          expect(guest.relay.bodies.last, (
            to: null,
            message: const AnswerSent(
              number: 1,
              trackId: null,
              real: true,
              at: 1.5,
            ),
          ));

          guest.fromHost(
            StatusChanged(
              number: 1,
              playerId: _sam.id,
              status: AnswerStatus.answered,
            ),
          );
          expect(guest.state.statuses, {
            _maya.id: AnswerStatus.answered,
            _sam.id: AnswerStatus.answered,
          });

          final afterRound = [
            const PlayerScore.start('host1').copyWith(
              score: 100,
              streak: 1,
              best: 1,
              wins: 1,
              fastest: const FastestAnswer(seconds: 2, song: 'Karma'),
            ),
            PlayerScore.start(_maya.id),
          ];
          guest.fromHost(
            RoundRevealed(
              number: 1,
              answerTrackId: null,
              isReal: false,
              sourceSong: 'Anti-Hero',
              winnerId: null,
              results: [
                RoundResult(
                  playerId: _maya.id,
                  pickTrackId: null,
                  pickReal: true,
                  right: false,
                  at: 1.5,
                  gain: 0,
                ),
                RoundResult(
                  playerId: _sam.id,
                  pickTrackId: null,
                  pickReal: false,
                  right: true,
                  at: 2,
                  gain: 100,
                ),
              ],
              standings: afterRound,
            ),
          );
          expect(guest.state.stage, TogetherStage.reveal);
          expect(guest.state.isReal, isFalse);
          expect(guest.state.sourceSong, 'Anti-Hero');
          expect(guest.state.results[_sam.id]?.gain, 100);
          expect(guest.state.standings, afterRound);
          expect(guest.state.revealLeft, revealSeconds);
          async.elapse(const Duration(seconds: revealSeconds));
          expect(guest.state.revealLeft, 0);
          expect(guest.state.stage, TogetherStage.reveal);

          guest.fromHost(GameEnded(standings: afterRound));
          expect(guest.state.stage, TogetherStage.ended);
          expect(guest.state.standings, afterRound);

          guest.fromHost(const BackToLobby());
          expect(guest.state, TogetherGameState.initial);
          expect(guest.single.phase, phase);
          expect(guest.phases, isEmpty);
        });
      },
    );

    test("guests play the host's clip start", () {
      fakeAsync((async) {
        final guest = _Harness(async, nickname: 'Maya')..joinRoom();
        final options = [
          for (final id in [101, 102, 103, 104]) _track(id),
        ];
        guest
          ..fromHost(const GameStarting(settings: RoomSettings()))
          ..fromHost(
            RoundStart(
              number: 1,
              total: 2,
              track: _track(101),
              options: options,
              clipStart: 12.5,
            ),
          );
        expect(guest.state.stage, TogetherStage.countdown);
        expect(guest.engine.loaded.single.bytes, _bytesOf(101));
        expect(guest.engine.slices, isEmpty);

        guest.countdown();
        expect(guest.state.stage, TogetherStage.round);
        expect(guest.engine.slices.single.offset, 12.5);
        expect(guest.engine.slices.single.clip, guest.engine.loaded.single);

        guest.fromHost(
          RoundRevealed(
            number: 1,
            answerTrackId: 101,
            isReal: null,
            sourceSong: null,
            winnerId: null,
            results: const [],
            standings: [
              PlayerScore.start(_sam.id),
              PlayerScore.start(_maya.id),
            ],
          ),
        );
        expect(guest.state.stage, TogetherStage.reveal);
        expect(guest.container.read(audioControllerProvider).playing, isFalse);

        guest
          ..hold(102)
          ..fromHost(
            RoundStart(
              number: 2,
              total: 2,
              track: _track(102),
              options: options,
              clipStart: 7.5,
            ),
          )
          ..countdown();
        expect(guest.state.stage, TogetherStage.loading);
        expect(guest.engine.slices, hasLength(1));
        guest.release(102);
        expect(guest.state.stage, TogetherStage.round);
        expect(guest.engine.slices.last.offset, 7.5);
        expect(guest.engine.loaded.last.bytes, _bytesOf(102));

        expect(
          guest.engine.loaded.map((clip) => clip.sampleReads),
          everyElement(0),
        );
        expect(guest.zones.calls, isEmpty);
      });
    });

    test('a guest plays the mode and rounds the start message carries', () {
      fakeAsync((async) {
        final guest = _Harness(async, nickname: 'Maya')..joinRoom();
        expect(
          guest.container.read(roomControllerProvider).settings,
          const RoomSettings(),
        );

        guest.fromHost(
          const GameStarting(
            settings: RoomSettings(
              mode: TogetherMode.lyricsOrLie,
              rounds: 5,
              difficulty: Difficulty.hard,
            ),
          ),
        );

        expect(guest.state.stage, TogetherStage.starting);
        expect(guest.state.mode, TogetherMode.lyricsOrLie);
        expect(guest.state.total, 5);
        expect(guest.state.difficulty, Difficulty.hard);
      });
    });

    test("an answer the host never counted is not shown as the guest's", () {
      fakeAsync((async) {
        final guest = _Harness(async, nickname: 'Maya')..joinRoom();
        guest
          ..fromHost(const GameStarting(settings: RoomSettings()))
          ..fromHost(
            RoundStart(
              number: 1,
              total: 2,
              track: _track(101),
              options: [
                for (final id in [101, 102, 103, 104]) _track(id),
              ],
              clipStart: 3,
            ),
          )
          ..countdown();
        guest.together.answer(trackId: 101);
        async.flushMicrotasks();
        expect(guest.state.statuses[_maya.id], AnswerStatus.answered);

        guest.fromHost(
          RoundRevealed(
            number: 1,
            answerTrackId: 101,
            isReal: null,
            sourceSong: null,
            winnerId: null,
            results: const [],
            standings: [
              PlayerScore.start(_sam.id),
              PlayerScore.start(_maya.id),
            ],
          ),
        );

        expect(guest.state.stage, TogetherStage.reveal);
        expect(guest.state.statuses.containsKey(_maya.id), isFalse);
      });
    });

    test('listen again replays the clip once it has ended', () {
      fakeAsync((async) {
        final guest = _Harness(async, nickname: 'Maya')..joinRoom();
        final options = [
          for (final id in [101, 102, 103, 104]) _track(id),
        ];
        guest
          ..fromHost(const GameStarting(settings: RoomSettings()))
          ..fromHost(
            RoundStart(
              number: 1,
              total: 2,
              track: _track(101),
              options: options,
              clipStart: 3,
            ),
          )
          ..countdown();
        expect(guest.engine.slices, hasLength(1));

        guest.engine.finished = [guest.engine.slices.single.voice];
        async.elapse(const Duration(seconds: 1));
        expect(guest.container.read(audioControllerProvider).playing, isFalse);

        guest.together.togglePause();
        async.flushMicrotasks();
        expect(guest.engine.slices, hasLength(2));
        expect(guest.container.read(gameControllerProvider).relistenCount, 1);

        guest.fromHost(
          RoundRevealed(
            number: 1,
            answerTrackId: 101,
            isReal: null,
            sourceSong: null,
            winnerId: null,
            results: const [],
            standings: [
              PlayerScore.start(_sam.id),
              PlayerScore.start(_maya.id),
            ],
          ),
        );
        guest.fromHost(
          RoundStart(
            number: 2,
            total: 2,
            track: _track(102),
            options: options,
            clipStart: 4,
          ),
        );
        expect(guest.container.read(gameControllerProvider).relistenCount, 0);
      });
    });

    test("a guest's late clip for an ended round never plays", () {
      fakeAsync((async) {
        final guest = _Harness(async, nickname: 'Maya')..joinRoom();
        final options = [
          for (final id in [101, 102, 103, 104]) _track(id),
        ];
        guest
          ..fromHost(const GameStarting(settings: RoomSettings()))
          ..hold(101)
          ..fromHost(
            RoundStart(
              number: 1,
              total: 2,
              track: _track(101),
              options: options,
              clipStart: 3,
            ),
          )
          ..countdown();
        expect(guest.state.stage, TogetherStage.loading);

        guest.fromHost(
          RoundRevealed(
            number: 1,
            answerTrackId: 101,
            isReal: null,
            sourceSong: null,
            winnerId: null,
            results: const [],
            standings: [
              PlayerScore.start(_sam.id),
              PlayerScore.start(_maya.id),
            ],
          ),
        );
        guest.release(101);
        expect(guest.engine.slices, isEmpty);

        guest
          ..fromHost(
            RoundStart(
              number: 2,
              total: 2,
              track: _track(102),
              options: options,
              clipStart: 4,
            ),
          )
          ..countdown();
        expect(guest.engine.slices.single.offset, 4);
        expect(guest.engine.slices.single.clip, guest.engine.loaded.last);
        expect(
          guest.engine.unloaded.whereType<_FakeClip>().map(
            (clip) => clip.bytes,
          ),
          anyElement(_bytesOf(101)),
        );
      });
    });

    test('a whole game leaves progress and play history untouched', () async {
      late _Harness host;
      late GameProgress progress;
      late PlayHistory history;
      fakeAsync((async) {
        host = _Harness(async);
        host.container.read(playHistoryProvider.notifier)
          ..heard(_track(201))
          ..read(_track(202), const ['A line read earlier']);
        host.game
          ..setProgress(
            host.single.progress.copyWith(
              stats: host.single.progress.stats.copyWith(
                totalCorrect: 7,
                lyricsOrLieCorrect: 2,
              ),
            ),
          )
          ..setMode(GameMode.tonight)
          ..setDifficulty(Difficulty.hard)
          ..setVersions(const VersionChoice(live: false));
        progress = host.single.progress;
        history = host.container.read(playHistoryProvider);

        host
          ..hostRoom(const RoomSettings(rounds: 5))
          ..start();
        for (var number = 1; number <= 5; number++) {
          host.playRound(hostRight: number.isOdd);
          async.elapse(const Duration(seconds: revealSeconds));
        }
        expect(host.state.stage, TogetherStage.ended);
        expect(host.single.progress, progress);
        expect(host.container.read(playHistoryProvider), history);

        host.together.playAgain();
        host.room.setSettings(
          const RoomSettings(mode: TogetherMode.lyricsOrLie, rounds: 5),
          'Shuffle everything',
        );
        host.start();
        for (var number = 1; number <= 5; number++) {
          host.playLyricsRound(real: number.isEven);
          async.elapse(const Duration(seconds: revealSeconds));
        }
        expect(host.state.stage, TogetherStage.ended);
        expect(host.single.progress, progress);
        expect(host.container.read(playHistoryProvider), history);
      });

      await host.together.leaveTogether();
      expect(host.state, TogetherGameState.initial);
      expect(host.relay.connected, isFalse);
      expect(host.single.phase, GamePhase.menu);
      expect(host.single.trackPool, isEmpty);
      expect(host.single.mode, GameMode.tonight);
      expect(host.single.difficulty, Difficulty.hard);
      expect(host.single.versions, const VersionChoice(live: false));
      expect(host.single.progress, progress);
      expect(host.container.read(playHistoryProvider), history);
    });

    test('misu remarks on close finishes and wins unless visits are off', () {
      for (final visits in [MisuVisits.often, MisuVisits.off]) {
        fakeAsync((async) {
          final host = _Harness(async, misuVisits: visits)
            ..hostRoom(const RoomSettings(rounds: 2))
            ..start()
            ..countdown();
          async.elapse(const Duration(seconds: 4));
          host.together.answer(trackId: host.wrongId);
          host
            ..guestAnswers(_maya, trackId: host.rightId, at: 4)
            ..guestAnswers(_lee, trackId: host.rightId, at: 4.3);
          async.elapse(allAnsweredDelay);
          expect(host.state.stage, TogetherStage.reveal);
          async.elapse(const Duration(seconds: revealSeconds));

          host.playRound(hostRight: true, mayaRight: false);
          async.elapse(const Duration(seconds: revealSeconds));
          expect(host.state.stage, TogetherStage.ended);
          expect(
            [for (final score in host.state.standings) score.score],
            [200, 180, 179],
          );

          expect(
            host.visits,
            visits == MisuVisits.off
                ? isEmpty
                : const [
                    MisuVisit(
                      text: '0.3 seconds apart. Misu calls it a tie.',
                      side: MisuSide.right,
                      long: false,
                    ),
                    MisuVisit(
                      text: 'You won, Sam! Misu knew it.',
                      side: MisuSide.right,
                      long: false,
                    ),
                  ],
            reason: visits.name,
          );
        });
      }
    });

    test('a guest who leaves is marked and not waited for', () {
      fakeAsync((async) {
        final host = _Harness(async)
          ..hostRoom(const RoomSettings(rounds: 3))
          ..start()
          ..playRound(hostRight: true, leeRight: true);
        final leeBefore = host.state.standings.firstWhere(
          (score) => score.id == _lee.id,
        );
        expect(leeBefore.score, greaterThan(0));
        async.elapse(const Duration(seconds: revealSeconds));

        host
          ..countdown()
          ..guestAnswers(_maya, trackId: host.rightId, at: 1);
        host.relay.push(PeerLeft(_lee.id));
        async.flushMicrotasks();
        expect(host.state.departed, {_lee.id});
        expect(host.state.stage, TogetherStage.round);
        expect(host.container.read(roomControllerProvider).players, [
          _sam,
          _maya,
        ]);

        host.together.answer(trackId: host.rightId);
        async.elapse(allAnsweredDelay - _instant);
        expect(host.state.stage, TogetherStage.round);
        async.elapse(_instant);
        expect(host.state.stage, TogetherStage.reveal);

        expect(host.state.roster, [_sam, _maya, _lee]);
        final lee = host.state.roster.firstWhere(
          (player) => player.id == _lee.id,
        );
        expect(lee.name, 'Lee');
        expect(lee.avatar, 'seedLee');
        final leeAfter = host.state.standings.firstWhere(
          (score) => score.id == _lee.id,
        );
        expect(leeAfter, leeBefore.copyWith(left: true));
        expect(
          host.revealed.standings.firstWhere((score) => score.id == _lee.id),
          leeAfter,
        );
        expect(
          host.revealed.results.map((result) => result.playerId),
          isNot(contains(_lee.id)),
        );
      });

      fakeAsync((async) {
        final quick = _Harness(async)
          ..hostRoom(
            const RoomSettings(mode: TogetherMode.quickDraw, rounds: 1),
          )
          ..start()
          ..countdown();
        quick.guestAnswers(_lee, trackId: quick.rightId, at: 0.5);
        expect(quick.state.statuses[_lee.id], AnswerStatus.answered);
        quick.relay.push(PeerLeft(_lee.id));
        async
          ..flushMicrotasks()
          ..elapse(quickDrawWindow);
        expect(quick.state.stage, TogetherStage.round);
        quick.guestAnswers(_maya, trackId: quick.rightId, at: 1.2);
        async.elapse(quickDrawWindow - _instant);
        expect(quick.state.stage, TogetherStage.round);
        async.elapse(_instant);
        expect(quick.state.stage, TogetherStage.reveal);
        expect(quick.state.winnerId, _maya.id);
      });
    });
  });
}
