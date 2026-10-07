import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:swiftie_quiz/data/together/relay_connection.dart';
import 'package:swiftie_quiz/domain/together/server_link.dart';
import 'package:together_protocol/together_protocol.dart';

final String _key = '${'Ab0-_' * 8}xyz';

typedef _Seen = ({String path, String? authorization, String? protocol});

typedef _RelaySide = ({WebSocket socket, Future<List<Object?>> frames});

typedef _FakeRelay = ({
  ServerLink link,
  List<_Seen> seen,
  Stream<_RelaySide> sockets,
});

final _Seen _checkWithKey = (
  path: checkPath,
  authorization: '$bearerPrefix$_key',
  protocol: '$relayProtocolVersion',
);

final _Seen _upgradeWithKey = (
  path: relayPath,
  authorization: '$bearerPrefix$_key',
  protocol: '$relayProtocolVersion',
);

Future<_FakeRelay> _startRelay({int? checkAnswer = statusChecked}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final seen = <_Seen>[];
  final upgraded = <WebSocket>[];
  final sockets = StreamController<_RelaySide>();
  addTearDown(() async {
    await server.close(force: true);
    await Future.wait([for (final socket in upgraded) socket.close()]);
    unawaited(sockets.close());
  });
  server.listen((request) async {
    seen.add((
      path: request.uri.path,
      authorization: request.headers.value(HttpHeaders.authorizationHeader),
      protocol: request.headers.value(relayProtocolHeader),
    ));
    if (request.uri.path == relayPath &&
        WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      upgraded.add(socket);
      sockets.add((socket: socket, frames: socket.toList()));
      return;
    }
    if (request.uri.path == checkPath && checkAnswer == null) {
      return;
    }
    request.response.statusCode = request.uri.path == checkPath
        ? checkAnswer!
        : HttpStatus.notFound;
    await request.response.close();
  });
  return (
    link: ServerLink.parse('http://127.0.0.1:${server.port}/#$_key')!,
    seen: seen,
    sockets: sockets.stream,
  );
}

Future<ServerLink> _closedPortLink() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();
  return ServerLink.parse('http://127.0.0.1:$port/#$_key')!;
}

HttpRelayConnector _connector({Duration timeout = const Duration(seconds: 8)}) {
  final client = http.Client();
  addTearDown(client.close);
  return HttpRelayConnector(
    client: client,
    openSocket: (uri, headers) =>
        WebSocket.connect(uri.toString(), headers: headers),
    timeout: timeout,
  );
}

Future<RelayFailure?> _refusal(Future<void> attempt) async {
  try {
    await attempt;
    return null;
  } on RelayRefused catch (refused) {
    return refused.failure;
  }
}

Future<RelayConnection> _connect(ServerLink link) async {
  final connection = await _connector().connect(link);
  addTearDown(connection.close);
  return connection;
}

const _maya = Player(id: 'p1', name: 'Maya', avatar: 'a1');

void main() {
  test('check reports a working server, a refused link, an old app and an unreachable server', () async {
    final connector = _connector();
    final answers = <int, RelayFailure?>{
      statusChecked: null,
      statusBadKey: RelayFailure.badLink,
      statusNeedsUpdate: RelayFailure.needsUpdate,
      statusTooMany: RelayFailure.busy,
      statusBusy: RelayFailure.busy,
      HttpStatus.notFound: RelayFailure.unreachable,
      HttpStatus.internalServerError: RelayFailure.unreachable,
    };

    for (final MapEntry(key: status, value: failure) in answers.entries) {
      final relay = await _startRelay(checkAnswer: status);

      expect(
        await _refusal(connector.check(relay.link)),
        failure,
        reason: '$status',
      );
      expect(relay.seen, [_checkWithKey], reason: '$status');
    }

    expect(
      await _refusal(connector.check(await _closedPortLink())),
      RelayFailure.unreachable,
    );

    final silent = await _startRelay(checkAnswer: null);

    expect(
      await _refusal(
        _connector(timeout: const Duration(milliseconds: 200))
            .check(silent.link),
      ),
      RelayFailure.unreachable,
    );
  });

  test(
    'connect sends the key and protocol headers and decodes relay messages',
    () async {
      final refusing = await _startRelay(checkAnswer: statusBadKey);

      expect(
        await _refusal(_connector().connect(refusing.link)),
        RelayFailure.badLink,
      );
      expect(refusing.seen, [_checkWithKey]);

      final relay = await _startRelay();
      final sockets = StreamIterator(relay.sockets);
      final connection = await _connect(relay.link);
      final received = connection.messages.toList();
      await sockets.moveNext();
      const opened = RoomOpened(code: 'ABCD', you: _maya);

      expect(relay.seen, [_checkWithKey, _upgradeWithKey]);

      sockets.current.socket
        ..add(opened.encode())
        ..add(const RoomClosed().encode());
      await sockets.current.socket.close();

      expect(await received, [opened, const RoomClosed()]);

      final strict = await _connect(relay.link);
      final strictReceived = strict.messages.toList();
      await sockets.moveNext();
      final relaySide = sockets.current;
      relaySide.socket
        ..add(opened.encode())
        ..add('{"t":"surprise"}')
        ..add(const RoomClosed().encode());

      expect(await strictReceived, [opened]);
      await relaySide.frames;
      expect(relaySide.socket.closeCode, closePolicy);
      await sockets.cancel();
    },
  );

  test('messages the app sends reach the relay as protocol JSON', () async {
    final relay = await _startRelay();
    final connection = await _connect(relay.link);
    final relaySide = await relay.sockets.first;
    const open = OpenRoom(name: 'Maya', game: 1);
    final body = SendBody(body: const {'k': 'pick', 'option': 2}, to: 'p1');

    connection
      ..send(open)
      ..send(body);
    await connection.close();
    final frames = (await relaySide.frames).cast<String>();

    expect(jsonDecode(frames.first), {'t': 'open', 'name': 'Maya', 'game': 1});
    expect(
      [for (final frame in frames) ClientMessage.decode(frame)],
      [open, body],
    );
    await expectLater(connection.messages, emitsDone);
  });
}
