import 'package:flutter/material.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/swiftie_modal.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

const String confirmDialogCancelLabel = 'Cancel';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final answer = await showGeneralDialog<bool>(
    context: context,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) {
      final route = ModalRoute.of(context);
      return ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        destructive: destructive,
        onAnswer: (answer) {
          if (route?.isCurrent ?? false) {
            Navigator.of(context).pop(answer);
          }
        },
      );
    },
  );
  return answer ?? false;
}

class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onAnswer,
    this.destructive = false,
  });

  static const double maxWidth = 440;
  static const double gap = 10;
  static const double actionsTop = 12;

  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return SwiftieModal(
      maxWidth: maxWidth,
      onDismiss: () => onAnswer(false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppType.display(30, height: 34 / 30, color: tokens.fg),
          ),
          const SizedBox(height: gap),
          Text(message, style: AppType.body.copyWith(color: tokens.mut)),
          const SizedBox(height: gap + actionsTop),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PillButton(
                label: confirmDialogCancelLabel,
                kind: PillKind.quiet,
                onPressed: () => onAnswer(false),
              ),
              const SizedBox(width: gap),
              PillButton(
                label: confirmLabel,
                kind: destructive ? PillKind.danger : PillKind.coral,
                onPressed: () => onAnswer(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
