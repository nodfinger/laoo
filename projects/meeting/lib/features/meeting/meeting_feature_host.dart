import 'package:flutter/widgets.dart';

import '../support/presentation/widgets/support_workspace_shell.dart';

typedef MeetingWorkspaceShellBuilder = Widget Function({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
});

MeetingWorkspaceShellBuilder _workspaceShellBuilder = _defaultWorkspaceShell;

void configureMeetingFeatureHost(MeetingWorkspaceShellBuilder builder) {
  _workspaceShellBuilder = builder;
}

Widget buildMeetingWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  return _workspaceShellBuilder(
    pageTitle: pageTitle,
    activeMenu: activeMenu,
    child: child,
  );
}

Widget _defaultWorkspaceShell({
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
