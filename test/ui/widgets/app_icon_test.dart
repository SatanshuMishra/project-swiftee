import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';

const reactIconFiles = <String>{
  'music',
  'album',
  'award',
  'settings',
  'arrow-left',
  'volume-2',
  'book-open',
  'eye',
  'zap',
  'flame',
  'skull',
  'play',
  'pause',
  'check',
  'x',
  'lock',
  'moon',
  'sun',
  'monitor',
  'clock',
  'trash-2',
  'bell',
  'archive',
  'cake',
  'sparkles',
  'download',
  'loader-circle',
  'circle-alert',
  'refresh-ccw',
};

const lucideStrokeAttributes = <String>[
  'viewBox="0 0 24 24"',
  'fill="none"',
  'stroke="currentColor"',
  'stroke-width="2"',
  'stroke-linecap="round"',
  'stroke-linejoin="round"',
];

void main() {
  group('every lucide icon the UI uses is bundled', () {
    test('the 29 React icons each have a glyph and an asset, and no more', () {
      final glyphFiles = LucideGlyph.values
          .map((glyph) => glyph.fileName)
          .toSet();
      final bundledFiles = Directory('assets/icons')
          .listSync()
          .whereType<File>()
          .where((file) => p.extension(file.path) == '.svg')
          .map((file) => p.basenameWithoutExtension(file.path))
          .toSet();

      expect(reactIconFiles, hasLength(29));
      expect(glyphFiles, reactIconFiles);
      expect(bundledFiles, reactIconFiles);
      for (final glyph in LucideGlyph.values) {
        expect(glyph.assetPath, 'assets/icons/${glyph.fileName}.svg');
      }
    });

    test('each asset is a bare 24 x 24 Lucide stroke drawing', () {
      for (final glyph in LucideGlyph.values) {
        final source = File(glyph.assetPath).readAsStringSync();
        for (final attribute in lucideStrokeAttributes) {
          expect(source, contains(attribute), reason: glyph.fileName);
        }
        expect(source, isNot(contains('<!--')), reason: glyph.fileName);
        expect(source, isNot(contains('@license')), reason: glyph.fileName);
      }
    });

    testWidgets(
      'each asset loads from the bundle and parses with flutter_svg',
      (tester) async {
        for (final glyph in LucideGlyph.values) {
          final picture = await tester.runAsync(
            () => vg.loadPicture(LucideIconLoader(glyph), null),
          );
          expect(picture, isNotNull, reason: glyph.fileName);
          expect(picture!.size, const Size(24, 24), reason: glyph.fileName);
          picture.picture.dispose();
        }
      },
    );

    testWidgets('AppIcon renders each glyph at 16 and 24 px tinted', (
      tester,
    ) async {
      const tint = Color(0xFFFF6467);
      for (final size in const [16.0, 24.0]) {
        for (final glyph in LucideGlyph.values) {
          await tester.pumpWidget(
            Center(
              child: AppIcon(glyph, size: size, color: tint),
            ),
          );
          await tester.runAsync(vg.waitForPendingDecodes);
          await tester.pump();

          final icon = find.byType(AppIcon);
          expect(tester.getSize(icon), Size.square(size));
          final picture = tester.widget<SvgPicture>(
            find.descendant(of: icon, matching: find.byType(SvgPicture)),
          );
          expect(
            picture.colorFilter,
            const ColorFilter.mode(tint, BlendMode.srcIn),
          );
          expect(
            icon,
            paints
              ..something(
                (method, arguments) =>
                    method == #saveLayer &&
                    (arguments[1] as Paint).colorFilter ==
                        const ColorFilter.mode(tint, BlendMode.srcIn),
              )
              ..something((method, arguments) => method == #drawPicture),
            reason: '${glyph.fileName} at $size',
          );
        }
      }
    });

    testWidgets('AppIcon takes the ambient text colour like currentColor', (
      tester,
    ) async {
      const ambient = Color(0xFFA1A1A1);
      await tester.pumpWidget(
        const DefaultTextStyle(
          style: TextStyle(color: ambient),
          child: Center(child: AppIcon(LucideGlyph.arrowLeft, size: 16)),
        ),
      );

      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        picture.colorFilter,
        const ColorFilter.mode(ambient, BlendMode.srcIn),
      );
    });

    testWidgets('icons are hidden from accessibility as lucide-react does', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const Center(child: AppIcon(LucideGlyph.music)));

      expect(
        tester.getSemantics(find.byType(AppIcon)),
        matchesSemantics(label: '', isImage: false),
      );
      handle.dispose();
    });

    testWidgets('a custom stroke width loads as its own drawing', (
      tester,
    ) async {
      final thin = await tester.runAsync(
        () => LucideIconLoader(LucideGlyph.x, strokeWidth: 1.5).loadBytes(null),
      );
      final regular = await tester.runAsync(
        () => LucideIconLoader(LucideGlyph.x).loadBytes(null),
      );

      expect(thin, isNotNull);
      expect(regular, isNotNull);
      expect(
        thin!.buffer.asUint8List(),
        isNot(equals(regular!.buffer.asUint8List())),
      );
      expect(
        LucideIconLoader(LucideGlyph.x, strokeWidth: 1.5),
        isNot(LucideIconLoader(LucideGlyph.x)),
      );
    });
  });
}
