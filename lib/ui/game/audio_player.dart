import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/relisten_schedule.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';

final class _ScopeLifetime {
  bool _ended = false;

  bool get ended => _ended;

  void end() => _ended = true;
}

final _scopeLifetimeProvider = Provider<_ScopeLifetime>((ref) {
  final lifetime = _ScopeLifetime();
  ref.onDispose(lifetime.end);
  return lifetime;
});

class AudioPlayer extends ConsumerStatefulWidget {
  const AudioPlayer({
    super.key,
    required this.track,
    required this.active,
    this.onLoaded,
  });

  static const String heading = 'Name That Song!';
  static const String subheading = 'Listen carefully and guess the track';
  static const String extendedNotice = 'Clip extended to help with your guess';
  static const double padding = 32;
  static const double radius = AppRadii.xl2;
  static const double gap = 24;
  static const double headingGap = 4;
  static const double buttonSize = 80;
  static const double buttonIconSize = 32;
  static const double playIconNudge = 4;
  static const double outlineWidth = 2;
  static const int outlinePercent = 50;
  static const double hoverScale = 1.1;
  static const double progressHeight = 8;
  static const double progressGap = 12;
  static const double noticeGap = 8;
  static const int noticePercent = 70;

  final Track track;
  final bool active;
  final VoidCallback? onLoaded;

  static String formatSeconds(double seconds) => '${seconds.floor()}s';

  @override
  ConsumerState<AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends ConsumerState<AudioPlayer>
    with SingleTickerProviderStateMixin {
  late final ProviderContainer _container;
  late final _ScopeLifetime _scope;
  late final AnimationController _hover = AnimationController(
    vsync: this,
    duration: AppMotion.cssTransitionDuration,
  );
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _scope = ref.read(_scopeLifetimeProvider);
    if (widget.active) {
      _autoPlay();
    }
  }

  @override
  void didUpdateWidget(AudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track == widget.track && oldWidget.active == widget.active) {
      return;
    }
    if (widget.active) {
      _autoPlay();
    } else {
      _release();
    }
  }

  @override
  void dispose() {
    _release();
    _hover.dispose();
    super.dispose();
  }

  void _afterFrame(Future<void> Function(AudioController audio) action) {
    final container = _container;
    final scope = _scope;
    scheduleMicrotask(() async {
      if (!scope.ended) {
        await action(container.read(audioControllerProvider.notifier));
      }
    });
  }

  void _autoPlay() {
    final request = ++_request;
    final track = widget.track;
    _afterFrame((audio) => _playAndReport(audio, track, request));
  }

  void _release() {
    _request += 1;
    _afterFrame((audio) async {
      audio.reset();
    });
  }

  Future<void> _playAndReport(
    AudioController audio,
    Track track,
    int request,
  ) async {
    await audio.play(track);
    if (mounted && request == _request) {
      widget.onLoaded?.call();
    }
  }

  void _handleTap() {
    final audio = ref.read(audioControllerProvider.notifier);
    final state = ref.read(audioControllerProvider);
    if (state.playing) {
      audio.pause();
    } else if (state.paused) {
      audio.resume();
    } else if (state.progress > 0) {
      audio.relisten();
    } else {
      unawaited(_playAndReport(audio, widget.track, ++_request));
    }
  }

  void _setHovered(bool hovered) {
    _hover.animateTo(hovered ? 1 : 0, curve: AppMotion.cssTransitionCurve);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final audio = ref.watch(audioControllerProvider);
    final clipExtended = audio.relistenStage >= firstEscalationRelisten;
    final elapsed = audio.clipDuration > 0
        ? audio.progress * audio.clipDuration
        : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AudioPlayer.padding),
          decoration: BoxDecoration(
            color: tokens.card,
            border: Border.all(color: tokens.border),
            borderRadius: BorderRadius.circular(AudioPlayer.radius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AudioPlayer.heading,
                textAlign: TextAlign.center,
                style: AppText.xl3
                    .copyWith(
                      fontWeight: FontWeight.w700,
                      color: tokens.foreground,
                    )
                    .trackingTight,
              ),
              const SizedBox(height: AudioPlayer.headingGap),
              Text(
                AudioPlayer.subheading,
                textAlign: TextAlign.center,
                style: AppText.sm.copyWith(color: tokens.mutedForeground),
              ),
              const SizedBox(height: AudioPlayer.gap),
              if (audio.loading)
                const SizedBox.square(
                  dimension: AudioPlayer.buttonSize,
                  child: ClipRect(
                    child: Center(child: CatLoader(size: CatLoaderSize.sm)),
                  ),
                )
              else
                _playButton(tokens, audio),
              const SizedBox(height: AudioPlayer.gap),
              _progressRow(tokens, audio, elapsed),
            ],
          ),
        ),
        if (clipExtended) ...[
          const SizedBox(height: AudioPlayer.noticeGap),
          Text(
            AudioPlayer.extendedNotice,
            textAlign: TextAlign.center,
            style: AppText.xs.copyWith(
              color: tokens.mutedForeground.slashOpacity(
                AudioPlayer.noticePercent,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _playButton(AppTokens tokens, AudioState audio) {
    final gradient = audio.playing || (!audio.paused && audio.progress == 0);
    final iconColor = gradient ? AppPalette.white : AppPalette.purple400;
    final Widget icon = audio.playing
        ? AppIcon(
            LucideGlyph.pause,
            size: AudioPlayer.buttonIconSize,
            color: iconColor,
          )
        : Padding(
            padding: EdgeInsets.only(
              left: gradient ? AudioPlayer.playIconNudge : 0,
            ),
            child: AppIcon(
              LucideGlyph.play,
              size: AudioPlayer.buttonIconSize,
              color: iconColor,
            ),
          );
    final face = Container(
      width: AudioPlayer.buttonSize,
      height: AudioPlayer.buttonSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppShadows.lg,
        color: gradient ? null : tokens.card,
        gradient: gradient
            ? AppGradients.play.tailwind(
                const CssGradientDirection.toBottomRight(),
              )
            : null,
        border: gradient
            ? null
            : Border.all(
                color: AppPalette.purple500.slashOpacity(
                  AudioPlayer.outlinePercent,
                ),
                width: AudioPlayer.outlineWidth,
              ),
      ),
      child: icon,
    );
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: FocusableActionDetector(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _handleTap();
              return null;
            },
          ),
        },
        child: Semantics(
          button: true,
          label: audio.playing ? 'Pause' : 'Play',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            child: AnimatedBuilder(
              animation: _hover,
              builder: (context, child) => Transform.scale(
                scale: 1 + (AudioPlayer.hoverScale - 1) * _hover.value,
                child: child,
              ),
              child: face,
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressRow(AppTokens tokens, AudioState audio, double elapsed) {
    const radius = BorderRadius.all(
      Radius.circular(AudioPlayer.progressHeight / 2),
    );
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: radius,
            child: SizedBox(
              height: AudioPlayer.progressHeight,
              child: ColoredBox(
                color: tokens.muted,
                child: AnimatedFractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: audio.progress.clamp(0.0, 1.0),
                  heightFactor: 1,
                  duration: AppMotion.cssTransitionDuration,
                  curve: AppMotion.cssTransitionCurve,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: AppGradients.play.tailwind(
                        CssGradientDirection.toRight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (audio.clipDuration > 0) ...[
          const SizedBox(width: AudioPlayer.progressGap),
          Text(
            '${AudioPlayer.formatSeconds(elapsed)} / '
            '${AudioPlayer.formatSeconds(audio.clipDuration)}',
            style: AppText.xs.copyWith(
              color: tokens.mutedForeground,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}
