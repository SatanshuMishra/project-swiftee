import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/services/window/window_controls.dart';
import 'package:swiftie_quiz/ui/chrome/caption_buttons.dart';
import 'package:swiftie_quiz/ui/overlays/update_badge.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

final titleBarPlatformProvider = Provider<TargetPlatform>(
  (ref) => defaultTargetPlatform,
);

enum TitleBarLayout {
  mac(
    height: 28,
    titleSize: 13,
    badge: UpdateBadgeSize.mac,
    badgeMargin: EdgeInsets.only(right: 10),
    drawsWindowFrame: false,
  ),
  windows(
    height: 32,
    titleSize: 12,
    fontFamily: 'Segoe UI Variable Text',
    fontFamilyFallback: ['Segoe UI'],
    badge: UpdateBadgeSize.windows,
    badgeMargin: EdgeInsets.only(right: 8),
    drawsWindowFrame: true,
  );

  const TitleBarLayout({
    required this.height,
    required this.titleSize,
    this.fontFamily,
    this.fontFamilyFallback,
    required this.badge,
    required this.badgeMargin,
    required this.drawsWindowFrame,
  });

  final double height;
  final double titleSize;
  final String? fontFamily;
  final List<String>? fontFamilyFallback;
  final UpdateBadgeSize badge;
  final EdgeInsets badgeMargin;
  final bool drawsWindowFrame;

  static TitleBarLayout of(TargetPlatform platform) =>
      platform == TargetPlatform.windows ? windows : mac;
}

class AppTitleBar extends ConsumerWidget {
  const AppTitleBar({super.key});

  static const String title = 'Project Swiftie';
  static const double titleLineHeight = 16;
  static const double titleOpacity = 0.8;
  static const double resizeEdge = 4;
  static const double resizeCorner = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = TitleBarLayout.of(ref.watch(titleBarPlatformProvider));
    final controls = ref.watch(windowControlsProvider);
    if (!layout.drawsWindowFrame) {
      return _TitleBarContent(
        layout: layout,
        controls: controls,
        maximized: false,
      );
    }
    return _WindowMaximized(
      controls: controls,
      builder: (context, maximized) => _TitleBarContent(
        layout: layout,
        controls: controls,
        maximized: maximized,
      ),
    );
  }
}

class _TitleBarContent extends StatelessWidget {
  const _TitleBarContent({
    required this.layout,
    required this.controls,
    required this.maximized,
  });

  final TitleBarLayout layout;
  final WindowControls controls;
  final bool maximized;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return SizedBox(
      height: layout.height,
      child: ColoredBox(
        color: tokens.bg,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontFamily: layout.fontFamily,
            fontFamilyFallback: layout.fontFamilyFallback,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _WindowDragArea(
                controls: controls,
                child: Center(
                  child: Text(
                    AppTitleBar.title,
                    maxLines: 1,
                    softWrap: false,
                    style:
                        AppType.sized(
                          layout.titleSize,
                          AppTitleBar.titleLineHeight,
                          weight: FontWeight.w600,
                        ).copyWith(
                          color: tokens.fg.withValues(
                            alpha: tokens.fg.a * AppTitleBar.titleOpacity,
                          ),
                        ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UpdateBadge(size: layout.badge, margin: layout.badgeMargin),
                    if (layout.drawsWindowFrame)
                      CaptionButtons(
                        controls: controls,
                        height: layout.height,
                        maximized: maximized,
                      ),
                  ],
                ),
              ),
              if (layout.drawsWindowFrame && !maximized)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: AppTitleBar.resizeEdge,
                  child: _TopResizeEdge(controls: controls),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowDragArea extends StatelessWidget {
  const _WindowDragArea({required this.controls, required this.child});

  final WindowControls controls;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    excludeFromSemantics: true,
    onPanStart: (_) => unawaited(controls.startDragging()),
    onDoubleTap: () => unawaited(controls.toggleMaximize()),
    child: child,
  );
}

class _TopResizeEdge extends StatelessWidget {
  const _TopResizeEdge({required this.controls});

  final WindowControls controls;

  Widget _handle(WindowEdge edge, MouseCursor cursor) => MouseRegion(
    cursor: cursor,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onPanStart: (_) => unawaited(controls.startResizing(edge)),
    ),
  );

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        width: AppTitleBar.resizeCorner,
        child: _handle(WindowEdge.topLeft, SystemMouseCursors.resizeUpLeft),
      ),
      Expanded(child: _handle(WindowEdge.top, SystemMouseCursors.resizeUp)),
      SizedBox(
        width: AppTitleBar.resizeCorner,
        child: _handle(WindowEdge.topRight, SystemMouseCursors.resizeUpRight),
      ),
    ],
  );
}

class _WindowMaximized extends StatefulWidget {
  const _WindowMaximized({required this.controls, required this.builder});

  final WindowControls controls;
  final Widget Function(BuildContext context, bool maximized) builder;

  @override
  State<_WindowMaximized> createState() => _WindowMaximizedState();
}

class _WindowMaximizedState extends State<_WindowMaximized> {
  bool _maximized = false;
  StreamSubscription<bool>? _changes;

  @override
  void initState() {
    super.initState();
    _follow(widget.controls);
  }

  @override
  void didUpdateWidget(_WindowMaximized oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controls, widget.controls)) {
      unawaited(_changes?.cancel());
      _follow(widget.controls);
    }
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  void _follow(WindowControls controls) {
    var heard = false;
    _changes = controls.maximizedChanges.listen((maximized) {
      heard = true;
      _show(maximized);
    });
    unawaited(
      controls.isMaximized().then((maximized) {
        if (!heard && mounted && identical(controls, widget.controls)) {
          _show(maximized);
        }
      }),
    );
  }

  void _show(bool maximized) {
    if (mounted && maximized != _maximized) {
      setState(() => _maximized = maximized);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _maximized);
}
