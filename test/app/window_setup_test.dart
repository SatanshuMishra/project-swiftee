import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/app/window_setup.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/services/window/window_controls.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:window_manager/window_manager.dart';

const MethodChannel _windowChannel = MethodChannel('window_manager');
const MethodChannel _screenChannel = MethodChannel(
  'dev.leanflutter.plugins/screen_retriever',
);

const Map<String, Object?> _display = {
  'id': '1',
  'name': 'Built-in Retina Display',
  'size': {'width': 1728.0, 'height': 1117.0},
  'visiblePosition': {'dx': 0.0, 'dy': 38.0},
  'visibleSize': {'width': 1728.0, 'height': 1079.0},
  'scaleFactor': 2,
};

final class _FakeWindow {
  Rect bounds = const Rect.fromLTWH(0, 0, 800, 600);
  Size? minimumSize;
  String? title;
  String? titleBarStyle;
  bool maximized = false;
  Map<String, Object?> resizing = const {};
  List<String> calls = const [];

  Future<Object?> handle(MethodCall call) async {
    calls = [...calls, call.method];
    final args = call.arguments is Map
        ? (call.arguments as Map).cast<String, Object?>()
        : const <String, Object?>{};
    switch (call.method) {
      case 'isFullScreen' || 'isMinimized':
        return false;
      case 'isMaximized':
        return maximized;
      case 'maximize':
        maximized = true;
        return null;
      case 'unmaximize':
        maximized = false;
        return null;
      case 'startResizing':
        resizing = args;
        return true;
      case 'getBounds':
        return {
          'x': bounds.left,
          'y': bounds.top,
          'width': bounds.width,
          'height': bounds.height,
        };
      case 'setBounds':
        final x = (args['x'] as num?)?.toDouble() ?? bounds.left;
        final y = (args['y'] as num?)?.toDouble() ?? bounds.top;
        final width = (args['width'] as num?)?.toDouble() ?? bounds.width;
        final height = (args['height'] as num?)?.toDouble() ?? bounds.height;
        bounds = Rect.fromLTWH(x, y, width, height);
        return null;
      case 'setMinimumSize':
        minimumSize = Size(
          (args['width']! as num).toDouble(),
          (args['height']! as num).toDouble(),
        );
        return null;
      case 'setTitle':
        title = args['title']! as String;
        return null;
      case 'setTitleBarStyle':
        titleBarStyle = args['titleBarStyle']! as String;
        return null;
      default:
        return true;
    }
  }
}

const Map<String, Object?> _shortLaptopDisplay = {
  'id': '2',
  'name': '1920 by 1080 at 150 percent',
  'size': {'width': 1280.0, 'height': 720.0},
  'visiblePosition': {'dx': 0.0, 'dy': 0.0},
  'visibleSize': {'width': 1280.0, 'height': 672.0},
  'scaleFactor': 1.5,
};

