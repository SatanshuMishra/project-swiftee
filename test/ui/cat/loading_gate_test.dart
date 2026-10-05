import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/cat/loading_gate.dart';

Widget host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(data: const MediaQueryData(), child: child),
);

Widget gate({
  required bool loading,
  String? label,
  CatLoaderSize size = CatLoaderSize.lg,
  VoidCallback? onReady,
}) => host(
  LoadingGate(
    loading: loading,
    label: label,
    size: size,
    onReady: onReady,
    child: const Text('Content'),
  ),
);

double loaderOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(of: find.byType(CatLoader), matching: find.byType(Opacity)),
    )
    .opacity;

double loaderScale(WidgetTester tester) => tester
    .widget<Transform>(
      find.ancestor(
        of: find.byType(CatLoader),
        matching: find.byType(Transform),
      ),
    )
    .transform
    .storage[0];

void main() {
  group('loading gate parity', () {
    testWidgets('shows CatLoader when loading is true', (tester) async {
      await tester.pumpWidget(gate(loading: true));

      expect(find.byType(CatLoader), findsOneWidget);
      expect(find.text('Content'), findsNothing);
    });

    testWidgets('shows children when loading is false', (tester) async {
      await tester.pumpWidget(gate(loading: false));

      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(CatLoader), findsNothing);
    });

    testWidgets('passes label to CatLoader', (tester) async {
      await tester.pumpWidget(gate(loading: true, label: 'Loading...'));

      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('accepts onReady callback without crashing', (tester) async {
      var ready = 0;
      await tester.pumpWidget(gate(loading: false, onReady: () => ready++));

      await tester.pumpWidget(host(const SizedBox()));

      expect(tester.takeException(), isNull);
      expect(ready, 0);
    });

    testWidgets('passes size to CatLoader', (tester) async {
      await tester.pumpWidget(gate(loading: true, size: CatLoaderSize.sm));

      expect(
        tester.widget<CatLoader>(find.byType(CatLoader)).size,
        CatLoaderSize.sm,
      );
    });

    testWidgets('the loader fades in over 300 ms', (tester) async {
      await tester.pumpWidget(gate(loading: true));

      expect(loaderOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 150));
      expect(loaderOpacity(tester), closeTo(0.5, 0.01));
      await tester.pump(const Duration(milliseconds: 150));
      expect(loaderOpacity(tester), 1);
      expect(loaderScale(tester), 1);
    });

    testWidgets(
      'when loading ends the loader fades out to scale 0.95, then the content '
      'shows and onReady fires once',
      (tester) async {
        var ready = 0;
        await tester.pumpWidget(gate(loading: true, onReady: () => ready++));
        await tester.pump(const Duration(milliseconds: 300));

        await tester.pumpWidget(gate(loading: false, onReady: () => ready++));
        await tester.pump(const Duration(milliseconds: 150));

        expect(find.text('Content'), findsNothing);
        expect(loaderOpacity(tester), closeTo(0.5, 0.01));
        expect(loaderScale(tester), closeTo(0.975, 0.001));
        expect(ready, 0);

        await tester.pump(const Duration(milliseconds: 151));
        await tester.pump();

        expect(find.byType(CatLoader), findsNothing);
        expect(find.text('Content'), findsOneWidget);
        expect(ready, 1);

        await tester.pump(const Duration(seconds: 1));
        expect(ready, 1);
      },
    );

    testWidgets('the exit reaches scale 0.95 at zero opacity', (tester) async {
      await tester.pumpWidget(gate(loading: true));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(gate(loading: false));
      await tester.pump(const Duration(milliseconds: 299));

      expect(loaderOpacity(tester), lessThan(0.001));
      expect(loaderScale(tester), closeTo(0.95, 0.001));
    });

    testWidgets('loading again during the exit keeps the loader', (
      tester,
    ) async {
      var ready = 0;
      await tester.pumpWidget(gate(loading: true, onReady: () => ready++));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(gate(loading: false, onReady: () => ready++));
      await tester.pump(const Duration(milliseconds: 150));

      await tester.pumpWidget(gate(loading: true, onReady: () => ready++));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Content'), findsNothing);
      expect(loaderOpacity(tester), 1);
      expect(loaderScale(tester), 1);
      expect(ready, 0);
    });

    testWidgets('loading again after the content shows hides it at once', (
      tester,
    ) async {
      await tester.pumpWidget(gate(loading: false));
      expect(find.text('Content'), findsOneWidget);

      await tester.pumpWidget(gate(loading: true));

      expect(find.text('Content'), findsNothing);
      expect(find.byType(CatLoader), findsOneWidget);
      expect(loaderOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 300));
      expect(loaderOpacity(tester), 1);
    });

    testWidgets('the latest onReady is the one called', (tester) async {
      var first = 0;
      var latest = 0;
      await tester.pumpWidget(gate(loading: true, onReady: () => first++));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(gate(loading: false, onReady: () => first++));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(gate(loading: false, onReady: () => latest++));
      await tester.pump(const Duration(milliseconds: 201));
      await tester.pump();

      expect(first, 0);
      expect(latest, 1);
    });
  });
}
