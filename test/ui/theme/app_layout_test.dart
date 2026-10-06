import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';

typedef Metrics = ({
  double padX,
  double h1,
  double rowTitle,
  double leftColumn,
  double gap,
  double sleeve,
  int eraColumns,
  int shelfColumns,
});

const Map<WidthClass, Metrics> handoff = {
  WidthClass.narrow: (
    padX: 32,
    h1: 44,
    rowTitle: 30,
    leftColumn: 250,
    gap: 28,
    sleeve: 200,
    eraColumns: 3,
    shelfColumns: 3,
  ),
  WidthClass.regular: (
    padX: 56,
    h1: 56,
    rowTitle: 38,
    leftColumn: 380,
    gap: 56,
    sleeve: 270,
    eraColumns: 4,
    shelfColumns: 5,
  ),
  WidthClass.large: (
    padX: 72,
    h1: 64,
    rowTitle: 38,
    leftColumn: 460,
    gap: 56,
    sleeve: 320,
    eraColumns: 6,
    shelfColumns: 5,
  ),
};

Metrics metricsOf(AppLayout layout) => (
  padX: layout.padX,
  h1: layout.h1,
  rowTitle: layout.rowTitle,
  leftColumn: layout.leftColumn,
  gap: layout.gap,
  sleeve: layout.sleeve,
  eraColumns: layout.eraColumns,
  shelfColumns: layout.shelfColumns,
);

void main() {
  test('layout metrics follow the three width classes', () {
    const widths = [
      (686.0, WidthClass.narrow),
      (899.0, WidthClass.narrow),
      (900.0, WidthClass.regular),
      (1024.0, WidthClass.regular),
      (1199.0, WidthClass.regular),
      (1280.0, WidthClass.large),
    ];
    for (final (width, widthClass) in widths) {
      final layout = AppLayout.forWidth(width);
      expect(layout.widthClass, widthClass, reason: '$width');
      expect(metricsOf(layout), handoff[widthClass], reason: '$width');
    }
  });

  testWidgets('AppLayout.of reads the window width', (tester) async {
    for (final (size, widthClass) in [
      (const Size(686, 571), WidthClass.narrow),
      (const Size(1024, 800), WidthClass.regular),
      (const Size(1280, 900), WidthClass.large),
    ]) {
      late AppLayout seen;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: Builder(
            builder: (context) {
              seen = AppLayout.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen.widthClass, widthClass, reason: '$size');
      expect(seen, AppLayout.forWidth(size.width), reason: '$size');
    }
  });
}
