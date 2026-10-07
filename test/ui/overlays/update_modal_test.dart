import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/updater.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/updater_controller.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/kit/modal_stack.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/overlays/update_modal.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

const Size surface = Size(800, 600);
const String notes =
    '### Added\n- **Records everywhere.** Every win is a record.\n- Misu drops by now and then.';
const String firstHeading = 'Added';
const String firstBullet = 'Records everywhere. Every win is a record.';
const UpdateManifest manifest = UpdateManifest(
  version: '0.3.1',
  notes: notes,
  pubDate: '2026-10-05T00:00:00Z',
);
const String behindTheDialog = 'Main menu behind the dialog';
const String restarting = 'Restarting Project Swiftie...';

typedef Press = ({String label, PillKind kind, String? call, bool closes});

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

  void setUpdater(UpdaterMachineState state) =>
      container.read(gameControllerProvider.notifier).setUpdaterState(state);

  Future<void> pumpModal(
    WidgetTester tester, {
    bool isOpen = true,
    ThemeData? theme,
  }) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme ?? AppTheme.dark,
        home: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => screenTaps++,
              child: Align(
                alignment: Alignment.topLeft,
                child: PillButton(
                  label: behindTheDialog,
                  onPressed: () => screenTaps++,
                ),
              ),
            ),
            UpdateModal(isOpen: isOpen, onClose: () => closes++),
          ],
        ),
      ),
    ),
  );

  Future<void> openWith(
    WidgetTester tester,
    UpdaterMachineState state, {
    ThemeData? theme,
  }) async {
    setUpdater(state);
    await pumpModal(tester, theme: theme);
    await tester.pumpAndSettle();
  }

  List<String> buttonLabels() => [
    for (final node
        in find.semantics
            .byPredicate(
              (node) => node.getSemanticsData().flagsCollection.isButton,
            )
            .evaluate())
      node.getSemanticsData().label,
  ];

  SemanticsFinder dialogNode() => find.semantics.byPredicate(
    (node) => node.getSemanticsData().role == SemanticsRole.dialog,
  );

  Finder pill(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(PillButton));

  Finder boxAround(String text) => find
      .ancestor(
        of: find.text(text),
        matching: find.byWidgetPredicate(
          (widget) => widget is Container && widget.decoration is BoxDecoration,
        ),
      )
      .first;

  Finder panel() => find
      .ancestor(
        of: find.byType(Column),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).borderRadius ==
                  const BorderRadius.all(Radius.circular(16)),
        ),
      )
      .first;

  Finder progressTrack([AppTokens tokens = AppTokens.dark]) => find.descendant(
    of: find.byType(UpdateModal),
    matching: find.byWidgetPredicate(
      (widget) => widget is ColoredBox && widget.color == tokens.line,
    ),
  );

  bool focused(WidgetTester tester, String label) =>
      Focus.of(tester.element(find.text(label))).hasPrimaryFocus;

  Finder progressFill() => find.descendant(
    of: find.byType(FractionallySizedBox),
    matching: find.byType(ColoredBox),
  );

  testWidgets('the update dialog shows the design copy for each state', (
    tester,
  ) async {
    final cases =
        <
          ({UpdaterMachineState state, List<String> texts, List<Press> presses})
        >[
          (
            state: const UpdaterAvailable(manifest: manifest),
            texts: ['Version 0.3.1 is here', firstHeading, firstBullet],
            presses: [
              (
                label: 'Remind me later',
                kind: PillKind.quiet,
                call: 'remindLater',
                closes: true,
              ),
              (
                label: 'Skip this version',
                kind: PillKind.outline,
                call: 'skipVersion(0.3.1)',
                closes: true,
              ),
              (
                label: 'Download',
                kind: PillKind.coral,
                call: 'download',
                closes: false,
              ),
            ],
          ),
          (
            state: const UpdaterDownloading(manifest: manifest, progress: 42),
            texts: ['Downloading 0.3.1', '42%'],
            presses: [
              (label: 'Hide', kind: PillKind.quiet, call: null, closes: true),
              (
                label: 'Cancel download',
                kind: PillKind.outline,
                call: 'cancel',
                closes: true,
              ),
            ],
          ),
          (
            state: const UpdaterReady(manifest: manifest),
            texts: [
              '0.3.1 is ready',
              'Restart Project Swiftie to finish updating. Your progress is '
                  'saved.',
            ],
            presses: [
              (label: 'Later', kind: PillKind.quiet, call: null, closes: true),
              (
                label: 'Restart now',
                kind: PillKind.coral,
                call: 'install',
                closes: false,
              ),
            ],
          ),
          (
            state: const UpdaterError(
              subtype: UpdaterErrorSubtype.download,
              message: 'Connection reset by peer',
            ),
            texts: ['The update hit a snag', 'Connection reset by peer'],
            presses: [
              (
                label: 'Close',
                kind: PillKind.quiet,
                call: 'dismiss',
                closes: true,
              ),
              (
                label: 'Try again',
                kind: PillKind.coral,
                call: 'retry',
                closes: false,
              ),
            ],
          ),
          (
            state: const UpdaterError(
              subtype: UpdaterErrorSubtype.check,
              message: '',
            ),
            texts: [
              'The update hit a snag',
              'Could not reach the update server.',
            ],
            presses: [
              (
                label: 'Close',
                kind: PillKind.quiet,
                call: 'dismiss',
                closes: true,
              ),
              (
                label: 'Try again',
                kind: PillKind.coral,
                call: 'retry',
                closes: false,
              ),
            ],
          ),
          (
            state: const UpdaterUpToDate(),
            texts: ['No updates', "You're on the latest version."],
            presses: [
              (label: 'Close', kind: PillKind.quiet, call: null, closes: true),
            ],
          ),
        ];

    for (final (:state, :texts, :presses) in cases) {
      await openWith(tester, state);

      expect(dialogNode(), findsOne, reason: '$state');
      for (final text in texts) {
        expect(find.text(text), findsOneWidget, reason: '$state "$text"');
      }
      expect(buttonLabels(), [
        for (final press in presses) press.label,
      ], reason: '$state');

      for (final press in presses) {
        expect(
          tester.widget<PillButton>(pill(press.label)).kind,
          press.kind,
          reason: '$state ${press.label}',
        );
        updater.calls.clear();
        closes = 0;
        await tester.tap(find.text(press.label));
        await tester.pump();
        expect(updater.calls, [?press.call], reason: '$state ${press.label}');
        expect(closes, press.closes ? 1 : 0, reason: '$state ${press.label}');
      }
    }

    await openWith(
      tester,
      const UpdaterDownloading(manifest: manifest, progress: 42),
    );
    final bar = find.semantics.byPredicate(
      (node) => node.getSemanticsData().role == SemanticsRole.progressBar,
    );
    expect(bar, findsOne);
    expect(bar.evaluate().single.getSemanticsData().value, '42');
    final track = tester.getRect(progressTrack());
    expect(track.height, 4);
    expect(
      tester.getRect(progressFill()).width,
      closeTo(track.width * 0.42, 0.01),
    );
    expect(
      tester.widget<ColoredBox>(progressFill()).color,
      AppTokens.dark.coral,
    );

    setUpdater(const UpdaterInstalling());
    await tester.pump();
    expect(dialogNode(), findsNothing);
    expect(buttonLabels(), isEmpty);
    final loader = tester.widget<CatLoader>(find.byType(CatLoader));
    expect(loader.size, CatLoaderSize.lg);
    expect(loader.px, 200);
    expect(loader.label, restarting);
    expect(find.text(restarting), findsOneWidget);
  });

  testWidgets('a closed dialog draws and announces nothing', (tester) async {
    setUpdater(const UpdaterAvailable(manifest: manifest));
    await pumpModal(tester, isOpen: false);

    expect(find.textContaining('0.3.1'), findsNothing);
    expect(dialogNode(), findsNothing);
    expect(find.semantics.byLabel(behindTheDialog), findsOne);
    expect(container.read(modalStackProvider), isEmpty);
    await tester.tapAt(surface.center(Offset.zero));
    expect(screenTaps, 1);
  });

  testWidgets('the panel follows the design measurements', (tester) async {
    await openWith(tester, const UpdaterAvailable(manifest: manifest));
    const tokens = AppTokens.dark;

    final card = tester.getRect(panel());
    expect(card.width, 480);
    expect(card.center, surface.center(Offset.zero));
    final title = tester.widget<Text>(find.text('Version 0.3.1 is here'));
    expect(title.style!.fontFamily, 'Instrument Serif');
    expect(title.style!.fontSize, 32);
    expect(title.style!.height, 36 / 32);
    expect(title.style!.color, tokens.fg);

    final notesBox = tester.getRect(boxAround(firstBullet));
    final notesDecoration =
        tester.widget<Container>(boxAround(firstBullet)).decoration!
            as BoxDecoration;
    expect(
      notesBox.top - tester.getRect(find.text('Version 0.3.1 is here')).bottom,
      12,
    );
    expect(notesDecoration.color, tokens.card);
    expect(notesDecoration.border, Border.all(color: tokens.line));
    expect(
      notesDecoration.borderRadius,
      const BorderRadius.all(Radius.circular(10)),
    );
    final notesStyle = tester.widget<Text>(find.text(firstBullet)).style!;
    expect(notesStyle.fontSize, 14);
    expect(notesStyle.height, 22 / 14);
    expect(notesStyle.color, tokens.mut);
    expect(
      tester.getTopLeft(find.text(firstHeading)) - notesBox.topLeft,
      const Offset(17, 15),
    );
    final firstAction = tester.getRect(pill('Remind me later'));
    expect(firstAction.top - notesBox.bottom, 12 + 8);

    setUpdater(const UpdaterReady(manifest: manifest));
    await tester.pumpAndSettle();
    final paragraph = tester
        .widget<Text>(
          find.text(
            'Restart Project Swiftie to finish updating. Your progress is '
            'saved.',
          ),
        )
        .style!;
    expect(paragraph.fontSize, 15);
    expect(paragraph.height, 22 / 15);
    expect(paragraph.color, tokens.mut);
    final later = tester.getRect(pill('Later'));
    final restart = tester.getRect(pill('Restart now'));
    expect(restart.left - later.right, 8);
    expect(restart.top, later.top);
    expect(restart.right, tester.getRect(panel()).right - 26);

    setUpdater(
      const UpdaterError(
        subtype: UpdaterErrorSubtype.install,
        message: 'Disk full',
      ),
    );
    await tester.pumpAndSettle();
    final banner =
        tester.widget<Container>(boxAround('Disk full')).decoration!
            as BoxDecoration;
    expect(banner.color, tokens.roseBg);
    expect(banner.borderRadius, const BorderRadius.all(Radius.circular(10)));
    final bannerText = tester.widget<Text>(find.text('Disk full')).style!;
    expect(bannerText.fontSize, 14);
    expect(bannerText.height, 20 / 14);
    expect(bannerText.color, tokens.rose);
    expect(
      tester.getTopLeft(find.text('Disk full')) -
          tester.getTopLeft(boxAround('Disk full')),
      const Offset(14, 12),
    );
  });

  testWidgets('the panel takes the light theme colours', (tester) async {
    const tokens = AppTokens.light;
    await openWith(
      tester,
      const UpdaterAvailable(manifest: manifest),
      theme: AppTheme.light,
    );
    final notesBox =
        tester.widget<Container>(boxAround(firstBullet)).decoration!
            as BoxDecoration;
    expect(notesBox.color, tokens.card);
    expect(notesBox.border, Border.all(color: tokens.line));
    expect(
      tester.widget<Text>(find.text(firstBullet)).style!.color,
      tokens.mut,
    );

    setUpdater(const UpdaterDownloading(manifest: manifest, progress: 30));
    await tester.pumpAndSettle();
    expect(progressTrack(tokens), findsOneWidget);
    expect(tester.widget<ColoredBox>(progressFill()).color, tokens.coral);
    expect(tester.widget<Text>(find.text('30%')).style!.color, tokens.mut);

    setUpdater(
      const UpdaterError(
        subtype: UpdaterErrorSubtype.download,
        message: 'Connection reset by peer',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('The update hit a snag')).style!.color,
      tokens.fg,
    );
    expect(
      (tester
                  .widget<Container>(boxAround('Connection reset by peer'))
                  .decoration!
              as BoxDecoration)
          .color,
      tokens.roseBg,
    );
    expect(
      tester.widget<Text>(find.text('Connection reset by peer')).style!.color,
      tokens.rose,
    );
  });

  testWidgets('release notes show headings and bullets, not Markdown', (
    tester,
  ) async {
    await openWith(
      tester,
      const UpdaterAvailable(
        manifest: UpdateManifest(
          version: '0.4.1',
          notes:
              '### Updating from v0.4.0\n- **Try it again** on Windows.\n\n'
              '### Fixed\n- The window fits.',
          pubDate: '',
        ),
      ),
    );

    expect(find.textContaining('#'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
    final tokens = AppTokens.of(tester.element(find.text('Fixed')));
    expect(tester.widget<Text>(find.text('Fixed')).style!.color, tokens.fg);
    expect(find.text('Try it again on Windows.'), findsOneWidget);
    expect(find.text('•'), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Try it again on Windows.')).dx,
      greaterThan(tester.getTopLeft(find.text('Updating from v0.4.0')).dx),
    );
    expect(
      tester.getSemantics(find.text('Fixed')),
      isSemantics(isHeader: true, label: 'Fixed'),
    );
  });

  testWidgets('long release notes scroll inside the panel', (tester) async {
    final longNotes = List.generate(80, (line) => '- Line $line').join('\n');
    await openWith(
      tester,
      UpdaterAvailable(
        manifest: UpdateManifest(
          version: '0.3.1',
          notes: longNotes,
          pubDate: '',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getRect(panel()).height, lessThanOrEqualTo(600 - 48));
    expect(
      tester.getRect(pill('Download')).bottom,
      lessThanOrEqualTo(tester.getRect(panel()).bottom),
    );
    final before = tester.getTopLeft(find.text('Line 0')).dy;
    await tester.drag(boxAround('Line 0'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Line 0')).dy, lessThan(before));
  });

  testWidgets('empty release notes leave the notes box out', (tester) async {
    await openWith(
      tester,
      const UpdaterAvailable(
        manifest: UpdateManifest(version: '0.3.1', notes: '', pubDate: ''),
      ),
    );

    expect(
      tester.getRect(pill('Remind me later')).top -
          tester.getRect(find.text('Version 0.3.1 is here')).bottom,
      12 + 8,
    );
  });

  testWidgets('a failed signature check offers no retry', (tester) async {
    await openWith(
      tester,
      const UpdaterError(
        subtype: UpdaterErrorSubtype.signature,
        message: 'The signature verification failed',
      ),
    );

    expect(find.text('The update hit a snag'), findsOneWidget);
    expect(find.text('The signature verification failed'), findsOneWidget);
    expect(buttonLabels(), ['Close']);
    await tester.tap(find.text('Close'));
    expect(updater.calls, ['dismiss']);
    expect(closes, 1);
  });

  testWidgets('a failed relaunch asks the player to reopen the app', (
    tester,
  ) async {
    await openWith(tester, const UpdaterInstalled(manifest: manifest));

    expect(find.text('0.3.1 is installed'), findsOneWidget);
    expect(
      find.text('Quit and reopen Project Swiftie to start using it.'),
      findsOneWidget,
    );
    expect(buttonLabels(), ['Close']);
    await tester.tap(find.text('Close'));
    expect(updater.calls, isEmpty);
    expect(closes, 1);
  });

  testWidgets('a running check keeps the panel it interrupted', (tester) async {
    await openWith(tester, const UpdaterAvailable(manifest: manifest));

    setUpdater(const UpdaterChecking());
    await tester.pumpAndSettle();
    expect(find.text('Version 0.3.1 is here'), findsOneWidget);
    expect(find.text('No updates'), findsNothing);

    setUpdater(
      const UpdaterError(subtype: UpdaterErrorSubtype.check, message: ''),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    setUpdater(const UpdaterChecking());
    await tester.pumpAndSettle();
    expect(updater.calls, ['retry']);
    expect(closes, 0);
    expect(find.text('The update hit a snag'), findsOneWidget);

    setUpdater(const UpdaterUpToDate());
    await tester.pumpAndSettle();
    expect(find.text('No updates'), findsOneWidget);
  });

  testWidgets('a focused action never turns into another one', (tester) async {
    await openWith(
      tester,
      const UpdaterDownloading(manifest: manifest, progress: 90),
    );
    for (
      var press = 0;
      press < 3 && !focused(tester, 'Cancel download');
      press++
    ) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focused(tester, 'Cancel download'), isTrue);

    setUpdater(const UpdaterReady(manifest: manifest));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(updater.calls, isEmpty);
  });

  testWidgets('the progress bar slides to the new percentage, or jumps with '
      'reduced motion', (tester) async {
    double fillShare() =>
        tester.getSize(progressFill()).width /
        tester.getSize(progressTrack()).width;

    await openWith(
      tester,
      const UpdaterDownloading(manifest: manifest, progress: 10),
    );
    setUpdater(const UpdaterDownloading(manifest: manifest, progress: 60));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(fillShare(), closeTo(0.35, 0.01));
    await tester.pump(const Duration(milliseconds: 60));
    expect(fillShare(), closeTo(0.6, 0.001));

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    setUpdater(const UpdaterDownloading(manifest: manifest, progress: 20));
    await tester.pump();
    expect(fillShare(), closeTo(0.2, 0.001));
  });

  testWidgets('Escape and the backdrop close it only while it is topmost', (
    tester,
  ) async {
    await openWith(tester, const UpdaterReady(manifest: manifest));
    expect(container.read(modalStackProvider), hasLength(1));

    final above = Object();
    container.read(modalStackProvider.notifier).push(above);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closes, 0);

    container.read(modalStackProvider.notifier).remove(above);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closes, 1);

    await tester.tap(find.text('0.3.1 is ready'));
    expect(closes, 1);
    await tester.tapAt(const Offset(10, 10));
    expect(closes, 2);
    expect(screenTaps, 0);
  });

  testWidgets('the dialog is announced as a modal dialog with a heading', (
    tester,
  ) async {
    setUpdater(const UpdaterReady(manifest: manifest));
    await pumpModal(tester, isOpen: false);
    expect(find.semantics.byLabel(behindTheDialog), findsOne);

    await pumpModal(tester);
    await tester.pumpAndSettle();

    expect(dialogNode(), findsOne);
    expect(
      dialogNode()
          .evaluate()
          .single
          .getSemanticsData()
          .flagsCollection
          .scopesRoute,
      isTrue,
    );
    expect(find.semantics.byLabel(behindTheDialog), findsNothing);
    expect(
      find.semantics.byPredicate((node) {
        final data = node.getSemanticsData();
        return data.flagsCollection.isHeader && data.label == '0.3.1 is ready';
      }),
      findsOne,
    );
  });

  testWidgets('the restarting cover fills the window and blocks the screen', (
    tester,
  ) async {
    setUpdater(const UpdaterReady(manifest: manifest));
    await pumpModal(tester, isOpen: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focused(tester, behindTheDialog), isTrue);

    setUpdater(const UpdaterInstalling());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final cover = find.descendant(
      of: find.byType(UpdateModal),
      matching: find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == AppTokens.dark.bg,
      ),
    );
    expect(tester.getRect(cover), Offset.zero & surface);
    expect(find.text(restarting), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(restarting)).style!.color,
      AppTokens.dark.mut,
    );
    expect(find.semantics.byLabel(behindTheDialog), findsNothing);

    await tester.tapAt(const Offset(10, 10));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(screenTaps, 0);
    expect(closes, 0);
  });

  testWidgets('the restarting cover rises in, or appears at once with '
      'reduced motion', (tester) async {
    double coverOpacity() => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byType(CatLoader),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    setUpdater(const UpdaterInstalling());
    await pumpModal(tester);
    expect(coverOpacity(), 0);
    await tester.pump(const Duration(milliseconds: 125));
    expect(coverOpacity(), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 125));
    expect(coverOpacity(), 1);

    await tester.pumpWidget(const SizedBox.shrink());
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpModal(tester);
    expect(coverOpacity(), 1);
  });
}
