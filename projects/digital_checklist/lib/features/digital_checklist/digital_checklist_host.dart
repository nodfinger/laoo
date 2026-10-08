import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef DigitalChecklistShell =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
typedef DigitalChecklistUploader =
    Future<dynamic> Function(
      String path, {
      required String fileName,
      required List<int> bytes,
      required Map<String, String> fields,
    });
DigitalChecklistShell? _shell;
JsonApiClient Function()? _api;
LaooWorkspaceUiTokens Function()? _tokens;
Future<String> Function(String, String)? _title;
void Function(BuildContext, {required String message, required bool error})?
_message;
void Function(JsonApiClient)? _dispose;
DigitalChecklistUploader? _upload;
void configureDigitalChecklistFeature({
  required DigitalChecklistShell shell,
  required JsonApiClient Function() api,
  required void Function(JsonApiClient) dispose,
  required DigitalChecklistUploader upload,
  required LaooWorkspaceUiTokens Function() tokens,
  required Future<String> Function(String, String) title,
  required void Function(
    BuildContext, {
    required String message,
    required bool error,
  })
  message,
}) {
  _shell = shell;
  _api = api;
  _dispose = dispose;
  _upload = upload;
  _tokens = tokens;
  _title = title;
  _message = message;
}

Widget checklistShell({
  required String title,
  required String menu,
  required Widget child,
}) => _shell?.call(pageTitle: title, activeMenu: menu, child: child) ?? child;
JsonApiClient checklistApi() =>
    _api?.call() ??
    (throw StateError('Digital Checklist API is not configured'));
void disposeChecklistApi(JsonApiClient api) => _dispose?.call(api);
Future<dynamic> uploadChecklistEvidence(
  String path, {
  required String fileName,
  required List<int> bytes,
  required Map<String, String> fields,
}) =>
    _upload?.call(path, fileName: fileName, bytes: bytes, fields: fields) ??
    Future.error(StateError('Digital Checklist upload is not configured'));
LaooWorkspaceUiTokens get checklistTokens =>
    _tokens?.call() ??
    (throw StateError('Digital Checklist tokens are not configured'));
Future<String> checklistTitle(String code, String fallback) =>
    _title?.call(code, fallback) ?? Future.value(fallback);
void checklistMessage(
  BuildContext context, {
  required String message,
  bool error = false,
}) => _message?.call(context, message: message, error: error);
