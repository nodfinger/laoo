import 'package:flutter/widgets.dart';

typedef GatePassWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

GatePassWorkspaceShellBuilder? _workspaceShellBuilder;

void configureGatePassFeatureHost(GatePassWorkspaceShellBuilder builder) {
  _workspaceShellBuilder = builder;
}

Widget buildGatePassWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _workspaceShellBuilder;
  if (builder == null) {
    throw StateError('Gate Pass feature host is not configured.');
  }
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}
