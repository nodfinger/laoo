import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef SiteShell =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

late SiteShell siteShell;
late JsonApiClient Function() siteApi;
late void Function(JsonApiClient) siteDispose;
late LaooWorkspaceUiTokens Function() siteTokens;
late IconData Function(String?) siteMenuIcon;
late String Function(Object error, String action) siteErrorText;
late void Function(BuildContext, {required String message, required bool error})
siteMessage;
late Future<dynamic> Function(
  String path, {
  required String fileName,
  required List<int> bytes,
  required Map<String, String> fields,
})
siteUpload;
late Future<List<int>> Function(String path) siteDownload;
late String sitePublicApiBaseUrl;
late String? Function() siteDraftScope;

void configureSiteFeatureHost({
  required SiteShell shell,
  required JsonApiClient Function() api,
  required void Function(JsonApiClient) dispose,
  required LaooWorkspaceUiTokens Function() tokens,
  required IconData Function(String?) menuIcon,
  required String Function(Object error, String action) errorText,
  required void Function(
    BuildContext, {
    required String message,
    required bool error,
  })
  message,
  required Future<dynamic> Function(
    String path, {
    required String fileName,
    required List<int> bytes,
    required Map<String, String> fields,
  })
  upload,
  required Future<List<int>> Function(String path) download,
  required String publicApiBaseUrl,
  required String? Function() draftScope,
}) {
  siteShell = shell;
  siteApi = api;
  siteDispose = dispose;
  siteTokens = tokens;
  siteMenuIcon = menuIcon;
  siteErrorText = errorText;
  siteMessage = message;
  siteUpload = upload;
  siteDownload = download;
  sitePublicApiBaseUrl = publicApiBaseUrl;
  siteDraftScope = draftScope;
}
