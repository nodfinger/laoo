import 'package:flutter/widgets.dart';

typedef FiveSWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

FiveSWorkspaceShellBuilder? _workspaceShellBuilder;

void configureFiveSFeatureHost(FiveSWorkspaceShellBuilder builder) {
  _workspaceShellBuilder = builder;
}

Widget buildFiveSWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _workspaceShellBuilder;
  if (builder == null) {
    throw StateError('5S feature host is not configured.');
  }
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}
