import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/together/server_link.dart';

final String _key = '${'Ab0-_' * 8}xyz';

void main() {
  test('accepts an https link with a 43-character key', () {
    expect(_key, hasLength(43));

    final link = ServerLink.parse('https://swiftie.satanshu.tech/#$_key')!;

    expect(link.host, 'swiftie.satanshu.tech');
    expect(link.relayUri.toString(), 'wss://swiftie.satanshu.tech/v1');
    expect(link.checkUri.toString(), 'https://swiftie.satanshu.tech/v1/check');
    expect(link.key, _key);
    expect(link.text, 'https://swiftie.satanshu.tech/#$_key');

    expect(ServerLink.parse('  https://swiftie.satanshu.tech/#$_key \n'), link);
    expect(ServerLink.parse('https://swiftie.satanshu.tech#$_key'), link);

    final withPort = ServerLink.parse(
      'https://swiftie.satanshu.tech:8443/#$_key',
    )!;

    expect(withPort.host, 'swiftie.satanshu.tech:8443');
    expect(withPort.relayUri.toString(), 'wss://swiftie.satanshu.tech:8443/v1');
    expect(
      withPort.checkUri.toString(),
      'https://swiftie.satanshu.tech:8443/v1/check',
    );
    expect(withPort.text, 'https://swiftie.satanshu.tech:8443/#$_key');
    expect(withPort, isNot(link));
  });

  test(
    'rejects links that are not https, lack a key or have a malformed key',
    () {
      final rejected = [
        'http://swiftie.satanshu.tech/#$_key',
        'http://localhost.satanshu.tech/#$_key',
        'wss://swiftie.satanshu.tech/#$_key',
        'https://swiftie.satanshu.tech/',
        'https://swiftie.satanshu.tech/#',
        'https://swiftie.satanshu.tech/#${_key.substring(1)}',
        'https://swiftie.satanshu.tech/#${_key}A',
        'https://swiftie.satanshu.tech/#+${_key.substring(1)}',
        'https://swiftie.satanshu.tech/#/${_key.substring(1)}',
        'https://swiftie.satanshu.tech/?room=ABCD#$_key',
        'https://swiftie.satanshu.tech/v1#$_key',
        'https://friend@swiftie.satanshu.tech/#$_key',
        'https:///#$_key',
        _key,
        '',
      ];

      for (final input in rejected) {
        expect(ServerLink.parse(input), isNull, reason: input);
      }
    },
  );

  test('loopback http is allowed for local servers', () {
    final localhost = ServerLink.parse('http://localhost:8080/#$_key')!;

    expect(localhost.host, 'localhost:8080');
    expect(localhost.relayUri.toString(), 'ws://localhost:8080/v1');
    expect(localhost.checkUri.toString(), 'http://localhost:8080/v1/check');
    expect(localhost.key, _key);
    expect(localhost.text, 'http://localhost:8080/#$_key');

    final ipv4 = ServerLink.parse('http://127.0.0.1/#$_key')!;

    expect(ipv4.relayUri.toString(), 'ws://127.0.0.1/v1');
    expect(ipv4.checkUri.toString(), 'http://127.0.0.1/v1/check');

    final ipv6 = ServerLink.parse('http://[::1]:9000/#$_key')!;

    expect(ipv6.host, '[::1]:9000');
    expect(ipv6.relayUri.toString(), 'ws://[::1]:9000/v1');
    expect(ipv6.checkUri.toString(), 'http://[::1]:9000/v1/check');
    expect(ipv6.text, 'http://[::1]:9000/#$_key');
  });
}
