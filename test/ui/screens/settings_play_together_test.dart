import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:swiftie_quiz/ui/kit/serif_input.dart';
import 'package:swiftie_quiz/ui/screens/settings_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

import 'settings_screen_test.dart' show FakePersistence, FakeUpdater;

final String _key = '${'Ab0-_' * 8}xyz';
final String _otherKey = '${'Zy9_-' * 8}abc';
final String serverLink = 'https://swiftie.satanshu.tech/#$_key';
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

Future<void> clickOff(WidgetTester tester) async {
  final title = find.text('Server link');
  await tester.ensureVisible(title);
  await tester.pumpAndSettle();
  await tester.tap(title, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

bool locked(WidgetTester tester) {
  final field = tester.widget<TextField>(serverLinkField());
  return field.obscureText && field.enabled == false;
}

void main() {
  for (final (window, saved) in [
    for (final window in const [
      Size(1024, 800),
      Size(1440, 900),
      Size(686, 571),
    ])
      for (final saved in [null, serverLink]) (window, saved),
  ]) {
    testWidgets('the server link spans the settings column at $window '
        '${saved == null ? 'while empty' : 'once saved'}', (tester) async {
      await pumpSettings(tester, savedLink: saved);
      tester.view.physicalSize = window;
      await tester.pumpAndSettle();
      await tester.ensureVisible(serverLinkField());
      await tester.pumpAndSettle();

      final input = tester.getRect(
        find.ancestor(of: serverLinkField(), matching: find.byType(SerifInput)),
      );
      final row = tester.getRect(
        find
            .ancestor(
              of: find.text('Server link'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.decoration is BoxDecoration &&
                    (widget.decoration! as BoxDecoration).border != null,
              ),
            )
            .first,
      );
      final title = tester.getRect(find.text('Server link'));

      expect(input.left, title.left);
      expect(input.width, row.width);
      expect(input.top, greaterThan(title.bottom));
    });
  }

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
    expect(settingsOf(container).togetherLink, serverLink);
    expect(connector.checked, [ServerLink.parse(serverLink)]);
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

    await tester.enterText(field, serverLink);
    await tester.pumpAndSettle();
    expect(settingsOf(container).togetherLink, serverLink);

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
      final (_, connector) = await pumpSettings(tester, savedLink: serverLink);
      final tokens = tokensOf(tester);

      expect(connector.checked, [ServerLink.parse(serverLink)], reason: line);
      expect(find.text('Checking…'), findsOneWidget, reason: line);
      expect(colorOf(tester, 'Checking…'), tokens.mut, reason: line);
      expect(
        tester.widget<TextField>(serverLinkField()).controller!.text,
        serverLink,
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

    final (_, connector) = await pumpSettings(tester, savedLink: serverLink);
    final field = serverLinkField();
    await tester.ensureVisible(field);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
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

    await tester.enterText(field, serverLink);
    await tester.pumpAndSettle();
    expect(connector.checked, hasLength(3));
    await tester.pumpWidget(const SizedBox());
    connector.answer(RelayFailure.busy);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a saved link shows as stars and changes only through Clear', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final (container, connector) = await pumpSettings(
      tester,
      savedLink: serverLink,
    );
    final field = serverLinkField();
    bool focused() => tester.widget<TextField>(field).focusNode!.hasFocus;

    await tester.ensureVisible(field);
    connector.answer(null);
    await tester.pumpAndSettle();
    expect(find.text('Connected to swiftie.satanshu.tech.'), findsOneWidget);
    expect(
      tester.getSemantics(field),
      isSemantics(
        label: 'Server link',
        value: '*' * serverLink.length,
        isObscured: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    expect(find.text('Clear'), findsOneWidget);

    await tester.tap(field, kind: PointerDeviceKind.mouse, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(focused(), isFalse);
    expect(settingsOf(container).togetherLink, serverLink);

    await tester.tap(find.text('Clear'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(settingsOf(container).togetherLink, isNull);
    expect(find.text('Clear'), findsNothing);
    expect(find.text('Connected to swiftie.satanshu.tech.'), findsNothing);
    expect(focused(), isTrue);
    expect(
      tester.getSemantics(field),
      isSemantics(value: '', isObscured: false, isEnabled: true),
    );

    await tester.enterText(field, 'not a link at all');
    await clickOff(tester);
    expect(focused(), isFalse);
    expect(settingsOf(container).togetherLink, isNull);
    expect(find.text('Clear'), findsNothing);
    expect(
      tester.getSemantics(field),
      isSemantics(value: '', isObscured: false, isEnabled: true),
    );

    await tester.enterText(field, _otherLink);
    await tester.pumpAndSettle();
    connector.answer(null);
    await tester.pumpAndSettle();
    expect(settingsOf(container).togetherLink, _otherLink);
    expect(find.text('Connected to swiftie.satanshu.tech.'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
    expect(
      tester.getSemantics(field),
      isSemantics(value: _otherLink, isObscured: false, isEnabled: true),
    );
    final node = tester.getSemantics(field).id;

    await clickOff(tester);
    expect(tester.getSemantics(field).id, node);
    expect(find.text('Connected to swiftie.satanshu.tech.'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
    expect(
      tester.getSemantics(field),
      isSemantics(
        value: '*' * _otherLink.length,
        isObscured: true,
        isEnabled: false,
      ),
    );
    expect(connector.checked, hasLength(2));
    semantics.dispose();
  });

  testWidgets(
    'undo after Clear cannot bring a link back',
    (tester) async {
      final (container, _) = await pumpSettings(tester);
      final field = serverLinkField();
      final undo = defaultTargetPlatform == TargetPlatform.macOS
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;

      await tester.ensureVisible(field);
      await tester.enterText(field, serverLink);
      await tester.pump(const Duration(seconds: 1));
      await clickOff(tester);
      expect(locked(tester), isTrue);
      await tester.tap(find.text('Clear'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(undo);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(undo);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(settingsOf(container).togetherLink, isNull);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }),
  );

  testWidgets('leaving the app locks a link being typed', (tester) async {
    await pumpSettings(tester);
    final field = serverLinkField();

    await tester.ensureVisible(field);
    await tester.enterText(field, serverLink);
    await tester.pumpAndSettle();
    expect(locked(tester), isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(locked(tester), isTrue);
    expect(find.text('Clear'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(locked(tester), isTrue);
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a restored save locks the field only for a real link', (
    tester,
  ) async {
    final (container, connector) = await pumpSettings(
      tester,
      savedLink: serverLink,
    );
    void restore(String? link) {
      final progress = container.read(gameControllerProvider).progress;
      container
          .read(gameControllerProvider.notifier)
          .setProgress(
            progress.copyWith(
              settings: progress.settings.copyWith(togetherLink: link),
            ),
          );
    }

    await tester.ensureVisible(serverLinkField());
    expect(locked(tester), isTrue);

    restore(null);
    await tester.pumpAndSettle();
    expect(locked(tester), isFalse);
    expect(find.text('Clear'), findsNothing);

    restore(_otherLink);
    await tester.pumpAndSettle();
    expect(locked(tester), isTrue);
    expect(find.text('Clear'), findsOneWidget);
    expect(connector.checked.last, ServerLink.parse(_otherLink));

    restore('not a link');
    await tester.pumpAndSettle();
    expect(locked(tester), isFalse);
    expect(find.text('Clear'), findsNothing);
    expect(find.text("That isn't a Play together link."), findsOneWidget);
  });

  testWidgets('Clear works from the keyboard', (tester) async {
    final (container, _) = await pumpSettings(tester, savedLink: serverLink);
    final field = serverLinkField();

    await tester.ensureVisible(field);
    Focus.of(tester.element(find.text('Clear'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(settingsOf(container).togetherLink, isNull);
    expect(locked(tester), isFalse);
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);

    tester.testTextInput.enterText(_otherLink);
    await tester.pumpAndSettle();
    expect(settingsOf(container).togetherLink, _otherLink);
  });
}
