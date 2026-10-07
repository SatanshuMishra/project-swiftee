import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/game_engine.dart';
import 'package:swiftie_quiz/domain/engine/lyric_processor.dart';
import 'package:swiftie_quiz/domain/engine/option_generator.dart';
import 'package:swiftie_quiz/domain/engine/play_order.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/together/game_messages.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/domain/together/scoring.dart';
import 'package:swiftie_quiz/domain/together/standings.dart';
import 'package:swiftie_quiz/domain/util/song_title.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/lyrics_controller.dart';
import 'package:swiftie_quiz/state/misu_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/together/room_controller.dart';
import 'package:swiftie_quiz/state/together/room_state.dart';
import 'package:swiftie_quiz/state/together/together_game_state.dart';
import 'package:together_protocol/together_protocol.dart';

const int unplayedLyricsFloor = 3;

const int unplayableRedraws = 3;

const Duration revealStep = Duration(seconds: 1);

typedef _SinglePlayerChoice = ({
  GameMode mode,
  Difficulty difficulty,
  VersionChoice versions,
});

typedef _HostedRound = ({RoundStart start, bool? isReal, String? sourceSong});

typedef _Answer = ({
  int? trackId,
  bool? real,
  bool right,
  double at,
  Duration receivedAt,
});

final togetherGameControllerProvider =
    NotifierProvider<TogetherGameController, TogetherGameState>(
      TogetherGameController.new,
    );

class TogetherGameController extends Notifier<TogetherGameState> {
  int _game = 0;
  int _round = 0;
  Timer? _countdown;
  Timer? _reveal;
  Timer? _timeUp;
  Timer? _allDone;
  Timer? _quickDraw;
  DateTime? _roundStartedAt;
  bool? _clipLoaded;
  double _clipStart = 0;
  _SinglePlayerChoice? _snapshot;
  List<Track> _allTracks = const [];
  List<Track> _pool = const [];
  Set<Track> _played = const {};
  _HostedRound? _hosted;
  Future<_HostedRound?>? _next;
  Map<String, _Answer> _answers = const {};
  int _lastRemarkRound = -closeFinishEvery;

  @override
  TogetherGameState build() {
    final room = ref.read(roomControllerProvider.notifier);
    final messages = room.messages.listen(_receive);
    final presence = room.presence.listen(_presence);
    ref
      ..listen(roomControllerProvider, (_, next) => _roomChanged(next))
      ..onDispose(() {
        _halt();
        unawaited(messages.cancel());
        unawaited(presence.cancel());
      });
    return TogetherGameState.initial;
  }

  Future<void> start() async {
    final room = ref.read(roomControllerProvider);
    if (room.role != RoomRole.host ||
        room.status != RoomStatus.open ||
        room.players.length < 2 ||
        state.stage != TogetherStage.idle) {
      return;
    }
    final roomController = ref.read(roomControllerProvider.notifier)..lock();
    _broadcast(GameStarting(settings: room.settings));
    final game = _game;
    _pointAtRoom(room.settings);
    final ready = await _buildPool(room.settings);
    if (game != _game) {
      return;
    }
    if (!ready) {
      _broadcast(const BackToLobby());
      roomController.unlock();
      state = state.copyWith(startFailed: true);
      return;
    }
    final first = await _prepare(1);
    if (game != _game) {
      return;
    }
    _startOrEnd(first);
  }

  void answer({int? trackId, bool? real}) {
    final track = state.track;
    final you = ref.read(roomControllerProvider).you;
    final picked = state.mode == TogetherMode.lyricsOrLie
        ? real != null
        : trackId != null;
    if (state.stage != TogetherStage.round ||
        state.myStatus != null ||
        track == null ||
        you == null ||
        !picked) {
      return;
    }
    final status = answerStatus(state.mode, right: trackId == track.id);
    state = state.copyWith(
      myTrackPick: trackId,
      myRealPick: real,
      myStatus: status,
      statuses: {...state.statuses, you.id: status},
    );
    final sent = AnswerSent(
      number: state.number,
      trackId: trackId,
      real: real,
      at: _roundElapsed.inMicroseconds / Duration.microsecondsPerSecond,
    );
    if (_isHost) {
      _record(you.id, sent);
    } else {
      ref.read(roomControllerProvider.notifier).sendToHost(sent);
    }
  }

  void togglePause() {
    if (state.stage != TogetherStage.round) {
      return;
    }
    final audio = ref.read(audioControllerProvider);
    final controller = ref.read(audioControllerProvider.notifier);
    if (audio.loading) {
      return;
    }
    if (audio.playing) {
      controller.pause();
    } else if (audio.paused) {
      controller.resume();
    } else if (audio.progress > 0) {
      controller.relisten();
    }
  }

