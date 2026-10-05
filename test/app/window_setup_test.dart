import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/app/window_setup.dart';

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
  List<String> calls = const [];

  Future<Object?> handle(MethodCall call) async {
    calls = [...calls, call.method];
    final args = call.arguments is Map
        ? (call.arguments as Map).cast<String, Object?>()
        : const <String, Object?>{};
    switch (call.method) {
      case 'isFullScreen' || 'isMaximized' || 'isMinimized':
        return false;
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
      default:
        return true;
    }
  }
}

Future<Object?> _screen(MethodCall call) async => switch (call.method) {
  'getPrimaryDisplay' => _display,
  'getAllDisplays' => {
    'displays': [_display],
  },
  'getCursorScreenPoint' => {'dx': 400.0, 'dy': 300.0},
  _ => null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeWindow window;

  setUp(() {
    window = _FakeWindow();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger
      ..setMockMethodCallHandler(_windowChannel, window.handle)
      ..setMockMethodCallHandler(_screenChannel, _screen);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(_windowChannel, null)
      ..setMockMethodCallHandler(_screenChannel, null);
  });

  group('window matches the Tauri window', () {
    test('the options are the tauri.conf.json main window', () {
      const options = windowOptions;

      expect(options.size, const Size(1024, 800));
      expect(options.minimumSize, const Size(686, 571));
      expect(options.center, isTrue);
      expect(options.title, 'Swiftie Quiz');
      expect(options.maximumSize, isNull);
      expect(options.alwaysOnTop, isNull);
      expect(options.fullScreen, isNull);
      expect(options.backgroundColor, isNull);
      expect(options.skipTaskbar, isNull);
      expect(options.titleBarStyle, isNull);
      expect(options.windowButtonVisibility, isNull);
    });

    test('setUpWindow sizes, centres, limits and titles the window before showing it', () async {
      await setUpWindow();

      expect(window.bounds, const Rect.fromLTWH(352, 177.5, 1024, 800));
      expect(window.minimumSize, const Size(686, 571));
      expect(window.title, 'Swiftie Quiz');
      expect(window.calls.first, 'ensureInitialized');
      expect(window.calls, contains('waitUntilReadyToShow'));
      expect(window.calls.sublist(window.calls.length - 2), ['show', 'focus']);
      expect(
        window.calls.lastIndexOf('setBounds'),
        lessThan(window.calls.indexOf('show')),
      );
      expect(
        window.calls.indexOf('setMinimumSize'),
        lessThan(window.calls.indexOf('show')),
      );
      expect(
        window.calls.indexOf('setTitle'),
        lessThan(window.calls.indexOf('show')),
      );
    });
  });
}
