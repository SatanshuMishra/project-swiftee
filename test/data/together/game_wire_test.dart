import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/together/game_wire.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/together/game_messages.dart';
import 'package:swiftie_quiz/domain/together/room_settings.dart';
import 'package:swiftie_quiz/domain/together/scoring.dart';
import 'package:swiftie_quiz/domain/together/standings.dart';

const taylor = Artist(id: 12246, name: 'Taylor Swift');

const enchanted = Track(
  id: 1109731832,
  title: "Enchanted (Taylor's Version)",
  titleShort: 'Enchanted',
  duration: 353,
  preview: 'https://cdnt-preview.dzcdn.net/api/1/1/enchanted.mp3',
  artist: taylor,
  album: Album(
    id: 422346587,
    title: "Speak Now (Taylor's Version)",
    coverMedium: 'https://e-cdns-images.dzcdn.net/images/cover/sn/250x250.jpg',
  ),
  trackPosition: 9,
  eraKey: 'speak-now',
);

const mine = Track(
  id: 7,
  title: 'Mine',
  titleShort: 'Mine',
  duration: 231,
  preview: 'https://cdnt-preview.dzcdn.net/api/1/1/mine.mp3',
  artist: taylor,
  album: Album(id: 11, title: 'Speak Now', coverMedium: null),
);

const style = Track(
  id: 8,
  title: 'Style',
  titleShort: 'Style',
  duration: 231,
  preview: 'https://cdnt-preview.dzcdn.net/api/1/1/style.mp3',
  artist: taylor,
  album: Album(id: 12, title: '1989', coverMedium: null),
  trackPosition: 3,
);

const willow = Track(
  id: 9,
  title: 'willow',
  titleShort: 'willow',
  duration: 214,
  preview: 'https://cdnt-preview.dzcdn.net/api/1/1/willow.mp3',
  artist: taylor,
  album: Album(id: 13, title: 'evermore', coverMedium: null),
  eraKey: 'evermore',
);

const standings = [
  PlayerScore(
    id: 'p-host',
    score: 366,
    streak: 2,
    best: 2,
    wins: 2,
    fastest: FastestAnswer(seconds: 2.6, song: 'Mine'),
    left: false,
  ),
  PlayerScore(
    id: 'p-guest',
    score: 100,
    streak: 0,
    best: 1,
    wins: 1,
    fastest: null,
    left: true,
  ),
];

List<GameMessage> everyMessage() => [
  SettingsChanged(
    settings: RoomSettings(
      mode: TogetherMode.quickDraw,
      rounds: 15,
      difficulty: Difficulty.hard,
      scope: RoomScope.picked(
        eraKeys: const ['speak-now', 'evermore'],
        releaseIds: const [422346587, 13],
      ),
      versions: const VersionChoice(
        live: false,
        rerecorded: Rerecorded.taylorsVersion,
      ),
    ),
    scopeLabel: '2 eras · 26 tracks',
  ),
  const SettingsChanged(
    settings: RoomSettings(),
    scopeLabel: 'Shuffle everything',
  ),
  const GameStarting(
    settings: RoomSettings(
      mode: TogetherMode.quickDraw,
      rounds: 15,
      difficulty: Difficulty.easy,
    ),
  ),
  RoundStart(
    number: 3,
    total: 10,
    track: enchanted,
    options: const [mine, enchanted, style, willow],
    clipStart: 12.5,
  ),
  RoundStart(
    number: 4,
    total: 10,
    track: style,
    lines: const ['We’re dancing in the kitchen light', 'Say it again…'],
  ),
  const AnswerSent(number: 3, trackId: 1109731832, real: null, at: 4.25),
  const AnswerSent(number: 4, trackId: null, real: false, at: 0),
  const StatusChanged(number: 3, playerId: 'p-guest', status: AnswerStatus.out),
  const StatusChanged(
    number: 3,
    playerId: 'p-host',
    status: AnswerStatus.answered,
  ),
  RoundRevealed(
    number: 3,
    answerTrackId: 1109731832,
    isReal: null,
    sourceSong: null,
    winnerId: 'p-host',
    results: const [
      RoundResult(
        playerId: 'p-host',
        pickTrackId: 1109731832,
        pickReal: null,
        right: true,
        at: 2.6,
        gain: 100,
      ),
      RoundResult(
        playerId: 'p-guest',
        pickTrackId: null,
        pickReal: null,
        right: false,
        at: null,
        gain: 0,
      ),
    ],
    standings: standings,
  ),
  RoundRevealed(
    number: 4,
    answerTrackId: null,
    isReal: false,
    sourceSong: 'Blank Space',
    winnerId: null,
    results: const [
      RoundResult(
        playerId: 'p-host',
        pickTrackId: null,
        pickReal: false,
        right: true,
        at: 3,
        gain: 100,
      ),
    ],
    standings: standings,
  ),
  GameEnded(standings: standings),
  const BackToLobby(),
];

