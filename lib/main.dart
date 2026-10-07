import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/app/app.dart';
import 'package:swiftie_quiz/app/window_setup.dart';
import 'package:swiftie_quiz/services/network/bundled_roots.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorHandlers(renderFailures);
  await trustBundledRootsOnWindows(rootBundle);
  await setUpWindow();
  runApp(const ProviderScope(child: SwiftieQuizApp()));
}
