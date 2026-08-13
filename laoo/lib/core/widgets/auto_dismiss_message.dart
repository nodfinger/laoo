import 'dart:async';
import 'package:flutter/material.dart';
import '../company_setup/company_setup_controller.dart';

class AutoDismissMessage extends StatefulWidget {
  const AutoDismissMessage({super.key, required this.message, required this.onClose, this.error = false});
  final String message;
  final VoidCallback onClose;
  final bool error;
  @override State<AutoDismissMessage> createState() => _AutoDismissMessageState();
}

class _AutoDismissMessageState extends State<AutoDismissMessage> {
  Timer? _timer;
  @override void initState() { super.initState(); _start(); }
  void _start() { _timer = Timer(Duration(seconds: companySetupController.current?.timeAlert ?? 30), widget.onClose); }
  @override void dispose() { _timer?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.error ? scheme.error : scheme.primary;
    final foreground = widget.error ? scheme.onError : scheme.onPrimary;
    return Align(
      alignment: Alignment.topRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          elevation: 8,
          margin: EdgeInsets.zero,
          color: color.withValues(alpha: .62),
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
