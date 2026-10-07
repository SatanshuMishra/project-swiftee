import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:swiftie_relay/relay.dart';
import 'package:test/test.dart';
import 'package:together_protocol/together_protocol.dart';

const key = '0uEpDLyZmr1J3cjOqizYMRbyEu9txFLMHPM1jfEZObI';
const game = 3;
const patience = Duration(seconds: 5);

const admitted = {
  HttpHeaders.authorizationHeader: '$bearerPrefix$key',
  relayProtocolHeader: '$relayProtocolVersion',
};

const wrongKey = {
  HttpHeaders.authorizationHeader: '${bearerPrefix}wrong',
  relayProtocolHeader: '$relayProtocolVersion',
};

const upgradeHeaders = {
  'connection': 'Upgrade',
  'upgrade': 'websocket',
  'sec-websocket-version': '13',
  'sec-websocket-key': 'dGhlIHNhbXBsZSBub25jZQ==',
};

Map<String, String> from(
  String address, [
  Map<String, String> headers = admitted,
]) => {...headers, 'cf-connecting-ip': address};

void main() {
  test('upgrades only with the right key and protocol version', () async {
    final relay = await Relay.start();
    final offByOne = '${key.substring(0, key.length - 1)}J';

    for (final path in [checkPath, relayPath]) {
      expect(await relay.status(path), statusBadKey, reason: path);
      expect(await relay.status(path, wrongKey), statusBadKey, reason: path);
      expect(
        await relay.status(path, {
          ...admitted,
          HttpHeaders.authorizationHeader: '$bearerPrefix$offByOne',
        }),
        statusBadKey,
        reason: path,
      );
      expect(
        await relay.status(path, {...admitted, relayProtocolHeader: '2'}),
        statusNeedsUpdate,
        reason: path,
      );
      expect(
        await relay.status(path, {
          HttpHeaders.authorizationHeader: '$bearerPrefix$key',
        }),
        statusNeedsUpdate,
        reason: path,
      );
    }
    await expectLater(
      relay.connect(wrongKey),
      throwsA(isA<WebSocketException>()),
    );

    expect(await relay.status(checkPath, admitted), statusChecked);
    final peer = await relay.connect();
    expect(peer.socket.readyState, WebSocket.open);
    peer.send(const OpenRoom(name: 'Maya', game: game));
    expect(await peer.next(), isA<RoomOpened>());

    final welcome = await relay.get('/');
    expect(welcome.status, HttpStatus.ok);
    expect(welcome.contentType?.mimeType, 'text/plain');
    expect(
      welcome.body,
      'Project Swiftie relay. Copy the whole link into Project Swiftie → '
      'Settings → Play together.',
    );
    final health = await relay.get('/healthz');
    expect((health.status, health.body), (HttpStatus.ok, 'ok'));
    expect(await relay.status('/elsewhere'), HttpStatus.notFound);
    expect(
      (await relay.get(checkPath, headers: admitted, method: 'POST')).status,
      HttpStatus.methodNotAllowed,
    );
  });

  test(
    'opening a room returns a unique four-letter code and a random avatar',
    () async {
      final relay = await Relay.start(
        limits: const RelayLimits(
          maxSocketsPerAddress: 50,
          maxRoomsPerAddress: 50,
        ),
      );

      final opened = [
        for (var i = 0; i < 50; i++) (await relay.open('Maya')).$2,
      ];

      final codes = {for (final room in opened) room.code};
      expect(codes, hasLength(50));
      expect(
        codes,
        everyElement(matches(RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ]{4}$'))),
      );
      for (final room in opened) {
        expect(room.you.name, 'Maya');
        expect(room.you.id, matches(RegExp(r'^[A-Za-z0-9]{12}$')));
        expect(room.you.avatar, matches(RegExp(r'^[a-z0-9]{16}$')));
      }
      expect({for (final room in opened) room.you.id}, hasLength(50));
      expect({for (final room in opened) room.you.avatar}, hasLength(50));
    },
  );

  test('joining adds the player and tells everyone else', () async {
    final relay = await Relay.start();
    final (host, opened) = await relay.open('Maya');

    final (guest, joined) = await relay.join(opened.code, 'Juniper');
    expect(joined.code, opened.code);
    expect(joined.hostId, opened.you.id);
    expect(joined.you.name, 'Juniper');
    expect(joined.players, [opened.you, joined.you]);
    expect(await host.next(), PeerJoined(joined.you));

    final (third, latest) = await relay.join(opened.code, 'Theo');
    expect(latest.players, [opened.you, joined.you, latest.you]);
    expect(await host.next(), PeerJoined(latest.you));
    expect(await guest.next(), PeerJoined(latest.you));

    host.send(SendBody(body: const {'say': 'welcome'}));
    expect(
      await third.next(),
      Relayed(from: opened.you.id, body: const {'say': 'welcome'}),
    );
  });

  test('joins are refused when the room is full, locked, unknown or on another game version', () async {
    final relay = await Relay.start(
      limits: const RelayLimits(
        maxSocketsPerAddress: 32,
        maxRoomsPerAddress: 3,
      ),
    );
    final (_, crowded) = await relay.open('Maya');
    for (var i = 1; i < maxPlayers; i++) {
      await relay.join(crowded.code, 'Guest$i');
    }
    final (lockedHost, locked) = await relay.open('Theo');
    lockedHost.send(const LockRoom());
    await lockedHost.settle();
    final (_, open) = await relay.open('Iris');
    final taken = {crowded.code, locked.code, open.code};
    final madeUp = [
      'ZZZZ',
      'YYYY',
      'XXXX',
      'WWWW',
    ].firstWhere((code) => !taken.contains(code));

    Future<Peer> refused(
      String code,
      RelayErrorReason reason, [
      int version = game,
    ]) async {
      final peer = await relay.connect();
      peer.send(JoinRoom(code: code, name: 'Juniper', game: version));
      expect(await peer.next(), RelayError(reason));
      return peer;
    }

    final ninth = await refused(crowded.code, RelayErrorReason.full);
    final latecomer = await refused(locked.code, RelayErrorReason.inGame);
    final lost = await refused(madeUp, RelayErrorReason.notFound);
    final newer = await refused(
      open.code,
      RelayErrorReason.gameMismatch,
      game + 1,
    );

    for (final peer in [ninth, lost, newer]) {
      peer.send(JoinRoom(code: open.code, name: 'Juniper', game: game));
      expect(
        await peer.next(),
        isA<RoomJoined>().having(_code, 'code', open.code),
      );
    }
    lockedHost.send(const UnlockRoom());
    await lockedHost.settle();
    latecomer.send(JoinRoom(code: locked.code, name: 'Juniper', game: game));
    expect(
      await latecomer.next(),
      isA<RoomJoined>().having(_code, 'code', locked.code),
    );
  });

  test(
    'guests talk only to the host and the host talks to one or all',
    () async {
      final relay = await Relay.start();
      final (host, opened) = await relay.open('Maya');
      final (first, a) = await relay.join(opened.code, 'Juniper');
      final (second, b) = await relay.join(opened.code, 'Theo');
      expect(await host.next(), PeerJoined(a.you));
      expect(await host.next(), PeerJoined(b.you));
      expect(await first.next(), PeerJoined(b.you));
      final hostId = opened.you.id;

      first.send(SendBody(body: const {'say': 'psst'}, to: b.you.id));
      expect(
        await host.next(),
        Relayed(from: a.you.id, body: const {'say': 'psst'}),
      );

      host.send(SendBody(body: const {'say': 'only you'}, to: b.you.id));
      expect(
        await second.next(),
        Relayed(from: hostId, body: const {'say': 'only you'}),
      );

      host.send(SendBody(body: const {'say': 'everyone'}));
      for (final guest in [first, second]) {
        expect(
          await guest.next(),
          Relayed(from: hostId, body: const {'say': 'everyone'}),
        );
      }

      host.send(SendBody(body: const {'say': 'nobody'}, to: 'Nobody000000'));
      host.send(SendBody(body: const {'say': 'last'}));
      for (final guest in [first, second]) {
        expect(
          await guest.next(),
          Relayed(from: hostId, body: const {'say': 'last'}),
        );
      }

      second.send(SendBody(body: const {'say': 'back'}));
      expect(
        await host.next(),
        Relayed(from: b.you.id, body: const {'say': 'back'}),
      );

      first.sendText('{"t":"send","body":{"far":[1e400]}}');
      expect(await first.next(), const RelayError(RelayErrorReason.badRequest));
      host.sendText('{"t":"send","body":{"far":-1e400}}');
      expect(await host.next(), const RelayError(RelayErrorReason.badRequest));
      first.send(SendBody(body: const {'say': 'still here'}));
      expect(
        await host.next(),
        Relayed(from: a.you.id, body: const {'say': 'still here'}),
      );

      first.send(const LockRoom());
      expect(await first.next(), const RelayError(RelayErrorReason.notHost));
      first.send(const UnlockRoom());
      expect(await first.next(), const RelayError(RelayErrorReason.notHost));
    },
  );

  test('the room closes for everyone when the host leaves', () async {
    final relay = await Relay.start();
    final (host, opened) = await relay.open('Maya');
    final (first, a) = await relay.join(opened.code, 'Juniper');
    final (second, b) = await relay.join(opened.code, 'Theo');
    final (third, c) = await relay.join(opened.code, 'Iris');
    for (final player in [a, b, c]) {
      expect(await host.next(), PeerJoined(player.you));
    }
    for (final player in [b, c]) {
      expect(await first.next(), PeerJoined(player.you));
    }
    expect(await second.next(), PeerJoined(c.you));

    await third.leave();
    for (final peer in [host, first, second]) {
      expect(await peer.next(), PeerLeft(c.you.id));
    }

    await host.leave();
    for (final guest in [first, second]) {
      expect(await guest.next(), const RoomClosed());
      expect(await guest.ended(), WebSocketStatus.normalClosure);
    }

    final latecomer = await relay.connect();
    latecomer.send(JoinRoom(code: opened.code, name: 'Juniper', game: game));
    expect(await latecomer.next(), const RelayError(RelayErrorReason.notFound));
  });

  test('oversized, flooding and silent sockets are closed', () async {
    final relay = await Relay.start(
      limits: const RelayLimits(maxMessageBytes: 1024, burstMessages: 5),
    );

    final atLimit = await relay.connect();
    atLimit.sendText('x' * 1024);
    expect(await atLimit.next(), const RelayError(RelayErrorReason.badRequest));

    final oversized = await relay.connect();
    oversized.sendText('x' * 1025);
    expect(await oversized.ended(), closeTooBig);

    final wide = await relay.connect();
    wide.sendText('é' * 513);
    expect(await wide.ended(), closeTooBig);

    final (flooder, _) = await relay.open('Maya');
    for (var i = 0; i < 3; i++) {
      flooder.send(const LockRoom());
    }
    await flooder.settle();
    flooder.send(const LockRoom());
    expect(await flooder.ended(), closePolicy);

    final quiet = await Relay.start(
      limits: const RelayLimits(handshakeTimeout: Duration(milliseconds: 300)),
    );
    final (host, _) = await quiet.open('Maya');
    final clock = Stopwatch()..start();
    final idle = await quiet.connect();
    final wanderer = await quiet.connect();
    wanderer.send(const JoinRoom(code: 'IIII', name: 'Juniper', game: game));
    expect(await wanderer.next(), const RelayError(RelayErrorReason.notFound));

    expect(await idle.ended(), closePolicy);
    expect(await wanderer.ended(), closePolicy);
    expect(
      clock.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 300)),
    );
    await host.settle();
  });

  test('repeated bad keys from one address are throttled', () async {
    final throttled = await Relay.start(
      limits: const RelayLimits(
        authFailures: 3,
        authWindow: Duration(seconds: 1),
      ),
      trustCloudflareAddress: true,
    );
    for (var i = 0; i < 3; i++) {
      expect(
        await throttled.status(checkPath, from('198.51.100.1', wrongKey)),
        statusBadKey,
      );
    }
    expect(
      await throttled.status(checkPath, from('198.51.100.1', wrongKey)),
      statusTooMany,
    );
    expect(
      await throttled.status(relayPath, from('198.51.100.1', wrongKey)),
      statusTooMany,
    );
    expect(
      await throttled.status(checkPath, from('198.51.100.1')),
      statusChecked,
    );
    expect(
      await throttled.status(
        checkPath,
        from('198.51.100.1', {
          HttpHeaders.authorizationHeader: '$bearerPrefix$key',
        }),
      ),
      statusNeedsUpdate,
    );
    final player = await throttled.connect(from('198.51.100.1'));
    expect(player.socket.readyState, WebSocket.open);
    expect(
      await throttled.status(checkPath, from('198.51.100.2', wrongKey)),
      statusBadKey,
    );
    expect(await throttled.status(checkPath, admitted), statusChecked);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(
      await throttled.status(checkPath, from('198.51.100.1', wrongKey)),
      statusBadKey,
    );

    final untrusting = await Relay.start(
      limits: const RelayLimits(authFailures: 3),
    );
    for (final address in ['198.51.100.1', '198.51.100.2', '198.51.100.3']) {
      expect(
        await untrusting.status(checkPath, from(address, wrongKey)),
        statusBadKey,
      );
    }
    expect(
      await untrusting.status(checkPath, from('198.51.100.4', wrongKey)),
      statusTooMany,
    );
    expect(
      await untrusting.status(checkPath, from('198.51.100.4')),
      statusChecked,
    );

    final crowded = await Relay.start(
      limits: const RelayLimits(maxSockets: 3, maxSocketsPerAddress: 2),
      trustCloudflareAddress: true,
    );
    final first = await crowded.connect(from('198.51.100.1'));
    await crowded.connect(from('198.51.100.1'));
    expect(await crowded.status(relayPath, from('198.51.100.1')), statusBusy);
    await crowded.connect(from('198.51.100.2'));
    expect(await crowded.status(relayPath, from('198.51.100.3')), statusBusy);
    await first.leave();
    final returning = await crowded.connect(from('198.51.100.3'));
    expect(returning.socket.readyState, WebSocket.open);

    final packed = await Relay.start(limits: const RelayLimits(maxRooms: 1));
    final (owner, _) = await packed.open('Maya');
    final rival = await packed.connect();
    rival.send(const OpenRoom(name: 'Theo', game: game));
    expect(await rival.ended(), closePolicy);
    await owner.leave();
    final (_, reopened) = await packed.open('Theo');
    expect(reopened.you.name, 'Theo');
  });

  test('logs carry no names, codes, keys or addresses', () async {
    final relay = await Relay.start();
    final (host, opened) = await relay.open('Marigold');
    final (guest, joined) = await relay.join(opened.code, 'Juniper');
    expect(await host.next(), PeerJoined(joined.you));
    guest.send(SendBody(body: const {'secret': 'bluebird'}));
    expect(await host.next(), isA<Relayed>());
    await guest.leave();
    expect(await host.next(), PeerLeft(joined.you.id));
    expect(await relay.status(checkPath, wrongKey), statusBadKey);
    await host.leave();

    expect(relay.lines, anyElement(startsWith('room opened')));
    expect(relay.lines, anyElement(startsWith('player joined')));
    expect(relay.lines, anyElement(startsWith('room closed')));
    final private = [
      'Marigold',
      'Juniper',
      opened.code,
      opened.you.id,
      opened.you.avatar,
      joined.you.id,
      joined.you.avatar,
      key,
      'wrong',
      '127.0.0.1',
      'bluebird',
    ];
    for (final line in relay.lines) {
      for (final word in private) {
        expect(line, isNot(contains(word)));
      }
    }
  });

  test('every join gets a fresh id and avatar', () async {
    final relay = await Relay.start();
    final (host, opened) = await relay.open('Maya');

    final (guest, first) = await relay.join(opened.code, 'Juniper');
    await guest.leave();
    final (_, second) = await relay.join(opened.code, 'Juniper');

    expect(second.you.name, first.you.name);
    expect(second.you.id, isNot(first.you.id));
    expect(second.you.avatar, isNot(first.you.avatar));
    expect(second.players, [opened.you, second.you]);

    await host.leave();
    final (_, reopened) = await relay.open('Maya');
    expect(reopened.you.id, isNot(opened.you.id));
    expect(reopened.you.avatar, isNot(opened.you.avatar));
  });

  test(
    'a repeated upgrade header gets 400 and the relay keeps serving',
    () async {
      final relay = await Relay.start();

      for (final repeated in [
        'Sec-WebSocket-Version: 13',
        'Sec-WebSocket-Key: ${upgradeHeaders['sec-websocket-key']}',
        'Upgrade: websocket',
      ]) {
        final wire = await Wire.connect(relay);
        expect(
          await wire.response(upgradeRequest(repeated: [repeated])),
          startsWith('HTTP/1.1 400'),
          reason: repeated,
        );
      }

      final upgraded = await Wire.connect(relay);
      await upgraded.upgrade();
      expect(
        upgraded.text,
        contains('sec-websocket-accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo='),
      );
      final health = await relay.get('/healthz');
      expect((health.status, health.body), (HttpStatus.ok, 'ok'));
      final (_, opened) = await relay.open('Maya');
      expect(isRoomCode(opened.code), isTrue);
    },
  );

  test(
    'a frame claiming more than the message limit is refused at its header',
    () async {
      final relay = await Relay.start();
      final wire = await Wire.connect(relay);
      await wire.upgrade();
      final payload = Uint8List(1 << 20);
      final rss = ProcessInfo.currentRss;

      wire.frame(1, length: 1 << 40);
      await until(() => wire.closeCode != null);
      expect(wire.closeCode, closeTooBig);
      final pushed = await wire.push(payload, limit: 64 << 20);
      await wire.ended;

      expect(pushed, lessThan(64 << 20));
      expect(ProcessInfo.currentRss - rss, lessThan(32 << 20));
      expect(relay.lines, anyElement(startsWith('socket shut reason=too-big')));
      expect(
        relay.lines,
        anyElement(startsWith('socket dropped reason=byte-rate')),
      );
    },
  );

  test(
    'endless continuations, ping floods and byte floods are cut off',
    () async {
      final relay = await Relay.start(
        limits: const RelayLimits(
          maxMessageBytes: 1024,
          inboundBytesPerSecond: 1 << 30,
        ),
      );
      Future<Wire> upgraded(Relay relay) async {
        final wire = await Wire.connect(relay);
        await wire.upgrade();
        return wire;
      }

      final growing = await upgraded(relay);
      growing.frame(1, fin: false, payload: Uint8List(600));
      await growing.push(
        Wire.frameBytes(0, fin: false, payload: Uint8List(600)),
        limit: 1 << 20,
        stop: () => growing.closeCode != null,
      );
      await until(() => growing.closeCode != null);
      expect(growing.closeCode, closeTooBig);

      final hollow = await upgraded(relay);
      hollow.frame(1, fin: false);
      await hollow.push(
        repeated(Wire.frameBytes(0, fin: false), 100),
        limit: 1 << 20,
      );
      await hollow.ended;

      final pinging = await upgraded(relay);
      await pinging.push(
        repeated(Wire.frameBytes(9, payload: Uint8List(100)), 10),
        limit: 1 << 20,
      );
      await pinging.ended;

      expect(relay.lines, anyElement(startsWith('socket shut reason=too-big')));
      expect(
        relay.lines.where(
          (line) => line.startsWith('socket dropped reason=unfinished'),
        ),
        hasLength(1),
      );
      expect(
        relay.lines,
        anyElement(startsWith('socket dropped reason=pings')),
      );

      final metered = await Relay.start(
        limits: const RelayLimits(inboundBytesPerSecond: 4096),
      );
      final flooder = await upgraded(metered);
      await flooder.push(
        Wire.frameBytes(1, payload: utf8.encode('x' * 1000)),
        limit: 1 << 20,
      );
      await flooder.ended;
      expect(
        metered.lines,
        anyElement(startsWith('socket dropped reason=byte-rate')),
      );
    },
  );

  test(
    'a guest that stops reading is closed while the host keeps sending',
    () async {
      final relay = await Relay.start(
        limits: const RelayLimits(
          maxQueuedBytes: 64 * 1024,
          inboundBytesPerSecond: 1 << 30,
          burstMessages: 1 << 20,
          closeGrace: Duration(milliseconds: 200),
        ),
      );
      final (host, opened) = await relay.open('Maya');
      final (reader, a) = await relay.join(opened.code, 'Juniper');
      final (stalled, b) = await relay.join(opened.code, 'Theo');
      expect(await host.next(), PeerJoined(a.you));
      expect(await host.next(), PeerJoined(b.you));
      expect(await reader.next(), PeerJoined(b.you));

      stalled.pause();
      final chatter = SendBody(body: {'say': 'x' * 16000});
      var sending = true;
      final left = host.next().whenComplete(() => sending = false);
      while (sending) {
        host.send(chatter);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(await left, PeerLeft(b.you.id));
      expect(relay.lines, anyElement(startsWith('socket shut reason=backlog')));
      await host.settle();
      host.send(SendBody(body: const {'say': 'still here'}));
      await reader.skipTo(PeerLeft(b.you.id));
      await reader.skipTo(
        Relayed(from: opened.you.id, body: const {'say': 'still here'}),
      );
      stalled.resume();
      await stalled.drain();
      expect(stalled.socket.closeCode, isNot(WebSocketStatus.normalClosure));
    },
  );

  test(
    'a body that grows past the message limit when relayed is refused',
    () async {
      final relay = await Relay.start(
        limits: const RelayLimits(maxMessageBytes: 1024),
      );
      final (host, opened) = await relay.open('Maya');
      final (guest, joined) = await relay.join(opened.code, 'Juniper');
      expect(await host.next(), PeerJoined(joined.you));
      final swelling =
          '{"t":"send","body":{"n":[${List.filled(150, '9e20').join(',')}]}}';
      expect(utf8.encode(swelling).length, lessThan(1024));

      host.sendText(swelling);
      expect(await host.next(), const RelayError(RelayErrorReason.badRequest));
      guest.sendText(swelling);
      expect(await guest.next(), const RelayError(RelayErrorReason.badRequest));

      host.send(SendBody(body: const {'say': 'small'}));
      expect(
        await guest.next(),
        Relayed(from: opened.you.id, body: const {'say': 'small'}),
      );
      guest.send(SendBody(body: const {'say': 'small'}));
      expect(
        await host.next(),
        Relayed(from: joined.you.id, body: const {'say': 'small'}),
      );
    },
  );

  test(
    'wrong keys from thousands of addresses stay capped and cheap',
    () async {
      final relay = await Relay.start(
        limits: const RelayLimits(authFailures: 1),
        trustCloudflareAddress: true,
      );
      String network(int n) =>
          '2001:db8:${(n >> 16).toRadixString(16)}:'
          '${(n & 0xffff).toRadixString(16)}::1';

      final batches = <Duration>[];
      for (var batch = 0; batch < 5; batch++) {
        final clock = Stopwatch()..start();
        final statuses = await relay.pipeline([
          for (var n = batch * 1000; n < (batch + 1) * 1000; n++)
            from(network(n), wrongKey),
        ]);
        batches.add(clock.elapsed);
        expect(statuses, List.filled(1000, statusBadKey));
      }

      expect(
        await relay.status(checkPath, from(network(4999), wrongKey)),
        statusTooMany,
      );
      expect(
        await relay.status(checkPath, from(network(904), wrongKey)),
        statusTooMany,
      );
      expect(
        await relay.status(checkPath, from(network(903), wrongKey)),
        statusBadKey,
      );
      expect(
        await relay.status(checkPath, from(network(0), wrongKey)),
        statusBadKey,
      );
      expect(
        batches.last,
        lessThan(batches.first * 2 + const Duration(milliseconds: 100)),
      );
    },
  );

  test('a socket is closed after three refused joins', () async {
    final relay = await Relay.start();
    final (_, open) = await relay.open('Maya');
    final (lockedHost, locked) = await relay.open('Theo');
    lockedHost.send(const LockRoom());
    await lockedHost.settle();

    final guesser = await relay.connect();
    guesser.send(
      JoinRoom(
        code: unusedCode([open.code, locked.code]),
        name: 'Juniper',
        game: game,
      ),
    );
    expect(await guesser.next(), const RelayError(RelayErrorReason.notFound));
    guesser.send(JoinRoom(code: locked.code, name: 'Juniper', game: game));
    expect(await guesser.next(), const RelayError(RelayErrorReason.inGame));
    guesser.send(JoinRoom(code: open.code, name: 'Juniper', game: game + 1));
    expect(
      await guesser.next(),
      const RelayError(RelayErrorReason.gameMismatch),
    );
    expect(await guesser.ended(), closePolicy);
  });

  test(
    'an address with too many refused joins is turned away unseen',
    () async {
      final relay = await Relay.start(trustCloudflareAddress: true);
      final (host, opened) = await relay.open('Maya');
      final madeUp = unusedCode([opened.code]);

      for (var socket = 0; socket < 7; socket++) {
        final guesser = await relay.connect(from('198.51.100.7'));
        for (var i = 0; i < 3; i++) {
          guesser.send(JoinRoom(code: madeUp, name: 'Juniper', game: game));
          expect(
            await guesser.next(),
            const RelayError(RelayErrorReason.notFound),
          );
        }
        expect(await guesser.ended(), closePolicy);
      }

      final turnedAway = await relay.connect(from('198.51.100.7'));
      turnedAway.send(JoinRoom(code: opened.code, name: 'Juniper', game: game));
      expect(
        await turnedAway.next(),
        const RelayError(RelayErrorReason.notFound),
      );
      final (_, joined) = await relay.join(
        opened.code,
        'Theo',
        from('198.51.100.8'),
      );
      expect(await host.next(), PeerJoined(joined.you));
      expect(
        relay.lines,
        anyElement(startsWith('join refused reason=throttled')),
      );
    },
  );

  test('one address keeps at most two open rooms', () async {
    final relay = await Relay.start(trustCloudflareAddress: true);
    final (first, _) = await relay.open('Maya');
    await relay.open('Theo');

    final third = await relay.connect();
    third.send(const OpenRoom(name: 'Iris', game: game));
    expect(await third.ended(), closePolicy);
    final (_, elsewhere) = await relay.open('Iris', from('198.51.100.9'));
    expect(elsewhere.you.name, 'Iris');

    await first.leave();
    final (_, again) = await relay.open('Juniper');
    expect(again.you.name, 'Juniper');
    expect(
      relay.lines,
      anyElement(startsWith('socket shut reason=address-room-limit')),
    );
  });

  test(
    'a room whose host relays nothing closes after the idle timeout',
    () async {
      final relay = await Relay.start(
        limits: const RelayLimits(roomIdleTimeout: Duration(milliseconds: 600)),
      );
      final (busyHost, busy) = await relay.open('Maya');
      final (busyGuest, b) = await relay.join(busy.code, 'Juniper');
      expect(await busyHost.next(), PeerJoined(b.you));
      final (quietHost, quiet) = await relay.open('Theo');
      final (quietGuest, q) = await relay.join(quiet.code, 'Iris');
      expect(await quietHost.next(), PeerJoined(q.you));
      quietGuest.send(SendBody(body: const {'say': 'anyone?'}));
      expect(
        await quietHost.next(),
        Relayed(from: q.you.id, body: const {'say': 'anyone?'}),
      );

      for (var tick = 0; tick < 8; tick++) {
        busyHost.send(SendBody(body: {'tick': tick}));
        expect(
          await busyGuest.next(),
          Relayed(from: busy.you.id, body: {'tick': tick}),
        );
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }

      for (final peer in [quietHost, quietGuest]) {
        expect(await peer.next(), const RoomClosed());
        expect(await peer.ended(), WebSocketStatus.normalClosure);
      }
      expect(relay.lines, anyElement(startsWith('room closed reason=idle')));
      busyHost.send(SendBody(body: const {'say': 'still playing'}));
      expect(
        await busyGuest.next(),
        Relayed(from: busy.you.id, body: const {'say': 'still playing'}),
      );
    },
  );

  test(
    'pings past the budget drop a socket even between complete messages',
    () async {
      final relay = await Relay.start(
        limits: const RelayLimits(
          inboundBytesPerSecond: 1 << 30,
          burstMessages: 1 << 20,
        ),
      );
      final wire = await Wire.connect(relay);
      await wire.upgrade();
      wire.frame(
        1,
        payload: utf8.encode(const OpenRoom(name: 'Pinger', game: 1).encode()),
      );
      await until(
        () => relay.lines.any((line) => line.startsWith('room opened')),
      );

      final pings = repeated(Wire.frameBytes(9, payload: Uint8List(100)), 20);
      final lock = Wire.frameBytes(
        1,
        payload: utf8.encode(const LockRoom().encode()),
      );
      await wire.push(
        Uint8List.fromList([...pings, ...lock]),
        limit: 1 << 20,
        stop: () => wire.closed,
      );
      await wire.ended;

      expect(
        relay.lines,
        anyElement(startsWith('socket dropped reason=pings')),
      );
    },
  );

  test(
    'a host message that reaches nobody does not keep a room open',
    () async {
      final relay = await Relay.start(
        limits: const RelayLimits(roomIdleTimeout: Duration(milliseconds: 600)),
      );
      final (host, _) = await relay.open('Maya');
      for (var tick = 0; tick < 8; tick++) {
        host.send(SendBody(body: {'tick': tick}));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }

      expect(relay.lines, anyElement(startsWith('room closed reason=idle')));
      expect(await host.next(), const RoomClosed());
      expect(await host.ended(), WebSocketStatus.normalClosure);
      expect(relay.lines, anyElement(startsWith('room closed reason=idle')));
    },
  );

  test(
    'forwarded addresses count only when they parse and IPv6 counts per /64',
    () async {
      final relay = await Relay.start(
        limits: const RelayLimits(authFailures: 3),
        trustCloudflareAddress: true,
      );

      for (final garbled in [
        'not-an-address',
        '198.51.100.300',
        '2001:db8::zz',
      ]) {
        expect(
          await relay.status(checkPath, from(garbled, wrongKey)),
          statusBadKey,
          reason: garbled,
        );
      }
      expect(await relay.status(checkPath, wrongKey), statusTooMany);

      for (final neighbour in [
        '2001:db8:1:2::1',
        '2001:db8:1:2::ffff',
        '2001:db8:1:2:abcd::1',
      ]) {
        expect(
          await relay.status(checkPath, from(neighbour, wrongKey)),
          statusBadKey,
          reason: neighbour,
        );
      }
      expect(
        await relay.status(checkPath, from('2001:db8:1:2::9', wrongKey)),
        statusTooMany,
      );
      expect(
        await relay.status(checkPath, from('2001:db8:1:3::1', wrongKey)),
        statusBadKey,
      );

      for (var i = 0; i < 3; i++) {
        expect(
          await relay.status(checkPath, from('::ffff:198.51.100.9', wrongKey)),
          statusBadKey,
        );
      }
      expect(
        await relay.status(checkPath, from('198.51.100.9', wrongKey)),
        statusTooMany,
      );
    },
  );
}

