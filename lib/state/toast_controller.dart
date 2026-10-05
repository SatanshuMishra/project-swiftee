import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final toastControllerProvider = NotifierProvider<ToastController, String?>(
  ToastController.new,
);

class ToastController extends Notifier<String?> {
  static const Duration displayDuration = Duration(seconds: 5);

  Timer? _expiry;

  @override
  String? build() {
    ref.onDispose(_cancelExpiry);
    return null;
  }

  void show(String message) {
    _cancelExpiry();
    state = message;
    _expiry = Timer(displayDuration, dismiss);
  }

  void dismiss() {
    _cancelExpiry();
    state = null;
  }

  void _cancelExpiry() {
    _expiry?.cancel();
    _expiry = null;
  }
}
