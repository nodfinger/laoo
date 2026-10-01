import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef ExpenseWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
ExpenseWorkspaceShellBuilder? _shell;
JsonApiClient Function()? _apiFactory;
void Function(JsonApiClient)? _apiDisposer;
LaooWorkspaceUiTokens Function()? _tokens;
Future<String> Function(String, String)? _title;
void Function(BuildContext, {required String message, required bool error})?
_message;
void configureExpenseFeatureHost(
  ExpenseWorkspaceShellBuilder builder, {
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

JsonApiClient createExpenseApiClient() =>
    _apiFactory?.call() ??
    (throw StateError('Expense API client is not configured.'));
void disposeExpenseApiClient(JsonApiClient client) =>
    _apiDisposer?.call(client);
LaooWorkspaceUiTokens get expenseUiTokens =>
    _tokens?.call() ??
    (throw StateError('Expense UI tokens are not configured.'));
Future<String> resolveExpenseMenuTitle(String code, String fallback) =>
    _title?.call(code, fallback) ?? Future.value(fallback);
void showExpenseMessage(
  BuildContext context, {
  required String message,
  bool error = false,
}) => _message?.call(context, message: message, error: error);
Widget buildExpenseWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) =>
    _shell?.call(pageTitle: pageTitle, activeMenu: activeMenu, child: child) ??
    (throw StateError('Expense feature host is not configured.'));
