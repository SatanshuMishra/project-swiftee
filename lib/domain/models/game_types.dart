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
