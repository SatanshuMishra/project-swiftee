import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/kit/whole_word_text.dart';

import '../large_text.dart';

const double _fontSize = 20;

Future<RenderParagraph> _pump(
  WidgetTester tester, {
  required String text,
  required double width,
  double scale = 1,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: WholeWordText(
            text,
            style: const TextStyle(fontSize: _fontSize),
          ),
        ),
      ),
    ),
  );
  return tester.renderObject<RenderParagraph>(find.text(text));
}

void main() {
  testWidgets("text whose words fit keeps the reader's text size", (
    tester,
  ) async {
    final paragraph = await _pump(
      tester,
      text: 'Good afternoon, Ana.',
      width: 500,
      scale: 2,
    );

    expect(paragraph.textScaler.scale(_fontSize), 40);
    expect(brokenWords(tester), isEmpty);
  });

  testWidgets('text at the normal size is left alone', (tester) async {
    final paragraph = await _pump(
      tester,
      text: 'Good afternoon, Ana.',
      width: 300,
    );

    expect(paragraph.textScaler.scale(_fontSize), _fontSize);
  });

  testWidgets('large text shrinks only until its longest word fits', (
    tester,
  ) async {
    final paragraph = await _pump(
      tester,
      text: 'Good afternoon, Ana.',
      width: 300,
      scale: 2,
    );

    expect(brokenWords(tester), isEmpty);
    expect(paragraph.textScaler.scale(_fontSize), 30);
    expect(paragraph.size.width, lessThanOrEqualTo(300));
  });

  testWidgets('a word too long for the column shrinks below the normal size', (
    tester,
  ) async {
    final paragraph = await _pump(tester, text: 'Hi, Bartholomew.', width: 200);

    expect(brokenWords(tester), isEmpty);
    expect(paragraph.textScaler.scale(_fontSize), lessThan(_fontSize));
  });

  testWidgets('a column with no width limit leaves the text size alone', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      const MaterialApp(
        home: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: WholeWordText.rich(
            TextSpan(text: 'Good afternoon, Ana.'),
            style: TextStyle(fontSize: _fontSize),
          ),
        ),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('Good afternoon, Ana.'),
    );
    expect(paragraph.textScaler.scale(_fontSize), 40);
  });
}
