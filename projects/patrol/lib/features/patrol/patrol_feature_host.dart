import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef PatrolShell =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
PatrolShell? _shell;
JsonApiClient Function()? _apiFactory;
void Function(JsonApiClient)? _dispose;
LaooWorkspaceUiTokens Function()? _tokens;
Future<String> Function(String, String)? _title;
void Function(BuildContext, {required String message, required bool error})?
_message;

void configurePatrolFeatureHost(
  PatrolShell shell, {
  JsonApiClient Function()? apiClientFactory,
  void Function(JsonApiClient)? apiClientDisposer,
  LaooWorkspaceUiTokens Function()? uiTokensProvider,
  Future<String> Function(String, String)? menuTitleResolver,
  void Function(BuildContext, {required String message, required bool error})?
  messagePresenter,
}) {
  _shell = shell;
  _apiFactory = apiClientFactory;
  _dispose = apiClientDisposer;
  _tokens = uiTokensProvider;
  _title = menuTitleResolver;
  _message = messagePresenter;
}

JsonApiClient createPatrolApi() =>
    _apiFactory?.call() ?? (throw StateError('Patrol API is not configured'));
void disposePatrolApi(JsonApiClient api) => _dispose?.call(api);
LaooWorkspaceUiTokens get patrolTokens =>
    _tokens?.call() ??
    (throw StateError('Patrol UI tokens are not configured'));
Future<String> patrolTitle(String code, String fallback) =>
    _title?.call(code, fallback) ?? Future.value(fallback);
void patrolMessage(
  BuildContext context, {
  required String message,
  bool error = false,
}) => _message?.call(context, message: message, error: error);
Widget patrolShell({
  required String title,
  required String menu,
  required Widget child,
}) =>
    _shell?.call(pageTitle: title, activeMenu: menu, child: child) ??
    (throw StateError('Patrol shell is not configured'));
