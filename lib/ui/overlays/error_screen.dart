import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/primary_button.dart';

void restartAppWidgetTree() {
  final root = WidgetsBinding.instance.rootElement?.widget;
  final view = root is RootWidget ? root.child : null;
  if (view is! View) {
    return;
  }
  final current = view.child;
  final app = current is _RestartedApp ? current.child : current;
  runApp(_RestartedApp(key: UniqueKey(), child: app));
}

class _RestartedApp extends StatelessWidget {
  const _RestartedApp({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({
    super.key,
    required this.error,
    this.onRestart = restartAppWidgetTree,
  });

  static const String title = 'Something went wrong';
  static const String fallbackMessage = 'An unexpected error occurred.';
  static const String restartLabel = 'Restart';
  static const double padding = 32;
  static const double gap = 16;

  final Object? error;
  final VoidCallback onRestart;

  static String messageOf(Object? error) => switch (error) {
    null => fallbackMessage,
    ProviderException(:final exception) => messageOf(exception),
    FlutterError(:final diagnostics, :final message) =>
      diagnostics.whereType<ErrorSummary>().firstOrNull?.toString() ?? message,
    _ => '$error',
  };

  @override
  Widget build(BuildContext context) {
    final screen = Directionality(
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      child: Builder(builder: _buildScreen),
    );
    if (Theme.of(context).extension<AppTokens>() != null) {
      return screen;
    }
    return Theme(
      data: AppTheme.dark,
      child: Shortcuts(
        shortcuts: WidgetsApp.defaultShortcuts,
        child: Actions(
          actions: WidgetsApp.defaultActions,
          child: FocusScope(autofocus: true, child: screen),
        ),
      ),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final tokens = AppTokens.of(context);
    final viewport = MediaQuery.maybeSizeOf(context) ?? Size.zero;
    return Material(
      color: tokens.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : viewport.width,
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : viewport.height,
            ),
            child: Padding(
              padding: const EdgeInsets.all(padding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: gap,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: AppText.xl2
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.destructive,
                          )
                          .trackingTight,
                    ),
                  ),
                  Text(
                    messageOf(error),
                    textAlign: TextAlign.center,
                    style: AppText.sm.copyWith(color: tokens.mutedForeground),
                  ),
                  PrimaryButton(
                    label: restartLabel,
                    variant: PrimaryButtonVariant.restart,
                    onPressed: onRestart,
                  ),
                ],
              ),
            ),
          );
          return constraints.hasBoundedHeight
              ? SingleChildScrollView(child: content)
              : content;
        },
      ),
    );
  }
}
