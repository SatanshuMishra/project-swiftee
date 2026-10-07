import 'package:flutter/material.dart';

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.bg,
    required this.fg,
    required this.mut,
    required this.faint,
    required this.line,
    required this.line2,
    required this.card,
    required this.hover,
    required this.coral,
    required this.coralT,
    required this.onCoral,
    required this.btn,
    required this.onBtn,
    required this.paper,
    required this.paperFg,
    required this.bubble,
    required this.bubbleFg,
    required this.sleeve,
    required this.sleeveFg,
    required this.g1,
    required this.g2,
    required this.rose,
    required this.roseBg,
    required this.shadow,
    required this.scrim,
    required this.panel,
    required this.bar,
  });

  static const dark = AppTokens(
    bg: Color(0xFF1A1514),
    fg: Color(0xFFF5E5D4),
    mut: Color(0xFFB8A99C),
    faint: Color(0xFF8E8076),
    line: Color.from(
      alpha: 0.10,
      red: 245 / 255,
      green: 229 / 255,
      blue: 212 / 255,
    ),
    line2: Color.from(
      alpha: 0.18,
      red: 245 / 255,
      green: 229 / 255,
      blue: 212 / 255,
    ),
    card: Color.from(
      alpha: 0.04,
      red: 245 / 255,
      green: 229 / 255,
      blue: 212 / 255,
    ),
    hover: Color.from(
      alpha: 0.07,
      red: 245 / 255,
      green: 229 / 255,
      blue: 212 / 255,
    ),
    coral: Color(0xFFE97F6A),
    coralT: Color(0xFFE97F6A),
    onCoral: Color(0xFF1A1514),
    btn: Color(0xFFF5E5D4),
    onBtn: Color(0xFF1A1514),
    paper: Color(0xFFFBF0E6),
    paperFg: Color(0xFF3B2F2F),
    bubble: Color(0xFFFBF0E6),
    bubbleFg: Color(0xFF3B2F2F),
    sleeve: Color(0xFFE9DCCB),
    sleeveFg: Color.from(
      alpha: 0.55,
      red: 59 / 255,
      green: 47 / 255,
      blue: 47 / 255,
    ),
    g1: Color(0xFF18120F),
    g2: Color(0xFF2E2724),
    rose: Color(0xFFE4A0A0),
    roseBg: Color.from(
      alpha: 0.10,
      red: 212 / 255,
      green: 160 / 255,
      blue: 160 / 255,
    ),
    shadow: Color.from(
      alpha: 0.45,
      red: 0 / 255,
      green: 0 / 255,
      blue: 0 / 255,
    ),
    scrim: Color.from(
      alpha: 0.62,
      red: 12 / 255,
      green: 9 / 255,
      blue: 8 / 255,
    ),
    panel: Color(0xFF231D1B),
    bar: Color.from(
      alpha: 0.82,
      red: 26 / 255,
      green: 21 / 255,
      blue: 20 / 255,
    ),
  );

  static const light = AppTokens(
    bg: Color(0xFFFAF7F2),
    fg: Color(0xFF2A2422),
    mut: Color(0xFF6B5F59),
    faint: Color(0xFF857870),
    line: Color.from(
      alpha: 0.10,
      red: 42 / 255,
      green: 36 / 255,
      blue: 34 / 255,
    ),
    line2: Color.from(
      alpha: 0.20,
      red: 42 / 255,
      green: 36 / 255,
      blue: 34 / 255,
    ),
    card: Color(0xFFFFFFFF),
    hover: Color(0xFFF3EDE5),
    coral: Color(0xFFE97F6A),
    coralT: Color(0xFFB4533F),
    onCoral: Color(0xFF1A1514),
    btn: Color(0xFF2A2422),
    onBtn: Color(0xFFFAF7F2),
    paper: Color(0xFFFFFFFF),
    paperFg: Color(0xFF3B2F2F),
    bubble: Color(0xFFFFFFFF),
    bubbleFg: Color(0xFF3B2F2F),
    sleeve: Color(0xFFE9DCCB),
    sleeveFg: Color.from(
      alpha: 0.55,
      red: 59 / 255,
      green: 47 / 255,
      blue: 47 / 255,
    ),
    g1: Color(0xFF1A1514),
    g2: Color(0xFF3A322E),
    rose: Color(0xFFA64545),
    roseBg: Color.from(
      alpha: 0.08,
      red: 166 / 255,
      green: 69 / 255,
      blue: 69 / 255,
    ),
    shadow: Color.from(
      alpha: 0.20,
      red: 60 / 255,
      green: 40 / 255,
      blue: 30 / 255,
    ),
    scrim: Color.from(
      alpha: 0.35,
      red: 42 / 255,
      green: 36 / 255,
      blue: 34 / 255,
    ),
    panel: Color(0xFFFFFFFF),
    bar: Color.from(
      alpha: 0.86,
      red: 250 / 255,
      green: 247 / 255,
      blue: 242 / 255,
    ),
  );

  final Color bg;
  final Color fg;
  final Color mut;
  final Color faint;
  final Color line;
  final Color line2;
  final Color card;
  final Color hover;
  final Color coral;
  final Color coralT;
  final Color onCoral;
  final Color btn;
  final Color onBtn;
  final Color paper;
  final Color paperFg;
  final Color bubble;
  final Color bubbleFg;
  final Color sleeve;
  final Color sleeveFg;
  final Color g1;
  final Color g2;
  final Color rose;
  final Color roseBg;
  final Color shadow;
  final Color scrim;
  final Color panel;
  final Color bar;

  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>() ??
      (throw FlutterError('The ambient Theme carries no AppTokens.'));

  @override
  AppTokens copyWith({
    Color? bg,
    Color? fg,
    Color? mut,
    Color? faint,
    Color? line,
    Color? line2,
    Color? card,
    Color? hover,
    Color? coral,
    Color? coralT,
    Color? onCoral,
    Color? btn,
    Color? onBtn,
    Color? paper,
    Color? paperFg,
    Color? bubble,
    Color? bubbleFg,
    Color? sleeve,
    Color? sleeveFg,
    Color? g1,
    Color? g2,
    Color? rose,
    Color? roseBg,
    Color? shadow,
    Color? scrim,
    Color? panel,
    Color? bar,
  }) {
    return AppTokens(
      bg: bg ?? this.bg,
      fg: fg ?? this.fg,
      mut: mut ?? this.mut,
      faint: faint ?? this.faint,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      card: card ?? this.card,
      hover: hover ?? this.hover,
      coral: coral ?? this.coral,
      coralT: coralT ?? this.coralT,
      onCoral: onCoral ?? this.onCoral,
      btn: btn ?? this.btn,
      onBtn: onBtn ?? this.onBtn,
      paper: paper ?? this.paper,
      paperFg: paperFg ?? this.paperFg,
      bubble: bubble ?? this.bubble,
      bubbleFg: bubbleFg ?? this.bubbleFg,
      sleeve: sleeve ?? this.sleeve,
      sleeveFg: sleeveFg ?? this.sleeveFg,
      g1: g1 ?? this.g1,
      g2: g2 ?? this.g2,
      rose: rose ?? this.rose,
      roseBg: roseBg ?? this.roseBg,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
      panel: panel ?? this.panel,
      bar: bar ?? this.bar,
    );
  }

  @override
  AppTokens lerp(covariant ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) {
      return this;
    }
    return AppTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      fg: Color.lerp(fg, other.fg, t)!,
      mut: Color.lerp(mut, other.mut, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      card: Color.lerp(card, other.card, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      coralT: Color.lerp(coralT, other.coralT, t)!,
      onCoral: Color.lerp(onCoral, other.onCoral, t)!,
      btn: Color.lerp(btn, other.btn, t)!,
      onBtn: Color.lerp(onBtn, other.onBtn, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      paperFg: Color.lerp(paperFg, other.paperFg, t)!,
      bubble: Color.lerp(bubble, other.bubble, t)!,
      bubbleFg: Color.lerp(bubbleFg, other.bubbleFg, t)!,
      sleeve: Color.lerp(sleeve, other.sleeve, t)!,
      sleeveFg: Color.lerp(sleeveFg, other.sleeveFg, t)!,
      g1: Color.lerp(g1, other.g1, t)!,
      g2: Color.lerp(g2, other.g2, t)!,
      rose: Color.lerp(rose, other.rose, t)!,
      roseBg: Color.lerp(roseBg, other.roseBg, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      bar: Color.lerp(bar, other.bar, t)!,
    );
  }
}

abstract final class BrandColors {
  static const closeHover = Color(0xFFC42B1C);
  static const beads = <Color>[
    Color(0xFFF5E5D4),
    Color(0xFFD4A0A0),
    Color(0xFF6FA8DC),
    Color(0xFFE97F6A),
    Color(0xFFFBF0E6),
  ];
  static const players = <Color>[
    Color(0xFFE97F6A),
    Color(0xFF6FA8DC),
    Color(0xFFD4A0A0),
    Color(0xFF9DBF8E),
  ];
  static const birthdayHeader = Color(0xFFE97F6A);
  static const birthdayInk = Color(0xFF1A1514);
  static const letterSignature = Color(0xFFB4533F);
}
