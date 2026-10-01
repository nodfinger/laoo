import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef FiveSWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
typedef FiveSUpload =
    Future<dynamic> Function(
      String path, {
      required String fileName,
      required List<int> bytes,
      Map<String, String>? fields,
    });

FiveSWorkspaceShellBuilder? _workspaceShellBuilder;
JsonApiClient Function()? _apiFactory;
void Function(JsonApiClient)? _apiDisposer;
LaooWorkspaceUiTokens Function()? _tokensProvider;
Future<String> Function(String menuCode, String fallback)? _titleResolver;
void Function(
  BuildContext context, {
  required String message,
  required bool error,
})?
_messagePresenter;
FiveSUpload? _upload;

void configureFiveSFeatureHost(
  FiveSWorkspaceShellBuilder builder, {
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
  FiveSUpload? upload,
}) {
  _workspaceShellBuilder = builder;
  _apiFactory = apiClientFactory;
  _apiDisposer = apiClientDisposer;
  _tokensProvider = uiTokensProvider;
  _titleResolver = menuTitleResolver;
  _messagePresenter = messagePresenter;
  _upload = upload;
}

JsonApiClient createFiveSApiClient() =>
    _apiFactory?.call() ??
    (throw StateError('5S API client is not configured.'));

void disposeFiveSApiClient(JsonApiClient client) => _apiDisposer?.call(client);

LaooWorkspaceUiTokens get fiveSUiTokens =>
    _tokensProvider?.call() ??
    (throw StateError('5S UI tokens are not configured.'));

Future<String> resolveFiveSMenuTitle(String menuCode, String fallback) =>
    _titleResolver?.call(menuCode, fallback) ?? Future.value(fallback);

void showFiveSMessage(
  BuildContext context, {
  required String message,
  bool error = false,
}) => _messagePresenter?.call(context, message: message, error: error);

Future<dynamic> uploadFiveSFile(
  String path, {
  required String fileName,
  required List<int> bytes,
  Map<String, String>? fields,
}) =>
    _upload?.call(path, fileName: fileName, bytes: bytes, fields: fields) ??
    (throw StateError('5S upload is not configured.'));

Widget buildFiveSWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _workspaceShellBuilder;
  if (builder == null) {
    throw StateError('5S feature host is not configured.');
  }
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}
