import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/kit/whole_word_text.dart';

import '../large_text.dart';

const double _fontSize = 20;
const String _greeting = 'Good afternoon, Ana.';
const Key _neighbour = ValueKey('neighbour');

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

Widget _inWidth(double width, {String text = _greeting}) => SizedBox(
  width: width,
  child: WholeWordText(text, style: const TextStyle(fontSize: _fontSize)),
);

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text));

double _drawnScale(WidgetTester tester, String text) =>
    tester.getRect(find.text(text)).height /
    _paragraph(tester, text).size.height;

void main() {
  testWidgets("text whose words fit keeps the reader's text size", (
    tester,
  ) async {
    await _pump(tester, _inWidth(500), scale: 2);

    expect(_paragraph(tester, _greeting).textScaler.scale(_fontSize), 40);
    expect(_drawnScale(tester, _greeting), 1);
    expect(brokenWords(tester), isEmpty);
  });

  testWidgets('text at the normal size is left alone', (tester) async {
    await _pump(tester, _inWidth(300));

    expect(_paragraph(tester, _greeting).textScaler.scale(_fontSize), 20);
    expect(_drawnScale(tester, _greeting), 1);
  });

  testWidgets('large text shrinks only until its longest word fits', (
    tester,
  ) async {
    await _pump(tester, _inWidth(300), scale: 2);

    expect(brokenWords(tester), isEmpty);
    expect(_drawnScale(tester, _greeting), moreOrLessEquals(0.75));
    expect(tester.getRect(find.text(_greeting)).width, lessThanOrEqualTo(300));
    expect(tester.getSize(find.byType(WholeWordText)).width, 300);
  });

  testWidgets('a word too long for the column shrinks to fit', (tester) async {
    await _pump(tester, _inWidth(200, text: 'Hi, Bartholomew.'));

    expect(brokenWords(tester), isEmpty);
    expect(_drawnScale(tester, 'Hi, Bartholomew.'), lessThan(1));
    expect(
      tester.getRect(find.text('Hi, Bartholomew.')).width,
      lessThanOrEqualTo(200),
    );
  });

  testWidgets('a column with no width limit leaves the text size alone', (
    tester,
  ) async {
    await _pump(
      tester,
      const SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: WholeWordText.rich(
          TextSpan(text: _greeting),
          style: TextStyle(fontSize: _fontSize),
        ),
      ),
      scale: 2,
    );

    expect(_paragraph(tester, _greeting).textScaler.scale(_fontSize), 40);
    expect(_drawnScale(tester, _greeting), 1);
  });

  testWidgets('rows that size from their content can measure it', (
    tester,
  ) async {
    await _pump(
      tester,
      SizedBox(
        width: 300,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _inWidth(150, text: 'Medium')),
              const Expanded(
                child: ColoredBox(key: _neighbour, color: Colors.black),
              ),
            ],
          ),
        ),
      ),
      scale: 2,
    );

    expect(tester.takeException(), isNull);
    expect(brokenWords(tester), isEmpty);
    expect(
      tester.getSize(find.byKey(_neighbour)).height,
      moreOrLessEquals(tester.getRect(find.text('Medium')).height),
    );
  });

  testWidgets('a tap lands on the shrunken text', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      GestureDetector(onTap: () => taps += 1, child: _inWidth(300)),
      scale: 2,
    );

    await tester.tapAt(tester.getRect(find.text(_greeting)).center);

    expect(taps, 1);
  });
}
