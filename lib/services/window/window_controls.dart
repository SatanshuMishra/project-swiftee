import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

enum WindowEdge {
  top(ResizeEdge.top),
  topLeft(ResizeEdge.topLeft),
  topRight(ResizeEdge.topRight);

  const WindowEdge(this._resizeEdge);

  final ResizeEdge _resizeEdge;
}

abstract interface class WindowControls {
  Future<void> minimize();
  Future<void> toggleMaximize();
  Future<void> close();
  Future<bool> isMaximized();
  Future<void> startDragging();
  Future<void> startResizing(WindowEdge edge);
  Stream<bool> get maximizedChanges;
}

final class WindowManagerControls implements WindowControls {
  const WindowManagerControls(this._window);

  final WindowManager _window;

  @override
  Future<void> minimize() => _window.minimize();

  @override
  Future<void> toggleMaximize() async {
    if (await _window.isMaximized()) {
      await _window.unmaximize();
    } else {
      await _window.maximize();
    }
  }

  @override
  Future<void> close() => _window.close();

  @override
  Future<bool> isMaximized() => _window.isMaximized();

  @override
  Future<void> startDragging() => _window.startDragging();

  @override
  Future<void> startResizing(WindowEdge edge) =>
      _window.startResizing(edge._resizeEdge);

  @override
  Stream<bool> get maximizedChanges {
    late final StreamController<bool> changes;
    final listener = _MaximizeListener((maximized) => changes.add(maximized));
    changes = StreamController<bool>(
      onListen: () => _window.addListener(listener),
      onCancel: () => _window.removeListener(listener),
    );
    return changes.stream;
  }
}

final class _MaximizeListener with WindowListener {
  _MaximizeListener(this._changed);

  final void Function(bool maximized) _changed;

  @override
  void onWindowMaximize() => _changed(true);

  @override
  void onWindowUnmaximize() => _changed(false);
}

final windowControlsProvider = Provider<WindowControls>(
  (ref) => WindowManagerControls(windowManager),
);
