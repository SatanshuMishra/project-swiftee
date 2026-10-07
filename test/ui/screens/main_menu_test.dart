import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/achievements.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/misu_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/cat/cat_icon.dart';
import 'package:swiftie_quiz/ui/kit/arrow_row.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/vinyl.dart';
import 'package:swiftie_quiz/ui/overlays/birthday_card.dart';
import 'package:swiftie_quiz/ui/screens/main_menu.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

final DateTime outsideBirthday = DateTime(2026, 10, 6, 20);
final DateTime insideBirthday = DateTime(2026, 2, 19, 12);

const String cardPrompt = "Misu's keeping your birthday card safe.";

class RecordingGame extends GameController {
  List<GameMode> setups = const [];
  int quickRounds = 0;

  @override
  void beginSetup(GameMode mode) {
    setups = [...setups, mode];
    super.beginSetup(mode);
  }

  @override
  void startQuickRound() {
    quickRounds += 1;
    super.startQuickRound();
  }
}

class RecordingMisu extends MisuController {
  List<DateTime> greetings = const [];

  @override
  void greet(DateTime now) {
    greetings = [...greetings, now];
    state = state.copyWith(greeted: true);
  }
}

class RecordingCatalog extends CatalogController {
  int loads = 0;

  @override
  CatalogState build() => CatalogState.initial;

  @override
  Future<void> loadCatalogue() async => loads += 1;
}

Widget menuApp(
  ProviderContainer container, {
  Widget home = const MainMenu(),
  bool reducedMotion = false,
}) => UncontrolledProviderScope(
  key: UniqueKey(),
  container: container,
  child: MaterialApp(
    theme: AppTheme.dark,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
      child: app!,
    ),
    home: Material(child: home),
  ),
);

Future<ProviderContainer> pumpMenu(
  WidgetTester tester, {
  required Edition edition,
  required DateTime now,
  String? nickname,
  Map<String, AchievementState> achievements = const {},
  List<Album> albums = const [],
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = const Size(1024, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer.test(
    overrides: [
      editionProvider.overrideWithValue(edition),
      clockProvider.overrideWithValue(() => now),
      gameControllerProvider.overrideWith(RecordingGame.new),
      misuControllerProvider.overrideWith(RecordingMisu.new),
      catalogControllerProvider.overrideWith(RecordingCatalog.new),
    ],
  );
  final game = container.read(gameControllerProvider.notifier)
    ..setProgress(defaultProgress.copyWith(achievements: achievements))
    ..setAlbums(albums);
  if (nickname != null) {
    game.setNickname(nickname);
  }
  await tester.pumpWidget(menuApp(container, reducedMotion: reducedMotion));
  return container;
}

Future<void> remountMenu(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(menuApp(container, home: const SizedBox()));
  await tester.pumpWidget(menuApp(container));
}

RecordingGame gameOf(ProviderContainer container) =>
    container.read(gameControllerProvider.notifier) as RecordingGame;

RecordingMisu misuOf(ProviderContainer container) =>
    container.read(misuControllerProvider.notifier) as RecordingMisu;

Pressable pressableOf(WidgetTester tester, String label) =>
    tester.widget<Pressable>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Pressable))
          .first,
    );

Pressable? focusedPressable() => FocusManager.instance.primaryFocus?.context
    ?.findAncestorWidgetOfExactType<Pressable>();

double riseOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.text(cardPrompt),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

AnimatedScale catScale(WidgetTester tester) => tester.widget<AnimatedScale>(
  find.ancestor(of: find.byType(CatIcon), matching: find.byType(AnimatedScale)),
);

double arrowNudge(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .ancestor(of: find.text('Open it'), matching: find.byType(Transform))
          .first,
    )
    .transform
    .getTranslation()
    .x;

GamePhase phaseOf(ProviderContainer container) =>
    container.read(gameControllerProvider).phase;