  void nextNow() {
    final reveal = _reveal;
    if (!_isHost || state.stage != TogetherStage.reveal || reveal == null) {
      return;
    }
    reveal.cancel();
    _reveal = null;
    unawaited(_advance());
  }

  void playAgain() {
    if (!_isHost || state.stage != TogetherStage.ended) {
      return;
    }
    _broadcast(const BackToLobby());
    ref.read(roomControllerProvider.notifier).unlock();
  }

  Future<void> leaveTogether() async {
    _halt();
    ref.read(audioControllerProvider.notifier).reset();
    state = TogetherGameState.initial;
    await ref.read(roomControllerProvider.notifier).leave();
    if (!ref.mounted) {
      return;
    }
    final game = ref.read(gameControllerProvider.notifier)..resetGame();
    final snapshot = _snapshot;
    _snapshot = null;
    if (snapshot != null) {
      game
        ..setMode(snapshot.mode)
        ..setDifficulty(snapshot.difficulty)
        ..setVersions(snapshot.versions);
    }
  }

  bool get _isHost => ref.read(roomControllerProvider).role == RoomRole.host;

  Iterable<String> get _activeIds => [
    for (final player in state.roster)
      if (!state.departed.contains(player.id)) player.id,
  ];

  Duration get _roundElapsed {
    final startedAt = _roundStartedAt;
    return startedAt == null
        ? Duration.zero
        : ref.read(clockProvider)().difference(startedAt);
  }

  void _broadcast(GameMessage message) {
    ref.read(roomControllerProvider.notifier).sendToAll(message);
    _apply(message);
  }

  void _receive(RoomMessage received) {
    final room = ref.read(roomControllerProvider);
    switch (received.message) {
      case final AnswerSent sent when room.role == RoomRole.host:
        _record(received.from, sent);
      case AnswerSent() || SettingsChanged():
        break;
      case final message
          when room.role == RoomRole.guest && received.from == room.hostId:
        _apply(message);
      case _:
        break;
    }
  }

  void _apply(GameMessage message) {
    if (state.stage == TogetherStage.lost) {
      return;
    }
    switch (message) {
      case GameStarting(:final settings):
        _starting(settings);
      case final RoundStart start when _inGame:
        _roundStarted(start);
      case StatusChanged(:final number, :final playerId, :final status)
          when number == state.number && _inGame:
        state = state.copyWith(statuses: {...state.statuses, playerId: status});
      case final RoundRevealed revealed when _inRound:
        _revealed(revealed);
      case GameEnded(:final standings) when _inGame:
        _ended(standings);
      case BackToLobby():
        _toLobby();
      case _:
        break;
    }
  }

  bool get _inGame => switch (state.stage) {
    TogetherStage.idle || TogetherStage.ended || TogetherStage.lost => false,
    _ => true,
  };

  bool get _inRound => switch (state.stage) {
    TogetherStage.countdown ||
    TogetherStage.loading ||
    TogetherStage.round => true,
    _ => false,
  };

  void _starting(RoomSettings settings) {
    _halt();
    _lastRemarkRound = -closeFinishEvery;
    final room = ref.read(roomControllerProvider);
    state = TogetherGameState.initial.copyWith(
      stage: TogetherStage.starting,
      total: settings.rounds,
      mode: settings.mode,
      difficulty: settings.difficulty,
      roster: room.players,
      standings: [
        for (final player in room.players) PlayerScore.start(player.id),
      ],
    );
  }

  void _roundStarted(RoundStart start) {
    _cancelTimers();
    ref.read(gameControllerProvider.notifier).resetRelisten();
    final round = ++_round;
    _roundStartedAt = null;
    _clipStart = start.clipStart;
    final sound = state.mode != TogetherMode.lyricsOrLie;
    _clipLoaded = sound && !_isHost ? null : sound;
    if (sound && !_isHost) {
      unawaited(
        ref
            .read(audioControllerProvider.notifier)
            .load(start.track)
            .then((loaded) => _loaded(round, loaded)),
      );
    }
    state = state.copyWith(
      stage: TogetherStage.countdown,
      number: start.number,
      total: start.total,
      track: start.track,
      options: start.options,
      lines: start.lines,
      count: countdownFrom,
      myTrackPick: null,
      myRealPick: null,
      myStatus: null,
      statuses: const {},
      results: const {},
      answerTrackId: null,
      isReal: null,
      sourceSong: null,
      winnerId: null,
      revealLeft: 0,
    );
    _countdown = Timer.periodic(countdownStep, (timer) {
      final count = state.count - 1;
      if (count > 0) {
        state = state.copyWith(count: count);
        return;
      }
      timer.cancel();
      _countdown = null;
      if (_clipLoaded == null) {
        state = state.copyWith(stage: TogetherStage.loading);
      } else {
        _begin();
      }
    });
  }

