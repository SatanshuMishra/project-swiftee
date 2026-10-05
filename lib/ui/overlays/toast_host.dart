import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/state/toast_controller.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';

class ToastHost extends ConsumerWidget {
  const ToastHost({super.key});

  static const double bottomInset = 24;
  static const double maxWidthFraction = 0.5;
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  );
  static const Color background = AppPalette.emerald600;
  static const Color foreground = AppPalette.white;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(toastControllerProvider);
    if (message == null) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * maxWidthFraction,
            ),
            child: _Toast(
              message: message,
              onDismiss: () =>
                  ref.read(toastControllerProvider.notifier).dismiss(),
            ),
          ),
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      role: SemanticsRole.status,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: ToastHost.padding,
              decoration: const BoxDecoration(
                color: ToastHost.background,
                borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
                boxShadow: AppShadows.lg,
              ),
              child: Text(
                message,
                style: AppText.sm.copyWith(color: ToastHost.foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
