import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
        limits: const RelayLimits(maxSocketsPerAddress: 50),
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
      limits: const RelayLimits(maxSocketsPerAddress: 32),
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
      await throttled.status(checkPath, from('198.51.100.1')),
      statusTooMany,
    );
    expect(
      await throttled.status(relayPath, from('198.51.100.1')),
      statusTooMany,
    );
    expect(
      await throttled.status(checkPath, from('198.51.100.2')),
      statusChecked,
    );
    expect(await throttled.status(checkPath, admitted), statusChecked);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(
      await throttled.status(checkPath, from('198.51.100.1')),
      statusChecked,
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
      await untrusting.status(checkPath, from('198.51.100.4')),
      statusTooMany,
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
}

String _code(RoomJoined joined) => joined.code;

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

  Future<(Peer, RoomOpened)> open(String name) async {
    final host = await connect();
    host.send(OpenRoom(name: name, game: game));
    final opened = await host.next();
    expect(opened, isA<RoomOpened>());
    return (host, opened as RoomOpened);
  }

  Future<(Peer, RoomJoined)> join(String code, String name) async {
    final guest = await connect();
    guest.send(JoinRoom(code: code, name: name, game: game));
    final joined = await guest.next();
    expect(joined, isA<RoomJoined>());
    return (guest, joined as RoomJoined);
  }

  Future<void> _close() async {
    await server.close();
    _http.close(force: true);
  }
}

final class Peer {
  Peer(this.socket) {
    socket.done.ignore();
    socket.listen(_inbox.add, onDone: _inbox.close);
  }

  final WebSocket socket;
  final _inbox = StreamController<Object?>();
  late final _frames = StreamIterator<Object?>(_inbox.stream);

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
    while (await _frames.moveNext().timeout(patience)) {}
  }
}
