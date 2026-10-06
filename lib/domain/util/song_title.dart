final RegExp _versionLabel = RegExp(
  r"\s*[(\[](?:taylor['’]s version|from the vault)[^)\]]*[)\]]",
  caseSensitive: false,
);

final RegExp _whitespace = RegExp(r'\s+');

String displaySongTitle(String title) =>
    title.replaceAll(_versionLabel, '').replaceAll(_whitespace, ' ').trim();
