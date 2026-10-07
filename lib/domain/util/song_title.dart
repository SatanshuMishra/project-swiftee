final RegExp _versionLabel = RegExp(
  r"\s*[(\[](?:taylor['’]s version|from the vault)[^)\]]*[)\]]",
  caseSensitive: false,
);

final RegExp _whitespace = RegExp(r'\s+');

String displaySongTitle(String title) =>
    title.replaceAll(_versionLabel, '').replaceAll(_whitespace, ' ').trim();

final RegExp _titlePart = RegExp(r'[(\[]([^)\]]*)[)\]]|\s+-\s+(.*)$');
final RegExp _taylorsVersion = RegExp(
  r"^taylor['’]s version$",
  caseSensitive: false,
);
final RegExp _fromTheVault = RegExp(r'^from the vault$', caseSensitive: false);
final RegExp _featuring = RegExp(
  r'^(feat\.?|ft\.?|featuring|with)\s',
  caseSensitive: false,
);
final RegExp _soundtrack = RegExp(
  r'^from\s.*(soundtrack|motion picture|film|series|"|“)',
  caseSensitive: false,
);

List<String> _titleParts(String title) => [
  for (final match in _titlePart.allMatches(title))
    if ((match[1] ?? match[2] ?? '').trim() case final part
        when part.isNotEmpty)
      part,
];

String? versionLabel(String title, {required String shown}) {
  final parts = _titleParts(title);
  final shownParts = {
    for (final part in _titleParts(shown)) part.toLowerCase(),
  };
  final labels = [
    if (parts.any(_fromTheVault.hasMatch))
      'From The Vault'
    else if (parts.any(_taylorsVersion.hasMatch))
      "Taylor's Version",
    for (final part in parts)
      if (!_fromTheVault.hasMatch(part) &&
          !_taylorsVersion.hasMatch(part) &&
          !shownParts.contains(part.toLowerCase()))
        part,
  ];
  return labels.isEmpty ? null : labels.join(' · ');
}

enum Take { studio, live, alternate }

enum _Label { studio, live, alternate, unknown }

final RegExp _liveLabel = RegExp(
  r'\blive\b|long pond|eras tour',
  caseSensitive: false,
);
final RegExp _alternateLabel = RegExp(
  r'\b(acoustic|piano|demo|stripped|rehearsal|remix|mix|short film|'
  r'video edition|sped up|slowed|a ?c+ap+el+a|unplugged|alternate)\b|'
  r'\bversion$',
  caseSensitive: false,
);
final RegExp _studioLabel = RegExp(
  r'^(\d+ minute version|bonus track|featured in .+|oh my my my|'
  r'no really i can|radio edit|single edit|edit|album version|'
  r'single version|clean|clean version|explicit|explicit version)$',
  caseSensitive: false,
);

_Label _labelOf(String part) {
  if (_liveLabel.hasMatch(part)) {
    return _Label.live;
  }
  if (_taylorsVersion.hasMatch(part) ||
      _fromTheVault.hasMatch(part) ||
      _featuring.hasMatch(part) ||
      _soundtrack.hasMatch(part) ||
      _studioLabel.hasMatch(part)) {
    return _Label.studio;
  }
  if (_alternateLabel.hasMatch(part)) {
    return _Label.alternate;
  }
  return _Label.unknown;
}

Take takeOf(String title) {
  final labels = _titleParts(title).map(_labelOf).toSet();
  return labels.contains(_Label.live)
      ? Take.live
      : labels.contains(_Label.alternate)
      ? Take.alternate
      : Take.studio;
}

List<String> unknownTitleLabels(String title) => List.unmodifiable([
  for (final part in _titleParts(title))
    if (_labelOf(part) == _Label.unknown) part,
]);

bool isTaylorsVersion(String title) =>
    _titleParts(title).any(_taylorsVersion.hasMatch);

bool isFromTheVault(String title) =>
    _titleParts(title).any(_fromTheVault.hasMatch);
