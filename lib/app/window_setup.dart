import 'dart:ui';

import 'package:window_manager/window_manager.dart';

const WindowOptions windowOptions = WindowOptions(
  size: Size(1024, 800),
  minimumSize: Size(686, 571),
  center: true,
  title: 'Swiftie Quiz',
);

Future<void> setUpWindow() async {
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(windowOptions);
  await windowManager.show();
  await windowManager.focus();
}
