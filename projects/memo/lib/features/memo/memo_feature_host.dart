import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef MemoShell =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
typedef MemoUpload =
    Future<dynamic> Function(
      String path, {
      required String fileName,
      required List<int> bytes,
      Map<String, String>? fields,
    });
MemoShell? _shell;
JsonApiClient Function()? _api;
void Function(JsonApiClient)? _dispose;
MemoUpload? _upload;
LaooWorkspaceUiTokens Function()? _tokens;
Future<String> Function(String, String)? _title;
void Function(BuildContext, {required String message, required bool error})?
_message;
void configureMemoFeatureHost(
  MemoShell shell, {
  required JsonApiClient Function() apiClientFactory,
  required void Function(JsonApiClient) apiClientDisposer,
  required MemoUpload upload,
  required LaooWorkspaceUiTokens Function() uiTokensProvider,
  required Future<String> Function(String, String) menuTitleResolver,
  required void Function(
    BuildContext, {
    required String message,
    required bool error,
  })
  messagePresenter,
}) {
  _shell = shell;
  _api = apiClientFactory;
  _dispose = apiClientDisposer;
  _upload = upload;
  _tokens = uiTokensProvider;
  _title = menuTitleResolver;
  _message = messagePresenter;
}

JsonApiClient memoApi() => _api!.call();
Future<dynamic> memoUpload(
  String path, {
  required String fileName,
  required List<int> bytes,
  Map<String, String>? fields,
}) => _upload!.call(path, fileName: fileName, bytes: bytes, fields: fields);
void disposeMemoApi(JsonApiClient x) => _dispose?.call(x);
LaooWorkspaceUiTokens get memoTokens => _tokens!.call();
Future<String> memoTitle(String c, String f) =>
    _title?.call(c, f) ?? Future.value(f);
void memoMessage(BuildContext c, String m, {bool error = false}) =>
    _message?.call(c, message: m, error: error);
Widget memoShell({
  required String title,
  required String menu,
  required Widget child,
}) => _shell!.call(pageTitle: title, activeMenu: menu, child: child);
