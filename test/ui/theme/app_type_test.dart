import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('display text uses the bundled instrument serif', () {
    final upright = AppType.display(56, height: 1.02);
    final italic = AppType.display(44, italic: true, height: 52 / 44);
    expect(AppType.serifFamily, 'Instrument Serif');
    for (final style in [upright, italic]) {
      expect(style.fontFamily, 'Instrument Serif');
      expect(style.fontWeight, FontWeight.w400);
    }
    expect(upright.fontStyle, FontStyle.normal);
    expect(italic.fontStyle, FontStyle.italic);
    expect(upright.fontSize, 56);
    expect(upright.height, 1.02);
    expect(italic.fontSize! * italic.height!, closeTo(52, 1e-9));

    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
    final families = (pubspec['flutter'] as Map)['fonts'] as List;
    final serif = families.singleWhere(
      (family) => (family as Map)['family'] == 'Instrument Serif',
    ) as Map;
    final fonts = (serif['fonts'] as List).cast<Map<Object?, Object?>>();
    final regular = fonts.where((font) => font['style'] == null).toList();
    final italics = fonts.where((font) => font['style'] == 'italic').toList();
    expect(regular, hasLength(1));
    expect(italics, hasLength(1));
    for (final font in [...regular, ...italics]) {
      final bytes = File(font['asset'] as String).readAsBytesSync();
      expect(bytes.take(4), [0, 1, 0, 0], reason: '${font['asset']}');
    }

    for (final style in [
      AppType.body,
      AppType.bodyLarge,
      AppType.small,
      AppType.caption,
      AppType.sectionLabel,
    ]) {
      expect(style.fontFamily, isNull);
    }
  });

  test('system styles carry the handoff sizes and line heights', () {
    final scale = {
      'sectionLabel': (AppType.sectionLabel, 12, 16, FontWeight.w600),
      'body': (AppType.body, 15, 22, FontWeight.w400),
      'bodyLarge': (AppType.bodyLarge, 16, 24, FontWeight.w400),
      'small': (AppType.small, 13, 18, FontWeight.w400),
      'caption': (AppType.caption, 12, 16, FontWeight.w400),
    };
    for (final MapEntry(key: name, value: (style, size, lineHeight, weight))
        in scale.entries) {
      expect(style.fontSize, size, reason: name);
      expect(style.fontSize! * style.height!, closeTo(lineHeight, 1e-9));
      expect(style.fontWeight, weight, reason: name);
    }
    final sized = AppType.sized(14, 20, weight: FontWeight.w600);
    expect(sized.fontSize, 14);
    expect(sized.height, 20 / 14);
    expect(sized.fontWeight, FontWeight.w600);
    expect(sized.fontFamily, isNull);
  });
}
