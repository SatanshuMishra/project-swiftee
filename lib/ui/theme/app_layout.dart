import 'package:flutter/widgets.dart';

enum WidthClass { narrow, regular, large }

@immutable
final class AppLayout {
  const AppLayout._({
    required this.widthClass,
    required this.padX,
    required this.h1,
    required this.rowTitle,
    required this.leftColumn,
    required this.gap,
    required this.sleeve,
    required this.eraColumns,
    required this.releaseColumns,
    required this.shelfColumns,
  });

  factory AppLayout.forWidth(double width) {
    if (width < regularFrom) {
      return narrow;
    }
    if (width >= largeFrom) {
      return large;
    }
    return regular;
  }

  static AppLayout of(BuildContext context) =>
      AppLayout.forWidth(MediaQuery.sizeOf(context).width);

  static const double regularFrom = 900;
  static const double largeFrom = 1200;

  static const narrow = AppLayout._(
    widthClass: WidthClass.narrow,
    padX: 32,
    h1: 44,
    rowTitle: 30,
    leftColumn: 250,
    gap: 28,
    sleeve: 200,
    eraColumns: 3,
    releaseColumns: 3,
    shelfColumns: 3,
  );

  static const regular = AppLayout._(
    widthClass: WidthClass.regular,
    padX: 56,
    h1: 56,
    rowTitle: 38,
    leftColumn: 380,
    gap: 56,
    sleeve: 270,
    eraColumns: 4,
    releaseColumns: 5,
    shelfColumns: 5,
  );

  static const large = AppLayout._(
    widthClass: WidthClass.large,
    padX: 72,
    h1: 64,
    rowTitle: 38,
    leftColumn: 460,
    gap: 56,
    sleeve: 320,
    eraColumns: 6,
    releaseColumns: 7,
    shelfColumns: 5,
  );

  final WidthClass widthClass;
  final double padX;
  final double h1;
  final double rowTitle;
  final double leftColumn;
  final double gap;
  final double sleeve;
  final int eraColumns;
  final int releaseColumns;
  final int shelfColumns;

  bool get isNarrow => widthClass == WidthClass.narrow;

  static int columnsForText(
    int columns,
    TextScaler scaler, {
    required double fontSize,
  }) => (columns * fontSize / scaler.scale(fontSize)).round().clamp(1, columns);

  @override
  bool operator ==(Object other) =>
      other is AppLayout &&
      other.widthClass == widthClass &&
      other.padX == padX &&
      other.h1 == h1 &&
      other.rowTitle == rowTitle &&
      other.leftColumn == leftColumn &&
      other.gap == gap &&
      other.sleeve == sleeve &&
      other.eraColumns == eraColumns &&
      other.releaseColumns == releaseColumns &&
      other.shelfColumns == shelfColumns;

  @override
  int get hashCode => Object.hash(
    widthClass,
    padX,
    h1,
    rowTitle,
    leftColumn,
    gap,
    sleeve,
    eraColumns,
    releaseColumns,
    shelfColumns,
  );
}
