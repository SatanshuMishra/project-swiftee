import 'dart:collection';
import 'dart:math';

import 'package:swiftie_quiz/domain/engine/catalogue_rules.dart';
import 'package:swiftie_quiz/domain/engine/answer_matcher.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';

const Map<String, List<String>> eraGroups = {
  'country': [
    'Taylor Swift',
    "Fearless (Taylor's Version)",
    "Speak Now (Taylor's Version)",
  ],
  'countryPop': ["Red (Taylor's Version)"],
  'pop': ["1989 (Taylor's Version)", 'reputation'],
  'romanticPop': ['Lover'],
  'indieFolk': ['folklore', 'evermore'],
  'midnightsPop': ['Midnights'],
  'ttpd': ['THE TORTURED POETS DEPARTMENT'],
  'showgirl': ['The Life of a Showgirl'],
};

typedef ChorusRegion = ({int start, int end});

int lyricsLineCount(LyricsMode? mode, Difficulty difficulty) =>
    switch ((mode, difficulty)) {
      (LyricsMode.nameThatSong, Difficulty.easy) => 4,
      (LyricsMode.nameThatSong, Difficulty.medium) => 3,
      (LyricsMode.nameThatSong, Difficulty.hard) => 2,
      (LyricsMode.lyricsOrLie, Difficulty.easy) => 3,
      (LyricsMode.lyricsOrLie, Difficulty.medium) => 2,
      (LyricsMode.lyricsOrLie, Difficulty.hard) => 1,
      (null, _) => 1,
    };

final RegExp _nonAlphanumericOrSpace = RegExp(r'[^a-z0-9\s]');
final RegExp _whitespaceRun = RegExp(r'\s+');
final RegExp _parenthetical = RegExp(r'\s*\([^)]*\)\s*');
final RegExp _comparisonPunctuation = RegExp(r"""['.,?!:;"]""");
final RegExp _regexSpecialCharacter = RegExp(r'[.*+?^${}()|[\]\\]');

const String _titleBlank = '______';

String _normalizeLine(String line) => line
    .toLowerCase()
    .replaceAll(_nonAlphanumericOrSpace, '')
    .replaceAll(_whitespaceRun, ' ')
    .trim();

String lyricLineKey(String line) => _normalizeLine(line);

List<List<int>> _chorusBlocks(List<ChorusRegion> regions, int lineCount) => [
  for (final region in regions)
    for (
      var start = region.start;
      start + _blockLength(region, lineCount) - 1 <= region.end;
      start++
    )
      [for (var i = 0; i < _blockLength(region, lineCount); i++) start + i],
];

int _blockLength(ChorusRegion region, int lineCount) =>
    min(lineCount, region.end - region.start + 1);

Set<int> _withoutSeen(
  List<String> lines,
  int lineCount,
  Set<int> excluded,
  Set<String> avoid,
) {
  final seen = _seenIndices(lines, avoid);
  if (seen.isEmpty) {
    return excluded;
  }
  final both = {...excluded, ...seen};
  if (_hasBlock(lines, lineCount, both, playable: true)) {
    return both;
  }
  if (_hasBlock(lines, lineCount, excluded, playable: true)) {
    return excluded;
  }
  return _hasBlock(lines, lineCount, both) ? both : excluded;
}

bool _hasBlock(
  List<String> lines,
  int lineCount,
  Set<int> excluded, {
  bool playable = false,
}) {
  bool usable(int index) =>
      !excluded.contains(index) &&
      (!playable || _hasPlayableWordCount(lines[index]));
  if (lineCount <= 1) {
    return [for (var i = 0; i < lines.length; i++) i].any(usable);
  }
  final first = lines.length > 2 ? 1 : 0;
  final last = lines.length > 2 ? lines.length - 2 : lines.length - 1;
  final eligible = [
    for (var i = first; i <= last; i++)
      if (usable(i)) i,
  ];
  return [for (var i = 0; i <= eligible.length - lineCount; i++) i]
      .any((start) => _isContiguousRun(eligible, start, lineCount));
}

Set<int> _seenIndices(List<String> lines, Set<String> avoid) => {
  if (avoid.isNotEmpty)
    for (var i = 0; i < lines.length; i++)
      if (avoid.contains(_normalizeLine(lines[i]))) i,
};

