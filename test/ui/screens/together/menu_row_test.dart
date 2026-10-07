import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/misu_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/kit/arrow_row.dart';
import 'package:swiftie_quiz/ui/screens/main_menu.dart';
import 'package:swiftie_quiz/ui/screens/together/together_hub_screen.dart';
import 'package:swiftie_quiz/ui/screens/together/together_nav.dart';
import 'package:swiftie_quiz/ui/screens/together/together_shell.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';

import '../main_menu_test.dart' show RecordingCatalog, RecordingMisu;

final String _link = 'https://swiftie.satanshu.tech/#${'Ab0-_' * 8}xyz';

class _PhaseScreen extends ConsumerWidget {
  const _PhaseScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(gameControllerProvider.select((game) => game.phase)) ==
          GamePhase.together
      ? const TogetherShell()
      : const MainMenu();
}

Future<ProviderContainer> pumpMenu(
  WidgetTester tester, {
  String? togetherLink,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer.test(
    overrides: [
      editionProvider.overrideWithValue(Edition.open),
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 6, 20)),
      misuControllerProvider.overrideWith(RecordingMisu.new),
      catalogControllerProvider.overrideWith(RecordingCatalog.new),
    ],
  );
  container
      .read(gameControllerProvider.notifier)
      .setProgress(
        defaultProgress.copyWith(
          settings: defaultProgress.settings.copyWith(
            nickname: 'Sam',
            togetherLink: togetherLink,
          ),
        ),
      );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Material(child: _PhaseScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder rowOf(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(ArrowRow));

GamePhase phaseOf(ProviderContainer container) =>
    container.read(gameControllerProvider).phase;

void main() {
  testWidgets('with a saved link the third row opens the Play together hub', (
    tester,
  ) async {
    final container = await pumpMenu(tester, togetherLink: _link);
    container.read(togetherNavProvider.notifier).show(TogetherScreen.join);

    expect(
      [
        for (final row in tester.widgetList<ArrowRow>(find.byType(ArrowRow)))
          row.title,
      ],
      ['Shuffle everything', 'Pick your eras', 'Play together'],
    );
    final row = tester.widget<ArrowRow>(rowOf('Play together'));
    expect(row.description, 'Host a room or join one.');
    expect(row.primary, isFalse);
    expect(
      tester
          .widget<Opacity>(
            find
                .descendant(
                  of: rowOf('Play together'),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity,
      1,
    );

    await tester.tap(find.text('Play together'));
    await tester.pumpAndSettle();

    expect(phaseOf(container), GamePhase.together);
    expect(container.read(togetherNavProvider), TogetherScreen.hub);
    expect(find.byType(MainMenu), findsNothing);
    expect(find.byType(TogetherHubScreen), findsOneWidget);
    expect(find.text('Play together'), findsOneWidget);
    expect(
      find.text(
        'Same room or far apart. One person hosts, everyone else joins with '
        'a code. No accounts.',
      ),
      findsOneWidget,
    );
    expect(find.text('Host a room'), findsOneWidget);
    expect(find.text('Pick a game, then share the code.'), findsOneWidget);
    expect(find.text('Join a room'), findsOneWidget);
    expect(find.text('Got a code from a friend? Pop it in.'), findsOneWidget);
  });

  testWidgets('without a link the row is dimmed, says why and ignores taps', (
    tester,
  ) async {
    for (final link in [null, 'https://swiftie.satanshu.tech/#short']) {
      final container = await pumpMenu(tester, togetherLink: link);

      final row = tester.widget<ArrowRow>(rowOf('Play together'));
      expect(row.onTap, isNull, reason: link);
      expect(row.description, 'Add a server link in Settings first.');
      expect(find.text('Add a server link in Settings first.'), findsOneWidget);
      expect(find.text('Host a room or join one.'), findsNothing);
      final opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: rowOf('Play together'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 0.45, reason: link);

      await tester.tap(find.text('Play together'));
      await tester.pumpAndSettle();

      expect(phaseOf(container), GamePhase.menu, reason: link);
      expect(find.byType(MainMenu), findsOneWidget);
      expect(find.byType(TogetherShell), findsNothing);
    }
  });
}
