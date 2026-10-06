import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/backup_entry.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/persistence_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/screens/album_grid.dart';
import 'package:swiftie_quiz/ui/screens/settings_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';

final DateTime afterBirthdayPeriod = DateTime(2026, 10, 5, 12);

class IdleCatalog extends CatalogController {
  @override
  CatalogState build() => CatalogState.initial;

  @override
  Future<void> loadCatalogue() async {}
}

class NoBackups extends PersistenceController {
  @override
  PersistenceStatus build() => PersistenceStatus.loaded;

  @override
  Future<List<BackupEntry>> listBackups() async => const [];
}

typedef Setup = void Function(GameController game);

Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Setup? setup,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer.test(
    overrides: [
      clockProvider.overrideWithValue(() => afterBirthdayPeriod),
      catalogControllerProvider.overrideWith(IdleCatalog.new),
      persistenceControllerProvider.overrideWith(NoBackups.new),
      appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
    ],
  );
  setup?.call(container.read(gameControllerProvider.notifier));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      key: ObjectKey(container),
      container: container,
      child: MaterialApp(theme: AppTheme.dark, home: screen),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

GameState gameOf(ProviderContainer container) =>
    container.read(gameControllerProvider);

Future<void> tapBack(WidgetTester tester) async {
  await tester.tap(find.text('Back'));
  await tester.pump();
}

void main() {
  group('selection navigation', () {
    testWidgets('album select and settings go back to the menu', (
      tester,
    ) async {
      for (final screen in const [AlbumGrid(), SettingsScreen()]) {
        final container = await pumpScreen(
          tester,
          screen,
          setup: (game) => game.setPhase(GamePhase.settings),
        );
        expect(gameOf(container).phase, GamePhase.settings);

        await tapBack(tester);

        expect(
          gameOf(container).phase,
          GamePhase.menu,
          reason: '${screen.runtimeType}',
        );
      }
    });
  });
}