List<ChorusRegion> detectChorusRegions(List<String> lines) {
  final normalized = lines.map(_normalizeLine).toList(growable: false);

  final counts = <String, int>{};
  for (final line in normalized) {
    if (line.isEmpty) continue;
    counts[line] = (counts[line] ?? 0) + 1;
  }

  final isChorus = [for (final line in normalized) (counts[line] ?? 0) >= 2];

  final regions = <ChorusRegion>[];
  var regionStart = -1;
  for (var i = 0; i <= isChorus.length; i++) {
    if (i < isChorus.length && isChorus[i]) {
      if (regionStart == -1) regionStart = i;
    } else {
      if (regionStart != -1) {
        final length = i - regionStart;
        if (length >= 2) {
          regions.add((start: regionStart, end: i - 1));
        }
        regionStart = -1;
      }
    }
  }

  return UnmodifiableListView(regions);
}

bool _isContiguousRun(List<int> indices, int from, int count) {
  for (var j = 1; j < count; j++) {
    if (indices[from + j] != indices[from + j - 1] + 1) return false;
  }
  return true;
}

int _wordCount(String line) => line.split(_whitespaceRun).length;

bool _hasPlayableWordCount(String line) {
  final words = _wordCount(line);
  return words >= 4 && words <= 15;
}

LyricSnippet _snippetAt(List<String> allLines, List<int> indices) =>
    LyricSnippet(
      lines: [for (final i in indices) allLines[i]],
      sourceLineIndices: indices,
    );

LyricSnippet extractSnippet(
  List<String> allLines,
  int lineCount,
  bool preferChorus,
  bool excludeChorus, {
  Random? random,
  Set<String> avoid = const {},
}) {
  final generator = random ?? Random();
  final seen = _seenIndices(allLines, avoid);
  bool unseen(Iterable<int> block) => !block.any(seen.contains);

  if (allLines.length <= lineCount) {
    return LyricSnippet(
      lines: [...allLines],
      sourceLineIndices: [for (var i = 0; i < allLines.length; i++) i],
    );
  }

  final chorusRegions = detectChorusRegions(allLines);

  final unseenBlocks = !preferChorus || seen.isEmpty
      ? const <List<int>>[]
      : _chorusBlocks(chorusRegions, lineCount).where(unseen).toList();
  if (unseenBlocks.isNotEmpty) {
    return _snippetAt(
      allLines,
      unseenBlocks[generator.nextInt(unseenBlocks.length)],
    );
  }

  if (preferChorus &&
      chorusRegions.isNotEmpty &&
      (seen.isEmpty || !_hasBlock(allLines, lineCount, seen))) {
    final region = chorusRegions[generator.nextInt(chorusRegions.length)];
    final regionLength = region.end - region.start + 1;
    final actualCount = min(lineCount, regionLength);
    final maxStart = region.end - actualCount + 1;
    final start = region.start + generator.nextInt(maxStart - region.start + 1);
    return _snippetAt(allLines, [
      for (var i = 0; i < actualCount; i++) start + i,
    ]);
  }

  final interior = [for (var i = 1; i < allLines.length - 1; i++) i];

  var eligible = interior;
  if (excludeChorus && chorusRegions.isNotEmpty) {
    final chorusIndices = {
      for (final region in chorusRegions)
        for (var i = region.start; i <= region.end; i++) i,
    };
    eligible = [
      for (final i in interior)
        if (!chorusIndices.contains(i)) i,
    ];
  }

  if (eligible.length < lineCount) {
    eligible = interior;
  }

  if (eligible.length < lineCount) {
    return LyricSnippet(
      lines: allLines.take(lineCount).toList(growable: false),
      sourceLineIndices: [for (var i = 0; i < lineCount; i++) i],
    );
  }

  final contiguousStarts = [
    for (var i = 0; i <= eligible.length - lineCount; i++)
      if (_isContiguousRun(eligible, i, lineCount)) i,
  ];

  final unseenStarts = [
    if (seen.isNotEmpty)
      for (final start in contiguousStarts)
        if (unseen(eligible.getRange(start, start + lineCount))) start,
  ];
  final starts = unseenStarts.isNotEmpty ? unseenStarts : contiguousStarts;

  if (starts.isNotEmpty) {
    final startIdx = starts[generator.nextInt(starts.length)];
    return _snippetAt(allLines, [
      for (var i = 0; i < lineCount; i++) eligible[startIdx + i],
    ]);
  }

  return _snippetAt(allLines, eligible.take(lineCount).toList());
}