  void _loaded(int round, bool loaded) {
    if (round != _round) {
      return;
    }
    _clipLoaded = loaded;
    if (state.stage == TogetherStage.loading) {
      _begin();
    }
  }

  void _begin() {
    if (_clipLoaded ?? false) {
      ref.read(audioControllerProvider.notifier).playLoaded(_clipStart);
    }
    _roundStartedAt = ref.read(clockProvider)();
    state = state.copyWith(stage: TogetherStage.round);
    if (_isHost && _hosted != null) {
      _timeUp = Timer(
        Duration(seconds: roundSeconds(state.difficulty)) + timeUpGrace,
        _endRound,
      );
    }
  }

  void _record(String playerId, AnswerSent sent) {
    final hosted = _hosted;
    if (hosted == null ||
        sent.number != hosted.start.number ||
        _answers.containsKey(playerId) ||
        !_activeIds.contains(playerId)) {
      return;
    }
    final right = state.mode == TogetherMode.lyricsOrLie
        ? sent.real != null && sent.real == hosted.isReal
        : sent.trackId == hosted.start.track.id;
    final receivedAt = _roundElapsed;
    _answers = {
      ..._answers,
      playerId: (
        trackId: sent.trackId,
        real: sent.real,
        right: right,
        at: sent.at,
        receivedAt: receivedAt,
      ),
    };
    _broadcast(
      StatusChanged(
        number: sent.number,
        playerId: playerId,
        status: answerStatus(state.mode, right: right),
      ),
    );
    _checkEnd();
  }

  void _checkEnd() {
    if (_hosted == null) {
      return;
    }
    if (state.mode == TogetherMode.quickDraw) {
      _scheduleQuickDraw();
    }
    if (_allDone == null && everyoneDone(_activeIds, state.statuses)) {
      _allDone = Timer(allAnsweredDelay, _endRound);
    }
  }

  void _scheduleQuickDraw() {
    _quickDraw?.cancel();
    _quickDraw = null;
    final active = _activeIds.toSet();
    final firstRight = [
      for (final MapEntry(key: id, value: answer) in _answers.entries)
        if (answer.right && active.contains(id)) answer.receivedAt,
    ].minOrNull;
    if (firstRight == null) {
      return;
    }
    final left = firstRight + quickDrawWindow - _roundElapsed;
    _quickDraw = Timer(left < Duration.zero ? Duration.zero : left, _endRound);
  }

  void _endRound() {
    final hosted = _hosted;
    if (hosted == null) {
      return;
    }
    _hosted = null;
    _cancelRoundTimers();
    final mode = state.mode;
    final answers = {for (final id in _activeIds) id: ?_answers[id]};
    final winnerId = mode == TogetherMode.quickDraw
        ? quickDrawWinner([
            for (final MapEntry(key: id, value: answer) in answers.entries)
              TimedAnswer(
                playerId: id,
                right: answer.right,
                at: answer.at,
                receivedAt: answer.receivedAt,
              ),
          ])
        : null;
    final results = [
      for (final MapEntry(key: id, value: answer) in answers.entries)
        RoundResult(
          playerId: id,
          pickTrackId: answer.trackId,
          pickReal: answer.real,
          right: answer.right,
          at: answer.at,
          gain: roundGain(
            mode,
            right: answer.right,
            at: answer.at,
            difficulty: state.difficulty,
            won: id == winnerId,
          ),
        ),
    ];
    final track = hosted.start.track;
    _broadcast(
      RoundRevealed(
        number: hosted.start.number,
        answerTrackId: mode == TogetherMode.lyricsOrLie ? null : track.id,
        isReal: hosted.isReal,
        sourceSong: hosted.sourceSong,
        winnerId: winnerId,
        results: results,
        standings: applyRound(
          state.standings,
          results,
          displaySongTitle(track.title),
        ),
      ),
    );
  }

