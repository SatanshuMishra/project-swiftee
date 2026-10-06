import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/achievements.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/kit/vinyl.dart';
import 'package:swiftie_quiz/ui/screens/record_shelf_screen.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

const int _fearlessId = 221543452;
const String _fearlessCover = 'https://e-cdns-images.dzcdn.net/fearless.jpg';
const Color _fearlessPlaceholder = Color(0xFF6A5526);
const Offset _parked = Offset(1020, 4);

String _localNoon(int year, int month, int day) =>
    DateTime(year, month, day, 12).toUtc().toIso8601String();

final Map<String, AchievementState> _twoRecords = {
  'first_meow': AchievementState(
    unlocked: true,
    unlockedAt: _localNoon(2026, 9, 12),
    song: 'Love Story',
    albumId: '$_fearlessId',
    trackId: '1',
  ),
  'speed_demon': AchievementState(
    unlocked: true,
    unlockedAt: _localNoon(2026, 8, 3),
  ),
};

class _IdleCatalog extends CatalogController {
  int loads = 0;

  @override
  CatalogState build() => CatalogState.initial;

  @override
  Future<void> loadCatalogue() async {
    loads += 1;
  }
}

final class _RecordingAudio extends AudioController {
  List<String> log = const [];

  @override
  AudioState build() => AudioState.idle;

  @override
  Future<void> previewSnippet(String trackId) async {
    log = [...log, 'play $trackId'];
  }

  @override
  void stopSnippet() => log = [...log, 'stop'];

  Iterable<String> get plays => log.where((entry) => entry != 'stop');
}