Map<String, Object?> throughJson(Map<String, Object?> body) =>
    jsonDecode(jsonEncode(body)) as Map<String, Object?>;

Map<String, Object?> replaced(
  Map<String, Object?> body,
  String key,
  Object? value,
) => {...body, key: value};

Map<String, Object?> without(Map<String, Object?> body, String key) => {
  for (final entry in body.entries)
    if (entry.key != key) entry.key: entry.value,
};

Map<String, Object?> encodeScore(PlayerScore score) =>
    (encodeGameMessage(GameEnded(standings: [score]))['standings']!
                as List<Object?>)
            .single!
        as Map<String, Object?>;

void main() {
  test(
    'every game message survives a round trip and malformed bodies are refused',
    () {
      final messages = everyMessage();
      for (final message in messages) {
        final body = encodeGameMessage(message);
        expect(decodeGameMessage(body), message, reason: '$message');
        expect(
          decodeGameMessage(throughJson(body)),
          message,
          reason: '$message through JSON',
        );
      }
      expect(
        {for (final message in messages) encodeGameMessage(message)['k']},
        {
          'settings',
          'starting',
          'round',
          'answer',
          'status',
          'reveal',
          'end',
          'lobby',
        },
      );

      final round = encodeGameMessage(
        RoundStart(
          number: 1,
          total: 5,
          track: mine,
          options: const [mine, style, willow, enchanted],
          clipStart: 8,
        ),
      );
      expect(round['track'], {
        'id': 7,
        'title': 'Mine',
        'titleShort': 'Mine',
        'duration': 231,
        'preview': 'https://cdnt-preview.dzcdn.net/api/1/1/mine.mp3',
        'artist': {'id': 12246, 'name': 'Taylor Swift'},
        'album': {'id': 11, 'title': 'Speak Now', 'coverMedium': null},
        'trackPosition': null,
        'eraKey': null,
      });
      expect(
        (decodeGameMessage(throughJson(round)) as RoundStart).options.last,
        enchanted,
      );

      final answer = encodeGameMessage(
        const AnswerSent(number: 2, trackId: 7, real: null, at: 1.5),
      );
      final track = round['track']! as Map<String, Object?>;
      final reveal = encodeGameMessage(
        messages.whereType<RoundRevealed>().first,
      );
      final settings = encodeGameMessage(
        messages.whereType<SettingsChanged>().first,
      );
      final malformed = <Map<String, Object?>>[
        {'k': 'shrug'},
        {'k': 7},
        without(answer, 'k'),
        without(answer, 'number'),
        replaced(answer, 'number', '2'),
        replaced(answer, 'number', 2.5),
        replaced(answer, 'trackId', '7'),
        replaced(answer, 'at', '1.5'),
        without(round, 'number'),
        replaced(round, 'total', '5'),
        replaced(round, 'options', 'mine'),
        replaced(round, 'lines', [1, 2]),
        replaced(round, 'track', replaced(track, 'id', '7')),
        replaced(round, 'track', without(track, 'eraKey')),
        replaced(round, 'track', replaced(track, 'artist', {'id': 12246})),
        replaced(
          encodeGameMessage(messages.whereType<StatusChanged>().first),
          'status',
          'asleep',
        ),
        replaced(reveal, 'results', ['p-host']),
        replaced(reveal, 'standings', [
          replaced(encodeScore(standings.first), 'score', '366'),
        ]),
        replaced(
          settings,
          'settings',
          replaced(
            settings['settings']! as Map<String, Object?>,
            'mode',
            'battle-royale',
          ),
        ),
        replaced(
          settings,
          'settings',
          replaced(
            settings['settings']! as Map<String, Object?>,
            'releaseIds',
            ['13'],
          ),
        ),
        replaced(
          settings,
          'settings',
          without(settings['settings']! as Map<String, Object?>, 'versions'),
        ),
        replaced(
          settings,
          'settings',
          replaced(
            settings['settings']! as Map<String, Object?>,
            'versions',
            replaced(
              (settings['settings']! as Map<String, Object?>)['versions']!
                  as Map<String, Object?>,
              'rerecorded',
              'remastered',
            ),
          ),
        ),
        replaced(
          settings,
          'settings',
          replaced(
            settings['settings']! as Map<String, Object?>,
            'versions',
            replaced(
              (settings['settings']! as Map<String, Object?>)['versions']!
                  as Map<String, Object?>,
              'live',
              'no',
            ),
          ),
        ),
        replaced(settings, 'settings', null),
      ];
      for (final body in malformed) {
        expect(
          () => decodeGameMessage(body),
          throwsFormatException,
          reason: '$body',
        );
      }
    },
  );
}
