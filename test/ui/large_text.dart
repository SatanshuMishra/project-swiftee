import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

const double largestTextScale = 2.25;

const List<Size> largeTextWindows = [
  Size(686, 571),
  Size(900, 700),
  Size(1024, 768),
  Size(1199, 800),
  Size(1200, 800),
];

Future<void> loadRealFonts() async {
  final sdk = Platform.environment['FLUTTER_ROOT'];
  if (sdk == null) {
    fail('FLUTTER_ROOT is not set, so the Roboto test font cannot be found');
  }
  final sdkFonts = '$sdk/bin/cache/artifacts/material_fonts';
  await Future.wait([
    _load(AppType.serifFamily, const [
      'assets/fonts/InstrumentSerif-Regular.ttf',
      'assets/fonts/InstrumentSerif-Italic.ttf',
    ]),
    _load('Roboto', [
      '$sdkFonts/Roboto-Regular.ttf',
      '$sdkFonts/Roboto-Italic.ttf',
      '$sdkFonts/Roboto-Medium.ttf',
      '$sdkFonts/Roboto-Bold.ttf',
    ]),
  ]);
}

Future<void> _load(String family, List<String> paths) {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
    );
  }
  return loader.load();
}

void useLargeText(WidgetTester tester, Size window) {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = largestTextScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<List<String>> layoutFaults(
  WidgetTester tester,
  Future<void> Function() pump,
) async {
  final previous = FlutterError.onError;
  var reported = const <String>[];
  FlutterError.onError = (details) =>
      reported = [...reported, _describe(details)];
  try {
    await pump();
  } finally {
    FlutterError.onError = previous;
  }
  return [...reported, ...brokenWords(tester)];
}

List<String> brokenWords(WidgetTester tester) => [
  for (final paragraph in tester.allRenderObjects.whereType<RenderParagraph>())
    if (_breaksAWord(paragraph))
      'breaks a word: "${paragraph.text.toPlainText()}" needs '
          '${paragraph.getMinIntrinsicWidth(double.infinity).ceil()} px '
          'in ${paragraph.constraints.maxWidth.floor()} px',
];

bool _breaksAWord(RenderParagraph paragraph) =>
    paragraph.hasSize &&
    paragraph.attached &&
    paragraph.softWrap &&
    paragraph.maxLines != 1 &&
    paragraph.constraints.hasBoundedWidth &&
    paragraph.getMinIntrinsicWidth(double.infinity) >
        paragraph.constraints.maxWidth + 0.5;

String _describe(FlutterErrorDetails details) {
  final lines = details.toString().split('\n');
  final widget = lines.indexWhere(
    (line) => line.contains('relevant error-causing widget'),
  );
  final where = widget >= 0 && widget + 2 < lines.length
      ? ' at ${lines[widget + 2].trim()}'
      : '';
  return '${details.exceptionAsString().split('\n').first}$where';
}
