import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:swiftie_quiz/domain/engine/clip_selector.dart';
import 'package:swiftie_quiz/services/audio/audio_engine.dart';

final class SoLoudAudioEngine implements AudioEngine {
  SoLoudAudioEngine({SoLoud? soloud}) : _soloud = soloud ?? SoLoud.instance;

  static const String quackAsset = 'assets/sounds/quack.mp3';
  static const int analysisSampleRate = 8000;
  static const String _previewName = 'preview.mp3';

  final SoLoud _soloud;
  Future<void>? _initialization;
  Future<AudioSource>? _quack;
  Future<void> _sourceDisposals = Future.value();
  bool _shutDown = false;

  @override
  Future<void> init() => _shutDown
      ? Future.error(StateError('The audio engine has shut down'))
      : _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      if (!_soloud.isInitialized) {
        await _soloud.init();
      }
    } on Object {
      _initialization = null;
      rethrow;
    }
  }

  @override
  Future<LoadedClip> loadClip(Uint8List mp3Bytes) async {
    await init();
    final source = await _soloud.loadMem(_previewName, mp3Bytes);
    return _SoLoudClip(
      _soloud,
      source,
      mp3Bytes,
      _seconds(_soloud.getLength(source)),
    );
  }

  @override
  Future<void> unloadClip(LoadedClip clip) {
    final disposal = _sourceDisposals.then((_) => _disposeClip(clip));
    _sourceDisposals = disposal.catchError((Object _) {});
    return disposal;
  }

  Future<void> _disposeClip(LoadedClip clip) async {
    if (clip is _SoLoudClip && _soloud.isInitialized) {
      await _soloud.disposeSource(clip.source);
    }
  }

  @override
  AudioVoice playSlice(
    LoadedClip clip,
    double offsetSeconds,
    double durationSeconds,
    double volume,
  ) {
    final source = switch (clip) {
      final _SoLoudClip loaded => loaded.source,
      _ => throw ArgumentError.value(clip, 'clip', 'not loaded by SoLoud'),
    };
    final handle = _soloud.play(source, volume: volume, paused: true);
    try {
      _soloud
        ..seek(handle, _duration(offsetSeconds))
        ..setVolume(handle, volume)
        ..scheduleStop(handle, _duration(durationSeconds))
        ..setPause(handle, false);
    } on Object {
      _soloud.stop(handle).ignore();
      rethrow;
    }
    return AudioVoice(handle.id);
  }

  @override
  void pause(AudioVoice voice) => _setPause(voice, paused: true);

  @override
  void resume(AudioVoice voice) => _setPause(voice, paused: false);

  void _setPause(AudioVoice voice, {required bool paused}) {
    if (!_isLive(voice)) {
      return;
    }
    try {
      _soloud.setPause(SoundHandle(voice.id), paused);
    } on SoLoudSoundHandleNotFoundCppException {
      return;
    }
  }

  @override
  Future<void> stop(AudioVoice voice) async {
    if (_isLive(voice)) {
      await _soloud.stop(SoundHandle(voice.id));
    }
  }

  @override
  double? positionOf(AudioVoice voice) => _isLive(voice)
      ? _seconds(_soloud.getPosition(SoundHandle(voice.id)))
      : null;

  @override
  void setVolume(AudioVoice voice, double volume) {
    if (_isLive(voice)) {
      _soloud.setVolume(SoundHandle(voice.id), volume);
    }
  }

  @override
  Future<void> playQuack(double volume) async {
    await init();
    _soloud.play(await _quackSource(), volume: quackGain(volume));
  }

  Future<AudioSource> _quackSource() => _quack ??= _soloud
      .loadAsset(quackAsset)
      .catchError((Object error, StackTrace stackTrace) {
        _quack = null;
        return Future<AudioSource>.error(error, stackTrace);
      });

  @override
  Future<void> dispose() async {
    _quack = null;
    _initialization = null;
    await _sourceDisposals;
    if (_soloud.isInitialized) {
      await _soloud.disposeAllSources();
    }
  }

  @override
  Future<void> shutdown() async {
    final started = _initialization != null || _soloud.isInitialized;
    _shutDown = true;
    _quack = null;
    _initialization = null;
    if (started) {
      await _soloud.deinitAsync();
    }
  }

  bool _isLive(AudioVoice voice) =>
      _soloud.isInitialized &&
      _soloud.getIsValidVoiceHandle(SoundHandle(voice.id));

  static Duration _duration(double seconds) => Duration(
    microseconds: (seconds * Duration.microsecondsPerSecond).round(),
  );

  static double _seconds(Duration duration) =>
      duration.inMicroseconds / Duration.microsecondsPerSecond;
}

final class _SoLoudClip implements LoadedClip {
  const _SoLoudClip(
    this._soloud,
    this.source,
    this._bytes,
    this.durationSeconds,
  );

  final SoLoud _soloud;
  final AudioSource source;
  final Uint8List _bytes;

  @override
  final double durationSeconds;

  @override
  Future<ClipAudio> readSamples() async => ClipAudio(
    await _soloud.readSamplesFromMem(
      _bytes,
      (durationSeconds * SoLoudAudioEngine.analysisSampleRate).ceil(),
      average: false,
    ),
    SoLoudAudioEngine.analysisSampleRate,
    durationSeconds,
  );
}
