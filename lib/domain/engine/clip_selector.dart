import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:swiftie_quiz/domain/models/lyrics.dart';

const double _frameSizeSec = 0.25;
const double _stepSizeSec = 0.5;
const double _defaultSliceDuration = 10;

class ClipAudio {
  ClipAudio(Float32List samples, this.sampleRate, this.durationSeconds)
    : samples = samples.asUnmodifiableView();

  final Float32List samples;
  final int sampleRate;
  final double durationSeconds;
}

List<double> computeRmsProfile(
  Float32List channelData,
  int sampleRate, [
  double frameSizeSec = _frameSizeSec,
]) {
  final frameSamples = (sampleRate * frameSizeSec).floor();
  if (frameSamples == 0) return const [];

  final frameCount = channelData.length ~/ frameSamples;
  return UnmodifiableListView(
    List<double>.generate(frameCount, (frame) {
      var sumSquares = 0.0;
      final offset = frame * frameSamples;
      for (var s = 0; s < frameSamples; s++) {
        final sample = channelData[offset + s];
        sumSquares += sample * sample;
      }
      return sqrt(sumSquares / frameSamples);
    }, growable: false),
  );
}

double computeEnergyScore(
  List<double> rmsProfile,
  double globalMaxRms,
  double frameSizeSec,
  double startTime,
  double sliceDuration,
) {
  if (globalMaxRms == 0 || rmsProfile.isEmpty) return 1;

  final startFrame = (startTime / frameSizeSec).floor();
  final endFrame = min(
    rmsProfile.length,
    ((startTime + sliceDuration) / frameSizeSec).ceil(),
  );

  if (startFrame >= endFrame) return 1;

  var maxInWindow = 0.0;
  for (var i = startFrame; i < endFrame; i++) {
    if (rmsProfile[i] > maxInWindow) {
      maxInWindow = rmsProfile[i];
    }
  }

  return 1 - maxInWindow / globalMaxRms;
}

double computeCenterBias(
  double startTime,
  double bufferDuration,
  double sliceDuration,
) {
  final center = bufferDuration / 2;
  final windowCenter = startTime + sliceDuration / 2;
  final sigma = bufferDuration / 4;

  if (sigma == 0) return 1;

  final diff = windowCenter - center;
  return exp(-(diff * diff) / (2 * sigma * sigma));
}

double computeDangerZonePenalty(
  double startTime,
  double sliceDuration,
  List<DangerZone> dangerZones,
) {
  if (dangerZones.isEmpty) return 1;

  final windowEnd = startTime + sliceDuration;
  var totalOverlap = 0.0;

  for (final zone in dangerZones) {
    final overlapStart = max(startTime, zone.start);
    final overlapEnd = min(windowEnd, zone.end);
    if (overlapEnd > overlapStart) {
      totalOverlap += overlapEnd - overlapStart;
    }
  }

  if (totalOverlap >= 2) return 0;
  if (totalOverlap > 0) return 0.3;
  return 1;
}

double selectClipStart(
  ClipAudio audio,
  List<DangerZone> dangerZones, {
  double sliceDuration = _defaultSliceDuration,
}) {
  final maxStart = max(0.0, audio.durationSeconds - sliceDuration);
  if (maxStart == 0) return 0;

  final rmsProfile = computeRmsProfile(
    audio.samples,
    audio.sampleRate,
    _frameSizeSec,
  );

  var globalMaxRms = 0.0;
  for (final rms in rmsProfile) {
    if (rms > globalMaxRms) {
      globalMaxRms = rms;
    }
  }

  var bestStart = 0.0;
  var bestScore = -1.0;

  for (var s = 0.0; s <= maxStart; s += _stepSizeSec) {
    final energy = computeEnergyScore(
      rmsProfile,
      globalMaxRms,
      _frameSizeSec,
      s,
      sliceDuration,
    );
    final center = computeCenterBias(s, audio.durationSeconds, sliceDuration);
    final danger = computeDangerZonePenalty(s, sliceDuration, dangerZones);

    final score = energy * center * danger;

    if (score > bestScore) {
      bestScore = score;
      bestStart = s;
    }
  }

  return bestStart;
}

double selectClipStartWithFallback(
  ClipAudio audio,
  List<DangerZone> dangerZones, {
  Random? random,
}) {
  try {
    return selectClipStart(audio, dangerZones);
  } catch (_) {
    final maxStart = max(0.0, audio.durationSeconds - _defaultSliceDuration);
    return (random ?? Random()).nextDouble() * maxStart;
  }
}
