import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/workspace_theme_presets.dart';
import '../company_setup/company_setup_controller.dart';

void showTimedSnackBar(
  BuildContext context, {
  required String message,
  bool error = false,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final scheme = Theme.of(context).colorScheme;
  final preset = workspaceThemeController.value;
  final color = error ? scheme.error : preset.primary;
  final foreground = error ? scheme.onError : scheme.onPrimary;
  late final OverlayEntry entry;
  Timer? timer;

  void close() {
    timer?.cancel();
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: 12,
      right: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 8,
          color: color.withValues(alpha: .50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  error ? Icons.error_outline : Icons.check_circle_outline,
                  color: foreground,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(message, style: TextStyle(color: foreground)),
                ),
                IconButton(
                  tooltip: 'ปิด',
                  onPressed: close,
                  color: foreground,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  timer = Timer(
    Duration(seconds: companySetupController.current?.timeAlert ?? 30),
    close,
  );
}

void legacyShowTimedSnackBar(
  BuildContext context, {
  required String message,
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = Theme.of(context).colorScheme;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: Duration(
          seconds: companySetupController.current?.timeAlert ?? 30,
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? scheme.error : null,
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.info_outline,
              color: error ? scheme.onError : scheme.onInverseSurface,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        action: SnackBarAction(
          label: 'ปิด',
          textColor: error ? scheme.onError : null,
          onPressed: messenger.hideCurrentSnackBar,
        ),
      ),
    );
}
