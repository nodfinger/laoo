import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef IntranetWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

IntranetWorkspaceShellBuilder? _workspaceShellBuilder;
JsonApiClient Function()? _apiFactory;
void Function(JsonApiClient)? _apiDisposer;
LaooWorkspaceUiTokens Function()? _tokens;
Future<String> Function(String, String)? _title;
void Function(BuildContext, {required String message, required bool error})?
_message;

void configureIntranetFeatureHost(
  IntranetWorkspaceShellBuilder builder, {
  JsonApiClient Function()? apiClientFactory,
  void Function(JsonApiClient)? apiClientDisposer,
  LaooWorkspaceUiTokens Function()? uiTokensProvider,
  Future<String> Function(String menuCode, String fallback)? menuTitleResolver,
  void Function(
    BuildContext context, {
    required String message,
    required bool error,
  })?
  messagePresenter,
}) {
  _workspaceShellBuilder = builder;
  _apiFactory = apiClientFactory;
  _apiDisposer = apiClientDisposer;
  _tokens = uiTokensProvider;
  _title = menuTitleResolver;
  _message = messagePresenter;
}

JsonApiClient createIntranetApiClient() =>
    _apiFactory?.call() ??
    (throw StateError('Intranet API client is not configured.'));
void disposeIntranetApiClient(JsonApiClient client) =>
    _apiDisposer?.call(client);
LaooWorkspaceUiTokens get intranetUiTokens =>
    _tokens?.call() ??
    (throw StateError('Intranet UI tokens are not configured.'));
Future<String> resolveIntranetMenuTitle(String code, String fallback) =>
    _title?.call(code, fallback) ?? Future.value(fallback);
void showIntranetMessage(
  BuildContext context, {
  required String message,
  bool error = false,
}) => _message?.call(context, message: message, error: error);

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
