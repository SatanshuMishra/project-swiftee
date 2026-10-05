import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:swiftie_quiz/data/save/save_error.dart';

const String appIdentifier = 'com.swiftiequiz.desktop';
const String saveFileName = 'save.json';

String saveFilePath({
  required bool isMacOS,
  required Map<String, String> environment,
}) => isMacOS
    ? p.posix.join(
        _requireVariable(environment, 'HOME'),
        'Library',
        'Application Support',
        appIdentifier,
        saveFileName,
      )
    : p.windows.join(
        _requireVariable(environment, 'APPDATA'),
        appIdentifier,
        saveFileName,
      );

String defaultSaveFilePath() =>
    saveFilePath(isMacOS: Platform.isMacOS, environment: Platform.environment);

String _requireVariable(Map<String, String> environment, String name) =>
    switch (environment[name]) {
      final String value when value.isNotEmpty => value,
      _ => throw SaveFileError('$name is not set'),
    };
