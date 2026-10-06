import 'package:swiftie_quiz/domain/models/edition.dart';

const updateEndpoint =
    'https://github.com/SatanshuMishra/project-swiftee/releases/latest/download/latest.json';

// dart format off
const updaterPublicKey = 'dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk6IEU0NEZFQkM5NDVEQTlCRUYKUldUdm05cEZ5ZXRQNUs3a2RLYkpuUzU4cTVEN20yR1NpZE9iQXdiZWxOZDlQZC9Vczd1QUtMdDgK';
// dart format on

const updateCheckTimeout = Duration(seconds: 10);

enum UpdatePlatform {
  macos('darwin-aarch64'),
  windows('windows-x86_64'),
  windowsOpen('windows-x86_64-open');

  const UpdatePlatform(this.manifestKey);

  final String manifestKey;

  static UpdatePlatform? forBuild(String operatingSystem, Edition edition) =>
      switch ((operatingSystem, edition)) {
        ('macos', _) => UpdatePlatform.macos,
        ('windows', Edition.ana) => UpdatePlatform.windows,
        ('windows', Edition.open) => UpdatePlatform.windowsOpen,
        _ => null,
      };
}
