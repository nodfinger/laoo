import 'package:flutter/widgets.dart';

typedef ProjectWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

ProjectWorkspaceShellBuilder? _workspaceShellBuilder;

void configureProjectFeatureHost(ProjectWorkspaceShellBuilder builder) =>
    _workspaceShellBuilder = builder;

Widget buildProjectWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _workspaceShellBuilder;
  if (builder == null) {
    throw StateError('Project feature host is not configured.');
  }
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}
