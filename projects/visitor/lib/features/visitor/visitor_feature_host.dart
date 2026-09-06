import 'package:flutter/widgets.dart';

typedef VisitorWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

VisitorWorkspaceShellBuilder? _workspaceShellBuilder;

void configureVisitorFeatureHost(VisitorWorkspaceShellBuilder builder) {
  _workspaceShellBuilder = builder;
}

Widget buildVisitorWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _workspaceShellBuilder;
  if (builder == null) {
    throw StateError('Visitor feature host is not configured.');
  }
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}
