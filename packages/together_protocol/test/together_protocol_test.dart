import 'dart:convert';

import 'package:test/test.dart';
import 'package:together_protocol/together_protocol.dart';

void main() {
  test('every message survives a round trip through JSON', () {
    const maya = Player(id: 'h0st', name: 'Maya', avatar: 'q3k9z1');
    const ana = Player(id: 'Guest2', name: 'Ana', avatar: 'a1b2c3');
    const mayaJson = {'id': 'h0st', 'name': 'Maya', 'avatar': 'q3k9z1'};
    const anaJson = {'id': 'Guest2', 'name': 'Ana', 'avatar': 'a1b2c3'};
    final body = <String, Object?>{
      'k': 'round',
      'number': 3,
      'clipStart': 12.5,
      'options': ['Style', 'Clean', null],
      'track': {
        'id': 42,
        'explicit': false,
        'album': {'title': '1989'},
      },
    };
    final clientCases = <(ClientMessage, Map<String, Object?>)>[
      (
        const OpenRoom(name: 'Maya', game: 1),
        {'t': 'open', 'name': 'Maya', 'game': 1},
      ),
      (
        const JoinRoom(code: 'ABCD', name: 'Ana', game: 2),
        {'t': 'join', 'code': 'ABCD', 'name': 'Ana', 'game': 2},
      ),
      (SendBody(body: body), {'t': 'send', 'to': null, 'body': body}),
      (
        SendBody(body: body, to: 'Guest2'),
        {'t': 'send', 'to': 'Guest2', 'body': body},
      ),
      (const LockRoom(), {'t': 'lock'}),
      (const UnlockRoom(), {'t': 'unlock'}),
    ];
    final relayCases = <(RelayMessage, Map<String, Object?>)>[
      (
        const RoomOpened(code: 'WXYZ', you: maya),
        {'t': 'opened', 'code': 'WXYZ', 'you': mayaJson},
      ),
      (
        RoomJoined(
          code: 'WXYZ',
          you: ana,
          hostId: 'h0st',
          players: [maya, ana],
        ),
        {
          't': 'joined',
          'code': 'WXYZ',
          'you': anaJson,
          'host': 'h0st',
          'players': [mayaJson, anaJson],
        },
      ),
      (const PeerJoined(ana), {'t': 'peer-joined', 'player': anaJson}),
      (const PeerLeft('Guest2'), {'t': 'peer-left', 'id': 'Guest2'}),
      (
        Relayed(from: 'Guest2', body: body),
        {'t': 'msg', 'from': 'Guest2', 'body': body},
      ),
      (const RoomClosed(), {'t': 'closed'}),
      for (final (reason, wireName) in [
        (RelayErrorReason.notFound, 'not-found'),
        (RelayErrorReason.full, 'full'),
        (RelayErrorReason.inGame, 'in-game'),
        (RelayErrorReason.gameMismatch, 'game-mismatch'),
        (RelayErrorReason.notHost, 'not-host'),
        (RelayErrorReason.badRequest, 'bad-request'),
        (RelayErrorReason.alreadyInRoom, 'already-in-room'),
      ])
        (RelayError(reason), {'t': 'error', 'reason': wireName}),
    ];

    for (final (message, json) in clientCases) {
      final text = message.encode();
      expect(jsonDecode(text), json, reason: text);
      final decoded = ClientMessage.decode(text);
      expect(decoded, message, reason: text);
      expect(decoded.hashCode, message.hashCode, reason: text);
      expect(ClientMessage.decode(jsonEncode(json)), message, reason: text);
    }
    for (final (message, json) in relayCases) {
      final text = message.encode();
      expect(jsonDecode(text), json, reason: text);
      final decoded = RelayMessage.decode(text);
      expect(decoded, message, reason: text);
      expect(decoded.hashCode, message.hashCode, reason: text);
      expect(RelayMessage.decode(jsonEncode(json)), message, reason: text);
    }
  });

  test('decoding rejects unknown types, missing fields and wrong types', () {
    const you = '{"id":"h0st","name":"Maya","avatar":"q3k9z1"}';
    final client = [
      '{"t":"shout","name":"Maya","game":1}',
      '{"name":"Maya","game":1}',
      '{"t":"open","game":1}',
      '{"t":"open","name":"Maya"}',
      '{"t":"open","name":"Maya","game":"1"}',
      '{"t":"open","name":"Maya","game":1.5}',
      '{"t":"open","name":"Maya","game":0}',
      '{"t":"join","code":1234,"name":"Ana","game":1}',
      '{"t":"join","code":"abcd","name":"Ana","game":1}',
      '{"t":"join","code":"AB1D","name":"Ana","game":1}',
      '{"t":"join","name":"Ana","game":1}',
      '{"t":"send","to":null,"body":[1,2]}',
      '{"t":"send","to":null,"body":"hello"}',
      '{"t":"send","to":null}',
      '{"t":"send","to":7,"body":{}}',
      '{"t":"opened","code":"ABCD","you":$you}',
      '{"t":"open","name":"Maya","game":1',
      '[{"t":"lock"}]',
      '"lock"',
      'null',
      '',
    ];
    final relay = [
      '{"t":"lock"}',
      '{"t":"opened","code":"ABCD"}',
      '{"t":"opened","code":12,"you":$you}',
      '{"t":"opened","code":"ABCD","you":{"id":"h0st","name":"Maya"}}',
      '{"t":"opened","code":"ABCD","you":{"id":"h-st","name":"Maya","avatar":"q3"}}',
      '{"t":"opened","code":"ABCD","you":{"id":"h0st","name":"","avatar":"q3"}}',
      '{"t":"opened","code":"ABCD","you":["h0st","Maya","q3"]}',
      '{"t":"joined","code":"ABCD","you":$you,"host":"h0st","players":{}}',
      '{"t":"joined","code":"ABCD","you":$you,"host":"h0st","players":[{"id":"x"}]}',
      '{"t":"joined","code":"ABCD","you":$you,"players":[$you]}',
      '{"t":"peer-joined"}',
      '{"t":"peer-left","id":5}',
      '{"t":"msg","from":"h0st","body":[1]}',
      '{"t":"msg","body":{}}',
      '{"t":"error","reason":"angry"}',
      '{"t":"error"}',
      'not json',
      '{}',
    ];

    for (final text in client) {
      expect(
        () => ClientMessage.decode(text),
        throwsA(isA<ProtocolError>()),
        reason: text,
      );
    }
    for (final text in relay) {
      expect(
        () => RelayMessage.decode(text),
        throwsA(isA<ProtocolError>()),
        reason: text,
      );
    }
    expect(
      () => Player.fromJson({'id': 'a' * 33, 'name': 'Maya', 'avatar': 'q3'}),
      throwsA(isA<ProtocolError>()),
    );
    expect(() => Player.fromJson('Maya'), throwsA(isA<ProtocolError>()));

    final deep = '${'{"a":' * 3000}1${'}' * 3000}';
    expect(
      () => ClientMessage.decode('{"t":"send","to":null,"body":$deep}'),
      throwsA(isA<ProtocolError>()),
    );
    expect(
      () => RelayMessage.decode('{"t":"msg","from":"h0st","body":$deep}'),
      throwsA(isA<ProtocolError>()),
    );
  });

  test('names must be 1 to 20 characters after trimming', () {
    expect(cleanName('  Ana '), 'Ana');
    expect(cleanName('Taylor Alison Swift!'), 'Taylor Alison Swift!');
    expect(cleanName('é' * 20), 'é' * 20);

    for (final name in [
      '',
      '     ',
      'a' * 21,
      'é' * 21,
      'An\na',
      'An\ta',
      'Ana\u0000',
      'An\u007Fa',
      'An\u0085a',
      'An\u009Fa',
    ]) {
      expect(cleanName(name), isNull, reason: jsonEncode(name));
    }

    expect(
      ClientMessage.decode('{"t":"open","name":"  Ana ","game":1}'),
      const OpenRoom(name: 'Ana', game: 1),
    );
    expect(
      () => ClientMessage.decode(
        jsonEncode({'t': 'join', 'code': 'ABCD', 'name': 'a' * 21, 'game': 1}),
      ),
      throwsA(isA<ProtocolError>()),
    );
    expect(
      () => ClientMessage.decode(
        jsonEncode({'t': 'open', 'name': 'An\na', 'game': 1}),
      ),
      throwsA(isA<ProtocolError>()),
    );
  });

  test('room codes are four letters from the unambiguous alphabet', () {
    expect(isRoomCode('ABCD'), isTrue);
    expect(isRoomCode('ZYXW'), isTrue);
    for (final code in ['ABCI', 'ABCO', 'ABC', 'ABCDE', 'abcd', 'AB D', '']) {
      expect(isRoomCode(code), isFalse, reason: code);
    }

    expect(isJoinCode('ABCI'), isTrue);
    expect(isJoinCode('OOPS'), isTrue);
    for (final code in ['abcd', 'AB1D', 'ABC', 'ABCDE', 'ÄBCD', 'ABCD\n']) {
      expect(isJoinCode(code), isFalse, reason: jsonEncode(code));
    }
  });
}
