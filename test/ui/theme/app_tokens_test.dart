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
  'card': (tokens) => tokens.card,
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
          'card' => AppTokens.dark.copyWith(card: replacement),
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

  test('the Material theme takes every colour from the design tokens', () {
    for (final (name, theme, tokens, brightness) in [
      ('dark', AppTheme.dark, AppTokens.dark, Brightness.dark),
      ('light', AppTheme.light, AppTokens.light, Brightness.light),
    ]) {
      final scheme = theme.colorScheme;
      final roles = <String, (Color?, Color)>{
        'primary': (scheme.primary, tokens.coral),
        'onPrimary': (scheme.onPrimary, tokens.onCoral),
        'secondary': (scheme.secondary, tokens.hover),
        'onSecondary': (scheme.onSecondary, tokens.fg),
        'error': (scheme.error, tokens.rose),
        'onError': (scheme.onError, tokens.bg),
        'surface': (scheme.surface, tokens.bg),
        'onSurface': (scheme.onSurface, tokens.fg),
        'onSurfaceVariant': (scheme.onSurfaceVariant, tokens.mut),
        'surfaceContainerHighest': (
          scheme.surfaceContainerHighest,
          tokens.hover,
        ),
        'outline': (scheme.outline, tokens.line2),
        'outlineVariant': (scheme.outlineVariant, tokens.line),
        'scaffoldBackgroundColor': (theme.scaffoldBackgroundColor, tokens.bg),
        'canvasColor': (theme.canvasColor, tokens.bg),
        'cardColor': (theme.cardColor, tokens.panel),
        'dividerColor': (theme.dividerColor, tokens.line),
        'bodyMedium': (theme.textTheme.bodyMedium?.color, tokens.fg),
      };

      expect(theme.brightness, brightness, reason: name);
      expect(scheme.brightness, brightness, reason: name);
      for (final MapEntry(key: role, value: (actual, expected))
          in roles.entries) {
        expect(actual, expected, reason: '$name $role');
      }
      for (final (role, color) in [
        ('surface', scheme.surface),
        ('canvasColor', theme.canvasColor),
        ('cardColor', theme.cardColor),
      ]) {
        expect(color.a, 1, reason: '$name $role must be opaque');
      }
    }
  });

  group('css geometry', () {
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
  });
}
