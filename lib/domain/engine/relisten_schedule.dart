import 'dart:math';

const List<double> relistenSchedule = [10, 10, 15, 15, 20, 20];

final double _baseDuration = relistenSchedule.first;

final int fullClipThreshold = relistenSchedule.length + 1;

final int firstEscalationRelisten =
    relistenSchedule.indexWhere((duration) => duration > _baseDuration) + 1;

final class RelistenSlice {
  const RelistenSlice({required this.offset, required this.duration});

  final double offset;
  final double duration;

  RelistenSlice copyWith({double? offset, double? duration}) => RelistenSlice(
    offset: offset ?? this.offset,
    duration: duration ?? this.duration,
  );

  @override
  bool operator ==(Object other) =>
      other is RelistenSlice &&
      other.offset == offset &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(offset, duration);

  @override
  String toString() => 'RelistenSlice(offset: $offset, duration: $duration)';
}

RelistenSlice getRelistenSlice(
  int stage,
  double smartStart,
  double bufferDuration,
) {
  final index = stage - 1;

  if (index < 0 || index >= relistenSchedule.length) {
    return RelistenSlice(offset: 0, duration: bufferDuration);
  }

  return RelistenSlice(
    offset: smartStart,
    duration: min(relistenSchedule[index], bufferDuration - smartStart),
  );
}
