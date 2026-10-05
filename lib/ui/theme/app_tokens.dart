import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.background,
    required this.foreground,
    required this.card,
    required this.muted,
    required this.mutedForeground,
    required this.border,
    required this.primary,
    required this.primaryForeground,
    required this.destructive,
    required this.correct,
    required this.incorrect,
  });

  static const dark = AppTokens(
    background: Color(0xFF0A0A0A),
    foreground: Color(0xFFFAFAFA),
    card: Color(0xFF121212),
    muted: Color(0xFF262626),
    mutedForeground: Color(0xFFA1A1A1),
    border: Color(0xFF262626),
    primary: Color(0xFFFAFAFA),
    primaryForeground: Color(0xFF171717),
    destructive: Color(0xFFEF4444),
    correct: Color(0xFF22C55E),
    incorrect: Color(0xFFEF4444),
  );

  static const light = AppTokens(
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF030213),
    card: Color(0xFFFFFFFF),
    muted: Color(0xFFECECF0),
    mutedForeground: Color(0xFF717182),
    border: Color.from(alpha: 0.1, red: 0, green: 0, blue: 0),
    primary: Color(0xFF030213),
    primaryForeground: Color(0xFFFFFFFF),
    destructive: Color(0xFFDC2626),
    correct: Color(0xFF16A34A),
    incorrect: Color(0xFFDC2626),
  );

  final Color background;
  final Color foreground;
  final Color card;
  final Color muted;
  final Color mutedForeground;
  final Color border;
  final Color primary;
  final Color primaryForeground;
  final Color destructive;
  final Color correct;
  final Color incorrect;

  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>() ??
      (throw FlutterError('The ambient Theme carries no AppTokens.'));

  @override
  AppTokens copyWith({
    Color? background,
    Color? foreground,
    Color? card,
    Color? muted,
    Color? mutedForeground,
    Color? border,
    Color? primary,
    Color? primaryForeground,
    Color? destructive,
    Color? correct,
    Color? incorrect,
  }) {
    return AppTokens(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      card: card ?? this.card,
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      destructive: destructive ?? this.destructive,
      correct: correct ?? this.correct,
      incorrect: incorrect ?? this.incorrect,
    );
  }

  @override
  AppTokens lerp(covariant ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) {
      return this;
    }
    return AppTokens(
      background: Color.lerp(background, other.background, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      card: Color.lerp(card, other.card, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryForeground: Color.lerp(
        primaryForeground,
        other.primaryForeground,
        t,
      )!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      correct: Color.lerp(correct, other.correct, t)!,
      incorrect: Color.lerp(incorrect, other.incorrect, t)!,
    );
  }
}

extension TailwindOpacity on Color {
  Color slashOpacity(int percent) => withValues(alpha: a * percent / 100);
}

typedef OklabCoordinates = ({double lightness, double a, double b});

abstract final class Oklab {
  static const _linearSrgbToXyz = [
    [506752 / 1228815, 87881 / 245763, 12673 / 70218],
    [87098 / 409605, 175762 / 245763, 12673 / 175545],
    [7918 / 409605, 87881 / 737289, 1001167 / 1053270],
  ];
  static const _xyzToLms = [
    [0.8190224379967030, 0.3619062600528904, -0.1288737815209879],
    [0.0329836539323885, 0.9292868615863434, 0.0361446663506424],
    [0.0481771893596242, 0.2642395317527308, 0.6335478284694309],
  ];
  static const _lmsToOklab = [
    [0.2104542683093140, 0.7936177747023054, -0.0040720430116193],
    [1.9779985324311684, -2.4285922420485799, 0.4505937096174110],
    [0.0259040424655478, 0.7827717124575296, -0.8086757549230774],
  ];
  static const _oklabToLms = [
    [1.0, 0.3963377773761749, 0.2158037573099136],
    [1.0, -0.1055613458156586, -0.0638541728258133],
    [1.0, -0.0894841775298119, -1.2914855480194092],
  ];
  static const _lmsToXyz = [
    [1.2268798758459243, -0.5578149944602171, 0.2813910456659647],
    [-0.0405757452148008, 1.1122868032803170, -0.0717110580655164],
    [-0.0763729366746601, -0.4214933324022432, 1.5869240198367816],
  ];
  static const _xyzToLinearSrgb = [
    [12831 / 3959, -329 / 214, -1974 / 3959],
    [-851781 / 878810, 1648619 / 878810, 36519 / 878810],
    [705 / 12673, -2585 / 12673, 705 / 667],
  ];

