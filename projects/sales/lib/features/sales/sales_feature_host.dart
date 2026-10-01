import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef SalesWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
SalesWorkspaceShellBuilder? _shell;
JsonApiClient Function()? _apiFactory;
void Function(JsonApiClient)? _apiDisposer;
LaooWorkspaceUiTokens Function()? _tokens;
Future<String> Function(String, String)? _title;
void Function(BuildContext, {required String message, required bool error})?
_message;

void configureSalesFeatureHost(
  SalesWorkspaceShellBuilder builder, {
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
  _shell = builder;
  _apiFactory = apiClientFactory;
  _apiDisposer = apiClientDisposer;
  _tokens = uiTokensProvider;
  _title = menuTitleResolver;
  _message = messagePresenter;
}

JsonApiClient createSalesApiClient() =>
    _apiFactory?.call() ??
    (throw StateError('Sales API client is not configured.'));
void disposeSalesApiClient(JsonApiClient client) => _apiDisposer?.call(client);
LaooWorkspaceUiTokens get salesUiTokens =>
    _tokens?.call() ??
    (throw StateError('Sales UI tokens are not configured.'));
Future<String> resolveSalesMenuTitle(String code, String fallback) =>
    _title?.call(code, fallback) ?? Future.value(fallback);
void showSalesMessage(
  BuildContext context, {
  required String message,
  bool error = false,
}) => _message?.call(context, message: message, error: error);
Widget buildSalesWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) =>
    _shell?.call(pageTitle: pageTitle, activeMenu: activeMenu, child: child) ??
    (throw StateError('Sales feature host is not configured.'));
