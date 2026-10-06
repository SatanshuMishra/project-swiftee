final RegExp _versionLabel = RegExp(
  r"\s*[(\[](?:taylor['’]s version|from the vault)[^)\]]*[)\]]",
  caseSensitive: false,
);

final RegExp _whitespace = RegExp(r'\s+');

String displaySongTitle(String title) =>
    title.replaceAll(_versionLabel, '').replaceAll(_whitespace, ' ').trim();

final RegExp _livePattern = RegExp(r'\blive\b', caseSensitive: false);
final RegExp _acousticPattern = RegExp(
  r'acoustic|piano|voice/|strings|orchestral',
  caseSensitive: false,
);
final RegExp _demoPattern = RegExp(
  r'demo|first draft|phone memo',
  caseSensitive: false,
);

String? versionLabel(String title) {
  final lower = title.toLowerCase().replaceAll('’', "'");
  final labels = [
    if (lower.contains('from the vault'))
      'From The Vault'
    else if (lower.contains("taylor's version"))
      "Taylor's Version",
    if (lower.contains('long pond'))
      'Long Pond Studio Sessions'
    else if (_livePattern.hasMatch(lower))
      'Live',
    if (_acousticPattern.hasMatch(lower)) 'Acoustic',
    if (_demoPattern.hasMatch(lower)) 'Demo',
  ];
  return labels.isEmpty ? null : labels.join(' · ');
}
