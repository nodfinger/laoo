export '../../evaluation_feature.dart'
    show
        EvaluationMenuCodes,
        EvaluationProject,
        EvaluationRouteNames,
        EvaluationRoutePaths,
        EvaluationRoutes;
import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

typedef EvaluationWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
typedef EvaluationMessagePresenter =
    void Function(
      BuildContext context, {
      required String message,
      required bool error,
    });
EvaluationWorkspaceShellBuilder? _builder;
JsonApiClient Function()? _apiFactory;
void Function(JsonApiClient)? _apiDisposer;
EvaluationMessagePresenter? _messagePresenter;
void configureEvaluationFeatureHost(
  EvaluationWorkspaceShellBuilder builder, {
  required JsonApiClient Function() apiClientFactory,
  required void Function(JsonApiClient) apiClientDisposer,
  EvaluationMessagePresenter? messagePresenter,
}) {
  _builder = builder;
  _apiFactory = apiClientFactory;
  _apiDisposer = apiClientDisposer;
  _messagePresenter = messagePresenter;
}

Widget buildEvaluationWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _builder;
  if (builder == null) {
    throw StateError('Evaluation feature host is not configured.');
  }
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}

JsonApiClient createEvaluationApiClient() =>
    _apiFactory?.call() ??
    (throw StateError('Evaluation API client is not configured.'));
void disposeEvaluationApiClient(JsonApiClient client) =>
    _apiDisposer?.call(client);

void showEvaluationMessage(
  BuildContext context, {
  required String message,
  bool error = false,
}) => _messagePresenter?.call(context, message: message, error: error);
