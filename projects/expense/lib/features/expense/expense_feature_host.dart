import 'package:flutter/widgets.dart';

typedef ExpenseWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
ExpenseWorkspaceShellBuilder? _workspaceShellBuilder;
void configureExpenseFeatureHost(ExpenseWorkspaceShellBuilder builder) =>
    _workspaceShellBuilder = builder;
Widget buildExpenseWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _workspaceShellBuilder;
  if (builder == null)
    throw StateError('Expense feature host is not configured.');
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}
