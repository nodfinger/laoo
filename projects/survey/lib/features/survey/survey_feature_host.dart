import 'package:flutter/widgets.dart';

typedef SurveyWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
SurveyWorkspaceShellBuilder? _workspaceShellBuilder;

void configureSurveyFeatureHost(SurveyWorkspaceShellBuilder builder) =>
    _workspaceShellBuilder = builder;

Widget buildSurveyWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _workspaceShellBuilder;
  if (builder == null)
    throw StateError('Survey feature host is not configured.');
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}
