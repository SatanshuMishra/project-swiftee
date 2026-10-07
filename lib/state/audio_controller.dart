import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/data/catalog/catalog_error.dart';
import 'package:swiftie_quiz/domain/engine/clip_selector.dart';
import 'package:swiftie_quiz/domain/engine/relisten_schedule.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/services/audio/audio_engine.dart';
import 'package:swiftie_quiz/services/audio/preview_downloader.dart';
import 'package:swiftie_quiz/services/audio/soloud_audio_engine.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

const Object _unchanged = Object();

const double sliceDurationSeconds = 10;

const Duration progressPollInterval = Duration(milliseconds: 50);

const double snippetStartSeconds = 8;

const Duration snippetLength = Duration(seconds: 5);

const double snippetVolumeShare = 0.7;

const Duration snippetRest = Duration(milliseconds: 250);
const Duration prefetchedLinkLifetime = Duration(minutes: 10);

const Duration audioShutdownLimit = Duration(seconds: 2);

final class AudioState {
  const AudioState({
    required this.playing,
    required this.paused,
    required this.loading,
    required this.progress,
    required this.clipDuration,
    required this.relistenStage,
    required this.error,
    this.unavailable = false,
  });

  static const AudioState idle = AudioState(
    playing: false,
    paused: false,
    loading: false,
    progress: 0,
    clipDuration: 0,
    relistenStage: 0,
    error: null,
  );

  final bool playing;
  final bool paused;
  final bool loading;
  final double progress;
  final double clipDuration;
  final int relistenStage;
  final String? error;
  final bool unavailable;

  AudioState copyWith({
    bool? playing,
    bool? paused,
    bool? loading,
    double? progress,
    double? clipDuration,
    int? relistenStage,
    Object? error = _unchanged,
    bool? unavailable,
  }) => AudioState(
    playing: playing ?? this.playing,
    paused: paused ?? this.paused,
    loading: loading ?? this.loading,
    progress: progress ?? this.progress,
    clipDuration: clipDuration ?? this.clipDuration,
    relistenStage: relistenStage ?? this.relistenStage,
    error: identical(error, _unchanged) ? this.error : error as String?,
    unavailable: unavailable ?? this.unavailable,
  );

  @override
  bool operator ==(Object other) =>
      other is AudioState &&
      other.playing == playing &&
      other.paused == paused &&
      other.loading == loading &&
      other.progress == progress &&
      other.clipDuration == clipDuration &&
      other.relistenStage == relistenStage &&
      other.error == error &&
      other.unavailable == unavailable;

  @override
  int get hashCode => Object.hash(
    playing,
    paused,
    loading,
    progress,
    clipDuration,
    relistenStage,
    error,
    unavailable,
  );

  @override
  String toString() =>
      'AudioState(playing: $playing, paused: $paused, loading: $loading, '
      'progress: $progress, clipDuration: $clipDuration, '
      'relistenStage: $relistenStage, error: $error, '
      'unavailable: $unavailable)';
}

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = SoLoudAudioEngine();
  ref.onDispose(() => unawaited(engine.dispose()));
  return engine;
});

Future<void> shutDownAudio(AudioEngine engine) =>
    engine.shutdown().timeout(audioShutdownLimit).catchError((Object _) {});

final previewDownloaderProvider = FutureProvider<PreviewDownloader>(
  (ref) async => PreviewDownloader(
    ref.watch(httpClientProvider),
    await ref.watch(userAgentProvider.future),
  ),
);

final audioControllerProvider = NotifierProvider<AudioController, AudioState>(
  AudioController.new,
);

class AudioController extends Notifier<AudioState> {
  late AudioEngine _engine;
  int _playVersion = 0;
  LoadedClip? _clip;
  double _clipStart = 0;
  AudioVoice? _voice;
  Timer? _progressTimer;
  double _sliceOffset = 0;
  double _sliceDuration = 0;
  int _snippetVersion = 0;
  Map<int, ({String link, DateTime fetchedAt})> _prefetched = const {};
  LoadedClip? _snippetClip;
  AudioVoice? _snippetVoice;
  Timer? _snippetTimer;

  @override
  AudioState build() {
    _engine = ref.watch(audioEngineProvider);
    ref
      ..listen(
        gameControllerProvider.select((game) => game.relistenCount),
        (_, count) => state = state.copyWith(relistenStage: count),
      )
      ..onDispose(_release);
    return AudioState.idle.copyWith(
      relistenStage: ref.read(gameControllerProvider).relistenCount,
    );
  }

