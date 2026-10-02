import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef DocumentControlWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

DocumentControlWorkspaceShellBuilder? _shell;
typedef DocumentControlUpload =
    Future<dynamic> Function(
      String path, {
      required String fileName,
      required List<int> bytes,
      Map<String, String>? fields,
    });
typedef DocumentControlFilePresenter =
    Future<void> Function(
      BuildContext context, {
      required String path,
      required String fileName,
      required String contentType,
      required bool download,
    });
JsonApiClient Function()? _apiFactory;
void Function(JsonApiClient)? _apiDisposer;
LaooWorkspaceUiTokens Function()? _tokens;
Future<String> Function(String, String)? _title;
void Function(BuildContext, {required String message, required bool error})?
_message;
DocumentControlUpload? _upload;
DocumentControlFilePresenter? _filePresenter;

void configureDocumentControlFeatureHost(
  DocumentControlWorkspaceShellBuilder builder, {
  JsonApiClient Function()? apiClientFactory,
  void Function(JsonApiClient)? apiClientDisposer,
  LaooWorkspaceUiTokens Function()? uiTokensProvider,
  Future<String> Function(String, String)? menuTitleResolver,
  void Function(BuildContext, {required String message, required bool error})?
  messagePresenter,
  DocumentControlUpload? upload,
  DocumentControlFilePresenter? filePresenter,
}) {
  _shell = builder;
  _apiFactory = apiClientFactory;
  _apiDisposer = apiClientDisposer;
  _tokens = uiTokensProvider;
  _title = menuTitleResolver;
  _message = messagePresenter;
  _upload = upload;
  _filePresenter = filePresenter;
}

JsonApiClient createDocumentControlApiClient() =>
    _apiFactory?.call() ??
    (throw StateError('Document Control API client is not configured.'));
void disposeDocumentControlApiClient(JsonApiClient client) =>
    _apiDisposer?.call(client);
LaooWorkspaceUiTokens get documentControlUiTokens =>
    _tokens?.call() ??
    (throw StateError('Document Control UI tokens are not configured.'));
Future<String> resolveDocumentControlMenuTitle(String code, String fallback) =>
    _title?.call(code, fallback) ?? Future.value(fallback);
void showDocumentControlMessage(
  BuildContext context, {
  required String message,
  bool error = false,
}) => _message?.call(context, message: message, error: error);
Future<dynamic> uploadDocumentControlFile(
  String path, {
  required String fileName,
  required List<int> bytes,
  Map<String, String>? fields,
}) =>
    _upload?.call(path, fileName: fileName, bytes: bytes, fields: fields) ??
    (throw StateError('Document Control upload is not configured.'));
Future<void> presentDocumentControlFile(
  BuildContext context, {
  required String path,
  required String fileName,
  required String contentType,
  required bool download,
}) =>
    _filePresenter?.call(
      context,
      path: path,
      fileName: fileName,
      contentType: contentType,
      download: download,
    ) ??
    (throw StateError('Document Control file presenter is not configured.'));
Widget buildDocumentControlWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) =>
    _shell?.call(pageTitle: pageTitle, activeMenu: activeMenu, child: child) ??
    (throw StateError('Document Control feature host is not configured.'));
