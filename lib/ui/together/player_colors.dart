import 'package:flutter/widgets.dart';

const List<Color> playerColors = [
  Color(0xFFE97F6A),
  Color(0xFF6FA8DC),
  Color(0xFFD4A0A0),
  Color(0xFF9DBF8E),
];

Color playerColor({required bool viewer, required int joinIndex}) => viewer
    ? playerColors.first
    : playerColors[1 + joinIndex % (playerColors.length - 1)];
