import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/relisten_schedule.dart';

const double smartStart = 5;
const double bufferDuration = 30;

void main() {
  group('relisten schedule parity', () {
    group('getRelistenSlice', () {
      test('stage 1: 10s from smart start', () {
        expect(
          getRelistenSlice(1, smartStart, bufferDuration),
          const RelistenSlice(offset: 5, duration: 10),
        );
      });

      test('stage 2: 10s from smart start', () {
        expect(
          getRelistenSlice(2, smartStart, bufferDuration),
          const RelistenSlice(offset: 5, duration: 10),
        );
      });

      test('stage 3: 15s from smart start', () {
        expect(
          getRelistenSlice(3, smartStart, bufferDuration),
          const RelistenSlice(offset: 5, duration: 15),
        );
      });

      test('stage 4: 15s from smart start', () {
        expect(
          getRelistenSlice(4, smartStart, bufferDuration),
          const RelistenSlice(offset: 5, duration: 15),
        );
      });

      test('stage 5: 20s from smart start', () {
        expect(
          getRelistenSlice(5, smartStart, bufferDuration),
          const RelistenSlice(offset: 5, duration: 20),
        );
      });

      test('stage 6: 20s from smart start', () {
        expect(
          getRelistenSlice(6, smartStart, bufferDuration),
          const RelistenSlice(offset: 5, duration: 20),
        );
      });

      test('stage 7: full buffer from position 0', () {
        expect(
          getRelistenSlice(7, smartStart, bufferDuration),
          const RelistenSlice(offset: 0, duration: 30),
        );
      });

      test('stage 10: full buffer (high stage)', () {
        expect(
          getRelistenSlice(10, smartStart, bufferDuration),
          const RelistenSlice(offset: 0, duration: 30),
        );
      });

      test('clamps duration when buffer is shorter than requested', () {
        expect(
          getRelistenSlice(3, 25, 30),
          const RelistenSlice(offset: 25, duration: 5),
        );
      });

      test('clamps 20s request near end of buffer', () {
        expect(
          getRelistenSlice(5, 15, 30),
          const RelistenSlice(offset: 15, duration: 15),
        );
      });

      test('stage 0: falls through to full clip', () {
        expect(
          getRelistenSlice(0, smartStart, bufferDuration),
          const RelistenSlice(offset: 0, duration: 30),
        );
      });

      test('negative stage: falls through to full clip', () {
        expect(
          getRelistenSlice(-1, smartStart, bufferDuration),
          const RelistenSlice(offset: 0, duration: 30),
        );
      });

      test('smartStart at 0', () {
        expect(
          getRelistenSlice(1, 0, 30),
          const RelistenSlice(offset: 0, duration: 10),
        );
      });

      test('very short buffer', () {
        expect(
          getRelistenSlice(1, 0, 5),
          const RelistenSlice(offset: 0, duration: 5),
        );
      });
    });

    group('constants', () {
      test('FULL_CLIP_THRESHOLD equals 7', () {
        expect(fullClipThreshold, 7);
      });

      test('FIRST_ESCALATION_RELISTEN equals 3', () {
        expect(firstEscalationRelisten, 3);
      });

      test('FULL_CLIP_THRESHOLD aligns with schedule: stage at threshold returns full clip', () {
        final result = getRelistenSlice(fullClipThreshold, 5, 30);
        expect(result.offset, 0);
        expect(result.duration, 30);
      });

      test('stage before FULL_CLIP_THRESHOLD is NOT full clip', () {
        final result = getRelistenSlice(fullClipThreshold - 1, 5, 30);
        expect(result.offset, 5);
        expect(result.duration, lessThan(30));
      });

      test('FIRST_ESCALATION_RELISTEN aligns with schedule: stage at threshold is > 10s', () {
        final result = getRelistenSlice(firstEscalationRelisten, 0, 30);
        expect(result.duration, greaterThan(10));
      });

      test('stage before FIRST_ESCALATION_RELISTEN is still 10s', () {
        final result = getRelistenSlice(firstEscalationRelisten - 1, 0, 30);
        expect(result.duration, 10);
      });
    });
  });
}