void main() {
  testWidgets('the greeting follows the time of day and edition', (
    tester,
  ) async {
    const parts = [
      (
        hour: 8,
        opening: 'Good morning, ',
        closing: '.',
        subline: 'Coffee first, then a quiz.',
      ),
      (
        hour: 14,
        opening: 'Good afternoon, ',
        closing: '.',
        subline: 'Perfect time for a quick round.',
      ),
      (
        hour: 19,
        opening: 'Good evening, ',
        closing: '.',
        subline: "Long story short, it's a good night for a quiz.",
      ),
      (
        hour: 1,
        opening: 'Still up, ',
        closing: '?',
        subline: 'Midnights, but make it a quiz.',
      ),
    ];
    const players = [
      (edition: Edition.ana, nickname: null, name: 'Ana'),
      (edition: Edition.open, nickname: 'Sam', name: 'Sam'),
    ];

    for (final player in players) {
      for (final part in parts) {
        final now = DateTime(2026, 10, 6, part.hour);
        final reason = '${player.edition.name} at ${part.hour}:00';
        final container = await pumpMenu(
          tester,
          edition: player.edition,
          now: now,
          nickname: player.nickname,
        );

        final heading = find.text(
          '${part.opening}${player.name}${part.closing}',
        );
        expect(heading, findsOneWidget, reason: reason);
        final text = tester.widget<Text>(heading);
        expect(text.style?.fontFamily, 'Instrument Serif', reason: reason);
        expect(text.style?.fontSize, 56, reason: reason);
        final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
        expect(
          [for (final span in spans) span.text],
          [part.opening, player.name, part.closing],
          reason: reason,
        );
        expect(spans[1].style?.fontStyle, FontStyle.italic, reason: reason);
        expect(spans[1].style?.color, AppTokens.dark.coralT, reason: reason);
        expect(find.text(part.subline), findsOneWidget, reason: reason);

        final misu = misuOf(container);
        await tester.pump(const Duration(milliseconds: 899));
        expect(misu.greetings, isEmpty, reason: reason);
        await tester.pump(const Duration(milliseconds: 1));
        expect(misu.greetings, [now], reason: reason);

        await remountMenu(tester, container);
        await tester.pump(const Duration(seconds: 2));
        expect(misu.greetings, [now], reason: reason);
      }
    }
  });

  testWidgets('only the ana edition keeps the birthday card', (tester) async {
    final ana = await pumpMenu(
      tester,
      edition: Edition.ana,
      now: outsideBirthday,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text(cardPrompt), findsOneWidget);
    expect(find.text('Open it'), findsOneWidget);
    expect(find.text(BirthdayCard.greeting), findsNothing);
    expect(misuOf(ana).greetings, [outsideBirthday]);

    await tester.tap(find.text(cardPrompt));
    await tester.pumpAndSettle();
    expect(find.text('For Ana'), findsOneWidget);
    expect(find.text('Dear Ana,'), findsOneWidget);
    expect(ana.read(birthdayCardSessionProvider), isFalse);

    await tester.tap(find.text('✕'));
    await tester.pumpAndSettle();
    expect(find.text('Dear Ana,'), findsNothing);

    await tester.tap(find.text('Open it'));
    await tester.pumpAndSettle();
    expect(find.text('Dear Ana,'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Dear Ana,'), findsNothing);

    final birthday = await pumpMenu(
      tester,
      edition: Edition.ana,
      now: insideBirthday,
    );
    await tester.pump(const Duration(milliseconds: 999));
    expect(find.text('Dear Ana,'), findsNothing);
    expect(birthday.read(birthdayCardSessionProvider), isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Dear Ana,'), findsOneWidget);
    expect(birthday.read(birthdayCardSessionProvider), isTrue);
    expect(misuOf(birthday).greetings, isEmpty);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('Dear Ana,'), findsNothing);
    await remountMenu(tester, birthday);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Dear Ana,'), findsNothing);
    expect(misuOf(birthday).greetings, isEmpty);

    final open = await pumpMenu(
      tester,
      edition: Edition.open,
      now: insideBirthday,
      nickname: 'Sam',
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(cardPrompt), findsNothing);
    expect(find.text('Open it'), findsNothing);
    expect(find.byType(BirthdayCard), findsNothing);
    expect(find.text('Dear Ana,'), findsNothing);
    expect(open.read(birthdayCardSessionProvider), isFalse);
    expect(misuOf(open).greetings, [insideBirthday]);
  });

  testWidgets('menu rows lead to set up, eras, shelf and settings', (
    tester,
  ) async {
    final container = await pumpMenu(
      tester,
      edition: Edition.open,
      now: outsideBirthday,
      nickname: 'Sam',
      achievements: {
        for (final def in achievementDefs.take(3))
          def.id: const AchievementState(
            unlocked: true,
            unlockedAt: '2026-09-12T20:00:00.000',
          ),
        achievementDefs[3].id: const AchievementState(
          unlocked: false,
          unlockedAt: null,
        ),
      },
    );
    await tester.pumpAndSettle();
    final game = gameOf(container);

    final shuffle = tester.widget<ArrowRow>(
      find.ancestor(
        of: find.text('Shuffle everything'),
        matching: find.byType(ArrowRow),
      ),
    );
    expect(shuffle.primary, isTrue);
    expect(shuffle.description, 'Every song, every era.');
    await tester.tap(find.text('Shuffle everything'));
    expect(game.setups, [GameMode.random]);
    expect(phaseOf(container), GamePhase.setup);
    expect(container.read(gameControllerProvider).mode, GameMode.random);

    game
      ..startQuickRound()
      ..setPhase(GamePhase.menu);
    final eras = tester.widget<ArrowRow>(
      find.ancestor(
        of: find.text('Pick your eras'),
        matching: find.byType(ArrowRow),
      ),
    );
    expect(eras.primary, isFalse);
    expect(eras.description, 'Stick to the albums you love most.');
    await tester.tap(find.text('Pick your eras'));
    expect(phaseOf(container), GamePhase.albumSelect);
    expect(container.read(gameControllerProvider).mode, GameMode.album);
    expect(game.setups, [GameMode.random]);

    await tester.tap(find.text('Record shelf · 3 of 15'));
    expect(phaseOf(container), GamePhase.recordShelf);

    await tester.tap(find.text('Settings'));
    expect(phaseOf(container), GamePhase.settings);

    expect(find.byType(ArrowRow), findsNWidgets(3));
    expect(find.text('Play together'), findsOneWidget);
    expect(find.textContaining('Host a room'), findsNothing);
  });

  testWidgets("tonight's era starts a ten song quick round", (tester) async {
    final now = DateTime(2026, 10, 6, 20);
    final era = curatedEras.singleWhere((era) => era.key == 'red');
    const cover = 'https://cdn.example/red.jpg';
    final container = await pumpMenu(
      tester,
      edition: Edition.ana,
      now: now,
      albums: [Album(id: era.deezerAlbumId, title: 'Red', coverMedium: cover)],
    );
    await tester.pumpAndSettle();

    expect(find.text("Tonight's era"), findsOneWidget);
    expect(find.text('Red'), findsOneWidget);
    expect(find.text('A quick round of 10 →'), findsOneWidget);
    final sleeve = tester.widget<AlbumSleeve>(find.byType(AlbumSleeve));
    expect(sleeve.size, 88);
    expect(sleeve.coverUrl, cover);
    expect(sleeve.placeholder, Color(era.placeholderArgb));
    final disc = tester.widget<VinylDisc>(find.byType(VinylDisc));
    expect(disc.size, 80);
    expect(disc.labelUrl, cover);
    expect(tester.getSize(find.byType(VinylDisc)), const Size(80, 80));
    expect(
      tester.getTopLeft(find.byType(VinylDisc)) -
          tester.getTopLeft(find.byType(AlbumSleeve)),
      const Offset(44, 4),
    );

    await tester.tap(find.text('Red'));

    final game = gameOf(container);
    final state = container.read(gameControllerProvider);
    expect(game.quickRounds, 1);
    expect(state.phase, GamePhase.playing);
    expect(state.mode, GameMode.tonight);
    expect(state.quickRoundTotal, 10);
  });

  testWidgets('the menu asks the catalogue for albums until it has them', (
    tester,
  ) async {
    final empty = await pumpMenu(
      tester,
      edition: Edition.open,
      now: outsideBirthday,
    );
    await tester.pump();
    final catalog =
        empty.read(catalogControllerProvider.notifier) as RecordingCatalog;
    expect(catalog.loads, 1);

    final loaded = await pumpMenu(
      tester,
      edition: Edition.open,
      now: outsideBirthday,
      albums: const [Album(id: 1, title: 'Red', coverMedium: null)],
    );
    await tester.pump();
    final idle =
        loaded.read(catalogControllerProvider.notifier) as RecordingCatalog;
    expect(idle.loads, 0);
    expect(find.text('Good evening, you.'), findsOneWidget);
  });

  testWidgets('the menu stacks into one column on a narrow window', (
    tester,
  ) async {
    await pumpMenu(tester, edition: Edition.ana, now: outsideBirthday);
    tester.view.physicalSize = const Size(686, 571);
    await tester.pumpAndSettle();

    final heading = tester.getRect(find.text('Good evening, Ana.'));
    final shuffle = tester.getRect(find.text('Shuffle everything'));
    expect(heading.left, 32);
    expect(shuffle.left, 32);
    expect(shuffle.top, greaterThan(heading.bottom));
    expect(
      tester.widget<Text>(find.text('Good evening, Ana.')).style?.fontSize,
      44,
    );
  });
  testWidgets('the birthday prompt rises in late and answers hover and press', (
    tester,
  ) async {
    await pumpMenu(tester, edition: Edition.ana, now: outsideBirthday);

    await tester.pump(const Duration(milliseconds: 399));
    expect(riseOpacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 251));
    expect(riseOpacity(tester), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(riseOpacity(tester), 1);
    await tester.pumpAndSettle();
    expect(catScale(tester).scale, 1);
    expect(catScale(tester).alignment, Alignment.bottomCenter);
    expect(catScale(tester).duration, const Duration(milliseconds: 350));
    final cat = tester.getSize(find.byType(CatIcon));
    expect(cat.width, moreOrLessEquals(44));
    expect(cat.height, moreOrLessEquals(88));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1020, 790));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text(cardPrompt)));
    await tester.pumpAndSettle();
    expect(catScale(tester).scale, 1.1);
    expect(arrowNudge(tester), 4);

    await mouse.down(tester.getCenter(find.text(cardPrompt)));
    await tester.pump();
    expect(catScale(tester).scale, 0.95);
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.text(BirthdayCard.greeting), findsOneWidget);
    expect(catScale(tester).scale, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await mouse.moveTo(tester.getCenter(find.text('Red')));
    await tester.pumpAndSettle();
    expect(catScale(tester).scale, 1);
    expect(arrowNudge(tester), 0);
    expect(
      tester
          .widget<Opacity>(
            find
                .ancestor(of: find.text('Red'), matching: find.byType(Opacity))
                .first,
          )
          .opacity,
      0.9,
    );
  });

  testWidgets('reduced motion shows the menu without animating', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      edition: Edition.ana,
      now: outsideBirthday,
      reducedMotion: true,
    );

    expect(riseOpacity(tester), 1);
    expect(catScale(tester).duration, Duration.zero);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the keyboard walks the left column before the right', (
    tester,
  ) async {
    final container = await pumpMenu(
      tester,
      edition: Edition.ana,
      now: outsideBirthday,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final order = [
      cardPrompt,
      'Red',
      'Shuffle everything',
      'Pick your eras',
      'Record shelf · 0 of 15',
      'Settings',
    ];
    for (final label in order) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        focusedPressable(),
        same(pressableOf(tester, label)),
        reason: label,
      );
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusedPressable(), same(pressableOf(tester, 'Red')));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(gameOf(container).quickRounds, 1);
  });
}
