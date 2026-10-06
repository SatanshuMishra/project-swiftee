import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/ui/kit/vinyl.dart';
import 'package:swiftie_quiz/ui/overlays/achievement_toasts.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

const Size surface = Size(800, 600);
const String firstMeow = 'first_meow';
const String warmedUp = 'getting_warmed_up';
const String streak = 'purrfect_streak';
const int fearlessId = 221543452;
const int loverId = 108447472;
const int singleId = 999001;
const String fearlessCover = 'https://e-cdns-images.dzcdn.net/fearless.jpg';
const String singleCover = 'https://e-cdns-images.dzcdn.net/single.jpg';
const Duration stagger = Duration(milliseconds: 350);
const Duration fade = Duration(milliseconds: 300);
const Curve fadeCurve = Curves.ease;

typedef Unlock = ({String id, String? song, int? albumId});

Unlock record(String id, {String? song, int? albumId}) =>
    (id: id, song: song, albumId: albumId);

Track trackOn(int albumId, {String? cover}) => Track(
  id: 7001,
  title: 'Love Story',
  titleShort: 'Love Story',
  duration: 235,
  preview: 'https://cdns-preview.dzcdn.net/love-story.mp3',
  artist: const Artist(id: 12246, name: 'Taylor Swift'),
  album: Album(id: albumId, title: 'Single', coverMedium: cover),
);

