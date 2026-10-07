import 'dart:math';
import 'dart:typed_data';

import 'package:swiftie_quiz/domain/engine/clip_selector.dart';

const double quackGainFactor = 0.9;

double quackGain(double volume) => min(volume * quackGainFactor, 1.0);

final class AudioVoice {
  const AudioVoice(this.id);

  final int id;

  @override
  bool operator ==(Object other) => other is AudioVoice && other.id == id;

  @override
  int get hashCode => Object.hash(AudioVoice, id);

  @override
  String toString() => 'AudioVoice($id)';
}

abstract interface class LoadedClip {
  double get durationSeconds;

  Future<ClipAudio> readSamples();
}

abstract interface class AudioEngine {
  Future<void> init();

  Future<LoadedClip> loadClip(Uint8List mp3Bytes);

  Future<void> unloadClip(LoadedClip clip);

  AudioVoice playSlice(
    LoadedClip clip,
    double offsetSeconds,
    double durationSeconds,
    double volume,
  );

  void pause(AudioVoice voice);

  void resume(AudioVoice voice);

  Future<void> stop(AudioVoice voice);

  double? positionOf(AudioVoice voice);

  void setVolume(AudioVoice voice, double volume);

  Future<void> playQuack(double volume);

  Future<void> dispose();

  Future<void> shutdown();
}
