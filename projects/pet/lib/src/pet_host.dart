import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef PetShell =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

late PetShell petShell;
late JsonApiClient Function() petApi;
late void Function(JsonApiClient) petDispose;
late LaooWorkspaceUiTokens Function() petTokens;
late IconData Function(String?) petMenuIcon;
late String Function(Object error, String action) petErrorText;
late String Function(DateTime date) petDateFormat;
late Future<dynamic> Function(
  String path, {
  required String fileName,
  required List<int> bytes,
  required Map<String, String> fields,
})
petUpload;
late Future<List<int>> Function(String path) petDownload;
late void Function(BuildContext, {required String message, required bool error})
petMessage;

void configurePetFeatureHost({
  required PetShell shell,
  required JsonApiClient Function() api,
  required void Function(JsonApiClient) dispose,
  required LaooWorkspaceUiTokens Function() tokens,
  required IconData Function(String?) menuIcon,
  required String Function(Object error, String action) errorText,
  required String Function(DateTime date) dateFormat,
  required Future<dynamic> Function(
    String path, {
    required String fileName,
    required List<int> bytes,
    required Map<String, String> fields,
  })
  upload,
  required Future<List<int>> Function(String path) download,
  required void Function(
    BuildContext, {
    required String message,
    required bool error,
  })
  message,
}) {
  petShell = shell;
  petApi = api;
  petDispose = dispose;
  petTokens = tokens;
  petMenuIcon = menuIcon;
  petErrorText = errorText;
  petDateFormat = dateFormat;
  petUpload = upload;
  petDownload = download;
  petMessage = message;
}