Future<Object?> Function(MethodCall) _screenWith(
  Map<String, Object?> display,
) =>
    (call) async => switch (call.method) {
      'getPrimaryDisplay' => display,
      'getAllDisplays' => {
        'displays': [display],
      },
      'getCursorScreenPoint' => {'dx': 400.0, 'dy': 300.0},
      _ => null,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeWindow window;
  late List<MethodCall> chromeCalls;

  setUp(() {
    window = _FakeWindow();
    chromeCalls = const [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger
      ..setMockMethodCallHandler(_windowChannel, window.handle)
      ..setMockMethodCallHandler(_screenChannel, _screenWith(_display))
      ..setMockMethodCallHandler(windowChromeChannel, (call) async {
        chromeCalls = [...chromeCalls, call];
        return null;
      });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(_windowChannel, null)
      ..setMockMethodCallHandler(_screenChannel, null)
      ..setMockMethodCallHandler(windowChromeChannel, null);
  });

  group('window opens as Project Swiftie', () {
    test('the window opens as project swiftie with a hidden title bar', () {
      const options = windowOptions;

      expect(options.title, 'Project Swiftie');
      expect(options.size, const Size(1024, 800));
      expect(options.minimumSize, const Size(686, 571));
      expect(options.center, isTrue);
      expect(options.titleBarStyle, TitleBarStyle.hidden);
      expect(options.windowButtonVisibility, isNull);
      expect(options.maximumSize, isNull);
      expect(options.alwaysOnTop, isNull);
      expect(options.fullScreen, isNull);
      expect(options.backgroundColor, isNull);
      expect(options.skipTaskbar, isNull);
    });

    test('setUpWindow hides the title bar, sizes, centres, limits and titles '
        'the window before showing it', () async {
      await setUpWindow();

      expect(window.titleBarStyle, 'hidden');
      expect(window.bounds, const Rect.fromLTWH(352, 177.5, 1024, 800));
      expect(window.minimumSize, const Size(686, 571));
      expect(window.title, 'Project Swiftie');
      expect(window.calls.first, 'ensureInitialized');
      expect(window.calls, contains('waitUntilReadyToShow'));
      expect(window.calls.sublist(window.calls.length - 2), ['show', 'focus']);
      for (final call in ['setTitleBarStyle', 'setMinimumSize', 'setTitle']) {
        expect(
          window.calls.indexOf(call),
          lessThan(window.calls.indexOf('show')),
          reason: call,
        );
      }
      expect(
        window.calls.lastIndexOf('setBounds'),
        lessThan(window.calls.indexOf('show')),
      );
    });
  });

  group('the window controls drive window_manager', () {
    Future<void> windowEvent(String name) async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            _windowChannel.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('onEvent', {'eventName': name}),
            ),
            (_) {},
          );
      await pumpEventQueue();
    }

    test('minimise, close, drag and resize reach the window', () async {
      final controls = WindowManagerControls(windowManager);

      await controls.minimize();
      await controls.close();
      await controls.startDragging();
      await controls.startResizing(WindowEdge.topLeft);

      expect(window.calls, [
        'minimize',
        'close',
        'startDragging',
        'startResizing',
      ]);
      expect(window.resizing, {
        'resizeEdge': 'topLeft',
        'top': true,
        'bottom': false,
        'right': false,
        'left': true,
      });
    });

    test('each top edge resizes from its own side', () async {
      final controls = WindowManagerControls(windowManager);
      var edges = const <String>[];
      for (final edge in WindowEdge.values) {
        await controls.startResizing(edge);
        edges = [...edges, window.resizing['resizeEdge']! as String];
      }

      expect(edges, ['top', 'topLeft', 'topRight']);
    });

    test('toggling maximises a restored window and restores a maximised '
        'one', () async {
      final controls = WindowManagerControls(windowManager);

      await controls.toggleMaximize();
      expect(window.calls, ['isMaximized', 'maximize']);
      expect(await controls.isMaximized(), isTrue);

      await controls.toggleMaximize();
      expect(window.calls.sublist(3), ['isMaximized', 'unmaximize']);
      expect(await controls.isMaximized(), isFalse);
    });

    test('maximise events reach the stream until it is cancelled', () async {
      final controls = WindowManagerControls(windowManager);
      var seen = const <bool>[];
      expect(windowManager.hasListeners, isFalse);

      final subscription = controls.maximizedChanges.listen(
        (maximized) => seen = [...seen, maximized],
      );
      expect(windowManager.hasListeners, isTrue);
      await windowEvent('maximize');
      await windowEvent('focus');
      await windowEvent('unmaximize');
      expect(seen, [true, false]);

      await subscription.cancel();
      expect(windowManager.hasListeners, isFalse);
      await windowEvent('maximize');
      expect(seen, [true, false]);
    });
  });

  group('the title bar stays on screen like Tauri', () {
    test('a screen shorter than the window keeps the title bar at the top of '
        'its usable area', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            _screenChannel,
            _screenWith(_shortLaptopDisplay),
          );

      await setUpWindow();

      expect(window.bounds, const Rect.fromLTWH(128, 0, 1024, 800));
      expect(
        window.calls.lastIndexOf('setBounds'),
        lessThan(window.calls.indexOf('show')),
      );
    });

    test(
      'a screen tall enough for the window keeps the window centred',
      () async {
        await setUpWindow();

        expect(window.bounds.top, 177.5);
      },
    );
  });

  group('window chrome matches the app background', () {
    test('the window opens with the chrome of the default theme', () async {
      var order = const <String>[];
      await setUpWindow(
        chrome: (brightness, background) async {
          order = [
            ...window.calls,
            'chrome ${brightness.name} ${background.toARGB32()}',
          ];
        },
      );

      expect(defaultProgress.settings.theme, ThemeSetting.dark);
      expect(launchBrightness, Brightness.dark);
      expect(order.last, 'chrome dark ${AppTokens.dark.bg.toARGB32()}');
      expect(order, isNot(contains('show')));
      expect(window.calls.sublist(window.calls.length - 2), ['show', 'focus']);
    });

    test('each brightness uses the bg token of its theme', () async {
      var applied = const <(Brightness, Color)>[];
      Future<void> record(Brightness brightness, Color background) async {
        applied = [...applied, (brightness, background)];
      }

      await applyWindowChrome(record, Brightness.dark);
      await applyWindowChrome(record, Brightness.light);

      expect(applied, [
        (Brightness.dark, AppTokens.dark.bg),
        (Brightness.light, AppTokens.light.bg),
      ]);
    });

    test('the mac chrome reaches the runner over its channel', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      await matchMacWindowChrome(Brightness.light, AppTokens.light.bg);
      await matchMacWindowChrome(Brightness.dark, AppTokens.dark.bg);

      expect(chromeCalls.map((call) => call.method), ['match', 'match']);
      expect(chromeCalls.map((call) => call.arguments), [
        {'dark': false, 'background': 0xFFFAF7F2},
        {'dark': true, 'background': 0xFF1A1514},
      ]);
    });

    test('other platforms leave the window chrome alone', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      await matchMacWindowChrome(Brightness.light, AppTokens.light.bg);

      expect(chromeCalls, isEmpty);
    });

    test('a failing runner never stops the window from showing', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            windowChromeChannel,
            (call) async => throw PlatformException(code: 'failed'),
          );

      await setUpWindow();

      expect(window.calls.sublist(window.calls.length - 2), ['show', 'focus']);
    });

    test(
      'a runner without the channel never stops the window from showing',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(windowChromeChannel, null);

        await setUpWindow();

        expect(window.calls.sublist(window.calls.length - 2), [
          'show',
          'focus',
        ]);
      },
    );
  });
}
