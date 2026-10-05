import 'dart:io';

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
  title: 'Swiftie Quiz',
);

const Brightness launchBrightness = Brightness.dark;

const MethodChannel windowChromeChannel = MethodChannel(
  'swiftie_quiz/window_chrome',
);

Future<void> matchMacWindowChrome(
  Brightness brightness,
  Color background,
) async {
  if (!Platform.isMacOS) {
    return;
  }
  await windowChromeChannel.invokeMethod<void>('match', {
    'dark': brightness == Brightness.dark,
    'background': background.toARGB32(),
  });
}

Future<void> applyWindowChrome(WindowChrome chrome, Brightness brightness) =>
    chrome(brightness, switch (brightness) {
      Brightness.dark => AppTokens.dark.background,
      Brightness.light => AppTokens.light.background,
    });

Future<void> setUpWindow({WindowChrome chrome = matchMacWindowChrome}) async {
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(windowOptions);
  await applyWindowChrome(chrome, launchBrightness);
  await windowManager.show();
  await windowManager.focus();
}
