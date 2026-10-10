import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef RentalShell = Widget Function({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
});
typedef RentalUpload = Future<dynamic> Function(
  String path, {
  required String fileName,
  required List<int> bytes,
  required Map<String, String> fields,
});
typedef RentalDownload = Future<void> Function(
  String path, {
  required String fileName,
});

late RentalShell rentalShell;
late JsonApiClient Function() rentalApi;
late void Function(JsonApiClient) rentalDispose;
late RentalUpload rentalUpload;
late RentalDownload rentalDownload;
late LaooWorkspaceUiTokens Function() rentalTokens;
late IconData Function(String?) rentalMenuIcon;
late String Function(Object error, String action) rentalErrorText;
late void Function(BuildContext, {required String message, required bool error})
    rentalMessage;

void configureRentalFeatureHost({
  required RentalShell shell,
  required JsonApiClient Function() api,
  required void Function(JsonApiClient) dispose,
  required RentalUpload upload,
  required RentalDownload download,
  required LaooWorkspaceUiTokens Function() tokens,
  required IconData Function(String?) menuIcon,
  required String Function(Object error, String action) errorText,
  required void Function(
    BuildContext, {
    required String message,
    required bool error,
  })
  message,
}) {
  rentalShell = shell;
  rentalApi = api;
  rentalDispose = dispose;
  rentalUpload = upload;
  rentalDownload = download;
  rentalTokens = tokens;
  rentalMenuIcon = menuIcon;
  rentalErrorText = errorText;
  rentalMessage = message;
}
