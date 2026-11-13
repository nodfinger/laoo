import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef PurchasingWorkspaceShellBuilder = Widget Function({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
});
typedef PurchasingUpload = Future<dynamic> Function(
  String path,
  List<int> bytes,
  String fileName,
  Map<String, String> fields,
);

PurchasingWorkspaceShellBuilder? _shell;
JsonApiClient Function()? _apiFactory;
void Function(JsonApiClient)? _apiDisposer;
LaooWorkspaceUiTokens Function()? _tokens;
Future<String> Function(String, String)? _title;
void Function(BuildContext, {required String message, required bool error})?
    _message;
PurchasingUpload? _upload;

void configurePurchasingFeatureHost(
  PurchasingWorkspaceShellBuilder builder, {
  JsonApiClient Function()? apiClientFactory,
  void Function(JsonApiClient)? apiClientDisposer,
  LaooWorkspaceUiTokens Function()? uiTokensProvider,
  Future<String> Function(String menuCode, String fallback)? menuTitleResolver,
  void Function(BuildContext, {required String message, required bool error})?
      messagePresenter,
  PurchasingUpload? upload,
}) {
  _shell = builder;
  _apiFactory = apiClientFactory;
  _apiDisposer = apiClientDisposer;
  _tokens = uiTokensProvider;
  _title = menuTitleResolver;
  _message = messagePresenter;
  _upload = upload;
}

JsonApiClient createPurchasingApiClient() =>
    _apiFactory?.call() ??
    (throw StateError('Purchasing API client is not configured.'));
void disposePurchasingApiClient(JsonApiClient client) => _apiDisposer?.call(client);
LaooWorkspaceUiTokens get purchasingUiTokens =>
    _tokens?.call() ?? (throw StateError('Purchasing UI tokens are not configured.'));
Future<String> resolvePurchasingMenuTitle(String code, String fallback) =>
    _title?.call(code, fallback) ?? Future.value(fallback);
PurchasingUpload? get purchasingUpload => _upload;
void showPurchasingMessage(BuildContext context,
    {required String message, bool error = false}) =>
    _message?.call(context, message: message, error: error);

Widget buildPurchasingWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) =>
    _shell?.call(pageTitle: pageTitle, activeMenu: activeMenu, child: child) ??
    (throw StateError('Purchasing feature host is not configured.'));
