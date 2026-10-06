import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/data/catalog/catalog_error.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/game_state.dart';
import 'package:swiftie_quiz/state/lyrics_controller.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/kit/text_link.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

class LyricsLoadingScreen extends ConsumerStatefulWidget {
  const LyricsLoadingScreen({super.key});

  static const List<String> loadingMessages = [
    'Fetching lyrics...',
    'Digging through the vault...',
    'Long story short, almost ready...',
    'Shaking it off...',
    'Gathering all the easter eggs...',
    'In your wildest dreams...',
    'This is me trying...',
    'Almost out of the woods...',
    "It's a love story, just wait...",
    'Finding the bridge...',
  ];

  static const Duration messageInterval = Duration(seconds: 3);
  static const Duration fetchTimeout = Duration(seconds: 30);
  static const String waitingLabel = 'Getting the songs ready…';
  static const String lostTitle = 'The lyric sheets got lost.';
  static const String lostMessage =
      "We couldn't fetch lyrics from LRCLIB. "
      'Check your connection and try again.';
  static const String timeoutMessage =
      'Lyrics loading timed out. Please try again.';
  static const String notEnoughMessage =
      'Not enough songs with lyrics available. Try a different mode or add more albums.';
  static const String retryLabel = 'Try again';
  static const String backToMenuLabel = 'Back to menu';
  static const String backToMenuLink = '← Back to menu';
  static const Key progressBarKey = ValueKey('lyrics-progress-bar');
  static const Key progressFillKey = ValueKey('lyrics-progress-fill');
  static const double padTop = 24;
  static const double padBottom = 60;

  static String progressLabel(LyricsFetchProgress? progress) =>
      switch (progress) {
        (:final fetched, :final total) when total > 0 =>
          '$fetched of $total songs',
        _ => waitingLabel,
      };

  static double progressFraction(LyricsFetchProgress? progress) =>
      switch (progress) {
        (:final fetched, :final total) when total > 0 =>
          (fetched / total).clamp(0.0, 1.0),
        _ => 0,
      };

  @override
  ConsumerState<LyricsLoadingScreen> createState() =>
      _LyricsLoadingScreenState();
}

final class _LyricsTimedOut implements Exception {
  const _LyricsTimedOut();
}

class _LyricsLoadingScreenState extends ConsumerState<LyricsLoadingScreen> {
  String? _error;
  int _messageIndex = 0;
  Timer? _rotation;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _rotation?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  void _start() {
    _rotation?.cancel();
    _rotation = Timer.periodic(
      LyricsLoadingScreen.messageInterval,
      (_) => setState(
        () => _messageIndex =
            (_messageIndex + 1) % LyricsLoadingScreen.loadingMessages.length,
      ),
    );
    unawaited(_load());
  }

  void _retry() {
    setState(() {
      _error = null;
      _messageIndex = 0;
    });
    _start();
  }

  void _fail(String message) {
    _rotation?.cancel();
    ref.read(gameControllerProvider.notifier).setLyricsFetchProgress(null);
    setState(() => _error = message);
  }

  void _toMenu() => ref.read(gameControllerProvider.notifier).resetGame();

  Future<void> _load() async {
    final lyrics = ref.read(lyricsControllerProvider);
    try {
      final tracks = await lyrics.loadSourceTracks();
      if (!mounted) {
        return;
      }
      final pool = await _withinTimeout(lyrics.preFetchInitial(tracks));
      if (!mounted) {
        return;
      }
      if (pool.length < minLyricsPoolSize) {
        _fail(LyricsLoadingScreen.notEnoughMessage);
        return;
      }
      ref.read(gameControllerProvider.notifier).setPhase(GamePhase.playing);
    } on Object catch (error) {
      if (mounted) {
        _fail(_messageFor(error));
      }
    }
  }

  Future<List<TrackWithLyrics>> _withinTimeout(
    Future<List<TrackWithLyrics>> fetch,
  ) {
    final timedOut = Completer<List<TrackWithLyrics>>();
    _timeout = Timer(
      LyricsLoadingScreen.fetchTimeout,
      () => timedOut.completeError(const _LyricsTimedOut()),
    );
    return Future.any([fetch, timedOut.future]).whenComplete(() {
      _timeout?.cancel();
      _timeout = null;
    });
  }

  static String _messageFor(Object error) => switch (error) {
    LyricsSourceError(:final message) => message,
    RateLimited(:final message) => message,
    _LyricsTimedOut() => LyricsLoadingScreen.timeoutMessage,
    _ => LyricsLoadingScreen.lostMessage,
  };

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final error = _error;
    return ScreenEnter(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                layout.padX,
                LyricsLoadingScreen.padTop,
                layout.padX,
                LyricsLoadingScreen.padBottom,
              ),
              child: Center(
                child: error == null
                    ? _LyricsProgress(
                        message:
                            LyricsLoadingScreen.loadingMessages[_messageIndex],
                        onBack: _toMenu,
                      )
                    : _LyricSheetsLost(
                        message: error,
                        onRetry: _retry,
                        onBack: _toMenu,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LyricsProgress extends ConsumerWidget {
  const _LyricsProgress({required this.message, required this.onBack});

  static const double loaderSize = 220;
  static const double gap = 20;
  static const double blockGap = 18;

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final progress = ref.watch(
      gameControllerProvider.select((state) => state.lyricsFetchProgress),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          spacing: blockGap,
          children: [
            CatLoader(
              px: loaderSize,
              label: message,
              labelStyle: CatLoader.defaultLabelStyle.copyWith(
                color: tokens.mut,
              ),
            ),
            _ProgressBar(
              fraction: LyricsLoadingScreen.progressFraction(progress),
            ),
            Text(
              LyricsLoadingScreen.progressLabel(progress),
              textAlign: TextAlign.center,
              style: AppType.small.copyWith(
                color: tokens.mut,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        TextLink(label: LyricsLoadingScreen.backToMenuLink, onTap: onBack),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  static const double width = 220;
  static const double height = 2;
  static const radius = BorderRadius.all(Radius.circular(2));
  static const Duration fill = Duration(milliseconds: 300);

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return ClipRRect(
      key: LyricsLoadingScreen.progressBarKey,
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(
          color: tokens.line,
          child: AnimatedFractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: fraction,
            heightFactor: 1,
            duration: AppMotion.duration(context, fill),
            curve: Curves.ease,
            child: ColoredBox(
              key: LyricsLoadingScreen.progressFillKey,
              color: tokens.coral,
            ),
          ),
        ),
      ),
    );
  }
}

class _LyricSheetsLost extends StatelessWidget {
  const _LyricSheetsLost({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  static const double gap = 12;
  static const double actionsPadTop = 8;
  static const double messageMaxWidth = 420;

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: [
        Text(
          LyricsLoadingScreen.lostTitle,
          textAlign: TextAlign.center,
          style: AppType.display(36, height: 40 / 36, color: tokens.fg),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: messageMaxWidth),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: tokens.mut),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: actionsPadTop),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: gap,
            runSpacing: gap,
            children: [
              PillButton(
                label: LyricsLoadingScreen.retryLabel,
                onPressed: onRetry,
                size: PillSize.large,
              ),
              PillButton(
                label: LyricsLoadingScreen.backToMenuLabel,
                onPressed: onBack,
                kind: PillKind.outline,
                size: PillSize.large,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
