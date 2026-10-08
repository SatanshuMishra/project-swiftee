import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/together/game_messages.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/domain/together/scoring.dart';
import 'package:swiftie_quiz/domain/together/standings.dart';

Map<String, Object?> encodeGameMessage(GameMessage message) =>
    switch (message) {
      SettingsChanged(:final settings, :final scopeLabel) => {
        'k': 'settings',
        'settings': _encodeSettings(settings),
        'scopeLabel': scopeLabel,
      },
      GameStarting(:final settings) => {
        'k': 'starting',
        'settings': _encodeSettings(settings),
      },
      RoundStart(
        :final number,
        :final total,
        :final track,
        :final options,
        :final clipStart,
        :final lines,
      ) =>
        {
          'k': 'round',
          'number': number,
          'total': total,
          'track': _encodeTrack(track),
          'options': [for (final option in options) _encodeTrack(option)],
          'clipStart': clipStart,
          'lines': [...lines],
        },
      AnswerSent(:final number, :final trackId, :final real, :final at) => {
        'k': 'answer',
        'number': number,
        'trackId': trackId,
        'real': real,
        'at': at,
      },
      StatusChanged(:final number, :final playerId, :final status) => {
        'k': 'status',
        'number': number,
        'playerId': playerId,
        'status': status.name,
      },
      RoundRevealed(
        :final number,
        :final answerTrackId,
        :final isReal,
        :final sourceSong,
        :final winnerId,
        :final results,
        :final standings,
      ) =>
        {
          'k': 'reveal',
          'number': number,
          'answerTrackId': answerTrackId,
          'isReal': isReal,
          'sourceSong': sourceSong,
          'winnerId': winnerId,
          'results': [for (final result in results) _encodeResult(result)],
          'standings': [for (final score in standings) _encodeScore(score)],
        },
      GameEnded(:final standings) => {
        'k': 'end',
        'standings': [for (final score in standings) _encodeScore(score)],
      },
      BackToLobby() => {'k': 'lobby'},
    };

GameMessage decodeGameMessage(Map<String, Object?> body) => switch (body) {
  {
    'k': 'settings',
    'settings': final Object? settings,
    'scopeLabel': final String scopeLabel,
  } =>
    SettingsChanged(
      settings: _decodeSettings(settings),
      scopeLabel: scopeLabel,
    ),
  {'k': 'starting', 'settings': final Object? settings} => GameStarting(
    settings: _decodeSettings(settings),
  ),
  {
    'k': 'round',
    'number': final int number,
    'total': final int total,
    'track': final Object? track,
    'options': final List<Object?> options,
    'clipStart': final num clipStart,
    'lines': final List<Object?> lines,
  } =>
    RoundStart(
      number: number,
      total: total,
      track: _decodeTrack(track),
      options: options.map(_decodeTrack).toList(),
      clipStart: clipStart.toDouble(),
      lines: lines.map(_decodeLine).toList(),
    ),
  {
    'k': 'answer',
    'number': final int number,
    'trackId': final int? trackId,
    'real': final bool? real,
    'at': final num at,
  } =>
    AnswerSent(number: number, trackId: trackId, real: real, at: at.toDouble()),
  {
    'k': 'status',
    'number': final int number,
    'playerId': final String playerId,
    'status': final String status,
  } =>
    StatusChanged(
      number: number,
      playerId: playerId,
      status: _decodeStatus(status),
    ),
  {
    'k': 'reveal',
    'number': final int number,
    'answerTrackId': final int? answerTrackId,
    'isReal': final bool? isReal,
    'sourceSong': final String? sourceSong,
    'winnerId': final String? winnerId,
    'results': final List<Object?> results,
    'standings': final List<Object?> standings,
  } =>
    RoundRevealed(
      number: number,
      answerTrackId: answerTrackId,
      isReal: isReal,
      sourceSong: sourceSong,
      winnerId: winnerId,
      results: results.map(_decodeResult).toList(),
      standings: standings.map(_decodeScore).toList(),
    ),
  {'k': 'end', 'standings': final List<Object?> standings} => GameEnded(
    standings: standings.map(_decodeScore).toList(),
  ),
  {'k': 'lobby'} => const BackToLobby(),
  _ => throw const FormatException('invalid game message'),
};

Map<String, Object?> _encodeSettings(RoomSettings settings) => {
  'mode': settings.mode.wireName,
  'rounds': settings.rounds,
  'difficulty': settings.difficulty.wireName,
  'eraKeys': [...settings.scope.eraKeys],
  'releaseIds': [...settings.scope.releaseIds],
  'versions': {
    'studio': settings.versions.studio,
    'live': settings.versions.live,
    'alternate': settings.versions.alternate,
    'rerecorded': settings.versions.rerecorded.name,
  },
};

