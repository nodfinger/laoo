import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef ProviderShell =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
typedef ProviderUpload =
    Future<dynamic> Function(
      String path, {
      required String fileName,
      required List<int> bytes,
      Map<String, String>? fields,
    });
ProviderShell? _shell;
JsonApiClient Function()? _api;
void Function(JsonApiClient)? _dispose;
LaooWorkspaceUiTokens Function()? _tokens;
Future<String> Function(String, String)? _title;
void Function(BuildContext, {required String message, required bool error})?
_message;
ProviderUpload? _upload;
void configureProviderFeatureHost(
  ProviderShell shell, {
  required JsonApiClient Function() apiClientFactory,
  required void Function(JsonApiClient) apiClientDisposer,
  required LaooWorkspaceUiTokens Function() uiTokensProvider,
  required Future<String> Function(String, String) menuTitleResolver,
  required void Function(
    BuildContext, {
    required String message,
    required bool error,
  })
  messagePresenter,
  ProviderUpload? upload,
}) {
  _shell = shell;
  _api = apiClientFactory;
  _dispose = apiClientDisposer;
  _tokens = uiTokensProvider;
  _title = menuTitleResolver;
  _message = messagePresenter;
  _upload = upload;
}

JsonApiClient createProviderApi() => _api!.call();
void disposeProviderApi(JsonApiClient value) => _dispose?.call(value);
LaooWorkspaceUiTokens get providerTokens => _tokens!.call();
Future<String> providerTitle(String code, String fallback) =>
    _title?.call(code, fallback) ?? Future.value(fallback);
void providerMessage(
  BuildContext context,
  String message, {
  bool error = false,
}) => _message?.call(context, message: message, error: error);
Future<dynamic> uploadProviderFile(
  String path, {
  required String fileName,
  required List<int> bytes,
  Map<String, String>? fields,
}) =>
    _upload?.call(path, fileName: fileName, bytes: bytes, fields: fields) ??
    (throw StateError('Provider upload is not configured.'));
Widget providerShell({
  required String title,
  required String menu,
  required Widget child,
}) => _shell!.call(pageTitle: title, activeMenu: menu, child: child);
