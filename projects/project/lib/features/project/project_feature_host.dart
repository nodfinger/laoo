import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef ProjectWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
ProjectWorkspaceShellBuilder? _shell;
JsonApiClient Function()? _apiFactory;
void Function(JsonApiClient)? _apiDisposer;
LaooWorkspaceUiTokens Function()? _tokens;
Future<String> Function(String, String)? _title;
void Function(BuildContext, {required String message, required bool error})?
_message;
void configureProjectFeatureHost(
  ProjectWorkspaceShellBuilder builder, {
  JsonApiClient Function()? apiClientFactory,
  void Function(JsonApiClient)? apiClientDisposer,
  LaooWorkspaceUiTokens Function()? uiTokensProvider,
  Future<String> Function(String, String)? menuTitleResolver,
  void Function(BuildContext, {required String message, required bool error})?
  messagePresenter,
}) {
  _shell = builder;
  _apiFactory = apiClientFactory;
  _apiDisposer = apiClientDisposer;
  _tokens = uiTokensProvider;
  _title = menuTitleResolver;
  _message = messagePresenter;
}

JsonApiClient createProjectApiClient() =>
    _apiFactory?.call() ??
    (throw StateError('Project API client is not configured.'));
void disposeProjectApiClient(JsonApiClient c) => _apiDisposer?.call(c);
LaooWorkspaceUiTokens get projectUiTokens =>
    _tokens?.call() ??
    (throw StateError('Project UI tokens are not configured.'));
Future<String> resolveProjectMenuTitle(String c, String f) =>
    _title?.call(c, f) ?? Future.value(f);
void showProjectMessage(
  BuildContext c, {
  required String message,
  bool error = false,
}) => _message?.call(c, message: message, error: error);
Widget buildProjectWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) =>
    _shell?.call(pageTitle: pageTitle, activeMenu: activeMenu, child: child) ??
    (throw StateError('Project feature host is not configured.'));