RoomSettings _decodeSettings(Object? json) => switch (json) {
  {
    'mode': final String mode,
    'rounds': final int rounds,
    'difficulty': final String difficulty,
    'eraKeys': final List<Object?> eraKeys,
    'releaseIds': final List<Object?> releaseIds,
    'versions': final Object? versions,
  } =>
    RoomSettings(
      mode:
          TogetherMode.fromWireName(mode) ??
          (throw const FormatException('invalid room mode')),
      rounds: rounds,
      difficulty:
          Difficulty.fromWireName(difficulty) ??
          (throw const FormatException('invalid room difficulty')),
      scope: RoomScope.picked(
        eraKeys: eraKeys.map(_decodeEraKey).toList(),
        releaseIds: releaseIds.map(_decodeReleaseId).toList(),
      ),
      versions: _decodeVersions(versions),
    ),
  _ => throw const FormatException('invalid room settings'),
};

VersionChoice _decodeVersions(Object? json) => switch (json) {
  {
    'studio': final bool studio,
    'live': final bool live,
    'alternate': final bool alternate,
    'rerecorded': final String rerecorded,
  } =>
    VersionChoice(
      studio: studio,
      live: live,
      alternate: alternate,
      rerecorded:
          Rerecorded.values.asNameMap()[rerecorded] ??
          (throw const FormatException('invalid recording choice')),
    ),
  _ => throw const FormatException('invalid version choice'),
};

String _decodeEraKey(Object? json) => switch (json) {
  final String key => key,
  _ => throw const FormatException('invalid era key'),
};

int _decodeReleaseId(Object? json) => switch (json) {
  final int id => id,
  _ => throw const FormatException('invalid release id'),
};

String _decodeLine(Object? json) => switch (json) {
  final String line => line,
  _ => throw const FormatException('invalid lyric line'),
};

AnswerStatus _decodeStatus(String name) =>
    AnswerStatus.values.asNameMap()[name] ??
    (throw const FormatException('invalid answer status'));

Map<String, Object?> _encodeTrack(Track track) => {
  'id': track.id,
  'title': track.title,
  'titleShort': track.titleShort,
  'duration': track.duration,
  'preview': track.preview,
  'artist': {'id': track.artist.id, 'name': track.artist.name},
  'album': {
    'id': track.album.id,
    'title': track.album.title,
    'coverMedium': track.album.coverMedium,
  },
  'trackPosition': track.trackPosition,
  'eraKey': track.eraKey,
};

Track _decodeTrack(Object? json) => switch (json) {
  {
    'id': final int id,
    'title': final String title,
    'titleShort': final String titleShort,
    'duration': final int duration,
    'preview': final String preview,
    'artist': {'id': final int artistId, 'name': final String artistName},
    'album': {
      'id': final int albumId,
      'title': final String albumTitle,
      'coverMedium': final String? coverMedium,
    },
    'trackPosition': final int? trackPosition,
    'eraKey': final String? eraKey,
  } =>
    Track(
      id: id,
      title: title,
      titleShort: titleShort,
      duration: duration,
      preview: preview,
      artist: Artist(id: artistId, name: artistName),
      album: Album(id: albumId, title: albumTitle, coverMedium: coverMedium),
      trackPosition: trackPosition,
      eraKey: eraKey,
    ),
  _ => throw const FormatException('invalid track'),
};

Map<String, Object?> _encodeResult(RoundResult result) => {
  'playerId': result.playerId,
  'pickTrackId': result.pickTrackId,
  'pickReal': result.pickReal,
  'right': result.right,
  'at': result.at,
  'gain': result.gain,
};

RoundResult _decodeResult(Object? json) => switch (json) {
  {
    'playerId': final String playerId,
    'pickTrackId': final int? pickTrackId,
    'pickReal': final bool? pickReal,
    'right': final bool right,
    'at': final num? at,
    'gain': final int gain,
  } =>
    RoundResult(
      playerId: playerId,
      pickTrackId: pickTrackId,
      pickReal: pickReal,
      right: right,
      at: at?.toDouble(),
      gain: gain,
    ),
  _ => throw const FormatException('invalid round result'),
};

Map<String, Object?> _encodeScore(PlayerScore score) => {
  'id': score.id,
  'score': score.score,
  'streak': score.streak,
  'best': score.best,
  'wins': score.wins,
  'fastest': switch (score.fastest) {
    final fastest? => {'seconds': fastest.seconds, 'song': fastest.song},
    null => null,
  },
  'left': score.left,
};

PlayerScore _decodeScore(Object? json) => switch (json) {
  {
    'id': final String id,
    'score': final int score,
    'streak': final int streak,
    'best': final int best,
    'wins': final int wins,
    'fastest': final Object? fastest,
    'left': final bool left,
  } =>
    PlayerScore(
      id: id,
      score: score,
      streak: streak,
      best: best,
      wins: wins,
      fastest: _decodeFastest(fastest),
      left: left,
    ),
  _ => throw const FormatException('invalid player score'),
};

FastestAnswer? _decodeFastest(Object? json) => switch (json) {
  null => null,
  {'seconds': final num seconds, 'song': final String song} => FastestAnswer(
    seconds: seconds.toDouble(),
    song: song,
  ),
  _ => throw const FormatException('invalid fastest answer'),
};
