import 'package:flutter/material.dart';

import 'auto_dismiss_message.dart';

final Map<OverlayState, OverlayEntry> _topRightAlerts = {};

/// Shows every application message at the top-right of the root overlay.
void showTimedSnackBar(
  BuildContext context, {
  required String message,
  bool error = false,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _topRightAlerts.remove(overlay)?.remove();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: 16,
      right: 16,
      child: SafeArea(
        child: AutoDismissMessage(
          message: message,
          error: error,
          onClose: () {
            if (identical(_topRightAlerts[overlay], entry)) {
              _topRightAlerts.remove(overlay);
            }
            entry.remove();
          },
        ),
      ),
    ),
  );
  _topRightAlerts[overlay] = entry;
  overlay.insert(entry);
}
