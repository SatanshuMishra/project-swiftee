import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

Color css(String value) {
  if (value.startsWith('#')) {
    return Color(int.parse('FF${value.substring(1)}', radix: 16));
  }
  final rgba = RegExp(r'^rgba\((\d+),(\d+),(\d+),([\d.]+)\)$')
      .firstMatch(value.replaceAll(' ', ''))!;
  return Color.from(
    alpha: double.parse(rgba[4]!),
    red: int.parse(rgba[1]!) / 255,
    green: int.parse(rgba[2]!) / 255,
    blue: int.parse(rgba[3]!) / 255,
  );
}

final Map<String, Color Function(AppTokens)> designFields = {
  'bg': (tokens) => tokens.bg,
  'fg': (tokens) => tokens.fg,
  'mut': (tokens) => tokens.mut,
  'faint': (tokens) => tokens.faint,
  'line': (tokens) => tokens.line,
  'line2': (tokens) => tokens.line2,
  'card': (tokens) => tokens.designCard,
  'hover': (tokens) => tokens.hover,
  'coral': (tokens) => tokens.coral,
  'coralT': (tokens) => tokens.coralT,
  'onCoral': (tokens) => tokens.onCoral,
  'btn': (tokens) => tokens.btn,
  'onBtn': (tokens) => tokens.onBtn,
  'paper': (tokens) => tokens.paper,
  'paperFg': (tokens) => tokens.paperFg,
  'bubble': (tokens) => tokens.bubble,
  'bubbleFg': (tokens) => tokens.bubbleFg,
  'sleeve': (tokens) => tokens.sleeve,
  'sleeveFg': (tokens) => tokens.sleeveFg,
  'g1': (tokens) => tokens.g1,
  'g2': (tokens) => tokens.g2,
  'rose': (tokens) => tokens.rose,
  'roseBg': (tokens) => tokens.roseBg,
  'shadow': (tokens) => tokens.shadow,
  'scrim': (tokens) => tokens.scrim,
  'panel': (tokens) => tokens.panel,
  'bar': (tokens) => tokens.bar,
};

const Map<String, String> darkHandoff = {
  'bg': '#1A1514',
  'fg': '#F5E5D4',
  'mut': '#B8A99C',
  'faint': '#8E8076',
  'line': 'rgba(245,229,212,.10)',
  'line2': 'rgba(245,229,212,.18)',
  'card': 'rgba(245,229,212,.04)',
  'hover': 'rgba(245,229,212,.07)',
  'coral': '#E97F6A',
  'coralT': '#E97F6A',
  'onCoral': '#1A1514',
  'btn': '#F5E5D4',
  'onBtn': '#1A1514',
  'paper': '#FBF0E6',
  'paperFg': '#3B2F2F',
  'bubble': '#FBF0E6',
  'bubbleFg': '#3B2F2F',
  'sleeve': '#E9DCCB',
  'sleeveFg': 'rgba(59,47,47,.55)',
  'g1': '#18120F',
  'g2': '#2E2724',
  'rose': '#E4A0A0',
  'roseBg': 'rgba(212,160,160,.10)',
  'shadow': 'rgba(0,0,0,.45)',
  'scrim': 'rgba(12,9,8,.62)',
  'panel': '#231D1B',
  'bar': 'rgba(26,21,20,.82)',
};

const Map<String, String> lightHandoff = {
  'bg': '#FAF7F2',
  'fg': '#2A2422',
  'mut': '#6B5F59',
  'faint': '#857870',
  'line': 'rgba(42,36,34,.10)',
  'line2': 'rgba(42,36,34,.20)',
  'card': '#FFFFFF',
  'hover': '#F3EDE5',
  'coral': '#E97F6A',
  'coralT': '#B4533F',
  'onCoral': '#1A1514',
  'btn': '#2A2422',
  'onBtn': '#FAF7F2',
  'paper': '#FFFFFF',
  'paperFg': '#3B2F2F',
  'bubble': '#FFFFFF',
  'bubbleFg': '#3B2F2F',
  'sleeve': '#E9DCCB',
  'sleeveFg': 'rgba(59,47,47,.55)',
  'g1': '#1A1514',
  'g2': '#3A322E',
  'rose': '#A64545',
  'roseBg': 'rgba(166,69,69,.08)',
  'shadow': 'rgba(60,40,30,.20)',
  'scrim': 'rgba(42,36,34,.35)',
  'panel': '#FFFFFF',
  'bar': 'rgba(250,247,242,.86)',
};

