import 'package:flutter/widgets.dart';
import 'package:swiftie_quiz/ui/cat/cat_icon.dart';

class CatIconButton extends StatelessWidget {
  const CatIconButton({super.key, required this.onTap, this.size = 44});

  static const String semanticsLabel = 'Open birthday card';
  static const double minHitSize = 44;

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: semanticsLabel,
    child: FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: _activate),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
          onInvoke: _activate,
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: minHitSize,
            minHeight: minHitSize,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: CatIcon(height: size),
          ),
        ),
      ),
    ),
  );

  Object? _activate(Intent intent) {
    onTap();
    return null;
  }
}