  Future<void> play(Track track, {bool smartClip = true}) async {
    stop();
    final version = ++_playVersion;
    _replaceClip(null);
    final dangerZones = smartClip
        ? _dangerZonesFor(track)
        : Future.value(const <DangerZone>[]);
    state = state.copyWith(loading: true, error: null, unavailable: false);
    try {
      final bytes = await _downloadPreview(track, version);
      if (bytes == null || version != _playVersion) {
        return;
      }
      final clip = await _engine.loadClip(bytes);
      if (version != _playVersion) {
        _engine.unloadClip(clip).ignore();
        return;
      }
      _replaceClip(clip);
      final zones = await dangerZones;
      if (version != _playVersion) {
        return;
      }
      final start = smartClip
          ? await _smartStart(clip, zones)
          : _randomStart(clip.durationSeconds);
      if (version != _playVersion) {
        return;
      }
      _clipStart = start;
      _playSlice(clip, start, sliceDurationSeconds);
    } on PreviewMissing {
      if (version == _playVersion) {
        state = state.copyWith(unavailable: true);
      }
    } on Object catch (error) {
      if (version == _playVersion) {
        state = state.copyWith(error: '$error');
      }
    } finally {
      if (version == _playVersion) {
        state = state.copyWith(loading: false);
      }
    }
  }

  Future<void> prefetchPreview(Track track) async {
    if (track.preview.isNotEmpty || _prefetchedLink(track.id) != null) {
      return;
    }
    try {
      final link = await _freshLink(track.id);
      if (link.isNotEmpty) {
        _prefetched = {
          ..._prefetched,
          track.id: (link: link, fetchedAt: ref.read(clockProvider)()),
        };
      }
    } on Object {
      return;
    }
  }

  void relisten() {
    final clip = _clip;
    if (clip == null) {
      return;
    }
    final stage = ref.read(gameControllerProvider).relistenCount + 1;
    ref.read(gameControllerProvider.notifier).incrementRelisten();
    final slice = getRelistenSlice(stage, _clipStart, clip.durationSeconds);
    _playSlice(clip, slice.offset, slice.duration);
  }

  void pause() {
    final voice = _voice;
    if (!state.playing || voice == null) {
      return;
    }
    _cancelProgressPolling();
    _engine.pause(voice);
    state = state.copyWith(playing: false, paused: true);
  }

  void resume() {
    final voice = _voice;
    if (!state.paused || voice == null || _clip == null) {
      return;
    }
    if (_sliceDuration - _elapsedIn(voice) <= 0) {
      state = state.copyWith(paused: false);
      return;
    }
    _engine
      ..setVolume(voice, _volume)
      ..resume(voice);
    state = state.copyWith(playing: true, paused: false);
    _pollProgress(voice);
  }

  void stop() {
    _haltVoice();
    _sliceOffset = 0;
    _sliceDuration = 0;
    state = state.copyWith(
      playing: false,
      paused: false,
      progress: 0,
      clipDuration: 0,
    );
  }

  void reset() {
    stop();
    _playVersion += 1;
    _replaceClip(null);
    _clipStart = 0;
    state = state.copyWith(loading: false, error: null);
  }

  void playQuack() => _engine.playQuack(_volume).ignore();

  Future<void> previewSnippet(String trackId) async {
    stopSnippet();
    final version = _snippetVersion;
    final id = int.tryParse(trackId);
    if (id == null) {
      return;
    }
    await Future<void>.delayed(snippetRest);
    if (version != _snippetVersion) {
      return;
    }
    try {
      final deezer = await ref.read(deezerClientProvider.future);
      final track = await deezer.refreshTrack(id);
      if (version != _snippetVersion) {
        return;
      }
      final downloader = await ref.read(previewDownloaderProvider.future);
      final bytes = await downloader.download(Uri.parse(track.preview));
      if (version != _snippetVersion) {
        return;
      }
      final clip = await _engine.loadClip(bytes);
      if (version != _snippetVersion) {
        _engine.unloadClip(clip).ignore();
        return;
      }
      _snippetClip = clip;
      _snippetVoice = _engine.playSlice(
        clip,
        snippetStartSeconds,
        snippetLength.inMilliseconds / Duration.millisecondsPerSecond,
        _volume * snippetVolumeShare,
      );
      _snippetTimer = Timer(snippetLength, stopSnippet);
    } on Object {
      return;
    }
  }

  void stopSnippet() {
    _snippetVersion += 1;
    _snippetTimer?.cancel();
    _snippetTimer = null;
    final voice = _snippetVoice;
    _snippetVoice = null;
    if (voice != null) {
      _engine.stop(voice).ignore();
    }
    final clip = _snippetClip;
    _snippetClip = null;
    if (clip != null) {
      _engine.unloadClip(clip).ignore();
    }
  }

