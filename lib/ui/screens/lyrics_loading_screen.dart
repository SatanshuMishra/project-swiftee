import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/data/catalog/catalog_error.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/lyrics_controller.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/widgets/motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/back_link.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';
import 'package:swiftie_quiz/ui/widgets/screen_background.dart';

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
  static const String timeoutMessage =
      'Lyrics loading timed out. Please try again.';
  static const String notEnoughMessage =
      'Not enough songs with lyrics available. Try a different mode or add more albums.';
  static const String loadFailedMessage =
      'Failed to load lyrics. Please try again.';
  static const String backToModeSelectLabel = 'Back to Mode Select';
  static const String backToMenuLabel = 'Back to Menu';
  static const double horizontalPadding = 24;
  static const double gap = 16;
  static const double menuLinkGap = 32;
  static const Offset entranceOffset = Offset(0, 10);
  static const double errorEntranceScale = 0.95;

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
    _rotation = Timer.periodic(
      LyricsLoadingScreen.messageInterval,
      (_) => setState(
        () => _messageIndex =
            (_messageIndex + 1) % LyricsLoadingScreen.loadingMessages.length,
      ),
    );
    unawaited(_load());
  }

  @override
  void dispose() {
    _rotation?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

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
        setState(() => _error = LyricsLoadingScreen.notEnoughMessage);
        return;
      }
      ref.read(gameControllerProvider.notifier).setPhase(GamePhase.playing);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = _messageFor(error));
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
    _ => LyricsLoadingScreen.loadFailedMessage,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final error = _error;
    return ScreenBackground(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LyricsLoadingScreen.horizontalPadding,
          ),
          child: error != null ? _errorPanel(error) : _loadingPanel(tokens),
        ),
      ),
    );
  }

  Widget _errorPanel(String error) => Motion(
    key: const ValueKey('error'),
    initial: const MotionPose(
      opacity: 0,
      scale: LyricsLoadingScreen.errorEntranceScale,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          error,
          textAlign: TextAlign.center,
          style: AppText.lg.copyWith(color: AppPalette.red400),
        ),
        const SizedBox(height: LyricsLoadingScreen.gap),
        BackLink(
          label: LyricsLoadingScreen.backToModeSelectLabel,
          animateEntrance: false,
          onPressed: () => ref
              .read(gameControllerProvider.notifier)
              .setPhase(GamePhase.setup),
        ),
      ],
    ),
  );

  Widget _loadingPanel(AppTokens tokens) => Entrance(
    fromOffset: LyricsLoadingScreen.entranceOffset,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CatLoader(
          label: LyricsLoadingScreen.loadingMessages[_messageIndex],
          labelStyle: CatLoader.defaultLabelStyle.copyWith(
            color: tokens.mutedForeground,
          ),
        ),
        const SizedBox(height: LyricsLoadingScreen.menuLinkGap),
        BackLink(
          label: LyricsLoadingScreen.backToMenuLabel,
          animateEntrance: false,
          onPressed: () =>
              ref.read(gameControllerProvider.notifier).resetGame(),
        ),
      ],
    ),
  );
}
