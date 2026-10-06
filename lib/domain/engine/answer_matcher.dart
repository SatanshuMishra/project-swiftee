import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/domain/util/levenshtein.dart';

final RegExp _parenthetical = RegExp(r'\s*\([^)]*\)\s*');
final RegExp _dashSuffix = RegExp(r'\s+-\s+.*$');
final RegExp _punctuation = RegExp('[\'‘’.,?!:;"“”]');
final RegExp _whitespace = RegExp(r'\s+');

String normalizeTitle(String title) => title
    .toLowerCase()
    .replaceAll(_parenthetical, ' ')
    .replaceAll(_dashSuffix, '')
    .replaceAll('-', ' ')
    .replaceAll(_punctuation, '')
    .replaceAll(_whitespace, ' ')
    .trim();

bool checkAnswer(Object input, Track correctTrack, Difficulty difficulty) =>
    switch (difficulty) {
      Difficulty.easy || Difficulty.medium => input == correctTrack.id,
      Difficulty.hard =>
        input is String &&
            isCloseMatch(
              normalizeTitle(input),
              normalizeTitle(correctTrack.title),
            ),
    };
