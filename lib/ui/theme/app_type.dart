import 'package:flutter/painting.dart';

abstract final class AppType {
  static const String serifFamily = 'Instrument Serif';

  static TextStyle display(
    double size, {
    bool italic = false,
    double? height,
    Color? color,
  }) => TextStyle(
    fontFamily: serifFamily,
    fontSize: size,
    fontWeight: FontWeight.w400,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    height: height,
    color: color,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const sectionLabel = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const body = TextStyle(
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const bodyLarge = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const small = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const caption = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static TextStyle sized(
    double size,
    double lineHeight, {
    FontWeight? weight,
  }) => TextStyle(
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight ?? FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
}
