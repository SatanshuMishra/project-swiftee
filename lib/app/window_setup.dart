import 'dart:developer' as developer;
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:window_manager/window_manager.dart';

typedef WindowChrome = Future<void> Function(
  Brightness brightness,
  Color background,
);

const Size preferredWindowSize = Size(1024, 800);

const Size minimumWindowSize = Size(686, 571);

const WindowOptions windowOptions = WindowOptions(
  size: preferredWindowSize,
  minimumSize: minimumWindowSize,
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

Rect workAreaOf(Display display) => Rect.fromLTWH(
  display.visiblePosition?.dx ?? 0,
  display.visiblePosition?.dy ?? 0,
  display.visibleSize?.width ?? display.size.width,
  display.visibleSize?.height ?? display.size.height,
);

Rect launchWorkArea(List<Display> displays, Offset cursor, Display primary) =>
    displays
        .map(workAreaOf)
        .firstWhereOrNull((area) => area.contains(cursor)) ??
    workAreaOf(primary);

Rect launchWindowBounds(Rect workArea) {
  final size = Size(
    max(
      minimumWindowSize.width,
      min(preferredWindowSize.width, workArea.width),
    ),
    max(
      minimumWindowSize.height,
      min(preferredWindowSize.height, workArea.height),
    ),
  );
  return Rect.fromLTWH(
    workArea.left + max(0, (workArea.width - size.width) / 2),
    workArea.top + max(0, (workArea.height - size.height) / 2),
    size.width,
    size.height,
  );
}

Future<void> fitWindowToWorkArea() async {
  final workArea = launchWorkArea(
    await screenRetriever.getAllDisplays(),
    await screenRetriever.getCursorScreenPoint(),
    await screenRetriever.getPrimaryDisplay(),
  );
  await windowManager.setBounds(launchWindowBounds(workArea));
}

Future<void> setUpWindow({WindowChrome chrome = matchMacWindowChrome}) async {
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(windowOptions);
  await fitWindowToWorkArea();
  await applyWindowChrome(chrome, launchBrightness);
  await windowManager.show();
  await windowManager.focus();
}
