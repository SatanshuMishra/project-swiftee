import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:window_manager/window_manager.dart';

typedef WindowChrome = Future<void> Function(
  Brightness brightness,
  Color background,
);

const WindowOptions windowOptions = WindowOptions(
  size: Size(1024, 800),
  minimumSize: Size(686, 571),
  center: true,
  title: 'Project Swiftie',
  titleBarStyle: TitleBarStyle.hidden,
);

const Brightness launchBrightness = Brightness.dark;

const MethodChannel windowChromeChannel = MethodChannel(
  'swiftie_quiz/window_chrome',
);

Future<void> matchMacWindowChrome(
  Brightness brightness,
  Color background,
) async {
  if (defaultTargetPlatform != TargetPlatform.macOS) {
    return;
  }
  try {
    await windowChromeChannel.invokeMethod<void>('match', {
      'dark': brightness == Brightness.dark,
      'background': background.toARGB32(),
    });
  } on PlatformException catch (error, stackTrace) {
    _logChromeFailure(error, stackTrace);
  } on MissingPluginException catch (error, stackTrace) {
    _logChromeFailure(error, stackTrace);
  }
}

void _logChromeFailure(Object error, StackTrace stackTrace) => developer.log(
  'The window chrome could not follow the theme',
  name: 'swiftie_quiz.window',
  error: error,
  stackTrace: stackTrace,
);

Future<void> applyWindowChrome(WindowChrome chrome, Brightness brightness) =>
    chrome(brightness, switch (brightness) {
      Brightness.dark => AppTokens.dark.bg,
      Brightness.light => AppTokens.light.bg,
    });

Future<void> keepTitleBarOnScreen() async {
  final bounds = await windowManager.getBounds();
  final topOfScreen = await calcWindowPosition(
    bounds.size,
    Alignment.topCenter,
  );
  if (bounds.top < topOfScreen.dy) {
    await windowManager.setPosition(Offset(bounds.left, topOfScreen.dy));
  }
}

Future<void> setUpWindow({WindowChrome chrome = matchMacWindowChrome}) async {
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(windowOptions);
  await keepTitleBarOnScreen();
  await applyWindowChrome(chrome, launchBrightness);
  await windowManager.show();
  await windowManager.focus();
}
