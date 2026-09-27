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
  final previousEntry = _topRightAlerts.remove(overlay);
  if (previousEntry?.mounted == true) {
    previousEntry!.remove();
  }

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
            // A newer alert may already have replaced and removed this entry.
            // In that case the old timer must not remove the stale entry again.
            if (!identical(_topRightAlerts[overlay], entry)) return;
            _topRightAlerts.remove(overlay);
            if (entry.mounted) entry.remove();
          },
        ),
      ),
    ),
  );
  _topRightAlerts[overlay] = entry;
  overlay.insert(entry);
}
