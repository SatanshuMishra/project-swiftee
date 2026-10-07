import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/data/together/relay_connection.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/together/server_link.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/persistence_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/state/updater_controller.dart';
import 'package:swiftie_quiz/ui/screens/settings_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

import 'settings_screen_test.dart' show FakePersistence, FakeUpdater;

final String _key = '${'Ab0-_' * 8}xyz';
final String _otherKey = '${'Zy9_-' * 8}abc';
final String _link = 'https://swiftie.satanshu.tech/#$_key';
final String _otherLink = 'https://swiftie.satanshu.tech/#$_otherKey';

final class FakeConnector implements RelayConnector {
  List<ServerLink> _checked = const [];
  List<Completer<void>> _pending = const [];

  List<ServerLink> get checked => _checked;

  void answer(RelayFailure? failure, {int index = -1}) {
    final pending = index < 0 ? _pending.last : _pending[index];
    if (failure == null) {
      pending.complete();
    } else {
      pending.completeError(RelayRefused(failure));
    }
  }

  @override
  Future<void> check(ServerLink link) {
    final pending = Completer<void>();
    _checked = [..._checked, link];
    _pending = [..._pending, pending];
    return pending.future;
  }

  @override
  Future<RelayConnection> connect(ServerLink link) =>
      throw UnimplementedError();
}

Future<(ProviderContainer, FakeConnector)> pumpSettings(
  WidgetTester tester, {
  String? savedLink,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final connector = FakeConnector();
  final container = ProviderContainer.test(
    overrides: [
      editionProvider.overrideWithValue(Edition.open),
      persistenceControllerProvider.overrideWith(FakePersistence.new),
      updaterControllerProvider.overrideWith(FakeUpdater.new),
      appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
      relayConnectorProvider.overrideWithValue(connector),
    ],
  );
  if (savedLink != null) {
    container.read(gameControllerProvider.notifier).setTogetherLink(savedLink);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      key: ObjectKey(container),
      container: container,
      child: MaterialApp(theme: AppTheme.dark, home: const SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return (container, connector);
}

Finder serverLinkField() => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == 'Server link',
  ),
  matching: find.byType(TextField),
);

GameSettings settingsOf(ProviderContainer container) =>
    container.read(gameControllerProvider).progress.settings;

Color? colorOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

AppTokens tokensOf(WidgetTester tester) =>
    AppTokens.of(tester.element(find.byType(SettingsScreen)));

void main() {
  testWidgets('a pasted link is saved and an invalid one is not', (
    tester,
  ) async {
    final (container, connector) = await pumpSettings(tester);
    final tokens = tokensOf(tester);
    final field = serverLinkField();

    expect(find.text('Play together'), findsOneWidget);
    expect(find.text('Server link'), findsOneWidget);
    expect(
      find.text('Paste the link from whoever runs your server.'),
      findsOneWidget,
    );
    expect(settingsOf(container).togetherLink, isNull);
    expect(connector.checked, isEmpty);

    await tester.ensureVisible(field);
    await tester.enterText(field, '  https://swiftie.satanshu.tech#$_key ');
    await tester.pumpAndSettle();
    expect(settingsOf(container).togetherLink, _link);
    expect(connector.checked, [ServerLink.parse(_link)]);
    expect(find.text("That isn't a Play together link."), findsNothing);

    await tester.enterText(field, 'not a link at all');
    await tester.pumpAndSettle();
    expect(settingsOf(container).togetherLink, isNull);
    expect(find.text("That isn't a Play together link."), findsOneWidget);
    expect(colorOf(tester, "That isn't a Play together link."), tokens.rose);

    await tester.enterText(field, 'http://swiftie.satanshu.tech/#$_key');
    await tester.pumpAndSettle();
    expect(settingsOf(container).togetherLink, isNull);
    expect(find.text("That isn't a Play together link."), findsOneWidget);

    await tester.enterText(field, _link);
    await tester.pumpAndSettle();
    expect(settingsOf(container).togetherLink, _link);

    await tester.enterText(field, '');
    await tester.pumpAndSettle();
    expect(settingsOf(container).togetherLink, isNull);
    expect(find.text("That isn't a Play together link."), findsNothing);
    expect(find.text('Checking…'), findsNothing);
    expect(connector.checked, hasLength(2));
  });

  testWidgets('each check result shows its line', (tester) async {
    for (final (failure, line, rose) in [
      (null, 'Connected to swiftie.satanshu.tech.', false),
      (RelayFailure.badLink, "The server didn't accept that link.", true),
      (
        RelayFailure.needsUpdate,
        'That server needs a newer Project Swiftie.',
        true,
      ),
      (RelayFailure.busy, 'The server is busy. Try again in a minute.', true),
      (RelayFailure.unreachable, "Couldn't reach the server.", true),
    ]) {
      final (_, connector) = await pumpSettings(tester, savedLink: _link);
      final tokens = tokensOf(tester);

      expect(connector.checked, [ServerLink.parse(_link)], reason: line);
      expect(find.text('Checking…'), findsOneWidget, reason: line);
      expect(colorOf(tester, 'Checking…'), tokens.mut, reason: line);
      expect(
        tester.widget<TextField>(serverLinkField()).controller!.text,
        _link,
      );

      connector.answer(failure);
      await tester.pumpAndSettle();

      expect(find.text('Checking…'), findsNothing, reason: line);
      expect(find.text(line), findsOneWidget, reason: line);
      expect(
        colorOf(tester, line),
        rose ? tokens.rose : tokens.mut,
        reason: line,
      );
      expect(connector.checked, hasLength(1), reason: line);
    }

    final (_, connector) = await pumpSettings(tester, savedLink: _link);
    final field = serverLinkField();
    await tester.ensureVisible(field);
    await tester.enterText(field, _otherLink);
    await tester.pumpAndSettle();
    expect(connector.checked, hasLength(2));

    connector.answer(RelayFailure.badLink, index: 0);
    await tester.pumpAndSettle();
    expect(find.text('Checking…'), findsOneWidget);
    expect(find.text("The server didn't accept that link."), findsNothing);

    connector.answer(null, index: 1);
    await tester.pumpAndSettle();
    expect(find.text('Connected to swiftie.satanshu.tech.'), findsOneWidget);

    await tester.enterText(field, _link);
    await tester.pumpAndSettle();
    expect(connector.checked, hasLength(3));
    await tester.pumpWidget(const SizedBox());
    connector.answer(RelayFailure.busy);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
