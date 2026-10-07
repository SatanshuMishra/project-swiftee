import 'package:collection/collection.dart';

enum GamePhase {
  nickname('nickname'),
  menu('menu'),
  albumSelect('album-select'),
  setup('setup'),
  lyricsLoading('lyrics-loading'),
  playing('playing'),
  roundSummary('round-summary'),
  recordShelf('record-shelf'),
  settings('settings');

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

enum VersionOption { taylorsVersions, originals, liveTakes, otherTakes }

final class VersionChoice {
  const VersionChoice({
    this.taylorsVersions = true,
    this.originals = true,
    this.liveTakes = true,
    this.otherTakes = true,
  });

  static const VersionChoice all = VersionChoice();

  bool includes(VersionOption option) => switch (option) {
    VersionOption.taylorsVersions => taylorsVersions,
    VersionOption.originals => originals,
    VersionOption.liveTakes => liveTakes,
    VersionOption.otherTakes => otherTakes,
  };

  VersionChoice toggled(VersionOption option) => switch (option) {
    VersionOption.taylorsVersions => copyWith(
      taylorsVersions: !taylorsVersions,
    ),
    VersionOption.originals => copyWith(originals: !originals),
    VersionOption.liveTakes => copyWith(liveTakes: !liveTakes),
    VersionOption.otherTakes => copyWith(otherTakes: !otherTakes),
  };

  final bool taylorsVersions;
  final bool originals;
  final bool liveTakes;
  final bool otherTakes;

  VersionChoice copyWith({
    bool? taylorsVersions,
    bool? originals,
    bool? liveTakes,
    bool? otherTakes,
  }) => VersionChoice(
    taylorsVersions: taylorsVersions ?? this.taylorsVersions,
    originals: originals ?? this.originals,
    liveTakes: liveTakes ?? this.liveTakes,
    otherTakes: otherTakes ?? this.otherTakes,
  );

  @override
  bool operator ==(Object other) =>
      other is VersionChoice &&
      other.taylorsVersions == taylorsVersions &&
      other.originals == originals &&
      other.liveTakes == liveTakes &&
      other.otherTakes == otherTakes;

  @override
  int get hashCode =>
      Object.hash(taylorsVersions, originals, liveTakes, otherTakes);

  @override
  String toString() =>
      'VersionChoice(taylorsVersions: $taylorsVersions, originals: $originals, '
      'liveTakes: $liveTakes, otherTakes: $otherTakes)';
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
