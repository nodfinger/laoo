import 'package:flutter/material.dart';
import 'package:laoo_meeting/meeting_feature.dart';

import 'app/laoo_app.dart';
import 'features/support/presentation/widgets/support_workspace_shell.dart';

void main() {
  configureMeetingFeatureHost(_buildMeetingWorkspaceShell);
  runApp(const LaooApp());
}

Widget _buildMeetingWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  return SupportWorkspaceShell(
    menuScope: WorkspaceMenuScope.company,
    pageTitle: pageTitle,
    activeMenu: activeMenu,
    child: child,
  );
}
