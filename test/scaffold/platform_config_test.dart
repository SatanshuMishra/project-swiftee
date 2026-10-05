import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String readRepoFile(String relativePath) =>
    File(relativePath).readAsStringSync();

Map<String, String> xcconfigSettings(String source) => {
  for (final match in RegExp(
    r'^([A-Z_]+)\s*=\s*(.*?)\s*$',
    multiLine: true,
  ).allMatches(source))
    match.group(1)!: match.group(2)!,
};

Map<String, bool> plistFlags(String source) => {
  for (final match in RegExp(
    r'<key>([^<]+)</key>\s*<(true|false)\s*/>',
  ).allMatches(source))
    match.group(1)!: match.group(2) == 'true',
};

Map<String, String> plistStrings(String source) => {
  for (final match in RegExp(
    r'<key>([^<]+)</key>\s*<string>([^<]*)</string>',
  ).allMatches(source))
    match.group(1)!: match.group(2)!,
};

List<String> buildSettingsBlocks(String pbxproj) => [
  for (final match in RegExp(
    r'isa = XCBuildConfiguration;.*?buildSettings = \{(.*?)\n\t\t\t\};',
    dotAll: true,
  ).allMatches(pbxproj))
    match.group(1)!,
];

Map<String, String> versionResourceValues(String source) => {
  for (final match in RegExp(r'VALUE "(\w+)", "([^"]*)"').allMatches(source))
    match.group(1)!: match.group(2)!,
};

void main() {
  group('platform identity matches the Tauri app', () {
    test('macOS app info carries the bundle id, name and copyright', () {
      final settings = xcconfigSettings(
        readRepoFile('macos/Runner/Configs/AppInfo.xcconfig'),
      );

      expect(settings['PRODUCT_BUNDLE_IDENTIFIER'], 'com.swiftiequiz.desktop');
      expect(settings['PRODUCT_NAME'], 'Swiftie Quiz');
      expect(settings['PRODUCT_COPYRIGHT'], 'Copyright © 2026 Satanshu Mishra');
    });

    test('every Xcode build configuration targets macOS 12.0', () {
      final project = readRepoFile('macos/Runner.xcodeproj/project.pbxproj');
      final configurationCount = 'isa = XCBuildConfiguration;'
          .allMatches(project)
          .length;
      final blocks = buildSettingsBlocks(project);
      final targets = RegExp(r'MACOSX_DEPLOYMENT_TARGET = ([^;]+);')
          .allMatches(project)
          .map((match) => match.group(1))
          .toList();

      expect(configurationCount, greaterThan(0));
      expect(blocks, hasLength(configurationCount));
      for (final block in blocks) {
        expect(block, contains('MACOSX_DEPLOYMENT_TARGET = 12.0;'));
      }
      expect(targets, everyElement('12.0'));
    });

    test('Info.plist enforces the deployment target and product name', () {
      final info = plistStrings(readRepoFile('macos/Runner/Info.plist'));

      expect(info['LSMinimumSystemVersion'], r'$(MACOSX_DEPLOYMENT_TARGET)');
      expect(info['CFBundleName'], r'$(PRODUCT_NAME)');
      expect(info['CFBundleIdentifier'], r'$(PRODUCT_BUNDLE_IDENTIFIER)');
    });

    test('both macOS entitlements disable the sandbox and allow outgoing '
        'network', () {
      for (final path in [
        'macos/Runner/DebugProfile.entitlements',
        'macos/Runner/Release.entitlements',
      ]) {
        final flags = plistFlags(readRepoFile(path));

        expect(flags['com.apple.security.app-sandbox'], isFalse, reason: path);
        expect(
          flags['com.apple.security.network.client'],
          isTrue,
          reason: path,
        );
      }
    });

    test('Windows executable is named swiftie-quiz', () {
      final cmake = readRepoFile('windows/CMakeLists.txt');

      expect(
        RegExp(r'set\(BINARY_NAME "([^"]*)"\)').firstMatch(cmake)?.group(1),
        'swiftie-quiz',
      );
    });

    test('Windows version resource describes Swiftie Quiz', () {
      final values = versionResourceValues(
        readRepoFile('windows/runner/Runner.rc'),
      );

      expect(values['ProductName'], 'Swiftie Quiz');
      expect(values['FileDescription'], 'Swiftie Quiz');
      expect(values['CompanyName'], 'swiftiequiz');
      expect(values['InternalName'], 'swiftie-quiz');
      expect(values['OriginalFilename'], 'swiftie-quiz.exe');
      expect(values['LegalCopyright'], 'Copyright (C) 2026 Satanshu Mishra');
    });
  });
}