  static Color fromOklch(
    double lightness,
    double chroma,
    double hueDegrees, {
    double alpha = 1,
  }) {
    final hue = hueDegrees * math.pi / 180;
    return fromOklab((
      lightness: lightness,
      a: chroma * math.cos(hue),
      b: chroma * math.sin(hue),
    ), alpha: alpha);
  }

  static Color fromOklab(OklabCoordinates lab, {double alpha = 1}) {
    final lms = _multiply(_oklabToLms, [
      lab.lightness,
      lab.a,
      lab.b,
    ]).map((channel) => channel * channel * channel).toList();
    final rgb = _multiply(
      _xyzToLinearSrgb,
      _multiply(_lmsToXyz, lms),
    ).map(_encode).toList();
    return Color.fromARGB(
      _toByte(alpha),
      _toByte(rgb[0]),
      _toByte(rgb[1]),
      _toByte(rgb[2]),
    );
  }

  static OklabCoordinates toOklab(Color color) {
    final linear = [color.r, color.g, color.b].map(_decode).toList();
    final lms = _multiply(
      _xyzToLms,
      _multiply(_linearSrgbToXyz, linear),
    ).map(_cubeRoot).toList();
    final lab = _multiply(_lmsToOklab, lms);
    return (lightness: lab[0], a: lab[1], b: lab[2]);
  }

  static Color mix(Color from, Color to, double t) {
    if (t <= 0) {
      return from;
    }
    if (t >= 1) {
      return to;
    }
    final alpha = from.a + (to.a - from.a) * t;
    if (alpha <= 0) {
      return const Color(0x00000000);
    }
    final start = toOklab(from);
    final end = toOklab(to);
    double channel(double startValue, double endValue) =>
        (startValue * from.a + (endValue * to.a - startValue * from.a) * t) /
        alpha;
    return fromOklab((
      lightness: channel(start.lightness, end.lightness),
      a: channel(start.a, end.a),
      b: channel(start.b, end.b),
    ), alpha: alpha);
  }

  static (List<Color>, List<double>) sampleStops(
    List<Color> colors,
    List<double> stops,
    int samplesPerSegment,
  ) {
    final sampledColors = <Color>[];
    final sampledStops = <double>[];
    for (var segment = 0; segment < colors.length - 1; segment++) {
      for (var sample = 0; sample < samplesPerSegment; sample++) {
        final t = sample / samplesPerSegment;
        sampledColors.add(mix(colors[segment], colors[segment + 1], t));
        sampledStops.add(
          stops[segment] + (stops[segment + 1] - stops[segment]) * t,
        );
      }
    }
    return (
      List.unmodifiable([...sampledColors, colors.last]),
      List.unmodifiable([...sampledStops, stops.last]),
    );
  }

  static List<double> _multiply(List<List<double>> matrix, List<double> v) => [
    for (final row in matrix) row[0] * v[0] + row[1] * v[1] + row[2] * v[2],
  ];

  static double _decode(double channel) {
    final magnitude = channel.abs();
    if (magnitude <= 0.04045) {
      return channel / 12.92;
    }
    return channel.sign * math.pow((magnitude + 0.055) / 1.055, 2.4);
  }

  static double _encode(double channel) {
    final magnitude = channel.abs();
    if (magnitude <= 0.0031308) {
      return channel * 12.92;
    }
    return channel.sign * (1.055 * math.pow(magnitude, 1 / 2.4) - 0.055);
  }

  static double _cubeRoot(double value) =>
      value.sign * math.pow(value.abs(), 1 / 3).toDouble();

  static int _toByte(double channel) => (channel.clamp(0.0, 1.0) * 255).round();
}

abstract final class AppPalette {
  static const brand = Color(0xFFE97F6A);
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  static const red200 = Color(0xFFFFC9C9);
  static const red400 = Color(0xFFFF6467);
  static const red500 = Color(0xFFFB2C36);
  static const green400 = Color(0xFF05DF72);
  static const green500 = Color(0xFF00C950);
  static const orange400 = Color(0xFFFF8904);
  static const orange500 = Color(0xFFFF6900);
  static const purple400 = Color(0xFFC27AFF);
  static const purple500 = Color(0xFFAD46FF);
  static const violet600 = Color(0xFF7F22FE);
  static const violet700 = Color(0xFF7008E7);
  static const blue600 = Color(0xFF155DFC);
  static const emerald600 = Color(0xFF009966);
  static const yellow200 = Color(0xFFFFF085);
  static const yellow500 = Color(0xFFF0B100);
  static const yellow600 = Color(0xFFD08700);
  static const pink500 = Color(0xFFF6339A);
}

enum ColorInterpolation { srgb, oklab }

@immutable
final class CssGradientDirection {
  const CssGradientDirection.angle(double this.degrees);

