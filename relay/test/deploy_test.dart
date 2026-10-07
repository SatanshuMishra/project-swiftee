import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('the compose file runs the relay read-only, unprivileged and without new privileges', () {
    final compose =
        loadYaml(File('deploy/compose.yaml').readAsStringSync()) as YamlMap;
    final relay = (compose['services'] as YamlMap)['relay'] as YamlMap;

    expect(relay['user'], '1000:1000');
    expect(relay['read_only'], isTrue);
    expect(relay['cap_drop'], ['ALL']);
    expect(relay['security_opt'], contains('no-new-privileges:true'));
    expect(relay['mem_limit'], '128m');
    expect(relay['pids_limit'], 64);
    expect(relay['tmpfs'], ['/tmp']);
    expect(relay.containsKey('ports'), isFalse);
    expect(relay.containsKey('privileged'), isFalse);

    final volumes = relay['volumes'] as YamlList;
    expect(volumes, hasLength(1));
    final keyMount = volumes.single as YamlMap;
    expect(keyMount['type'], 'bind');
    expect(keyMount['source'], startsWith(r'${RELAY_KEY_PATH:?'));
    expect(keyMount['target'], '/run/relay.key');
    expect(keyMount['read_only'], isTrue);
    expect(
      (relay['environment'] as YamlMap)['RELAY_KEY_FILE'],
      '/run/relay.key',
    );
    expect((relay['healthcheck'] as YamlMap)['test'], [
      'CMD',
      '/app/bin/relay',
      '--health',
    ]);
  });
}
