import 'package:flutter/widgets.dart';

typedef SalesWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
SalesWorkspaceShellBuilder? _workspaceShellBuilder;
void configureSalesFeatureHost(SalesWorkspaceShellBuilder builder) =>
    _workspaceShellBuilder = builder;
Widget buildSalesWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _workspaceShellBuilder;
  if (builder == null)
    throw StateError('Sales feature host is not configured.');
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}