  double get _volume =>
      ref.read(gameControllerProvider).progress.settings.volume;

  Future<Uint8List?> _downloadPreview(Track track, int version) async {
    final downloader = await ref.read(previewDownloaderProvider.future);
    if (version != _playVersion) {
      return null;
    }
    final prefetched = track.preview.isEmpty ? _prefetchedLink(track.id) : null;
    _prefetched = {
      for (final entry in _prefetched.entries)
        if (entry.key != track.id) entry.key: entry.value,
    };
    final fetchedNow = track.preview.isEmpty && prefetched == null;
    final link = track.preview.isNotEmpty
        ? track.preview
        : prefetched ?? await _freshLink(track.id);
    if (version != _playVersion) {
      return null;
    }
    try {
      return await downloader.download(Uri.parse(_playable(link)));
    } on PreviewForbidden {
      if (fetchedNow) {
        rethrow;
      }
      if (version != _playVersion) {
        return null;
      }
      final refreshed = await _freshLink(track.id);
      if (version != _playVersion) {
        return null;
      }
      return downloader.download(Uri.parse(_playable(refreshed)));
    }
  }

  Future<String> _freshLink(int trackId) async {
    final deezer = await ref.read(deezerClientProvider.future);
    try {
      return (await deezer.refreshTrack(trackId)).preview;
    } on ApiError {
      throw const PreviewMissing();
    }
  }

  String? _prefetchedLink(int trackId) => switch (_prefetched[trackId]) {
    final entry?
        when ref.read(clockProvider)().difference(entry.fetchedAt) <
            prefetchedLinkLifetime =>
      entry.link,
    _ => null,
  };

  static String _playable(String link) =>
      link.isEmpty ? throw const PreviewMissing() : link;

  Future<List<DangerZone>> _dangerZonesFor(Track track) async {
    try {
      final service = await ref.read(dangerZoneServiceProvider.future);
      return await service.fetchDangerZones(
        track.title,
        track.artist.name,
        track.titleShort,
        track.duration,
      );
    } on Object {
      return const [];
    }
  }

  Future<double> _smartStart(LoadedClip clip, List<DangerZone> zones) async {
    try {
      return selectClipStartWithFallback(
        await clip.readSamples(),
        zones,
        random: ref.read(randomProvider),
      );
    } on Object {
      return _randomStart(clip.durationSeconds);
    }
  }

  double _randomStart(double durationSeconds) =>
      ref.read(randomProvider).nextDouble() *
      max(0.0, durationSeconds - sliceDurationSeconds);

  void _playSlice(LoadedClip clip, double offset, double duration) {
    _sliceOffset = offset;
    _sliceDuration = duration;
    state = state.copyWith(clipDuration: duration);
    _haltVoice();
    final voice = _engine.playSlice(clip, offset, duration, _volume);
    _voice = voice;
    state = state.copyWith(playing: true, paused: false);
    _pollProgress(voice);
  }

  void _pollProgress(AudioVoice voice) {
    final version = _playVersion;
    _cancelProgressPolling();
    _progressTimer = Timer.periodic(progressPollInterval, (timer) {
      if (version != _playVersion || voice != _voice) {
        timer.cancel();
        return;
      }
      final position = _engine.positionOf(voice);
      final elapsed = _elapsedAt(position);
      state = state.copyWith(
        progress: _sliceDuration > 0 ? min(elapsed / _sliceDuration, 1.0) : 1.0,
      );
      if (position == null || elapsed >= _sliceDuration) {
        timer.cancel();
        _progressTimer = null;
        state = state.copyWith(playing: false);
      }
    });
  }

  double _elapsedIn(AudioVoice voice) => _elapsedAt(_engine.positionOf(voice));

  double _elapsedAt(double? position) =>
      position == null ? _sliceDuration : max(0.0, position - _sliceOffset);

  void _cancelProgressPolling() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _haltVoice() {
    _cancelProgressPolling();
    final voice = _voice;
    _voice = null;
    if (voice != null) {
      _engine.stop(voice).ignore();
    }
  }

  void _replaceClip(LoadedClip? clip) {
    final previous = _clip;
    _clip = clip;
    if (previous != null && !identical(previous, clip)) {
      _engine.unloadClip(previous).ignore();
    }
  }

  void _release() {
    _playVersion += 1;
    _haltVoice();
    _replaceClip(null);
    stopSnippet();
  }
}
