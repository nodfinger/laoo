import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef KnowledgeShell =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
KnowledgeShell? _shell;
typedef KnowledgeUpload =
    Future<dynamic> Function(
      String path, {
      required String fileName,
      required List<int> bytes,
      Map<String, String>? fields,
    });
JsonApiClient Function()? _api;
void Function(JsonApiClient)? _dispose;
LaooWorkspaceUiTokens Function()? _tokens;
Future<String> Function(String, String)? _title;
void Function(BuildContext, {required String message, required bool error})?
_message;
KnowledgeUpload? _upload;

void configureKnowledgeFeatureHost(
  KnowledgeShell shell, {
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
  KnowledgeUpload? upload,
}) {
  _shell = shell;
  _api = apiClientFactory;
  _dispose = apiClientDisposer;
  _tokens = uiTokensProvider;
  _title = menuTitleResolver;
  _message = messagePresenter;
  _upload = upload;
}

JsonApiClient createKnowledgeApi() => _api!.call();
void disposeKnowledgeApi(JsonApiClient value) => _dispose?.call(value);
LaooWorkspaceUiTokens get knowledgeTokens => _tokens!.call();
Future<String> knowledgeTitle(String code, String fallback) =>
    _title?.call(code, fallback) ?? Future.value(fallback);
void knowledgeMessage(
  BuildContext context,
  String message, {
  bool error = false,
}) => _message?.call(context, message: message, error: error);
Future<dynamic> uploadKnowledgeFile(
  String path, {
  required String fileName,
  required List<int> bytes,
  Map<String, String>? fields,
}) =>
    _upload?.call(path, fileName: fileName, bytes: bytes, fields: fields) ??
    (throw StateError('Knowledge upload is not configured.'));
Widget knowledgeShell({
  required String title,
  required String menu,
  required Widget child,
}) => _shell!.call(pageTitle: title, activeMenu: menu, child: child);
