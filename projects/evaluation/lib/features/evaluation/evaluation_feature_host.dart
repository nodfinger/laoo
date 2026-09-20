export '../../evaluation_feature.dart'
    show
        EvaluationMenuCodes,
        EvaluationProject,
        EvaluationRouteNames,
        EvaluationRoutePaths,
        EvaluationRoutes;
import 'package:flutter/widgets.dart';

typedef EvaluationWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
EvaluationWorkspaceShellBuilder? _builder;
void configureEvaluationFeatureHost(EvaluationWorkspaceShellBuilder builder) =>
    _builder = builder;
Widget buildEvaluationWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _builder;
  if (builder == null)
    throw StateError('Evaluation feature host is not configured.');
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}