Map<String, int> legacyArgbOf(AppTokens tokens) => {
  'background': tokens.background.toARGB32(),
  'foreground': tokens.foreground.toARGB32(),
  'card': tokens.card.toARGB32(),
  'muted': tokens.muted.toARGB32(),
  'muted-foreground': tokens.mutedForeground.toARGB32(),
  'border': tokens.border.toARGB32(),
  'primary': tokens.primary.toARGB32(),
  'primary-foreground': tokens.primaryForeground.toARGB32(),
  'destructive': tokens.destructive.toARGB32(),
  'correct': tokens.correct.toARGB32(),
  'incorrect': tokens.incorrect.toARGB32(),
};

void main() {
  test('design tokens match the handoff in both themes', () {
    for (final (theme, tokens, handoff) in [
      ('dark', AppTokens.dark, darkHandoff),
      ('light', AppTokens.light, lightHandoff),
    ]) {
      expect(handoff.keys.toSet(), designFields.keys.toSet(), reason: theme);
      for (final MapEntry(key: name, value: field) in designFields.entries) {
        final expected = css(handoff[name]!);
        final actual = field(tokens);
        expect(actual, expected, reason: '$theme $name');
        expect(actual.a, expected.a, reason: '$theme $name alpha');
      }
    }
  });

  group('design tokens', () {
    test('lerp cross-fades every design field between the themes', () {
      final halfway = AppTokens.dark.lerp(AppTokens.light, 0.5);
      final arrived = AppTokens.dark.lerp(AppTokens.light, 1);
      for (final MapEntry(key: name, value: field) in designFields.entries) {
        expect(
          field(halfway),
          Color.lerp(field(AppTokens.dark), field(AppTokens.light), 0.5),
          reason: name,
        );
        expect(field(arrived), field(AppTokens.light), reason: name);
      }
      expect(halfway.background, isNot(AppTokens.dark.background));
    });

    test('copyWith replaces one design field and keeps the rest', () {
      const replacement = Color(0xFF123456);
      for (final name in designFields.keys) {
        final copy = switch (name) {
          'bg' => AppTokens.dark.copyWith(bg: replacement),
          'fg' => AppTokens.dark.copyWith(fg: replacement),
          'mut' => AppTokens.dark.copyWith(mut: replacement),
          'faint' => AppTokens.dark.copyWith(faint: replacement),
          'line' => AppTokens.dark.copyWith(line: replacement),
          'line2' => AppTokens.dark.copyWith(line2: replacement),
          'card' => AppTokens.dark.copyWith(designCard: replacement),
          'hover' => AppTokens.dark.copyWith(hover: replacement),
          'coral' => AppTokens.dark.copyWith(coral: replacement),
          'coralT' => AppTokens.dark.copyWith(coralT: replacement),
          'onCoral' => AppTokens.dark.copyWith(onCoral: replacement),
          'btn' => AppTokens.dark.copyWith(btn: replacement),
          'onBtn' => AppTokens.dark.copyWith(onBtn: replacement),
          'paper' => AppTokens.dark.copyWith(paper: replacement),
          'paperFg' => AppTokens.dark.copyWith(paperFg: replacement),
          'bubble' => AppTokens.dark.copyWith(bubble: replacement),
          'bubbleFg' => AppTokens.dark.copyWith(bubbleFg: replacement),
          'sleeve' => AppTokens.dark.copyWith(sleeve: replacement),
          'sleeveFg' => AppTokens.dark.copyWith(sleeveFg: replacement),
          'g1' => AppTokens.dark.copyWith(g1: replacement),
          'g2' => AppTokens.dark.copyWith(g2: replacement),
          'rose' => AppTokens.dark.copyWith(rose: replacement),
          'roseBg' => AppTokens.dark.copyWith(roseBg: replacement),
          'shadow' => AppTokens.dark.copyWith(shadow: replacement),
          'scrim' => AppTokens.dark.copyWith(scrim: replacement),
          'panel' => AppTokens.dark.copyWith(panel: replacement),
          'bar' => AppTokens.dark.copyWith(bar: replacement),
          _ => throw StateError(name),
        };
        for (final MapEntry(key: other, value: otherField)
            in designFields.entries) {
          expect(
            otherField(copy),
            other == name ? replacement : otherField(AppTokens.dark),
            reason: '$name then $other',
          );
        }
      }
    });

    test('brand colours are the theme-independent handoff values', () {
      expect(BrandColors.closeHover, css('#C42B1C'));
      expect(BrandColors.beads, [
        css('#F5E5D4'),
        css('#D4A0A0'),
        css('#6FA8DC'),
        css('#E97F6A'),
        css('#FBF0E6'),
      ]);
      expect(BrandColors.players, [
        css('#E97F6A'),
        css('#6FA8DC'),
        css('#D4A0A0'),
        css('#9DBF8E'),
      ]);
      expect(BrandColors.birthdayHeader, css('#E97F6A'));
      expect(BrandColors.birthdayInk, css('#1A1514'));
      expect(BrandColors.letterSignature, css('#B4533F'));
    });

    test('both themes draw the caret, selection and focus in coral', () {
      for (final (theme, tokens) in [
        (AppTheme.dark, AppTokens.dark),
        (AppTheme.light, AppTokens.light),
      ]) {
        expect(theme.extension<AppTokens>(), tokens);
        expect(theme.textSelectionTheme.cursorColor, tokens.coral);
        expect(theme.textSelectionTheme.selectionHandleColor, tokens.coral);
        expect(
          theme.textSelectionTheme.selectionColor,
          tokens.coral.withValues(alpha: AppTheme.selectionOpacity),
        );
        expect(theme.focusColor, tokens.coral);
      }
    });
  });

  group('v0.3.0 tokens stay until every screen is rebuilt', () {
    test('dark tokens keep their v0.3.0 values', () {
      expect(legacyArgbOf(AppTokens.dark), {
        'background': 0xFF0A0A0A,
        'foreground': 0xFFFAFAFA,
        'card': 0xFF121212,
        'muted': 0xFF262626,
        'muted-foreground': 0xFFA1A1A1,
        'border': 0xFF262626,
        'primary': 0xFFFAFAFA,
        'primary-foreground': 0xFF171717,
        'destructive': 0xFFEF4444,
        'correct': 0xFF22C55E,
        'incorrect': 0xFFEF4444,
      });
    });

    test('light tokens keep their v0.3.0 values', () {
      expect(legacyArgbOf(AppTokens.light), {
        'background': 0xFFFFFFFF,
        'foreground': 0xFF030213,
        'card': 0xFFFFFFFF,
        'muted': 0xFFECECF0,
        'muted-foreground': 0xFF717182,
        'border': 0x1A000000,
        'primary': 0xFF030213,
        'primary-foreground': 0xFFFFFFFF,
        'destructive': 0xFFDC2626,
        'correct': 0xFF16A34A,
        'incorrect': 0xFFDC2626,
      });
      expect(AppTokens.light.border.a, 0.1);
    });

    test('each dark oklch token is the CSS Color 4 conversion', () {
      final cssTokens = {
        'background': (0.145, AppTokens.dark.background),
        'foreground': (0.985, AppTokens.dark.foreground),
        'card': (0.18, AppTokens.dark.card),
        'muted': (0.269, AppTokens.dark.muted),
        'muted-foreground': (0.708, AppTokens.dark.mutedForeground),
        'border': (0.269, AppTokens.dark.border),
        'primary': (0.985, AppTokens.dark.primary),
        'primary-foreground': (0.205, AppTokens.dark.primaryForeground),
      };
      for (final MapEntry(key: name, value: (lightness, token))
          in cssTokens.entries) {
        expect(
          Oklab.fromOklch(lightness, 0, 0).toARGB32(),
          token.toARGB32(),
          reason: name,
        );
      }
    });

    test('Tailwind 4.3.3 shades are their oklch values clipped to sRGB', () {
      final shades = {
        'red-200': ((0.885, 0.062, 18.334), AppPalette.red200, 0xFFFFC9C9),
        'red-400': ((0.704, 0.191, 22.216), AppPalette.red400, 0xFFFF6467),
        'red-500': ((0.637, 0.237, 25.331), AppPalette.red500, 0xFFFB2C36),
        'green-400': ((0.792, 0.209, 151.711), AppPalette.green400, 0xFF05DF72),
        'green-500': ((0.723, 0.219, 149.579), AppPalette.green500, 0xFF00C950),
        'orange-400': ((0.75, 0.183, 55.934), AppPalette.orange400, 0xFFFF8904),
        'orange-500': (
          (0.705, 0.213, 47.604),
          AppPalette.orange500,
          0xFFFF6900,
        ),
        'purple-400': (
          (0.714, 0.203, 305.504),
          AppPalette.purple400,
          0xFFC27AFF,
        ),
        'purple-500': ((0.627, 0.265, 303.9), AppPalette.purple500, 0xFFAD46FF),
        'violet-600': (
          (0.541, 0.281, 293.009),
          AppPalette.violet600,
          0xFF7F22FE,
        ),
        'violet-700': (
          (0.491, 0.27, 292.581),
          AppPalette.violet700,
          0xFF7008E7,
        ),
        'blue-600': ((0.546, 0.245, 262.881), AppPalette.blue600, 0xFF155DFC),
        'emerald-600': (
          (0.596, 0.145, 163.225),
          AppPalette.emerald600,
          0xFF009966,
        ),
        'yellow-200': (
          (0.945, 0.129, 101.54),
          AppPalette.yellow200,
          0xFFFFF085,
        ),
        'yellow-500': (
          (0.795, 0.184, 86.047),
          AppPalette.yellow500,
          0xFFF0B100,
        ),
        'yellow-600': (
          (0.681, 0.162, 75.834),
          AppPalette.yellow600,
          0xFFD08700,
        ),
        'pink-500': ((0.656, 0.241, 354.308), AppPalette.pink500, 0xFFF6339A),
      };
      for (final MapEntry(key: name, value: ((l, c, h), constant, argb))
          in shades.entries) {
        expect(Oklab.fromOklch(l, c, h).toARGB32(), argb, reason: name);
        expect(constant.toARGB32(), argb, reason: name);
      }
    });

    test('slash opacity is color-mix in oklab with transparent', () {
      const transparent = Color(0x00000000);
      final cases = {
        'dark muted/20': (AppTokens.dark.muted, 20),
        'dark primary/50': (AppTokens.dark.primary, 50),
        'light border/50': (AppTokens.light.border, 50),
        'green-500/10': (AppPalette.green500, 10),
      };
      for (final MapEntry(key: name, value: (color, percent))
          in cases.entries) {
        final mixed = color.slashOpacity(percent);
        final reference = Oklab.mix(color, transparent, 1 - percent / 100);
        expect(mixed.a, closeTo(color.a * percent / 100, 1e-9), reason: name);
        expect(mixed.a, closeTo(reference.a, 1 / 255), reason: name);
        expect(
          mixed.toARGB32() & 0x00FFFFFF,
          reference.toARGB32() & 0x00FFFFFF,
          reason: name,
        );
      }
    });

    test('both themes keep their v0.3.0 background and brightness', () {
      expect(AppTheme.dark.scaffoldBackgroundColor, const Color(0xFF0A0A0A));
      expect(AppTheme.light.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.light.brightness, Brightness.light);
    });
  });

  group('css geometry and interpolation', () {
    test('box-shadow blur is a Gaussian of half the radius as Blink draws', () {
      const shadow = CssBoxShadow(
        color: Color(0x1A000000),
        offset: Offset(0, 20),
        blur: 25,
        spread: -5,
      );
      expect(shadow.blurSigma, closeTo(12.5, 1e-9));
      expect(shadow.spreadRadius, -5);
    });

    test('drop-shadow blur is the standard deviation itself', () {
      const shadow = CssDropShadow(
        color: Color(0x26000000),
        offset: Offset(0, 25),
        blur: 25,
      );
      expect(shadow.blurSigma, closeTo(25, 1e-9));
    });

    test('a 135 degree gradient line spans the box as CSS defines it', () {
      final (start, end) = const CssGradientDirection.angle(135)
          .endpoints(const Rect.fromLTWH(0, 0, 200, 100));
      expect(start.dx, closeTo(25, 1e-9));
      expect(start.dy, closeTo(-25, 1e-9));
      expect(end.dx, closeTo(175, 1e-9));
      expect(end.dy, closeTo(125, 1e-9));
    });

    test('to bottom right puts the top-left corner at 0 percent', () {
      final (start, end) = const CssGradientDirection.toBottomRight().endpoints(
        const Rect.fromLTWH(0, 0, 200, 100),
      );
      expect(start.dx, closeTo(60, 1e-9));
      expect(start.dy, closeTo(-30, 1e-9));
      expect(end.dx, closeTo(140, 1e-9));
      expect(end.dy, closeTo(130, 1e-9));
    });

    test('oklab interpolation matches the premultiplied CSS midpoint', () {
      expect(
        Oklab.mix(AppPalette.purple500, AppPalette.pink500, 0.5).toARGB32(),
        0xFFD148CE,
      );
      final screenMidpoint = Oklab.mix(
        AppTokens.dark.background,
        AppTokens.dark.muted.slashOpacity(20),
        0.5,
      );
      expect(screenMidpoint.toARGB32() & 0x00FFFFFF, 0x000E0E0E);
      expect(screenMidpoint.a, closeTo(0.6, 1e-9));
    });
  });
}