Future<ProviderContainer> _pumpShelf(
  WidgetTester tester, {
  Map<String, AchievementState> achievements = const {},
  Edition edition = Edition.ana,
  String? nickname,
  List<Album> albums = const [],
  Size size = const Size(1024, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer.test(
    overrides: [
      editionProvider.overrideWithValue(edition),
      catalogControllerProvider.overrideWith(_IdleCatalog.new),
      audioControllerProvider.overrideWith(_RecordingAudio.new),
    ],
  );
  final game = container.read(gameControllerProvider.notifier)
    ..setAlbums(albums)
    ..setPhase(GamePhase.recordShelf);
  final progress = container.read(gameControllerProvider).progress;
  game.setProgress(
    progress.copyWith(
      achievements: achievements,
      settings: progress.settings.copyWith(nickname: nickname),
    ),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Material(child: RecordShelfScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

_RecordingAudio _audioOf(ProviderContainer container) =>
    container.read(audioControllerProvider.notifier) as _RecordingAudio;

Finder _record(String id) => find.byWidgetPredicate(
  (widget) => widget is ShelfRecord && widget.definition.id == id,
);

List<String?> _textsOf(WidgetTester tester, String id) => [
  for (final text in tester.widgetList<Text>(
    find.descendant(of: _record(id), matching: find.byType(Text)),
  ))
    text.data,
];

Finder _discOf(String id) =>
    find.descendant(of: _record(id), matching: find.byType(VinylDisc));

Finder _sleeveOf(String id) =>
    find.descendant(of: _record(id), matching: find.byType(AlbumSleeve));

Offset _discOffset(WidgetTester tester, String id) =>
    tester.getTopLeft(_discOf(id)) - tester.getTopLeft(_sleeveOf(id));

Future<TestGesture> _mouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: _parked);
  addTearDown(mouse.removePointer);
  return mouse;
}

Future<void> _hover(WidgetTester tester, TestGesture mouse, Offset at) async {
  await mouse.moveTo(at);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the shelf shows earned records and dashed locked slots', (
    tester,
  ) async {
    await _pumpShelf(tester, achievements: _twoRecords);

    expect(find.text("Ana's record shelf"), findsOneWidget);
    expect(find.text('2 of 15 · hover a record to hear it'), findsOneWidget);
    expect(_textsOf(tester, 'first_meow'), [
      'First Meow',
      'on Love Story · Sep 12',
    ]);
    expect(
      tester.getTopLeft(find.text('on Love Story · Sep 12')).dy,
      greaterThan(tester.getBottomLeft(find.text('First Meow')).dy - 1),
    );
    expect(_textsOf(tester, 'speed_demon'), ['Speed Demon', 'Aug 3']);
    expect(_sleeveOf('first_meow'), findsOneWidget);
    expect(_discOf('first_meow'), findsOneWidget);
    expect(
      tester.widget<AlbumSleeve>(_sleeveOf('first_meow')).placeholder,
      _fearlessPlaceholder,
    );

    final dashed = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is DashedOutlinePainter,
    );
    expect(dashed, findsNWidgets(13));
    for (final paint in tester.widgetList<CustomPaint>(dashed)) {
      expect(
        (paint.painter! as DashedOutlinePainter).color,
        AppTokens.dark.line2,
      );
    }
    for (final (id, name, hint) in const [
      ('getting_warmed_up', 'Getting Warmed Up', '10 right, all-time'),
      ('purrfect_streak', 'Purrfect Streak', '10 in a row'),
      ('album_explorer', 'Album Explorer', 'Songs from 5 eras'),
      ('album_completionist', 'Album Completionist', 'Every song on one album'),
      ('hard_mode_hero', 'Hard Mode Hero', '5 right on Hard'),
      (
        'persistent_listener',
        'Persistent Listener',
        'Right after the full clip',
      ),
      ('quack_collector', 'Quack Collector', 'A secret'),
      ('all_ears', 'All Ears', '50 songs, all-time'),
      ('lyric_lover', 'Lyric Lover', 'Any lyrics round'),
      ('poet_laureate', 'Poet Laureate', '20 in Name That Song'),
      ('lie_detector', 'Lie Detector', '15 in Lyrics or Lie'),
      ('dual_threat', 'Dual Threat', 'Sound and lyrics, one session'),
      ('lyric_streak', 'Lyric Streak', '10 in a row on lyrics'),
    ]) {
      expect(_textsOf(tester, id), [name, hint], reason: id);
      expect(
        find.descendant(of: _record(id), matching: dashed),
        findsOneWidget,
        reason: id,
      );
    }

    final corners = [
      for (final definition in achievementDefs)
        tester.getTopLeft(_record(definition.id)),
    ];
    expect({for (final corner in corners) corner.dx}, hasLength(5));
    expect({for (final corner in corners.take(5)) corner.dy}, hasLength(1));
    expect(corners[5].dy, greaterThan(corners[0].dy));
    expect(corners[5].dx, corners[0].dx);
  });

  testWidgets('a narrow window shows three columns', (tester) async {
    await _pumpShelf(tester, size: const Size(686, 571));

    final corners = [
      for (final definition in achievementDefs)
        tester.getTopLeft(_record(definition.id)),
    ];
    expect({for (final corner in corners) corner.dx}, hasLength(3));
    expect(corners[3].dx, corners[0].dx);
    expect(corners[3].dy, greaterThan(corners[0].dy));
  });

  testWidgets('an open player without a nickname sees your record shelf', (
    tester,
  ) async {
    await _pumpShelf(tester, edition: Edition.open);

    expect(find.text('Your record shelf'), findsOneWidget);
    expect(find.text('0 of 15 · hover a record to hear it'), findsOneWidget);
  });

  testWidgets('an open player with a nickname sees their own shelf', (
    tester,
  ) async {
    await _pumpShelf(tester, edition: Edition.open, nickname: 'Sam');

    expect(find.text("Sam's record shelf"), findsOneWidget);
  });

  testWidgets('a loaded album gives the record its cover', (tester) async {
    await _pumpShelf(
      tester,
      achievements: _twoRecords,
      albums: const [
        Album(id: _fearlessId, title: 'Fearless', coverMedium: _fearlessCover),
      ],
    );

    expect(
      tester.widget<AlbumSleeve>(_sleeveOf('first_meow')).coverUrl,
      _fearlessCover,
    );
    expect(
      tester.widget<VinylDisc>(_discOf('first_meow')).labelUrl,
      _fearlessCover,
    );
    expect(
      tester.widget<AlbumSleeve>(_sleeveOf('speed_demon')).placeholder,
      isNull,
    );
  });

  testWidgets('hovering an earned record slides its disc and plays its song', (
    tester,
  ) async {
    final container = await _pumpShelf(tester, achievements: _twoRecords);
    final audio = _audioOf(container);
    final width = tester.getSize(_sleeveOf('first_meow')).width;
    final mouse = await _mouse(tester);

    expect(_discOffset(tester, 'first_meow').dx, closeTo(width * 0.22, 0.01));
    expect(_discOffset(tester, 'first_meow').dy, closeTo(-width * 0.30, 0.01));

    await _hover(tester, mouse, tester.getCenter(_sleeveOf('first_meow')));

    expect(audio.log, ['play 1']);
    expect(_discOffset(tester, 'first_meow').dx, closeTo(width * 0.30, 0.01));
    expect(_discOffset(tester, 'first_meow').dy, closeTo(-width * 0.44, 0.01));

    await _hover(tester, mouse, _parked);

    expect(audio.log, ['play 1', 'stop']);
    expect(_discOffset(tester, 'first_meow').dy, closeTo(-width * 0.30, 0.01));

    await _hover(tester, mouse, tester.getCenter(_sleeveOf('speed_demon')));

    expect(audio.plays, ['play 1']);
    expect(audio.log.last, 'stop');
    expect(_discOffset(tester, 'speed_demon').dy, closeTo(-width * 0.44, 0.01));

    await _hover(tester, mouse, tester.getCenter(_sleeveOf('first_meow')));

    expect(audio.log.last, 'play 1');

    await _hover(tester, mouse, tester.getCenter(_record('all_ears')));

    expect(audio.log.last, 'stop');
    expect(audio.plays, ['play 1', 'play 1']);

    await _hover(tester, mouse, tester.getCenter(_sleeveOf('first_meow')));
    await tester.pumpWidget(const SizedBox());

    expect(audio.log.reversed.take(2), ['stop', 'play 1']);
  });

  testWidgets('the risen disc stays part of its record', (tester) async {
    AchievementState earnedOn(String song, String trackId) => AchievementState(
      unlocked: true,
      unlockedAt: _localNoon(2026, 9, 20),
      song: song,
      albumId: '$_fearlessId',
      trackId: trackId,
    );
    final container = await _pumpShelf(
      tester,
      size: const Size(1280, 900),
      achievements: {
        ..._twoRecords,
        'album_completionist': earnedOn('Mine', '5'),
        'all_ears': earnedOn('Fifteen', '10'),
      },
    );
    final audio = _audioOf(container);
    final mouse = await _mouse(tester);
    final width = tester.getSize(_sleeveOf('first_meow')).width;
    final sleeveTop = tester.getTopLeft(_sleeveOf('first_meow')).dy;

    await _hover(tester, mouse, tester.getCenter(_sleeveOf('first_meow')));
    final disc = tester.getRect(_discOf('first_meow'));
    final aboveCell = Offset(disc.center.dx, disc.top + 5);

    expect(aboveCell.dy, lessThan(sleeveTop - 46));

    await _hover(tester, mouse, aboveCell);

    expect(audio.log, ['play 1']);
    expect(tester.getRect(_discOf('first_meow')), disc);

    await _hover(tester, mouse, _parked);
    final detail = tester.getRect(
      find.descendant(
        of: _record('album_completionist'),
        matching: find.text('on Mine · Sep 20'),
      ),
    );
    final underNextDisc = detail.bottomLeft + const Offset(2, -4);
    final nextSleeveTop = tester.getTopLeft(_sleeveOf('all_ears')).dy;

    expect(underNextDisc.dy, greaterThan(nextSleeveTop - width * 0.44));

    await _hover(tester, mouse, underNextDisc);

    expect(audio.log, ['play 1', 'stop', 'play 5']);
  });

  testWidgets(
    'a keyboard-focused record shows a coral ring and plays on enter',
    (tester) async {
      final container = await _pumpShelf(tester, achievements: _twoRecords);
      final audio = _audioOf(container);
      final width = tester.getSize(_sleeveOf('first_meow')).width;

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(audio.log, isEmpty);
      expect(
        _discOffset(tester, 'first_meow').dy,
        closeTo(-width * 0.44, 0.01),
      );
      final boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: _record('first_meow'),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        boxes.any(
          (box) => switch (box.decoration) {
            BoxDecoration(border: Border(top: BorderSide(:final color))) =>
              color == AppTokens.dark.coral,
            _ => false,
          },
        ),
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(audio.log, ['play 1']);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(audio.log, ['play 1', 'stop']);
      expect(
        _discOffset(tester, 'first_meow').dy,
        closeTo(-width * 0.30, 0.01),
      );
    },
  );

  testWidgets('covers load when an earned record names its album', (
    tester,
  ) async {
    _IdleCatalog catalogOf(ProviderContainer container) =>
        container.read(catalogControllerProvider.notifier) as _IdleCatalog;

    expect(
      catalogOf(await _pumpShelf(tester, achievements: _twoRecords)).loads,
      1,
    );
    expect(
      catalogOf(
        await _pumpShelf(
          tester,
          achievements: _twoRecords,
          albums: const [
            Album(id: _fearlessId, title: 'Fearless', coverMedium: null),
          ],
        ),
      ).loads,
      0,
    );
    expect(
      catalogOf(
        await _pumpShelf(
          tester,
          achievements: {'speed_demon': _twoRecords['speed_demon']!},
        ),
      ).loads,
      0,
    );
  });

  testWidgets('reduced motion slides the disc at once', (tester) async {
    await _pumpShelf(tester, achievements: _twoRecords);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    final width = tester.getSize(_sleeveOf('first_meow')).width;
    final mouse = await _mouse(tester);

    await mouse.moveTo(tester.getCenter(_sleeveOf('first_meow')));
    await tester.pump();
    await tester.pump();

    expect(_discOffset(tester, 'first_meow').dy, closeTo(-width * 0.44, 0.01));
  });
}
