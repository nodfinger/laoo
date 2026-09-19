import 'package:flutter/widgets.dart';

typedef PosWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

PosWorkspaceShellBuilder? _workspaceShellBuilder;

void configurePosFeatureHost(PosWorkspaceShellBuilder builder) =>
    _workspaceShellBuilder = builder;

Widget buildPosWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _workspaceShellBuilder;
  if (builder == null) {
    throw StateError('POS feature host is not configured.');
  }
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}