void main() {
  group('achievement toasts', () {
    late ProviderContainer container;
    late int screenTaps;

    setUp(() {
      container = ProviderContainer.test();
      screenTaps = 0;
    });

    Future<void> pumpHost(
      WidgetTester tester, {
      ThemeData? theme,
      bool reducedMotion = false,
    }) => tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? AppTheme.dark,
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reducedMotion),
            child: app!,
          ),
          home: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => screenTaps++,
                ),
              ),
              const AchievementToasts(),
            ],
          ),
        ),
      ),
    );

    GameController game() => container.read(gameControllerProvider.notifier);

    void unlockTogether(List<Unlock> unlocks) {
      final progress = container.read(gameControllerProvider).progress;
      game().setProgress(
        progress.copyWith(
          achievements: {
            ...progress.achievements,
            for (final unlock in unlocks)
              unlock.id: AchievementState(
                unlocked: true,
                unlockedAt: '2026-10-06T20:15:00.000Z',
                song: unlock.song,
                albumId: unlock.albumId == null ? null : '${unlock.albumId}',
                trackId: unlock.song == null ? null : '7001',
              ),
          },
        ),
      );
      for (final unlock in unlocks) {
        game().addToast(unlock.id);
      }
    }

    void unlock(String id, {String? song, int? albumId}) =>
        unlockTogether([record(id, song: song, albumId: albumId)]);

    List<String> pending() =>
        container.read(gameControllerProvider).pendingToasts;

    Finder cardOf(String text) => find
        .ancestor(
          of: find.text(text),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container && widget.decoration is BoxDecoration,
          ),
        )
        .first;

    Finder closeOf(String text) => find.descendant(
      of: cardOf(text),
      matching: find.bySemanticsLabel('Dismiss'),
    );

    double opacityOf(WidgetTester tester, String text) => tester
        .widget<Opacity>(
          find.ancestor(of: cardOf(text), matching: find.byType(Opacity)).first,
        )
        .opacity;

    BoxDecoration decorationOf(WidgetTester tester, String text) =>
        tester.widget<Container>(cardOf(text)).decoration! as BoxDecoration;

    testWidgets('renders nothing without pending toasts', (tester) async {
      await pumpHost(tester);

      expect(tester.getSize(find.byType(AchievementToasts)), Size.zero);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('an unlock toast reads new on your shelf with the song', (
      tester,
    ) async {
      await pumpHost(tester);
      unlockTogether([
        record(firstMeow, song: 'Love Story', albumId: fearlessId),
        record(warmedUp, song: 'Cruel Summer', albumId: loverId),
      ]);
      await tester.pump();

      expect(find.text('New on your shelf'), findsOneWidget);
      expect(find.text('First Meow'), findsOneWidget);
      expect(find.text('on Love Story'), findsOneWidget);
      expect(
        find.descendant(
          of: cardOf('First Meow'),
          matching: find.byType(AlbumSleeve),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardOf('First Meow'),
          matching: find.byType(VinylDisc),
        ),
        findsOneWidget,
      );
      expect(find.text('Getting Warmed Up'), findsNothing);

      await tester.pump(stagger);
      expect(find.text('New on your shelf'), findsNWidgets(2));
      expect(find.text('Getting Warmed Up'), findsOneWidget);
      expect(find.text('on Cruel Summer'), findsOneWidget);

      await tester.pump(AppMotion.toastSlide);
      final first = tester.getRect(cardOf('First Meow'));
      final second = tester.getRect(cardOf('Getting Warmed Up'));
      expect(first.topRight, Offset(surface.width - 16, 16));
      expect(first.width, 300);
      expect(second.top, first.top + AppMotion.toastSpacing);
      expect(second.top, 100);
      expect(second.right, first.right);
      expect(second.width, 300);

      await tester.tap(closeOf('First Meow'));
      await tester.pump();
      expect(pending(), [warmedUp]);
      await tester.pump(fade);
      expect(find.text('First Meow'), findsNothing);
      expect(find.text('Getting Warmed Up'), findsOneWidget);

      await tester.pump(
        AppMotion.toastStay - stagger - fade - const Duration(milliseconds: 1),
      );
      expect(pending(), [warmedUp]);
      expect(find.text('Getting Warmed Up'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      expect(pending(), isEmpty);
      await tester.pump(fade);
      expect(find.text('Getting Warmed Up'), findsNothing);
      expect(find.text('New on your shelf'), findsNothing);
      expect(screenTaps, 0);
    });

    testWidgets('several records unlocked at once appear 350 ms apart', (
      tester,
    ) async {
      await pumpHost(tester);
      unlockTogether([
        record(firstMeow, song: 'Love Story'),
        record(warmedUp, song: 'Love Story'),
        record(streak, song: 'Love Story'),
      ]);
      await tester.pump();

      expect(find.text('First Meow'), findsOneWidget);
      expect(find.text('Getting Warmed Up'), findsNothing);

      await tester.pump(stagger - const Duration(milliseconds: 1));
      expect(find.text('Getting Warmed Up'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Getting Warmed Up'), findsOneWidget);
      expect(find.text('Purrfect Streak'), findsNothing);

      await tester.pump(stagger);
      expect(find.text('Purrfect Streak'), findsOneWidget);

      await tester.pump(AppMotion.toastSlide);
      expect(tester.getRect(cardOf('First Meow')).top, 16);
      expect(tester.getRect(cardOf('Getting Warmed Up')).top, 16 + 84);
      expect(tester.getRect(cardOf('Purrfect Streak')).top, 16 + 2 * 84);

      await tester.pump(AppMotion.toastStay);
      await tester.pump(fade);
      expect(pending(), isEmpty);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets(
      'slides in 24 px from the right over 350 ms while fading in over 300 ms',
      (tester) async {
        await pumpHost(tester);
        unlock(firstMeow, song: 'Love Story');
        await tester.pump();

        const restingLeft = 800 - 16 - 300;
        expect(tester.getTopLeft(cardOf('First Meow')).dx, restingLeft + 24);
        expect(tester.getTopLeft(cardOf('First Meow')).dy, 16);
        expect(opacityOf(tester, 'First Meow'), 0);

        await tester.pump(const Duration(milliseconds: 175));
        expect(
          tester.getTopLeft(cardOf('First Meow')).dx,
          moreOrLessEquals(
            restingLeft + 24 * (1 - AppMotion.toastSlideCurve.transform(0.5)),
          ),
        );
        expect(
          opacityOf(tester, 'First Meow'),
          moreOrLessEquals(fadeCurve.transform(175 / 300)),
        );

        await tester.pump(const Duration(milliseconds: 125));
        expect(opacityOf(tester, 'First Meow'), 1);
        expect(
          tester.getTopLeft(cardOf('First Meow')).dx,
          greaterThan(restingLeft),
        );

        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.getTopLeft(cardOf('First Meow')).dx, restingLeft);
        expect(opacityOf(tester, 'First Meow'), 1);

        await tester.pump(AppMotion.toastStay);
        await tester.pump(fade);
      },
    );

    testWidgets('fades and slides out over 300 ms before it is removed', (
      tester,
    ) async {
      await pumpHost(tester);
      unlock(firstMeow, song: 'Love Story');
      await tester.pump();
      await tester.pump(AppMotion.toastSlide);

      await tester.tap(closeOf('First Meow'));
      await tester.pump();
      expect(pending(), isEmpty);
      expect(find.text('First Meow'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      expect(
        opacityOf(tester, 'First Meow'),
        moreOrLessEquals(1 - fadeCurve.transform(0.5)),
      );
      expect(
        tester.getTopLeft(cardOf('First Meow')).dx,
        moreOrLessEquals(
          800 - 16 - 300 + 24 * AppMotion.toastSlideCurve.transform(150 / 350),
        ),
      );

      await tester.tap(cardOf('First Meow'), warnIfMissed: false);
      expect(screenTaps, 1);

      await tester.pump(const Duration(milliseconds: 149));
      expect(find.text('First Meow'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('First Meow'), findsNothing);
      expect(tester.getSize(find.byType(AchievementToasts)), Size.zero);
    });

    testWidgets(
      'each toast dismisses 4 s after it appeared, regardless of new toasts',
      (tester) async {
        await pumpHost(tester);
        unlock(firstMeow);
        await tester.pump();

        await tester.pump(const Duration(seconds: 2));
        unlock(warmedUp);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        unlock(streak);
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 999));
        expect(pending(), [firstMeow, warmedUp, streak]);

        await tester.pump(const Duration(milliseconds: 1));
        expect(pending(), [warmedUp, streak]);
        await tester.pump(fade);
        expect(find.text('First Meow'), findsNothing);
        expect(find.text('Getting Warmed Up'), findsOneWidget);
        expect(tester.getRect(cardOf('Getting Warmed Up')).top, 16);

        await tester.pump(const Duration(seconds: 2) - fade);
        expect(pending(), [streak]);
        await tester.pump(fade);
        expect(find.text('Getting Warmed Up'), findsNothing);
        expect(find.text('Purrfect Streak'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1) - fade);
        expect(pending(), isEmpty);
        await tester.pump(fade);
        expect(find.text('Purrfect Streak'), findsNothing);
      },
    );

    testWidgets('the close button labelled Dismiss removes only its toast', (
      tester,
    ) async {
      await pumpHost(tester);
      unlock(firstMeow);
      unlock(warmedUp);
      await tester.pump();
      await tester.pump(stagger);
      await tester.pump(AppMotion.toastSlide);

      expect(
        find.semantics.byPredicate((node) {
          final data = node.getSemanticsData();
          return data.flagsCollection.isButton && data.label == 'Dismiss';
        }),
        findsExactly(2),
      );

      await tester.tap(closeOf('First Meow'));
      await tester.pump();
      await tester.pump(fade);

      expect(find.text('First Meow'), findsNothing);
      expect(find.text('Getting Warmed Up'), findsOneWidget);
      expect(pending(), [warmedUp]);
      expect(screenTaps, 0);

      await tester.pump(AppMotion.toastStay);
      expect(pending(), isEmpty);
      await tester.pump(fade);
    });

    for (final (name, theme, tokens) in [
      ('dark', AppTheme.dark, AppTokens.dark),
      ('light', AppTheme.light, AppTokens.light),
    ]) {
      testWidgets('the $name card is 300 px of panel with a line2 border', (
        tester,
      ) async {
        await pumpHost(tester, theme: theme);
        unlock(firstMeow, song: 'Love Story', albumId: fearlessId);
        await tester.pump();
        await tester.pump(AppMotion.toastSlide);

        expect(
          tester.widget<Container>(cardOf('First Meow')).padding,
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        );
        final decoration = decorationOf(tester, 'First Meow');
        expect(decoration.color, tokens.panel);
        expect(decoration.border, Border.all(color: tokens.line2));
        expect(
          decoration.borderRadius,
          const BorderRadius.all(Radius.circular(14)),
        );
        expect(decoration.boxShadow, [
          CssBoxShadow(
            color: tokens.shadow,
            offset: const Offset(0, 12),
            blur: 32,
          ),
        ]);
        expect(tester.getSize(cardOf('First Meow')).width, 300);

        final kicker = tester.widget<Text>(find.text('New on your shelf'));
        expect(kicker.style!.fontSize, 11);
        expect(kicker.style!.height, 14 / 11);
        expect(kicker.style!.fontWeight, FontWeight.w600);
        expect(kicker.style!.color, tokens.coralT);

        final title = tester.widget<Text>(find.text('First Meow'));
        expect(title.style!.fontFamily, AppType.serifFamily);
        expect(title.style!.fontSize, 20);
        expect(title.style!.height, 24 / 20);
        expect(title.style!.color, tokens.fg);

        final song = tester.widget<Text>(find.text('on Love Story'));
        expect(song.style!.fontSize, 12);
        expect(song.style!.height, 16 / 12);
        expect(song.style!.color, tokens.mut);
        expect(song.maxLines, 1);
        expect(song.overflow, TextOverflow.ellipsis);

        await tester.pump(AppMotion.toastStay);
        await tester.pump(fade);
      });
    }

    testWidgets(
      'the sleeve shows the album cover in front of a 40 px disc 14 px right',
      (tester) async {
        await pumpHost(tester);
        game().setAlbums(const [
          Album(id: fearlessId, title: 'Fearless', coverMedium: fearlessCover),
        ]);
        unlock(firstMeow, song: 'Love Story', albumId: fearlessId);
        await tester.pump();
        await tester.pump(AppMotion.toastSlide);

        final sleeve = tester.widget<AlbumSleeve>(find.byType(AlbumSleeve));
        expect(sleeve.size, 44);
        expect(sleeve.radius, 3);
        expect(sleeve.coverUrl, fearlessCover);
        expect(
          sleeve.placeholder,
          Color(eraForAlbumId(fearlessId)!.placeholderArgb),
        );
        expect(tester.widget<VinylDisc>(find.byType(VinylDisc)).size, 40);

        final card = tester.getRect(cardOf('First Meow'));
        final sleeveRect = tester.getRect(find.byType(AlbumSleeve));
        final discRect = tester.getRect(find.byType(VinylDisc));
        final text = tester.getRect(find.text('New on your shelf'));
        expect(sleeveRect.size, const Size.square(44));
        expect(sleeveRect.left, card.left + 1 + 14);
        expect(discRect.size, const Size.square(40));
        expect(discRect.topLeft, sleeveRect.topLeft + const Offset(14, 2));
        expect(text.left, sleeveRect.left + 52 + 12);
        expect(sleeveRect.center.dy, moreOrLessEquals(card.center.dy));

        final sleeveBox = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(AlbumSleeve),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final shadows = (sleeveBox.decoration as BoxDecoration).boxShadow!;
        expect(shadows.every((shadow) => shadow.color.a == 0), isTrue);

        await tester.pump(AppMotion.toastStay);
        await tester.pump(fade);
      },
    );

    testWidgets(
      'a cover missing from the album list comes from the playing track',
      (tester) async {
        await pumpHost(tester);
        final track = trackOn(singleId, cover: singleCover);
        game().startRound(track, [track], [track]);
        unlock(firstMeow, song: 'Love Story', albumId: singleId);
        await tester.pump();

        final sleeve = tester.widget<AlbumSleeve>(find.byType(AlbumSleeve));
        expect(sleeve.coverUrl, singleCover);
        expect(sleeve.placeholder, isNull);

        await tester.pump(AppMotion.toastStay);
        await tester.pump(fade);
      },
    );

    testWidgets('without a cover the sleeve shows its era colour', (
      tester,
    ) async {
      await pumpHost(tester);
      unlock(firstMeow, song: 'Love Story', albumId: fearlessId);
      await tester.pump();

      final sleeve = tester.widget<AlbumSleeve>(find.byType(AlbumSleeve));
      expect(sleeve.coverUrl, isNull);
      expect(
        sleeve.placeholder,
        Color(eraForAlbumId(fearlessId)!.placeholderArgb),
      );

      await tester.pump(AppMotion.toastStay);
      await tester.pump(fade);
    });

    testWidgets(
      'a record without an album or song shows the kicker and the name',
      (tester) async {
        await pumpHost(tester);
        unlock(firstMeow);
        await tester.pump();

        expect(find.text('New on your shelf'), findsOneWidget);
        expect(find.text('First Meow'), findsOneWidget);
        expect(find.textContaining(RegExp('^on ')), findsNothing);
        expect(find.byType(AlbumSleeve), findsNothing);
        expect(find.byType(VinylDisc), findsNothing);
        expect(
          tester.getRect(find.text('New on your shelf')).left,
          tester.getRect(cardOf('First Meow')).left + 1 + 14,
        );

        await tester.pump(AppMotion.toastStay);
        await tester.pump(fade);
      },
    );

    testWidgets('a long song title stays on one line with an ellipsis', (
      tester,
    ) async {
      const long =
          "Back To December/Apologize/You're Not Sorry (Live/2011/Medley)";
      await pumpHost(tester);
      unlock(firstMeow, song: long, albumId: fearlessId);
      await tester.pump();

      final line = find.text('on $long');
      expect(tester.getSize(line).height, 16);
      expect(
        tester.renderObject<RenderParagraph>(line).didExceedMaxLines,
        true,
      );
      expect(
        tester.getRect(line).right,
        lessThanOrEqualTo(
          tester.getRect(cardOf('First Meow')).right - 1 - 14 - 24 - 12,
        ),
      );

      await tester.pump(AppMotion.toastStay);
      await tester.pump(fade);
    });

    testWidgets('the close button is a 24 px muted cross lit on hover', (
      tester,
    ) async {
      await pumpHost(tester);
      unlock(firstMeow, song: 'Love Story', albumId: fearlessId);
      await tester.pump();
      await tester.pump(AppMotion.toastSlide);

      final card = tester.getRect(cardOf('First Meow'));
      final close = tester.getRect(closeOf('First Meow'));
      expect(close.size, const Size.square(24));
      expect(close.topRight, card.topRight + const Offset(-1 - 14, 1 + 12));

      Finder background() => find.descendant(
        of: closeOf('First Meow'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.position == DecorationPosition.background &&
              (widget.decoration as BoxDecoration).borderRadius ==
                  const BorderRadius.all(Radius.circular(6)),
        ),
      );
      Color? fill() =>
          (tester.widget<DecoratedBox>(background()).decoration
                  as BoxDecoration)
              .color;
      Color? cross() => tester.widget<Text>(find.text('✕')).style!.color;

      expect(tester.widget<Text>(find.text('✕')).style!.fontSize, 13);
      expect(cross(), AppTokens.dark.mut);
      expect(fill(), isNull);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(close.center);
      await tester.pump();

      expect(fill(), AppTokens.dark.hover);
      expect(cross(), AppTokens.dark.fg);

      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(fill(), isNull);
      expect(cross(), AppTokens.dark.mut);

      await tester.pump(AppMotion.toastStay);
      await tester.pump(fade);
    });

    testWidgets('the close button works from the keyboard with a focus ring', (
      tester,
    ) async {
      await pumpHost(tester);
      unlock(firstMeow, song: 'Love Story');
      await tester.pump();
      await tester.pump(AppMotion.toastSlide);

      Finder ring() => find.descendant(
        of: closeOf('First Meow'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.position == DecorationPosition.foreground &&
              (widget.decoration as BoxDecoration).border?.top.color ==
                  AppTokens.dark.coral,
        ),
      );

      expect(ring(), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(ring(), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(pending(), isEmpty);

      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('First Meow'), findsOneWidget);
      expect(ring(), findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.context,
        isNot(
          predicate<BuildContext>(
            (context) =>
                context.findAncestorWidgetOfExactType<AchievementToasts>() !=
                null,
          ),
        ),
      );

      await tester.pump(fade);
      expect(find.text('First Meow'), findsNothing);
    });

    testWidgets('a toast keeps the record it arrived with', (tester) async {
      await pumpHost(tester);
      unlock(firstMeow, song: 'Love Story', albumId: fearlessId);
      await tester.pump();

      unlock(warmedUp, song: 'Cruel Summer', albumId: loverId);
      final progress = container.read(gameControllerProvider).progress;
      game().setProgress(
        progress.copyWith(
          achievements: {
            ...progress.achievements,
            firstMeow: const AchievementState(
              unlocked: true,
              unlockedAt: '2026-10-06T20:16:00.000Z',
              song: 'Cruel Summer',
              albumId: '$loverId',
              trackId: '7002',
            ),
          },
        ),
      );
      await tester.pump();

      expect(find.text('on Love Story'), findsOneWidget);
      expect(
        tester
            .widget<AlbumSleeve>(
              find.descendant(
                of: cardOf('First Meow'),
                matching: find.byType(AlbumSleeve),
              ),
            )
            .placeholder,
        Color(eraForAlbumId(fearlessId)!.placeholderArgb),
      );

      await tester.pump(AppMotion.toastStay);
      await tester.pump(fade);
    });

    testWidgets('is announced as a status once it shows', (tester) async {
      await pumpHost(tester);
      unlock(firstMeow, song: 'Love Story');
      await tester.pump();
      await tester.pump(AppMotion.toastSlide);

      expect(
        find.semantics.byPredicate((node) {
          final data = node.getSemanticsData();
          return data.role == SemanticsRole.status &&
              data.label.contains('New on your shelf') &&
              data.label.contains('First Meow') &&
              data.label.contains('on Love Story') &&
              !data.label.contains('Dismiss');
        }),
        findsOne,
      );

      await tester.pump(AppMotion.toastStay);
      await tester.pump(fade);
    });

    testWidgets('clicks around the toasts reach the screen beneath', (
      tester,
    ) async {
      await pumpHost(tester);
      unlock(firstMeow);
      unlock(warmedUp);
      await tester.pump();
      await tester.pump(AppMotion.toastSlide);

      final first = tester.getRect(cardOf('First Meow'));
      await tester.tapAt(Offset(first.left - 4, first.center.dy));
      await tester.tapAt(const Offset(20, 20));
      await tester.tapAt(Offset(first.center.dx, 300));

      expect(screenTaps, 3);

      await tester.tap(find.text('First Meow'));
      expect(screenTaps, 3);
      expect(pending(), [firstMeow, warmedUp]);

      await tester.pump(AppMotion.toastStay);
      await tester.pump(fade);
    });

    testWidgets('an unknown id renders nothing and still expires', (
      tester,
    ) async {
      await pumpHost(tester);
      game().addToast('not_an_achievement');
      await tester.pump();

      expect(find.byType(Text), findsNothing);

      await tester.pump(AppMotion.toastStay);
      expect(pending(), isEmpty);
    });

    testWidgets('a toast dismissed before its turn never appears', (
      tester,
    ) async {
      await pumpHost(tester);
      unlockTogether([record(firstMeow), record(warmedUp)]);
      await tester.pump();

      game().dismissToast(warmedUp);
      await tester.pump(stagger);
      await tester.pump(stagger);

      expect(find.text('First Meow'), findsOneWidget);
      expect(find.text('Getting Warmed Up'), findsNothing);

      await tester.pump(AppMotion.toastStay);
      await tester.pump(fade);
      expect(pending(), isEmpty);
    });

    testWidgets(
      'with reduced motion toasts appear together and leave at once',
      (tester) async {
        await pumpHost(tester, reducedMotion: true);
        unlockTogether([
          record(firstMeow, song: 'Love Story'),
          record(warmedUp, song: 'Love Story'),
        ]);
        await tester.pump();

        expect(find.text('First Meow'), findsOneWidget);
        expect(find.text('Getting Warmed Up'), findsOneWidget);
        expect(
          tester.getRect(cardOf('First Meow')).topLeft,
          const Offset(484, 16),
        );
        expect(
          tester.getRect(cardOf('Getting Warmed Up')).topLeft,
          const Offset(484, 100),
        );
        expect(opacityOf(tester, 'First Meow'), 1);

        await tester.tap(closeOf('First Meow'));
        await tester.pump();
        expect(find.text('First Meow'), findsNothing);
        expect(tester.getRect(cardOf('Getting Warmed Up')).top, 16);

        await tester.pump(AppMotion.toastStay);
        expect(find.byType(Text), findsNothing);
        expect(pending(), isEmpty);
      },
    );
  });
}
