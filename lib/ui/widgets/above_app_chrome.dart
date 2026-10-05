import 'package:flutter/widgets.dart';

class AboveAppChrome extends StatefulWidget {
  const AboveAppChrome({super.key, required this.child});

  final Widget child;

  @override
  State<AboveAppChrome> createState() => _AboveAppChromeState();
}

class _AboveAppChromeState extends State<AboveAppChrome> {
  final OverlayPortalController _portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _portal.show();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: (context) => widget.child,
  );
}
