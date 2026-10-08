import 'package:collection/collection.dart';
import 'package:swiftie_quiz/domain/util/song_title.dart';

enum GamePhase {
  nickname('nickname'),
  menu('menu'),
  albumSelect('album-select'),
  setup('setup'),
  lyricsLoading('lyrics-loading'),
  playing('playing'),
  roundSummary('round-summary'),
  recordShelf('record-shelf'),
  settings('settings'),
  together('together');

  const GamePhase(this.wireName);

  final String wireName;

  static GamePhase? fromWireName(String wireName) =>
      values.firstWhereOrNull((value) => value.wireName == wireName);
}

enum GameMode {
  random('random'),
  album('album'),
  tonight('tonight');

  const GameMode(this.wireName);

  final String wireName;

  static GameMode? fromWireName(String wireName) =>
      values.firstWhereOrNull((value) => value.wireName == wireName);
}

enum QuizType {
  sound('sound'),
  lyrics('lyrics');

  const QuizType(this.wireName);

  final String wireName;

  static QuizType? fromWireName(String wireName) =>
      values.firstWhereOrNull((value) => value.wireName == wireName);
}

enum LyricsMode {
  nameThatSong('name-that-song'),
  lyricsOrLie('lyrics-or-lie');

  const LyricsMode(this.wireName);

  final String wireName;

  static LyricsMode? fromWireName(String wireName) =>
      values.firstWhereOrNull((value) => value.wireName == wireName);
}

enum Rerecorded { taylorsVersion, original, both }

final class VersionChoice {
  const VersionChoice({
    this.studio = true,
    this.live = true,
    this.alternate = true,
    this.rerecorded = Rerecorded.both,
  });

  static const VersionChoice all = VersionChoice();

  final bool studio;
  final bool live;
  final bool alternate;
  final Rerecorded rerecorded;

  bool plays(Take take) => switch (take) {
    Take.studio => studio,
    Take.live => live,
    Take.alternate => alternate,
  };

  VersionChoice toggled(Take take) => switch (take) {
    Take.studio => copyWith(studio: !studio),
    Take.live => copyWith(live: !live),
    Take.alternate => copyWith(alternate: !alternate),
  };

  VersionChoice copyWith({
    bool? studio,
    bool? live,
    bool? alternate,
    Rerecorded? rerecorded,
  }) => VersionChoice(
    studio: studio ?? this.studio,
    live: live ?? this.live,
    alternate: alternate ?? this.alternate,
    rerecorded: rerecorded ?? this.rerecorded,
  );

  @override
  bool operator ==(Object other) =>
      other is VersionChoice &&
      other.studio == studio &&
      other.live == live &&
      other.alternate == alternate &&
      other.rerecorded == rerecorded;

  @override
  int get hashCode => Object.hash(studio, live, alternate, rerecorded);

  @override
  String toString() =>
      'VersionChoice(studio: $studio, live: $live, alternate: $alternate, '
      'rerecorded: $rerecorded)';
}

enum Difficulty {
  easy('easy'),
  medium('medium'),
  hard('hard');

  const Difficulty(this.wireName);

  final String wireName;

  static Difficulty? fromWireName(String wireName) =>
      values.firstWhereOrNull((value) => value.wireName == wireName);
}

enum ThemeSetting {
  dark('dark'),
  light('light'),
  system('system');

  const ThemeSetting(this.wireName);

  final String wireName;

  static ThemeSetting? fromWireName(String wireName) =>
      values.firstWhereOrNull((value) => value.wireName == wireName);
}