String _code(RoomJoined joined) => joined.code;

String unusedCode(Iterable<String> taken) => [
  'ZZZZ',
  'YYYY',
  'XXXX',
  'WWWW',
].firstWhere((code) => !taken.contains(code));

String upgradeRequest({
  Map<String, String> headers = admitted,
  List<String> repeated = const [],
}) => [
  'GET $relayPath HTTP/1.1',
  'Host: 127.0.0.1',
  for (final MapEntry(:key, :value) in {...headers, ...upgradeHeaders}.entries)
    '$key: $value',
  ...repeated,
  '',
  '',
].join('\r\n');

String checkRequest(Map<String, String> headers, {required bool last}) => [
  'GET $checkPath HTTP/1.1',
  'Host: 127.0.0.1',
  for (final MapEntry(:key, :value) in headers.entries) '$key: $value',
  if (last) 'Connection: close',
  '',
  '',
].join('\r\n');

Uint8List repeated(Uint8List bytes, int times) =>
    Uint8List.fromList([for (var i = 0; i < times; i++) ...bytes]);

Future<void> until(bool Function() condition) async {
  final clock = Stopwatch()..start();
  while (!condition()) {
    if (clock.elapsed > patience) fail('Gave up waiting after $patience');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

List<({int opcode, List<int> payload})> _frames(List<int> bytes) {
  final header = switch (bytes) {
    [_, final second, ...] when second & 0x7f < 126 => (
      length: second & 0x7f,
      start: 2,
    ),
    [_, final second, final high, final low, ...] when second & 0x7f == 126 => (
      length: (high << 8) | low,
      start: 4,
    ),
    [_, _, ...] when bytes.length >= 10 => (
      length: bytes.sublist(2, 10).fold(0, (n, byte) => (n << 8) | byte),
      start: 10,
    ),
    _ => null,
  };
  if (header == null || header.start + header.length > bytes.length) {
    return const [];
  }
  final end = header.start + header.length;
  return [
    (opcode: bytes[0] & 0x0f, payload: bytes.sublist(header.start, end)),
    ..._frames(bytes.sublist(end)),
  ];
}

final class Relay {
  Relay._(this.server, this.lines);

  static Future<Relay> start({
    RelayLimits limits = const RelayLimits(),
    bool trustCloudflareAddress = false,
  }) async {
    final lines = <String>[];
    final server = await RelayServer.start(
      key: key,
      address: InternetAddress.loopbackIPv4,
      port: 0,
      limits: limits,
      trustCloudflareAddress: trustCloudflareAddress,
      log: lines.add,
    );
    final relay = Relay._(server, lines);
    addTearDown(relay._close);
    return relay;
  }

  final RelayServer server;
  final List<String> lines;
  final _http = HttpClient();

  Future<({int status, String body, ContentType? contentType})> get(
    String path, {
    Map<String, String> headers = const {},
    String method = 'GET',
  }) async {
    final request = await _http.openUrl(
      method,
      Uri.http('127.0.0.1:${server.port}', path),
    );
    for (final MapEntry(key: name, :value) in headers.entries) {
      request.headers.set(name, value);
    }
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    return (
      status: response.statusCode,
      body: body,
      contentType: response.headers.contentType,
    );
  }

  Future<int> status(
    String path, [
    Map<String, String> headers = const {},
  ]) async => (await get(
    path,
    headers: path == relayPath ? {...upgradeHeaders, ...headers} : headers,
  )).status;

  Future<Peer> connect([Map<String, String> headers = admitted]) async => Peer(
    await WebSocket.connect(
      'ws://127.0.0.1:${server.port}$relayPath',
      headers: headers,
    ),
  );

  Future<(Peer, RoomOpened)> open(
    String name, [
    Map<String, String> headers = admitted,
  ]) async {
    final host = await connect(headers);
    host.send(OpenRoom(name: name, game: game));
    final opened = await host.next();
    expect(opened, isA<RoomOpened>());
    return (host, opened as RoomOpened);
  }

  Future<(Peer, RoomJoined)> join(
    String code,
    String name, [
    Map<String, String> headers = admitted,
  ]) async {
    final guest = await connect(headers);
    guest.send(JoinRoom(code: code, name: name, game: game));
    final joined = await guest.next();
    expect(joined, isA<RoomJoined>());
    return (guest, joined as RoomJoined);
  }

  Future<List<int>> pipeline(List<Map<String, String>> requests) async {
    final wire = await Wire.connect(this);
    wire.write(
      [
        for (final (i, headers) in requests.indexed)
          checkRequest(headers, last: i == requests.length - 1),
      ].join(),
    );
    await wire.ended;
    return [
      for (final match in RegExp(r'HTTP/1\.1 (\d{3})').allMatches(wire.text))
        int.parse(match.group(1)!),
    ];
  }

  Future<void> _close() async {
    await server.close();
    _http.close(force: true);
  }
}

final class Peer {
  Peer(this.socket) {
    socket.done.ignore();
    _subscription = socket.listen(_inbox.add, onDone: _inbox.close);
  }

  final WebSocket socket;
  final _inbox = StreamController<Object?>();
  late final _frames = StreamIterator<Object?>(_inbox.stream);
  late final StreamSubscription<Object?> _subscription;

  void pause() => _subscription.pause();

  void resume() => _subscription.resume();

  Future<void> skipTo(RelayMessage expected) async {
    while (await next() != expected) {}
  }

  Future<void> drain() async {
    while (await _frames.moveNext().timeout(patience)) {}
  }

  void send(ClientMessage message) => socket.add(message.encode());

  void sendText(String text) => socket.add(text);

  Future<RelayMessage> next() async {
    if (!await _frames.moveNext().timeout(patience)) {
      fail('The relay closed the socket with ${socket.closeCode}');
    }
    return RelayMessage.decode(_frames.current as String);
  }

  Future<int?> ended() async {
    if (await _frames.moveNext().timeout(patience)) {
      fail('The relay sent ${_frames.current} instead of closing');
    }
    return socket.closeCode;
  }

  Future<void> settle() async {
    send(const OpenRoom(name: 'Maya', game: game));
    expect(await next(), const RelayError(RelayErrorReason.alreadyInRoom));
  }

  Future<void> leave() async {
    socket.close().ignore();
    await drain();
  }
}

final class Wire {
  Wire._(this._socket) {
    _socket.done.ignore();
    _socket.listen(_received.add, onError: (Object _) => _end(), onDone: _end);
  }

  static Future<Wire> connect(Relay relay) async {
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      relay.server.port,
    );
    addTearDown(socket.destroy);
    return Wire._(socket);
  }

  static Uint8List frameBytes(
    int opcode, {
    bool fin = true,
    List<int> payload = const [],
    int? length,
  }) {
    final size = length ?? payload.length;
    return Uint8List.fromList([
      (fin ? 0x80 : 0) | opcode,
      ...switch (size) {
        < 126 => [0x80 | size],
        < 65536 => [0x80 | 126, size >> 8, size & 0xff],
        _ => [
          0x80 | 127,
          for (var shift = 56; shift >= 0; shift -= 8) (size >> shift) & 0xff,
        ],
      },
      0,
      0,
      0,
      0,
      ...payload,
    ]);
  }

  final Socket _socket;
  final _received = BytesBuilder();
  final _closed = Completer<void>();
  var _handshakeBytes = 0;

  bool get closed => _closed.isCompleted;

  Future<void> get ended => _closed.future.timeout(patience);

  String get text => latin1.decode(_received.toBytes());

  int? get closeCode =>
      switch (_frames(_received.toBytes().sublist(_handshakeBytes))
          .where((frame) => frame.opcode == 8)
          .firstOrNull) {
        (opcode: _, payload: [final high, final low, ...]) => (high << 8) | low,
        _ => null,
      };

  void write(String text) => _socket.write(text);

  void frame(
    int opcode, {
    bool fin = true,
    List<int> payload = const [],
    int? length,
  }) => _socket.add(
    frameBytes(opcode, fin: fin, payload: payload, length: length),
  );

  Future<String> response(String request) async {
    write(request);
    await until(() => text.contains('\r\n\r\n'));
    return text;
  }

  Future<void> upgrade() async {
    final reply = await response(upgradeRequest());
    expect(reply, startsWith('HTTP/1.1 101'));
    _handshakeBytes = reply.indexOf('\r\n\r\n') + 4;
  }

  Future<int> push(
    Uint8List bytes, {
    required int limit,
    bool Function()? stop,
  }) async {
    var pushed = 0;
    while (!(stop?.call() ?? false) && pushed < limit) {
      try {
        _socket.add(bytes);
        await _socket.flush();
      } on IOException {
        break;
      } on StateError {
        break;
      }
      pushed += bytes.length;
    }
    return pushed;
  }

  void _end() {
    if (!_closed.isCompleted) _closed.complete();
  }
}
