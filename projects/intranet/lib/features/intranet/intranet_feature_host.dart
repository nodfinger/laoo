import 'package:flutter/widgets.dart';

typedef IntranetWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

IntranetWorkspaceShellBuilder? _workspaceShellBuilder;

void configureIntranetFeatureHost(IntranetWorkspaceShellBuilder builder) =>
    _workspaceShellBuilder = builder;

Widget buildIntranetWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _workspaceShellBuilder;
  if (builder == null) {
    throw StateError('Intranet feature host is not configured.');
  }
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}
