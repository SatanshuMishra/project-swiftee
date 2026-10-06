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
final RegExp _soundtrack = RegExp(r'^from\s', caseSensitive: false);

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

bool isStudioVersion(String title) => _titleParts(title).every(
  (part) =>
      _taylorsVersion.hasMatch(part) ||
      _fromTheVault.hasMatch(part) ||
      _featuring.hasMatch(part) ||
      _soundtrack.hasMatch(part),
);
