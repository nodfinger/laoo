import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/theme/workspace_theme_presets.dart';
import '../company_setup/company_setup_controller.dart';

class AutoDismissMessage extends StatefulWidget {
  const AutoDismissMessage({
    super.key,
    required this.message,
    required this.onClose,
    this.error = false,
  });
  final String message;
  final VoidCallback onClose;
  final bool error;
  @override
  State<AutoDismissMessage> createState() => _AutoDismissMessageState();
}

class _AutoDismissMessageState extends State<AutoDismissMessage> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer(
      Duration(seconds: companySetupController.current?.timeAlert ?? 30),
      widget.onClose,
    );
  }

  @override
  void didUpdateWidget(covariant AutoDismissMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message ||
        oldWidget.onClose != widget.onClose) {
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preset = workspaceThemeController.value;
    final color = widget.error ? scheme.error : preset.primary;
    final foreground = widget.error ? scheme.onError : scheme.onPrimary;
    final maxWidth = (MediaQuery.sizeOf(context).width - 24).clamp(
      220.0,
      420.0,
    );
    return Align(
      alignment: Alignment.topRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Card(
          elevation: 8,
          margin: EdgeInsets.zero,
          color: color.withValues(alpha: .50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.error
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  color: foreground,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.message,
                    style: TextStyle(color: foreground),
                  ),
                ),
                IconButton(
                  tooltip: 'ปิด',
                  onPressed: widget.onClose,
                  color: foreground,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
