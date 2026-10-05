import 'package:flutter/material.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

abstract final class AppRadii {
  static const double md = 6;
  static const double lg = 8;
  static const double xl = 12;
  static const double xl2 = 16;
}

class CssBoxShadow extends BoxShadow {
  const CssBoxShadow({
    required super.color,
    required super.offset,
    required double blur,
    double spread = 0,
  }) : super(
         blurRadius: blur > 1 ? (blur / 2 - 0.5) / 0.57735 : 0,
         spreadRadius: spread,
       );
}

class CssDropShadow extends Shadow {
  const CssDropShadow({
    required super.color,
    required super.offset,
    required double blur,
  }) : super(blurRadius: blur > 0.5 ? (blur - 0.5) / 0.57735 : 0);
}

abstract final class AppShadows {
  static const _tenPercentBlack = Color.from(
    alpha: 0.1,
    red: 0,
    green: 0,
    blue: 0,
  );

  static const sm = <BoxShadow>[
    CssBoxShadow(color: _tenPercentBlack, offset: Offset(0, 1), blur: 3),
    CssBoxShadow(
      color: _tenPercentBlack,
      offset: Offset(0, 1),
      blur: 2,
      spread: -1,
    ),
  ];

  static const lg = <BoxShadow>[
    CssBoxShadow(
      color: _tenPercentBlack,
      offset: Offset(0, 10),
      blur: 15,
      spread: -3,
    ),
    CssBoxShadow(
      color: _tenPercentBlack,
      offset: Offset(0, 4),
      blur: 6,
      spread: -4,
    ),
  ];

  static const xl = <BoxShadow>[
    CssBoxShadow(
      color: _tenPercentBlack,
      offset: Offset(0, 20),
      blur: 25,
      spread: -5,
    ),
    CssBoxShadow(
      color: _tenPercentBlack,
      offset: Offset(0, 8),
      blur: 10,
      spread: -6,
    ),
  ];

  static const xl2 = <BoxShadow>[
    CssBoxShadow(
      color: Color.from(alpha: 0.25, red: 0, green: 0, blue: 0),
      offset: Offset(0, 25),
      blur: 50,
      spread: -12,
    ),
  ];

  static const drop2xl = <Shadow>[
    CssDropShadow(
      color: Color.from(alpha: 0.15, red: 0, green: 0, blue: 0),
      offset: Offset(0, 25),
      blur: 25,
    ),
  ];

  static List<BoxShadow> hidden(List<BoxShadow> shadows) => List.unmodifiable([
    for (final shadow in shadows)
      BoxShadow(color: shadow.color.withValues(alpha: 0)),
  ]);
}

abstract final class AppText {
  static const trackingTight = -0.025;