String _normalizeForComparison(String text) => text
    .toLowerCase()
    .replaceAll(_parenthetical, ' ')
    .replaceAll(_comparisonPunctuation, '')
    .replaceAll('-', ' ')
    .replaceAll(_whitespaceRun, ' ')
    .trim();

String _escapeForRegExp(String text) =>
    text.replaceAllMapped(_regexSpecialCharacter, (match) => '\\${match[0]}');

RegExp _wholeTitlePattern(String escapedTitle) =>
    RegExp('\\b$escapedTitle\\b', caseSensitive: false);

List<String> sanitiseSnippet(List<String> lines, String songTitle) {
  final normalizedTitle = _normalizeForComparison(songTitle);
  if (normalizedTitle.isEmpty) return UnmodifiableListView([...lines]);

  final escaped = _escapeForRegExp(normalizedTitle);
  final pattern = _wholeTitlePattern(escaped);
  final titleOccurrence = RegExp(
    escaped.replaceAll(_whitespaceRun, r'[\s\-]+'),
    caseSensitive: false,
  );

  return UnmodifiableListView([
    for (final line in lines)
      if (pattern.hasMatch(
        line.replaceAll("'", '').replaceAll('-', ' ').toLowerCase(),
      ))
        line.replaceAll(titleOccurrence, _titleBlank)
      else
        line,
  ]);
}

bool _containsTitle(String line, String songTitle) {
  final normalizedTitle = _normalizeForComparison(songTitle);
  if (normalizedTitle.isEmpty) return false;
  return _wholeTitlePattern(_escapeForRegExp(normalizedTitle))
      .hasMatch(_normalizeForComparison(line));
}

List<String> _pickContiguousBlock(
  List<String> allLines,
  int lineCount,
  Random random, {
  Set<int> excludeIndices = const {},
}) {
  if (lineCount <= 0 || allLines.isEmpty) return const [];

  if (lineCount == 1) {
    var validLines = [
      for (var i = 0; i < allLines.length; i++)
        if (!excludeIndices.contains(i) && _hasPlayableWordCount(allLines[i]))
          allLines[i],
    ];
    if (validLines.isEmpty) {
      validLines = [
        for (var i = 0; i < allLines.length; i++)
          if (!excludeIndices.contains(i)) allLines[i],
      ];
    }
    final pool = validLines.isNotEmpty ? validLines : allLines;
    return [pool[random.nextInt(pool.length)]];
  }

  final minIdx = allLines.length > 2 ? 1 : 0;
  final maxIdx = allLines.length > 2
      ? allLines.length - 2
      : allLines.length - 1;

  final eligible = [
    for (var i = minIdx; i <= maxIdx; i++)
      if (!excludeIndices.contains(i)) i,
  ];

  List<String> blockAt(int start) => [
    for (var j = 0; j < lineCount; j++) allLines[eligible[start + j]],
  ];

  final strictStarts = [
    for (var i = 0; i <= eligible.length - lineCount; i++)
      if (_isContiguousRun(eligible, i, lineCount) &&
          eligible
              .getRange(i, i + lineCount)
              .every((index) => _hasPlayableWordCount(allLines[index])))
        i,
  ];

  if (strictStarts.isNotEmpty) {
    return blockAt(strictStarts[random.nextInt(strictStarts.length)]);
  }

  final relaxedStarts = [
    for (var i = 0; i <= eligible.length - lineCount; i++)
      if (_isContiguousRun(eligible, i, lineCount)) i,
  ];

  if (relaxedStarts.isNotEmpty) {
    return blockAt(relaxedStarts[random.nextInt(relaxedStarts.length)]);
  }

  if (eligible.length >= lineCount) {
    return [for (final i in eligible.take(lineCount)) allLines[i]];
  }

  return allLines.take(lineCount).toList();
}

String _eraGroupOf(String albumTitle) =>
    _findEraGroup(albumTitle) ??
    'album:${eraNameFromTitle(albumTitle).toLowerCase()}';

