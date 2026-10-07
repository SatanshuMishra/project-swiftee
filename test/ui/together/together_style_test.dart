import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const List<String> _scanned = ['lib/ui/screens/together', 'lib/ui/together'];
const String _playerColors = 'lib/ui/together/player_colors.dart';
const List<String> _allowedColors = [
  '0xFFE97F6A',
  '0xFF6FA8DC',
  '0xFFD4A0A0',
  '0xFF9DBF8E',
];

final RegExp _colorCall = RegExp(r'\bColor(\(|\.from)');
final RegExp _colorLiteral = RegExp(r'\bColor\((0x[0-9A-Fa-f]{8})\)');
final RegExp _colorsMember = RegExp(r'\bColors\.(\w+)');

List<File> _dartFiles() => [
  for (final folder in _scanned)
    for (final entity in Directory(folder).listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart')) entity,
];

void main() {
  test(
    'play together screens use theme tokens and the four player colours only',
    () {
      final files = _dartFiles();
      expect(
        files.map((file) => p.normalize(file.path)),
        containsAll([
          p.normalize(_playerColors),
          p.normalize('lib/ui/screens/together/together_game_screen.dart'),
          p.normalize('lib/ui/screens/together/lobby_screen.dart'),
          p.normalize('lib/ui/together/standings_list.dart'),
        ]),
      );

      for (final file in files) {
        final path = p.normalize(file.path);
        final source = file.readAsStringSync();
        if (path != p.normalize(_playerColors)) {
          expect(
            _colorCall.allMatches(source).map((match) => match.group(0)),
            isEmpty,
            reason: '$path builds a colour instead of using a theme token',
          );
        }
        expect(
          [
            for (final match in _colorsMember.allMatches(source))
              if (match.group(1) != 'transparent') match.group(0),
          ],
          isEmpty,
          reason: '$path uses a Colors member other than Colors.transparent',
        );
      }

      final palette = File(_playerColors).readAsStringSync();
      expect(
        _colorLiteral
            .allMatches(palette)
            .map(
              (match) => match.group(1)!.toUpperCase().replaceFirst('0X', '0x'),
            ),
        _allowedColors,
      );
      expect(
        _colorCall.allMatches(palette).length,
        _allowedColors.length,
        reason:
            'player_colors.dart holds a colour beyond the four player colours',
      );
    },
  );
}
