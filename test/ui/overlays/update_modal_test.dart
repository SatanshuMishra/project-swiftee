import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/updater_controller.dart';
import 'package:swiftie_quiz/ui/overlays/update_modal.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

const Size surface = Size(800, 600);
const UpdateManifest bareManifest = UpdateManifest(
  version: '0.3.0',
  notes: '',
  pubDate: '',
);
const String behindTheDialog = 'Main menu behind the dialog';

final class _RecordingUpdater implements UpdaterController {
  final List<String> calls = [];

  @override
  UpdaterMachineState get state => const UpdaterIdle();

  @override
  Future<void> check({bool manual = false}) async =>
      calls.add('check(manual: $manual)');

  @override
  Future<void> download() async => calls.add('download');

  @override
  Future<void> install() async => calls.add('install');

  @override
  Future<void> retry() async => calls.add('retry');

  @override
  void cancel() => calls.add('cancel');

  @override
  void skipVersion(String version) => calls.add('skipVersion($version)');

  @override
  void remindLater() => calls.add('remindLater');

  @override
  void dismiss() => calls.add('dismiss');
}

void main() {
  group('update modal parity', () {
    late ProviderContainer container;
    late _RecordingUpdater updater;
    late int closes;
    late int screenTaps;

    setUp(() {
      updater = _RecordingUpdater();
      container = ProviderContainer.test(
        overrides: [updaterControllerProvider.overrideWithValue(updater)],
      );
      closes = 0;
      screenTaps = 0;
    });

    void setState(UpdaterMachineState state) =>
        container.read(gameControllerProvider.notifier).setUpdaterState(state);

    Future<void> pumpModal(
      WidgetTester tester, {
      bool isOpen = true,
      VoidCallback? onClose,
    }) => tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => screenTaps++,
                  child: const Align(
                    alignment: Alignment.topLeft,
                    child: Text(behindTheDialog),
                  ),
                ),
              ),
              UpdateModal(isOpen: isOpen, onClose: onClose ?? () => closes++),
            ],
          ),
        ),
      ),
    );

    Future<void> openWith(
      WidgetTester tester,
      UpdaterMachineState state,
    ) async {
      setState(state);
      await pumpModal(tester);
      await tester.pumpAndSettle();
    }

    SemanticsFinder buttonNamed(RegExp name) =>
        find.semantics.byPredicate((node) {
          final data = node.getSemanticsData();
          return data.flagsCollection.isButton && name.hasMatch(data.label);
        });

    RegExp exactly(String name) =>
        RegExp('^${RegExp.escape(name)}\$', caseSensitive: false);

    Finder dialogCard() => find.descendant(
      of: find.byType(UpdateModal),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).boxShadow == AppShadows.xl2,
      ),
    );

    Finder buttonBox(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate(
        (widget) => widget is Container && widget.decoration != null,
      ),
    );

    BoxDecoration buttonDecoration(WidgetTester tester, String label) =>
        tester.widget<Container>(buttonBox(label).first).decoration!
            as BoxDecoration;

    Finder progressTrack() => find
        .ancestor(
          of: find.byType(FractionallySizedBox),
          matching: find.byType(ClipRRect),
        )
        .first;

    ScaleTransition cardScale(WidgetTester tester) => tester.widget(
      find
          .ancestor(of: dialogCard(), matching: find.byType(ScaleTransition))
          .first,
    );

    testWidgets('returns null when isOpen is false', (tester) async {
      setState(const UpdaterAvailable(manifest: bareManifest));
      await pumpModal(tester, isOpen: false);

      expect(tester.getSize(find.byType(UpdateModal)), Size.zero);
      expect(find.textContaining('0.3.0'), findsNothing);
      expect(
        find.semantics.byPredicate(
          (node) => node.getSemanticsData().role == SemanticsRole.dialog,
        ),
        findsNothing,
      );
    });

    testWidgets(
      'renders release notes and Download/Skip/Remind buttons when state is available',
      (tester) async {
        await openWith(
          tester,
          const UpdaterAvailable(
            manifest: UpdateManifest(
              version: '0.3.0',
              notes: "## What's new\n- foo\n- bar",
              pubDate: '2026-05-01T00:00:00Z',
            ),
          ),
        );

        expect(find.textContaining(RegExp(r'0\.3\.0')), findsOneWidget);
        expect(find.text("## What's new\n- foo\n- bar"), findsOneWidget);
        expect(buttonNamed(exactly('Download')), findsOne);
        expect(
          buttonNamed(RegExp('skip this version', caseSensitive: false)),
          findsOne,
        );
        expect(
          buttonNamed(RegExp('remind me later', caseSensitive: false)),
          findsOne,
        );
      },
    );

    testWidgets('clicking Download invokes useUpdater.download()', (
      tester,
    ) async {
      await openWith(tester, const UpdaterAvailable(manifest: bareManifest));

      await tester.tap(find.text('Download'));

      expect(updater.calls, ['download']);
    });

    testWidgets(
      'clicking Skip this version invokes useUpdater.skipVersion(version)',
      (tester) async {
        await openWith(tester, const UpdaterAvailable(manifest: bareManifest));

        await tester.tap(find.text('Skip this version'));

        expect(updater.calls, ['skipVersion(0.3.0)']);
      },
    );

    testWidgets('clicking Remind me later invokes useUpdater.remindLater()', (
      tester,
    ) async {
      await openWith(tester, const UpdaterAvailable(manifest: bareManifest));

      await tester.tap(find.text('Remind me later'));

      expect(updater.calls, ['remindLater']);
    });

    testWidgets('renders progress bar with aria-valuenow when downloading', (
      tester,
    ) async {
      await openWith(
        tester,
        const UpdaterDownloading(manifest: bareManifest, progress: 73),
      );

      final bar = find.semantics.byPredicate(
        (node) => node.getSemanticsData().role == SemanticsRole.progressBar,
      );
      expect(bar, findsOne);
      final data = bar.evaluate().single.getSemanticsData();
      expect(data.value, '73');
      expect(data.minValue, '0');
      expect(data.maxValue, '100');
    });

    testWidgets(
      'clicking Cancel during downloading invokes useUpdater.cancel()',
      (tester) async {
        await openWith(
          tester,
          const UpdaterDownloading(manifest: bareManifest, progress: 50),
        );

        expect(buttonNamed(exactly('Cancel')), findsOne);
        await tester.tap(find.text('Cancel'));

        expect(updater.calls, ['cancel']);
      },
    );

    testWidgets('renders Install & Restart button when state is ready', (
      tester,
    ) async {
      await openWith(tester, const UpdaterReady(manifest: bareManifest));

      expect(
        buttonNamed(RegExp('install.*restart', caseSensitive: false)),
        findsOne,
      );
    });

    testWidgets('clicking Install & Restart invokes useUpdater.install()', (
      tester,
    ) async {
      await openWith(tester, const UpdaterReady(manifest: bareManifest));

      await tester.tap(find.text('Install & Restart'));

      expect(updater.calls, ['install']);
    });

    testWidgets(
      'renders red signature-error banner with no auto-retry button',
      (tester) async {
        await openWith(
          tester,
          const UpdaterError(
            subtype: UpdaterErrorSubtype.signature,
            message: 'Signature mismatch',
          ),
        );

        expect(
          find.textContaining(
            RegExp('verification failed', caseSensitive: false),
          ),
          findsOneWidget,
        );
        expect(buttonNamed(exactly('Retry')), findsNothing);
      },
    );

    testWidgets('renders Retry button for download error', (tester) async {
      await openWith(
        tester,
        const UpdaterError(
          subtype: UpdaterErrorSubtype.download,
          message: 'Connection reset',
        ),
      );

      expect(buttonNamed(exactly('Retry')), findsOne);
    });

    testWidgets('Retry on download error invokes useUpdater.download()', (
      tester,
    ) async {
      await openWith(
        tester,
        const UpdaterError(
          subtype: UpdaterErrorSubtype.download,
          message: 'Connection reset',
        ),
      );

      await tester.tap(find.text('Retry'));

      expect(updater.calls, ['download']);
    });

    testWidgets('Retry on check error checks again instead of installing', (
      tester,
    ) async {
      await openWith(
        tester,
        const UpdaterError(
          subtype: UpdaterErrorSubtype.check,
          message: 'network down',
        ),
      );

      await tester.tap(find.text('Retry'));

      expect(updater.calls, ['check(manual: true)']);
      expect(updater.calls, isNot(contains('install')));
    });

    testWidgets(
      'installed state asks the user to reopen the app and offers no retry',
      (tester) async {
        await openWith(tester, const UpdaterInstalled(manifest: bareManifest));

        expect(
          find.textContaining(
            RegExp(r'0\.3\.0 installed', caseSensitive: false),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(RegExp('quit and reopen', caseSensitive: false)),
          findsOneWidget,
        );
        expect(
          buttonNamed(RegExp('retry|install', caseSensitive: false)),
          findsNothing,
        );
      },
    );

    testWidgets('Escape key closes the modal', (tester) async {
      await openWith(tester, const UpdaterAvailable(manifest: bareManifest));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      expect(closes, greaterThan(0));
    });

    testWidgets('dialog has aria-modal=true', (tester) async {
      setState(const UpdaterAvailable(manifest: bareManifest));
      await pumpModal(tester, isOpen: false);
      expect(find.semantics.byLabel(behindTheDialog), findsOne);

      await pumpModal(tester);
      await tester.pumpAndSettle();

      final dialog = find.semantics.byPredicate(
        (node) => node.getSemanticsData().role == SemanticsRole.dialog,
      );
      expect(dialog, findsOne);
      expect(
        dialog.evaluate().single.getSemanticsData().flagsCollection.scopesRoute,
        isTrue,
      );
      expect(find.semantics.byLabel(behindTheDialog), findsNothing);
    });

    testWidgets('each state shows the same heading and body as today', (
      tester,
    ) async {
      final cases = <(UpdaterMachineState, List<String>, List<String>)>[
        (
          const UpdaterAvailable(manifest: bareManifest),
          ['Version 0.3.0 available'],
          ['Download', 'Skip this version', 'Remind me later', 'Close'],
        ),
        (
          const UpdaterDownloading(manifest: bareManifest, progress: 5),
          ['Downloading 0.3.0'],
          ['Cancel', 'Hide'],
        ),
        (
          const UpdaterReady(manifest: bareManifest),
          ['Version 0.3.0 ready', 'Restart the app to apply the update.'],
          ['Install & Restart', 'Close'],
        ),
        (
          const UpdaterError(
            subtype: UpdaterErrorSubtype.signature,
            message: 'Signature mismatch',
          ),
          [
            'Update verification failed',
            'The downloaded update could not be verified. The download may '
                'be corrupted or the release may be misconfigured.',
          ],
          ['Dismiss'],
        ),
        (
          const UpdaterError(
            subtype: UpdaterErrorSubtype.install,
            message: 'Disk full',
          ),
          ['Update failed', 'Disk full'],
          ['Retry', 'Close'],
        ),
        (
          const UpdaterInstalled(manifest: bareManifest),
          [
            'Version 0.3.0 installed',
            'Quit and reopen Swiftie Quiz to start using it.',
          ],
          ['Close'],
        ),
        (const UpdaterIdle(), ['No update information'], ['Close']),
        (const UpdaterChecking(), ['No update information'], ['Close']),
        (const UpdaterUpToDate(), ['No update information'], ['Close']),
        (const UpdaterInstalling(), ['No update information'], ['Close']),
      ];
      for (final (state, texts, buttons) in cases) {
        setState(state);
        await pumpModal(tester);
        await tester.pump();

        for (final text in texts) {
          expect(find.text(text), findsOneWidget, reason: '$state $text');
        }
        final labels = [
          for (final node in buttonNamed(RegExp('.')).evaluate())
            node.getSemanticsData().label,
        ];
        expect(labels, buttons, reason: '$state');
      }
      await tester.pumpAndSettle();
    });

    testWidgets('headings are 20 px semibold, tinted by tone', (tester) async {
      final cases = <(UpdaterMachineState, String, Color)>[
        (
          const UpdaterReady(manifest: bareManifest),
          'Version 0.3.0 ready',
          AppTokens.dark.foreground,
        ),
        (
          const UpdaterError(
            subtype: UpdaterErrorSubtype.download,
            message: 'x',
          ),
          'Update failed',
          const Color(0xFFFFF085),
        ),
        (
          const UpdaterError(
            subtype: UpdaterErrorSubtype.signature,
            message: 'x',
          ),
          'Update verification failed',
          const Color(0xFFFFC9C9),
        ),
      ];
      for (final (state, title, color) in cases) {
        setState(state);
        await pumpModal(tester);
        await tester.pump();

        final style = tester.widget<Text>(find.text(title)).style!;
        expect(style.fontSize, 20, reason: title);
        expect(style.height, 28 / 20);
        expect(style.fontWeight, FontWeight.w600);
        expect(style.letterSpacing, 20 * -0.025);
        expect(style.color, color, reason: title);
        expect(
          find.semantics.byPredicate((node) {
            final data = node.getSemanticsData();
            return data.flagsCollection.isHeader && data.label == title;
          }),
          findsOne,
        );
      }
      await tester.pumpAndSettle();
    });

    testWidgets('error banners tint the message red or yellow', (tester) async {
      setState(
        const UpdaterError(
          subtype: UpdaterErrorSubtype.check,
          message: 'network down',
        ),
      );
      await pumpModal(tester);
      await tester.pumpAndSettle();

      Container banner(String text) => tester.widget<Container>(
        find
            .ancestor(of: find.text(text), matching: find.byType(Container))
            .first,
      );
      expect(
        (banner('network down').decoration! as BoxDecoration).color,
        AppPalette.yellow500.slashOpacity(10),
      );
      expect(
        tester.widget<Text>(find.text('network down')).style!.color,
        AppPalette.yellow200,
      );

      setState(
        const UpdaterError(
          subtype: UpdaterErrorSubtype.signature,
          message: 'x',
        ),
      );
      await tester.pump();
      const text = _UpdateModalText.verificationFailure;
      expect(
        (banner(text).decoration! as BoxDecoration).color,
        AppPalette.red500.slashOpacity(10),
      );
      expect(
        tester.widget<Text>(find.text(text)).style!.color,
        AppPalette.red200,
      );
    });

    testWidgets('the card is a 512 px rounded card with a 24 px inset', (
      tester,
    ) async {
      await openWith(tester, const UpdaterReady(manifest: bareManifest));

      final card = tester.getRect(dialogCard());
      expect(card.width, 512);
      expect(card.center, surface.center(Offset.zero));
      final decoration =
          tester.widget<Container>(dialogCard()).decoration! as BoxDecoration;
      expect(decoration.color, AppTokens.dark.card);
      expect(decoration.border, Border.all(color: AppTokens.dark.border));
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(16)),
      );
      expect(
        tester.getTopLeft(find.text('Version 0.3.0 ready')) - card.topLeft,
        const Offset(25, 25),
      );
    });

    testWidgets('narrow windows keep 24 px of backdrop either side', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openWith(tester, const UpdaterReady(manifest: bareManifest));

      final card = tester.getRect(dialogCard());
      expect(card.left, 24);
      expect(card.right, 500 - 24);
    });

    testWidgets('margins collapse between blocks as the browser does', (
      tester,
    ) async {
      await openWith(
        tester,
        const UpdaterAvailable(
          manifest: UpdateManifest(version: '0.3.0', notes: 'n', pubDate: ''),
        ),
      );
      final heading = tester.getRect(find.text('Version 0.3.0 available'));
      final notes = tester.getRect(
        find
            .ancestor(of: find.text('n'), matching: find.byType(Container))
            .first,
      );
      final download = tester.getRect(buttonBox('Download').first);
      expect(notes.top - heading.bottom, 12);
      expect(download.top - notes.bottom, 16);

      setState(const UpdaterDownloading(manifest: bareManifest, progress: 5));
      await tester.pump();
      final title = tester.getRect(find.text('Downloading 0.3.0'));
      final bar = tester.getRect(progressTrack());
      final cancel = tester.getRect(buttonBox('Cancel').first);
      expect(bar.top - title.bottom, 16);
      expect(bar.height, 8);
      expect(cancel.top - bar.bottom, 16);

      setState(const UpdaterIdle());
      await tester.pump();
      final empty = tester.getRect(find.text('No update information'));
      final close = tester.getRect(buttonBox('Close').first);
      expect(close.top - empty.bottom, 16);
    });

    testWidgets('long notes scroll inside a 256 px area', (tester) async {
      final notes = List.generate(60, (line) => 'Line $line').join('\n');
      await openWith(
        tester,
        UpdaterAvailable(
          manifest: UpdateManifest(version: '0.3.0', notes: notes, pubDate: ''),
        ),
      );

      final area = find.ancestor(
        of: find.text(notes),
        matching: find.byType(SingleChildScrollView),
      );
      expect(tester.getSize(area).height, UpdateModal.notesMaxHeight);
      final style = tester.widget<Text>(find.text(notes)).style!;
      expect(style.fontSize, 14);
      expect(style.color, AppTokens.dark.mutedForeground);
      expect(style.fontFamily, '.AppleSystemUIFontMonospaced');
      expect(
        style.fontFamilyFallback,
        containsAllInOrder(['Menlo', 'Consolas']),
      );

      final before = tester.getTopLeft(find.text(notes)).dy;
      await tester.drag(area, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text(notes)).dy, lessThan(before));
    });

    testWidgets('empty notes leave the notes area out', (tester) async {
      await openWith(tester, const UpdaterAvailable(manifest: bareManifest));

      expect(
        find.descendant(
          of: find.byType(UpdateModal),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
    });

    testWidgets('the progress bar fills blue to the percentage', (
      tester,
    ) async {
      await openWith(
        tester,
        const UpdaterDownloading(manifest: bareManifest, progress: 25),
      );

      final track = tester.getRect(progressTrack());
      final fill = tester.getRect(
        find.descendant(
          of: find.byType(FractionallySizedBox),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(track.width, 512 - 50);
      expect(fill.width, track.width * 0.25);
      expect(fill.left, track.left);
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(
                of: find.byType(FractionallySizedBox),
                matching: find.byType(ColoredBox),
              ),
            )
            .color,
        AppPalette.blue600,
      );
    });

    testWidgets('primary, secondary and tertiary buttons look as today', (
      tester,
    ) async {
      await openWith(tester, const UpdaterAvailable(manifest: bareManifest));

      final primary = buttonDecoration(tester, 'Download');
      expect(primary.color, const Color(0xFF7F22FE));
      expect(primary.border, isNull);
      expect(primary.borderRadius, const BorderRadius.all(Radius.circular(6)));
      final primaryText = tester.widget<Text>(find.text('Download')).style!;
      expect(primaryText.color, AppPalette.white);
      expect(primaryText.fontWeight, FontWeight.w500);
      expect(primaryText.fontSize, 14);

      final secondary = buttonDecoration(tester, 'Skip this version');
      expect(secondary.color, AppTokens.dark.card);
      expect(secondary.border, Border.all(color: AppTokens.dark.border));
      expect(
        tester.widget<Text>(find.text('Skip this version')).style!.color,
        AppTokens.dark.foreground,
      );

      final tertiary = buttonDecoration(tester, 'Close');
      expect(tertiary.color, isNull);
      expect(tertiary.border, isNull);
      expect(
        tester.widget<Text>(find.text('Close')).style!.color,
        AppTokens.dark.mutedForeground,
      );
    });

    testWidgets('hover darkens primary, tints secondary, lights tertiary', (
      tester,
    ) async {
      await openWith(tester, const UpdaterAvailable(manifest: bareManifest));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);

      await mouse.moveTo(tester.getCenter(find.text('Download')));
      await tester.pump();
      expect(buttonDecoration(tester, 'Download').color, AppPalette.violet700);

      await mouse.moveTo(tester.getCenter(find.text('Skip this version')));
      await tester.pump();
      expect(
        buttonDecoration(tester, 'Skip this version').color,
        AppTokens.dark.muted.slashOpacity(40),
      );
      expect(buttonDecoration(tester, 'Download').color, AppPalette.violet600);

      await mouse.moveTo(tester.getCenter(find.text('Close')));
      await tester.pump();
      expect(
        tester.widget<Text>(find.text('Close')).style!.color,
        AppTokens.dark.foreground,
      );
    });

    testWidgets('a wrapped line of buttons stretches to its tallest button', (
      tester,
    ) async {
      await openWith(tester, const UpdaterAvailable(manifest: bareManifest));
      final card = tester.getRect(dialogCard());
      final innerRight = card.right - 25;

      final download = tester.getRect(buttonBox('Download').first);
      final skip = tester.getRect(buttonBox('Skip this version').first);
      final remind = tester.getRect(buttonBox('Remind me later').first);
      final close = tester.getRect(buttonBox('Close').first);

      expect(skip.height, 20 + 16 + 2);
      expect(download.height, skip.height);
      expect(download.top, skip.top);
      expect(skip.left - download.right, 8);
      expect(skip.right, innerRight);
      expect(remind.top, skip.bottom + 8);
      expect(close.height, remind.height);
      expect(close.right, innerRight);
      expect(tester.getCenter(find.text('Download')).dy, download.center.dy);

      setState(const UpdaterReady(manifest: bareManifest));
      await tester.pump();
      final install = tester.getRect(buttonBox('Install & Restart').first);
      final readyClose = tester.getRect(buttonBox('Close').first);
      expect(install.height, 20 + 16);
      expect(readyClose.height, 20 + 16);
      expect(readyClose.right, innerRight);
      expect(readyClose.left - install.right, 8);
    });

    testWidgets('Close and Hide close the dialog; error Close dismisses', (
      tester,
    ) async {
      await openWith(tester, const UpdaterReady(manifest: bareManifest));
      await tester.tap(find.text('Close'));
      expect(closes, 1);

      setState(const UpdaterDownloading(manifest: bareManifest, progress: 9));
      await tester.pump();
      await tester.tap(find.text('Hide'));
      expect(closes, 2);

      setState(
        const UpdaterError(subtype: UpdaterErrorSubtype.download, message: 'x'),
      );
      await tester.pump();
      await tester.tap(find.text('Close'));
      expect(closes, 2);
      expect(updater.calls, ['dismiss']);

      setState(
        const UpdaterError(
          subtype: UpdaterErrorSubtype.signature,
          message: 'x',
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Dismiss'));
      expect(updater.calls, ['dismiss', 'dismiss']);

      setState(
        const UpdaterError(subtype: UpdaterErrorSubtype.install, message: 'x'),
      );
      await tester.pump();
      await tester.tap(find.text('Retry'));
      expect(updater.calls, ['dismiss', 'dismiss', 'install']);
    });

    testWidgets('clicking the backdrop closes; clicking the card does not', (
      tester,
    ) async {
      await openWith(tester, const UpdaterReady(manifest: bareManifest));

      await tester.tap(find.text('Restart the app to apply the update.'));
      await tester.tapAt(
        tester.getRect(dialogCard()).topLeft + const Offset(30, 30),
      );
      expect(closes, 0);

      await tester.tapAt(const Offset(10, 10));
      expect(closes, 1);
      expect(screenTaps, 0);
    });

    testWidgets('scales in from 0.95 and fades in', (tester) async {
      setState(const UpdaterReady(manifest: bareManifest));
      await pumpModal(tester);

      final opacity = tester.widget<FadeTransition>(
        find
            .ancestor(of: dialogCard(), matching: find.byType(FadeTransition))
            .first,
      );
      expect(cardScale(tester).scale.value, UpdateModal.hiddenScale);
      expect(opacity.opacity.value, 0);

      await tester.pump(const Duration(milliseconds: 100));
      expect(cardScale(tester).scale.value, greaterThan(0.95));
      expect(opacity.opacity.value, inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 200));
      expect(opacity.opacity.value, 1);

      await tester.pumpAndSettle();
      expect(cardScale(tester).scale.value, 1);
    });

    testWidgets('animates out before it disappears', (tester) async {
      await openWith(tester, const UpdaterReady(manifest: bareManifest));

      await pumpModal(tester, isOpen: false);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Version 0.3.0 ready'), findsOneWidget);
      expect(cardScale(tester).scale.value, lessThan(1));
      expect(
        tester
            .widget<FadeTransition>(
              find
                  .ancestor(
                    of: dialogCard(),
                    matching: find.byType(FadeTransition),
                  )
                  .first,
            )
            .opacity
            .value,
        inExclusiveRange(0, 1),
      );

      await tester.tapAt(const Offset(10, 10));
      expect(closes, 0);
      expect(find.semantics.byLabel(behindTheDialog), findsOne);
      expect(
        find.semantics.byPredicate(
          (node) => node.getSemanticsData().role == SemanticsRole.dialog,
        ),
        findsNothing,
      );

      await tester.pumpAndSettle();
      expect(find.text('Version 0.3.0 ready'), findsNothing);
      expect(tester.getSize(find.byType(UpdateModal)), Size.zero);
    });

    testWidgets('reopening while it animates out keeps it open', (
      tester,
    ) async {
      await openWith(tester, const UpdaterReady(manifest: bareManifest));

      await pumpModal(tester, isOpen: false);
      await tester.pump(const Duration(milliseconds: 100));
      await pumpModal(tester);
      await tester.pumpAndSettle();

      expect(find.text('Version 0.3.0 ready'), findsOneWidget);
      expect(cardScale(tester).scale.value, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closes, 1);
    });

    testWidgets('keyboard activates buttons only while it is open', (
      tester,
    ) async {
      await openWith(tester, const UpdaterAvailable(manifest: bareManifest));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(updater.calls, ['download']);

      await pumpModal(tester, isOpen: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Download'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(updater.calls, ['download']);
    });

    testWidgets('reduced motion shows and hides it without animating', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      setState(const UpdaterReady(manifest: bareManifest));

      await pumpModal(tester);
      expect(cardScale(tester).scale.value, 1);
      expect(
        tester
            .widget<FadeTransition>(
              find
                  .ancestor(
                    of: dialogCard(),
                    matching: find.byType(FadeTransition),
                  )
                  .first,
            )
            .opacity
            .value,
        1,
      );
      expect(tester.hasRunningAnimations, isFalse);

      await pumpModal(tester, isOpen: false);
      expect(find.text('Version 0.3.0 ready'), findsNothing);
    });

    testWidgets('Escape does nothing while the dialog is closed', (
      tester,
    ) async {
      setState(const UpdaterAvailable(manifest: bareManifest));
      await pumpModal(tester, isOpen: false);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closes, 0);

      await pumpModal(tester);
      await tester.pumpAndSettle();
      await pumpModal(tester, isOpen: false);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closes, 0);
    });
  });
}

abstract final class _UpdateModalText {
  static const String verificationFailure =
      'The downloaded update could not be verified. The download may be '
      'corrupted or the release may be misconfigured.';
}