String? _findEraGroup(String albumTitle) {
  for (final MapEntry(key: era, value: albums) in eraGroups.entries) {
    if (albums.any(
      (album) => albumTitle.contains(album) || album.contains(albumTitle),
    )) {
      return era;
    }
  }
  return null;
}

DecoyResult selectDecoyOrReal(
  List<String> currentTrackLyrics,
  Map<int, TrackLyrics> decoyPool,
  Difficulty difficulty, {
  String? currentTrackAlbum,
  int lineCount = 1,
  String? currentTrackTitle,
  Random? random,
  Set<String> avoid = const {},
}) {
  final generator = random ?? Random();
  final showReal = generator.nextDouble() < 0.5;

  final titleExcluded = <int>{
    if (currentTrackTitle != null && currentTrackTitle.isNotEmpty)
      for (var i = 0; i < currentTrackLyrics.length; i++)
        if (_containsTitle(currentTrackLyrics[i], currentTrackTitle)) i,
  };

  DecoyResult realResult() => DecoyResult(
    lines: _pickContiguousBlock(
      currentTrackLyrics,
      lineCount,
      generator,
      excludeIndices: _withoutSeen(
        currentTrackLyrics,
        lineCount,
        titleExcluded,
        avoid,
      ),
    ),
    isReal: true,
    sourceSong: null,
  );

  if (showReal) return realResult();

  final currentSong = currentTrackTitle == null
      ? null
      : normalizeTitle(currentTrackTitle);
  final decoyEntries = [
    for (final lyrics in decoyPool.values)
      if (normalizeTitle(lyrics.sourceTrack) != currentSong) lyrics,
  ];
  if (decoyEntries.isEmpty) return realResult();

  final avgWordCount =
      currentTrackLyrics.fold<int>(0, (sum, line) => sum + _wordCount(line)) /
      currentTrackLyrics.length;

  var candidates = decoyEntries;

  if (difficulty == Difficulty.hard &&
      currentTrackAlbum != null &&
      currentTrackAlbum.isNotEmpty) {
    final sameAlbum = [
      for (final lyrics in candidates)
        if (lyrics.sourceAlbum == currentTrackAlbum) lyrics,
    ];
    if (sameAlbum.isNotEmpty) candidates = sameAlbum;
  } else if (difficulty == Difficulty.easy) {
    final currentEra = _eraGroupOf(currentTrackAlbum ?? '');
    final differentEra = [
      for (final lyrics in candidates)
        if (_eraGroupOf(lyrics.sourceAlbum) != currentEra) lyrics,
    ];
    if (differentEra.isNotEmpty) candidates = differentEra;
  }

  final decoyLyrics = candidates[generator.nextInt(candidates.length)];

  if (lineCount == 1) {
    final tolerance = avgWordCount * 0.3;
    bool matchesCurrentLength(String line) {
      final words = _wordCount(line);
      return words >= 4 &&
          words <= 15 &&
          (words - avgWordCount).abs() <= tolerance;
    }

    List<String> unseen(List<String> lines) => [
      for (final line in lines)
        if (!avoid.contains(_normalizeLine(line))) line,
    ];
    final close = [
      for (final line in decoyLyrics.lines)
        if (matchesCurrentLength(line)) line,
    ];
    final playable = [
      for (final line in decoyLyrics.lines)
        if (_wordCount(line) >= 4) line,
    ];
    final decoyLines = [
      unseen(close),
      unseen(playable),
      close,
      playable,
      unseen(decoyLyrics.lines),
      decoyLyrics.lines,
    ].firstWhere((lines) => lines.isNotEmpty, orElse: () => const []);

    final line = decoyLines[generator.nextInt(decoyLines.length)];
    return DecoyResult(
      lines: [line],
      isReal: false,
      sourceSong: decoyLyrics.sourceTrack,
    );
  }

  return DecoyResult(
    lines: _pickContiguousBlock(
      decoyLyrics.lines,
      lineCount,
      generator,
      excludeIndices: _withoutSeen(
        decoyLyrics.lines,
        lineCount,
        const {},
        avoid,
      ),
    ),
    isReal: false,
    sourceSong: decoyLyrics.sourceTrack,
  );
}
