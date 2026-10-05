import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/clip_selector.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';

Float32List filledSamples(int length, double value) =>
    Float32List(length)..fillRange(0, length, value);

ClipAudio makeClipAudio(
  double duration, {
  int sampleRate = 44100,
  Float32List? samples,
}) => ClipAudio(
  samples ?? filledSamples((duration * sampleRate).floor(), 0.5),
  sampleRate,
  duration,
);

final class FailingClipAudio implements ClipAudio {
  @override
  Float32List get samples => throw StateError('Simulated failure');

  @override
  int get sampleRate => 44100;

  @override
  double get durationSeconds => 30;
}

void main() {
  group('clip selector parity', () {
    group('computeRmsProfile', () {
      test('computes correct RMS for constant signal', () {
        final data = filledSamples(44100, 0.5);
        final profile = computeRmsProfile(data, 44100, 0.25);
        expect(profile, hasLength(4));
        for (final rms in profile) {
          expect(rms, closeTo(0.5, 0.0005));
        }
      });

      test('computes correct RMS for silence', () {
        final data = filledSamples(44100, 0);
        final profile = computeRmsProfile(data, 44100, 0.25);
        expect(profile, hasLength(4));
        for (final rms in profile) {
          expect(rms, 0);
        }
      });

      test('handles varying signal levels', () {
        const sampleRate = 1000;
        final data = Float32List(2000)
          ..fillRange(0, 1000, 0.2)
          ..fillRange(1000, 2000, 0.8);

        final profile = computeRmsProfile(data, sampleRate, 0.5);
        expect(profile, hasLength(4));
        expect(profile[0], closeTo(0.2, 0.005));
        expect(profile[1], closeTo(0.2, 0.005));
        expect(profile[2], closeTo(0.8, 0.005));
        expect(profile[3], closeTo(0.8, 0.005));
      });

      test('returns empty array for zero frame size', () {
        final data = filledSamples(100, 0.5);
        expect(computeRmsProfile(data, 44100, 0), isEmpty);
      });

      test('drops partial frames at the end', () {
        final data = filledSamples(1500, 0.3);
        final profile = computeRmsProfile(data, 1000, 1);
        expect(profile, hasLength(1));
      });
    });

    group('computeEnergyScore', () {
      test('returns 1 when globalMaxRms is 0', () {
        expect(computeEnergyScore([], 0, 0.25, 0, 10), 1);
      });

      test('returns 1 when profile is empty', () {
        expect(computeEnergyScore([], 0.5, 0.25, 0, 10), 1);
      });

      test('returns 0 for the loudest window', () {
        final profile = [0.5, 0.5, 0.5, 0.5];
        final score = computeEnergyScore(profile, 0.5, 0.25, 0, 1);
        expect(score, closeTo(0, 0.005));
      });

      test('returns high score for quiet window', () {
        final profile = [0.1, 0.1, 0.1, 0.1, 0.9, 0.9, 0.9, 0.9];
        final score = computeEnergyScore(profile, 0.9, 0.25, 0, 1);
        expect(score, closeTo(0.889, 0.005));
      });

      test('handles startFrame >= endFrame', () {
        final profile = [0.5];
        expect(computeEnergyScore(profile, 0.5, 0.25, 10, 1), 1);
      });
    });

    group('computeCenterBias', () {
      test('returns 1 at the center of the buffer', () {
        expect(computeCenterBias(10, 30, 10), closeTo(1, 0.000005));
      });

      test('returns lower value at edges', () {
        final centerScore = computeCenterBias(10, 30, 10);
        final edgeScore = computeCenterBias(0, 30, 10);
        expect(edgeScore, lessThan(centerScore));
      });

      test('is symmetric around center', () {
        final left = computeCenterBias(2, 30, 10);
        final right = computeCenterBias(18, 30, 10);
        expect(left, closeTo(right, 0.000005));
      });

      test('returns 1 when sigma is 0 (zero duration)', () {
        expect(computeCenterBias(0, 0, 0), 1);
      });

      test('returns value between 0 and 1', () {
        for (var s = 0; s <= 20; s += 2) {
          final score = computeCenterBias(s.toDouble(), 30, 10);
          expect(score, greaterThan(0));
          expect(score, lessThanOrEqualTo(1));
        }
      });
    });

    group('computeDangerZonePenalty', () {
      test('returns 1 when no danger zones', () {
        expect(computeDangerZonePenalty(5, 10, []), 1);
      });

      test('returns 0 for heavy overlap (>=2s)', () {
        const zones = [DangerZone(start: 5, end: 10)];
        expect(computeDangerZonePenalty(3, 10, zones), 0);
      });

      test('returns 0.3 for light overlap (<2s)', () {
        const zones = [DangerZone(start: 12, end: 14)];
        expect(computeDangerZonePenalty(5, 10, zones), 0);

        const zones2 = [DangerZone(start: 13.5, end: 14.5)];
        expect(computeDangerZonePenalty(5, 10, zones2), 0.3);
      });

      test("returns 1 when window doesn't overlap any zone", () {
        const zones = [DangerZone(start: 20, end: 25)];
        expect(computeDangerZonePenalty(0, 10, zones), 1);
      });

      test('accumulates overlap across multiple zones', () {
        const zones = [
          DangerZone(start: 2, end: 3),
          DangerZone(start: 7, end: 8.5),
        ];
        expect(computeDangerZonePenalty(0, 10, zones), 0);
      });
    });

    group('selectClipStart', () {
      test('returns 0 for buffer shorter than slice duration', () {
        final audio = makeClipAudio(5);
        expect(selectClipStart(audio, []), 0);
      });

      test('avoids loud sections', () {
        const sampleRate = 1000;
        const duration = 30;
        final data = Float32List(sampleRate * duration)
          ..fillRange(0, sampleRate * 10, 0.1)
          ..fillRange(sampleRate * 10, sampleRate * 20, 0.9)
          ..fillRange(sampleRate * 20, sampleRate * 30, 0.3);

        final audio = makeClipAudio(30, sampleRate: sampleRate, samples: data);
        final start = selectClipStart(audio, []);

        expect(start, lessThan(10));
      });

      test('avoids danger zones', () {
        const sampleRate = 1000;
        const duration = 30;
        final data = filledSamples(sampleRate * duration, 0.5);
        final audio = makeClipAudio(30, sampleRate: sampleRate, samples: data);

        const dangerZones = [DangerZone(start: 8, end: 15)];

        final start = selectClipStart(audio, dangerZones);

        final windowEnd = start + 10;
        final overlapStart = max(start, 8.0);
        final overlapEnd = min(windowEnd, 15.0);
        final overlap = max(0.0, overlapEnd - overlapStart);
        expect(overlap, lessThan(7));
      });

      test('returns a number within valid range', () {
        final audio = makeClipAudio(30);
        final start = selectClipStart(audio, []);
        expect(start, greaterThanOrEqualTo(0));
        expect(start, lessThanOrEqualTo(20));
      });

      test('handles uniform silence gracefully', () {
        final data = filledSamples(30000, 0);
        final audio = makeClipAudio(30, sampleRate: 1000, samples: data);
        final start = selectClipStart(audio, []);
        expect(start, greaterThanOrEqualTo(0));
        expect(start, lessThanOrEqualTo(20));
      });
    });

    group('selectClipStartWithFallback', () {
      test('returns valid position for normal buffer', () {
        final audio = makeClipAudio(30);
        final start = selectClipStartWithFallback(audio, [], random: Random(1));
        expect(start, greaterThanOrEqualTo(0));
        expect(start, lessThanOrEqualTo(20));
      });

      test('falls back to random on error', () {
        final start = selectClipStartWithFallback(
          FailingClipAudio(),
          [],
          random: Random(7),
        );
        expect(start, greaterThanOrEqualTo(0));
        expect(start, lessThanOrEqualTo(20));
        expect(start, Random(7).nextDouble() * 20);
      });

      test('returns 0 for short buffer', () {
        final audio = makeClipAudio(5);
        final start = selectClipStartWithFallback(audio, [], random: Random(3));
        expect(start, 0);
      });
    });
  });
}
