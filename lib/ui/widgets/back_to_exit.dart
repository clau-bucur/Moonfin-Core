import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../util/app_exit.dart';

/// Shared by Home and the root router so duplicate dispatch of one Back press
/// cannot accidentally close the app.
class BackExitController {
  BackExitController({DateTime Function()? now}) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  static const window = Duration(seconds: 2);
  DateTime? _armedAt;

  bool press() {
    final now = _now();
    final elapsed = _armedAt == null ? null : now.difference(_armedAt!);
    if (elapsed != null && elapsed < const Duration(milliseconds: 150))
      return false;
    if (elapsed != null && elapsed <= window) {
      reset();
      return true;
    }
    _armedAt = now;
    return false;
  }

  void reset() => _armedAt = null;
}

final _backExit = BackExitController();
OverlayEntry? _toast;
Timer? _toastTimer;

Future<void> requestBackToExit(BuildContext context) async {
  if (_backExit.press()) {
    _removeToast();
    await AppExit.closeApp();
    return;
  }
  if (_toast != null) return;
  final overlay =
      Overlay.maybeOf(context, rootOverlay: true) ??
      Navigator.maybeOf(context, rootNavigator: true)?.overlay;
  if (overlay == null) return;
  final label = AppLocalizations.of(context).pressBackAgainToExit;
  _toast = OverlayEntry(
    builder: (_) => Positioned(
      bottom: 64,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: Center(
          child: Material(
            color: const Color(0xE6222222),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(_toast!);
  _toastTimer = Timer(BackExitController.window, () {
    _removeToast();
    _backExit.reset();
  });
}

void resetBackToExit() {
  _backExit.reset();
  _removeToast();
}

void _removeToast() {
  _toastTimer?.cancel();
  _toastTimer = null;
  _toast?.remove();
  _toast?.dispose();
  _toast = null;
}