  void _revealed(RoundRevealed revealed) {
    _cancelTimers();
    _round += 1;
    ref.read(audioControllerProvider.notifier).stop();
    state = state.copyWith(
      stage: TogetherStage.reveal,
      statuses: {
        for (final MapEntry(:key, :value) in state.statuses.entries)
          if (revealed.results.any((result) => result.playerId == key))
            key: value,
      },
      results: {for (final result in revealed.results) result.playerId: result},
      answerTrackId: revealed.answerTrackId,
      isReal: revealed.isReal,
      sourceSong: revealed.sourceSong,
      winnerId: revealed.winnerId,
      standings: _marked(revealed.standings),
      revealLeft: revealSeconds,
    );
    _remarkOnFinish(revealed);
    _reveal = Timer.periodic(revealStep, (timer) {
      final left = state.revealLeft - 1;
      state = state.copyWith(revealLeft: left);
      if (left > 0) {
        return;
      }
      timer.cancel();
      _reveal = null;
      if (_isHost) {
        unawaited(_advance());
      }
    });
    if (_isHost && revealed.number < state.total) {
      _next = _prepare(revealed.number + 1);
    }
  }

  void _remarkOnFinish(RoundRevealed revealed) {
    final rightTimes = [
      for (final result in revealed.results)
        if (result case RoundResult(right: true, :final at?)) at,
    ];
    if (!closeFinish(
      mode: state.mode,
      rightTimes: rightTimes,
      round: revealed.number,
      lastRemarkRound: _lastRemarkRound,
    )) {
      return;
    }
    _lastRemarkRound = revealed.number;
    final fastest = rightTimes.sorted((a, b) => a.compareTo(b));
    ref
        .read(misuControllerProvider.notifier)
        .togetherCloseFinish(fastest[1] - fastest[0]);
  }

  Future<void> _advance() async {
    final game = _game;
    final next = _next;
    _next = null;
    if (state.number >= state.total || next == null) {
      _startOrEnd(null);
      return;
    }
    final prepared = await next;
    if (game == _game) {
      _startOrEnd(prepared);
    }
  }

  void _startOrEnd(_HostedRound? round) {
    if (round == null) {
      _broadcast(GameEnded(standings: state.standings));
      return;
    }
    _hosted = round;
    _answers = const {};
    _broadcast(round.start);
  }

  void _ended(List<PlayerScore> standings) {
    _halt();
    ref.read(audioControllerProvider.notifier).reset();
    state = state.copyWith(
      stage: TogetherStage.ended,
      standings: _marked(standings),
      revealLeft: 0,
    );
    final you = ref.read(roomControllerProvider).you;
    if (you == null) {
      return;
    }
    final first = ranked(
      state.standings,
      viewerId: you.id,
      joinOrder: [for (final player in state.roster) player.id],
    ).firstOrNull;
    if (first?.id == you.id) {
      ref.read(misuControllerProvider.notifier).togetherWon();
    }
  }

  void _toLobby() {
    _halt();
    ref.read(audioControllerProvider.notifier).reset();
    state = TogetherGameState.initial;
  }

  void _roomChanged(RoomState room) {
    final lost = switch (room.failure) {
      RoomFailure.hostClosed || RoomFailure.connectionLost => true,
      _ => false,
    };
    if (lost && _inGame) {
      _halt();
      ref.read(audioControllerProvider.notifier).reset();
      state = state.copyWith(stage: TogetherStage.lost);
    }
  }

  void _presence(RelayMessage message) {
    switch (message) {
      case PeerJoined(:final player) when _inGame && !_inRoster(player.id):
        state = state.copyWith(
          roster: [...state.roster, player],
          standings: [...state.standings, PlayerScore.start(player.id)],
        );
      case PeerLeft(:final id)
          when state.stage != TogetherStage.idle && _inRoster(id):
        state = state.copyWith(
          departed: {...state.departed, id},
          standings: [
            for (final score in state.standings)
              score.id == id ? score.copyWith(left: true) : score,
          ],
        );
        if (_isHost) {
          _checkEnd();
        }
      case _:
        break;
    }
  }

  bool _inRoster(String playerId) =>
      state.roster.any((player) => player.id == playerId);

  List<PlayerScore> _marked(List<PlayerScore> standings) => [
    for (final score in standings)
      state.departed.contains(score.id) ? score.copyWith(left: true) : score,
  ];

