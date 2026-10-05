import 'dart:math';

import 'package:swiftie_quiz/domain/engine/answer_matcher.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/util/shuffle.dart';

const int _wrongOptionCount = 3;

List<Track> generateOptions(
  Track correctTrack,
  Iterable<Track> pool, {
  Random? random,
}) {
  final normalizedCorrect = normalizeTitle(correctTrack.title);

  final candidates = pool.where(
    (track) =>
        track.id != correctTrack.id &&
        normalizeTitle(track.title) != normalizedCorrect,
  );

  final seenTitles = <String>{};
  final uniqueCandidates = <Track>[];
  for (final track in shuffle(candidates, random: random)) {
    if (seenTitles.add(normalizeTitle(track.title))) {
      uniqueCandidates.add(track);
    }
    if (uniqueCandidates.length >= _wrongOptionCount) break;
  }

  return shuffle([correctTrack, ...uniqueCandidates], random: random);
}