  const CssGradientDirection.toBottomRight() : degrees = null;

  static const toRight = CssGradientDirection.angle(90);
  static const diagonal = CssGradientDirection.angle(135);

  final double? degrees;

  (Offset, Offset) endpoints(Rect rect) {
    final diagonalLength = math.sqrt(
      rect.width * rect.width + rect.height * rect.height,
    );
    final angle = degrees;
    final Offset direction;
    if (angle != null) {
      final radians = angle * math.pi / 180;
      direction = Offset(math.sin(radians), -math.cos(radians));
    } else if (diagonalLength == 0) {
      direction = const Offset(math.sqrt1_2, math.sqrt1_2);
    } else {
      direction = Offset(
        rect.height / diagonalLength,
        rect.width / diagonalLength,
      );
    }
    final length =
        (rect.width * direction.dx).abs() + (rect.height * direction.dy).abs();
    final half = direction * (length / 2);
    return (rect.center - half, rect.center + half);
  }

  @override
  bool operator ==(Object other) =>
      other is CssGradientDirection && other.degrees == degrees;

  @override
  int get hashCode => degrees.hashCode;
}

@immutable
class CssLinearGradient extends Gradient {
  const CssLinearGradient({
    required this.direction,
    required super.colors,
    super.stops,
    this.interpolation = ColorInterpolation.srgb,
  }) : assert(colors.length >= 2);

  static const oklabSamplesPerSegment = 16;

  final CssGradientDirection direction;
  final ColorInterpolation interpolation;

  List<double> get resolvedStops =>
      stops ??
      List.unmodifiable([
        for (var index = 0; index < colors.length; index++)
          index / (colors.length - 1),
      ]);

  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) {
    final (start, end) = direction.endpoints(rect);
    final (shaderColors, shaderStops) = switch (interpolation) {
      ColorInterpolation.srgb => (colors, resolvedStops),
      ColorInterpolation.oklab => Oklab.sampleStops(
        colors,
        resolvedStops,
        oklabSamplesPerSegment,
      ),
    };
    return ui.Gradient.linear(start, end, shaderColors, shaderStops);
  }

  @override
  CssLinearGradient scale(double factor) => CssLinearGradient(
    direction: direction,
    colors: List.unmodifiable([
      for (final color in colors) Color.lerp(null, color, factor)!,
    ]),
    stops: stops,
    interpolation: interpolation,
  );

  @override
  CssLinearGradient withOpacity(double opacity) => CssLinearGradient(
    direction: direction,
    colors: List.unmodifiable([
      for (final color in colors) color.withValues(alpha: opacity),
    ]),
    stops: stops,
    interpolation: interpolation,
  );

  @override
  bool operator ==(Object other) =>
      other is CssLinearGradient &&
      other.direction == direction &&
      other.interpolation == interpolation &&
      listEquals(other.colors, colors) &&
      listEquals(other.stops, stops);

  @override
  int get hashCode => Object.hash(
    direction,
    interpolation,
    Object.hashAll(colors),
    Object.hashAll(stops ?? const <double>[]),
  );
}

@immutable
class GradientPair {
  const GradientPair(this.from, this.to);

  final Color from;
  final Color to;

  CssLinearGradient get diagonal =>
      linear(CssGradientDirection.diagonal, ColorInterpolation.srgb);

  CssLinearGradient tailwind(CssGradientDirection direction) =>
      linear(direction, ColorInterpolation.oklab);

  CssLinearGradient linear(
    CssGradientDirection direction,
    ColorInterpolation interpolation,
  ) => CssLinearGradient(
    direction: direction,
    colors: List.unmodifiable([from, to]),
    interpolation: interpolation,
  );

  @override
  bool operator ==(Object other) =>
      other is GradientPair && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

abstract final class AppGradients {
  static const violet = GradientPair(Color(0xFF8B5CF6), Color(0xFF6366F1));
  static const pink = GradientPair(Color(0xFFEC4899), Color(0xFFF43F5E));
  static const orange = GradientPair(Color(0xFFF97316), Color(0xFFEAB308));
  static const cyan = GradientPair(Color(0xFF06B6D4), Color(0xFF3B82F6));
  static const green = GradientPair(Color(0xFF22C55E), Color(0xFF16A34A));

  static const easy = GradientPair(Color(0xFF22C55E), Color(0xFF16A34A));
  static const medium = GradientPair(Color(0xFFF97316), Color(0xFFEA580C));
  static const hard = GradientPair(Color(0xFFEF4444), Color(0xFFDC2626));

  static const play = GradientPair(AppPalette.purple500, AppPalette.pink500);
}