  void _pointAtRoom(RoomSettings settings) {
    final current = ref.read(gameControllerProvider);
    _snapshot ??= (
      mode: current.mode,
      difficulty: current.difficulty,
      versions: current.versions,
    );
    final game = ref.read(gameControllerProvider.notifier)..clearSelection();
    if (settings.scope.everything) {
      game.setMode(GameMode.random);
    } else {
      game.setMode(GameMode.album);
      for (final eraKey in settings.scope.eraKeys) {
        game.toggleEra(eraKey);
      }
      for (final releaseId in settings.scope.releaseIds) {
        game.toggleRelease(releaseId);
      }
    }
    game
      ..setVersions(settings.versions)
      ..setDifficulty(settings.difficulty);
  }

  Future<bool> _buildPool(RoomSettings settings) async {
    try {
      if (settings.mode == TogetherMode.lyricsOrLie) {
        ref.read(gameControllerProvider.notifier)
          ..setQuizType(QuizType.lyrics)
          ..setLyricsMode(LyricsMode.lyricsOrLie);
        final lyrics = ref.read(lyricsControllerProvider);
        final pool = await lyrics
            .preFetchInitial(await lyrics.loadSourceTracks())
            .timeout(
              lyricsLoadLimit,
              onTimeout: () {
                lyrics.cancelInitial();
                return const [];
              },
            );
        return pool.length >= minLyricsPoolSize;
      }
      final tracks = await ref
          .read(catalogControllerProvider.notifier)
          .loadTrackPool();
      _allTracks = tracks.allTracks;
      _pool = tracks.pool;
      _played = const {};
      return _allTracks.isNotEmpty;
    } on Object {
      return false;
    }
  }

  Future<_HostedRound?> _prepare(int number) async {
    if (state.mode == TogetherMode.lyricsOrLie) {
      return _prepareLyrics(number);
    }
    final game = _game;
    final audio = ref.read(audioControllerProvider.notifier);
    for (var draw = 0; draw <= unplayableRedraws; draw++) {
      final track = _draw();
      final options = generateOptions(
        track,
        _allTracks,
        random: ref.read(randomProvider),
      );
      final clipStart = await audio.prepare(track);
      if (game != _game) {
        return null;
      }
      if (clipStart != null) {
        return (
          start: RoundStart(
            number: number,
            total: state.total,
            track: track,
            options: options,
            clipStart: clipStart,
          ),
          isReal: null,
          sourceSong: null,
        );
      }
    }
    return null;
  }

  Track _draw() {
    final random = ref.read(randomProvider);
    final playedSongs = {for (final track in _played) songKey(track)};
    bool unplayedSong(Track track) => !playedSongs.contains(songKey(track));
    bool unplayedTrack(Track track) => !_played.contains(track);
    final bool Function(Track track)? unplayed = _allTracks.any(unplayedSong)
        ? unplayedSong
        : _allTracks.any(unplayedTrack)
        ? unplayedTrack
        : null;
    var draw = drawNextTrack(_pool, _allTracks, random: random);
    while (unplayed != null && !unplayed(draw.track)) {
      draw = drawNextTrack(draw.remaining, _allTracks, random: random);
    }
    _pool = draw.remaining;
    _played = {..._played, draw.track};
    return draw.track;
  }

  _HostedRound? _prepareLyrics(int number) {
    final entry = ref.read(gameControllerProvider.notifier).nextLyricsTrack();
    if (entry == null) {
      return null;
    }
    final game = ref.read(gameControllerProvider);
    if (game.lyricsPool.length - game.lyricsPoolIndex < unplayedLyricsFloor) {
      unawaited(ref.read(lyricsControllerProvider).extendPool());
    }
    final decoy = selectDecoyOrReal(
      entry.lyrics.lines,
      game.decoyPool,
      state.difficulty,
      currentTrackAlbum: entry.lyrics.sourceAlbum,
      lineCount: lyricsLineCount(LyricsMode.lyricsOrLie, state.difficulty),
      currentTrackTitle: entry.track.title,
      random: ref.read(randomProvider),
    );
    return (
      start: RoundStart(
        number: number,
        total: state.total,
        track: entry.track,
        lines: decoy.lines,
      ),
      isReal: decoy.isReal,
      sourceSong: decoy.sourceSong,
    );
  }

  void _halt() {
    _game += 1;
    _round += 1;
    _cancelTimers();
    _hosted = null;
    _next = null;
    _answers = const {};
    _roundStartedAt = null;
  }

  void _cancelTimers() {
    _countdown?.cancel();
    _countdown = null;
    _reveal?.cancel();
    _reveal = null;
    _cancelRoundTimers();
  }

  void _cancelRoundTimers() {
    _timeUp?.cancel();
    _timeUp = null;
    _allDone?.cancel();
    _allDone = null;
    _quickDraw?.cancel();
    _quickDraw = null;
  }
}
