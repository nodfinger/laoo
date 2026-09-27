import 'package:flutter/material.dart';

import '../widgets/support_workspace_shell.dart';

class SupportPlaceholderPage extends StatelessWidget {
  const SupportPlaceholderPage({
    super.key,
    required this.title,
    required this.activeMenu,
  });

  final String title;
  final String activeMenu;

  @override
  Widget build(BuildContext context) {
    return SupportWorkspaceShell(
      pageTitle: title,
      activeMenu: activeMenu,
      child: Center(
        child: Text(
          '$title อยู่ในแผนพัฒนา Phase 1',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