  static const xs = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const sm = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const base = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const lg = TextStyle(
    fontSize: 18,
    height: 28 / 18,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const xl = TextStyle(
    fontSize: 20,
    height: 28 / 20,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const xl2 = TextStyle(
    fontSize: 24,
    height: 32 / 24,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const xl3 = TextStyle(
    fontSize: 30,
    height: 36 / 30,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const xl4 = TextStyle(
    fontSize: 36,
    height: 40 / 36,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const xl5 = TextStyle(
    fontSize: 48,
    height: 1,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const h1 = TextStyle(
    fontSize: 36,
    height: 40 / 36,
    fontWeight: FontWeight.w800,
    letterSpacing: 36 * trackingTight,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const h2 = TextStyle(
    fontSize: 30,
    height: 36 / 30,
    fontWeight: FontWeight.w700,
    letterSpacing: 30 * trackingTight,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const h3 = TextStyle(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const h4 = TextStyle(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

extension TailwindTracking on TextStyle {
  TextStyle get trackingTight =>
      copyWith(letterSpacing: fontSize! * AppText.trackingTight);
}

abstract final class ChromiumControlColors {
  static const accent = Color(0xFF0075FF);
  static const hoveredAccent = Color(0xFF005CC8);
  static const pressedAccent = Color(0xFF3793FF);
  static const disabledAccent = Color(0x4D767676);
  static const border = Color(0xFF767676);
  static const hoveredBorder = Color(0xFF4F4F4F);
  static const pressedBorder = Color(0xFF8D8D8D);
  static const disabledBorder = Color(0x4D767676);
  static const fill = Color(0xFFEFEFEF);
  static const disabledFill = Color(0x4DEFEFEF);
  static const background = Color(0xFFFFFFFF);
  static const disabledBackground = Color(0x99FFFFFF);
  static const disabledSlider = Color(0xFFCBCBCB);
  static const sliderTrackBorder = Color(0x80767676);
}

abstract final class AppTheme {
  static final dark = build(AppTokens.dark, Brightness.dark);

  static final light = build(AppTokens.light, Brightness.light);

  static ThemeData build(AppTokens tokens, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.primary,
      onPrimary: tokens.primaryForeground,
      secondary: tokens.muted,
      onSecondary: tokens.foreground,
      error: tokens.destructive,
      onError: AppPalette.white,
      surface: tokens.background,
      onSurface: tokens.foreground,
      onSurfaceVariant: tokens.mutedForeground,
      surfaceContainerHighest: tokens.muted,
      outline: tokens.border,
      outlineVariant: tokens.border,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.background,
      canvasColor: tokens.background,
      cardColor: tokens.card,
      dividerColor: tokens.border,
      textTheme: _textTheme(tokens.foreground),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      sliderTheme: _sliderTheme,
      checkboxTheme: _checkboxTheme,
      extensions: [tokens],
    );
  }

  static TextTheme _textTheme(Color foreground) => TextTheme(
    displayLarge: AppText.xl5.copyWith(color: foreground),
    displayMedium: AppText.xl4.copyWith(color: foreground),
    displaySmall: AppText.xl3.copyWith(color: foreground),
    headlineLarge: AppText.h1.copyWith(color: foreground),
    headlineMedium: AppText.h2.copyWith(color: foreground),
    headlineSmall: AppText.h3.copyWith(color: foreground),
    titleLarge: AppText.h4.copyWith(color: foreground),
    titleMedium: AppText.lg.copyWith(color: foreground),
    titleSmall: AppText.sm.copyWith(
      color: foreground,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: AppText.lg.copyWith(color: foreground),
    bodyMedium: AppText.base.copyWith(color: foreground),
    bodySmall: AppText.sm.copyWith(color: foreground),
    labelLarge: AppText.sm.copyWith(
      color: foreground,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: AppText.xs.copyWith(
      color: foreground,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: AppText.xs.copyWith(color: foreground),
  );

  static final _sliderTheme = SliderThemeData(
    trackHeight: ChromiumSliderTrackShape.thickness,
    activeTrackColor: ChromiumControlColors.accent,
    inactiveTrackColor: ChromiumControlColors.fill,
    disabledActiveTrackColor: ChromiumControlColors.disabledSlider,
    disabledInactiveTrackColor: ChromiumControlColors.disabledFill,
    thumbColor: ChromiumControlColors.accent,
    disabledThumbColor: ChromiumControlColors.disabledSlider,
    overlayColor: Colors.transparent,
    overlayShape: SliderComponentShape.noOverlay,
    trackShape: const ChromiumSliderTrackShape(),
    thumbShape: const ChromiumSliderThumbShape(),
    tickMarkShape: SliderTickMarkShape.noTickMark,
    showValueIndicator: ShowValueIndicator.never,
    mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.basic),
    padding: EdgeInsets.zero,
  );

  static final _checkboxTheme = CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (!states.contains(WidgetState.selected)) {
        return states.contains(WidgetState.disabled)
            ? ChromiumControlColors.disabledBackground
            : ChromiumControlColors.background;
      }
      if (states.contains(WidgetState.disabled)) {
        return ChromiumControlColors.disabledAccent;
      }
      if (states.contains(WidgetState.pressed)) {
        return ChromiumControlColors.pressedAccent;
      }
      if (states.contains(WidgetState.hovered)) {
        return ChromiumControlColors.hoveredAccent;
      }
      return ChromiumControlColors.accent;
    }),
    checkColor: const WidgetStatePropertyAll(ChromiumControlColors.background),
    side: WidgetStateBorderSide.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return BorderSide.none;
      }
      if (states.contains(WidgetState.disabled)) {
        return const BorderSide(color: ChromiumControlColors.disabledBorder);
      }
      if (states.contains(WidgetState.pressed)) {
        return const BorderSide(color: ChromiumControlColors.pressedBorder);
      }
      if (states.contains(WidgetState.hovered)) {
        return const BorderSide(color: ChromiumControlColors.hoveredBorder);
      }
      return const BorderSide(color: ChromiumControlColors.border);
    }),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(2)),
    ),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    splashRadius: 0,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.basic),
  );
}

class ChromiumSliderTrackShape extends SliderTrackShape {
  const ChromiumSliderTrackShape();

  static const double thickness = 8;
  static const double endInset = 1;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final thumbWidth = sliderTheme.thumbShape!
        .getPreferredSize(isEnabled, isDiscrete)
        .width;
    final height = sliderTheme.trackHeight ?? thickness;
    return Rect.fromLTWH(
      offset.dx + thumbWidth / 2,
      offset.dy + (parentBox.size.height - height) / 2,
      parentBox.size.width - thumbWidth,
      height,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final travel = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final track = Rect.fromLTRB(
      offset.dx + endInset,
      travel.top,
      offset.dx + parentBox.size.width - endInset,
      travel.bottom,
    );
    final rounded = RRect.fromRectAndRadius(
      track,
      Radius.circular(track.height / 2),
    );
    final enabled = enableAnimation.value;
    final canvas = context.canvas;

    canvas.drawRRect(
      rounded,
      Paint()
        ..color = Color.lerp(
          sliderTheme.disabledInactiveTrackColor,
          sliderTheme.inactiveTrackColor,
          enabled,
        )!,
    );

    final valueRect = textDirection == TextDirection.ltr
        ? Rect.fromLTRB(track.left, track.top, thumbCenter.dx, track.bottom)
        : Rect.fromLTRB(thumbCenter.dx, track.top, track.right, track.bottom);
    canvas
      ..save()
      ..clipRRect(rounded)
      ..drawRect(
        valueRect,
        Paint()
          ..color = Color.lerp(
            sliderTheme.disabledActiveTrackColor,
            sliderTheme.activeTrackColor,
            enabled,
          )!,
      )
      ..restore();

    canvas.drawRRect(
      rounded.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Color.lerp(
          ChromiumControlColors.disabledBorder,
          ChromiumControlColors.sliderTrackBorder,
          enabled,
        )!,
    );
  }
}

class ChromiumSliderThumbShape extends SliderComponentShape {
  const ChromiumSliderThumbShape();

  static const double diameter = 16;
  static const double borderWidth = 1;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(diameter);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final enabledColor = Color.lerp(
      sliderTheme.thumbColor,
      ChromiumControlColors.pressedAccent,
      activationAnimation.value,
    );
    final fill = Color.lerp(
      sliderTheme.disabledThumbColor,
      enabledColor,
      enableAnimation.value,
    )!;
    context.canvas
      ..drawCircle(
        center,
        diameter / 2,
        Paint()..color = ChromiumControlColors.background,
      )
      ..drawCircle(center, diameter / 2 - borderWidth, Paint()..color = fill);
  }
}
