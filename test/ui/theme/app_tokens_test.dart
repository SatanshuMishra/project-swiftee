import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

Map<String, int> argbOf(AppTokens tokens) => {
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
  group('tokens match index.css', () {
    test('dark tokens are the sRGB values of the :root block', () {
      expect(argbOf(AppTokens.dark), {
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

    test('light tokens are the values of the .light block', () {
      expect(argbOf(AppTokens.light), {
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

    test('both themes carry their tokens and background', () {
      expect(AppTheme.dark.extension<AppTokens>(), AppTokens.dark);
      expect(AppTheme.light.extension<AppTokens>(), AppTokens.light);
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
