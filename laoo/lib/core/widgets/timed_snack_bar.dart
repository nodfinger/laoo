import 'package:flutter/material.dart';

import '../company_setup/company_setup_controller.dart';

void showTimedSnackBar(
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
