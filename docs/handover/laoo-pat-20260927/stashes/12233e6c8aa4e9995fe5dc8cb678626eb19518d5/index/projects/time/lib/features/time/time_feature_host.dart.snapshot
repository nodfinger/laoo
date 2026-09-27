import 'package:flutter/widgets.dart';

typedef TimeWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

TimeWorkspaceShellBuilder? _workspaceShellBuilder;

void configureTimeFeatureHost(TimeWorkspaceShellBuilder builder) {
  _workspaceShellBuilder = builder;
}

Widget buildTimeWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _workspaceShellBuilder;
  if (builder == null) {
    throw StateError('Time feature host is not configured.');
  }
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}
